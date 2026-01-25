#!/bin/bash
set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

fail_count=0

ok()   { echo -e "${GREEN}[ OK ]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; fail_count=$((fail_count+1)); }

echo "===== Kubernetes init 前环境检查（Docker + cri-dockerd）====="

# --------------------------------------------------
# 1. 操作系统
# --------------------------------------------------
if [[ -f /etc/os-release ]]; then
  source /etc/os-release
  ok "操作系统: $PRETTY_NAME"
else
  fail "无法识别操作系统"
fi

# --------------------------------------------------
# 2. 内核版本
# --------------------------------------------------
ok "内核版本: $(uname -r)"

# --------------------------------------------------
# 3. Swap
# --------------------------------------------------
if swapon --summary | grep -q .; then
  warn "Swap 已开启（kubeadm 默认不推荐，需 --ignore-preflight-errors=Swap）"
else
  ok "Swap 已关闭"
fi

# --------------------------------------------------
# 4. br_netfilter
# --------------------------------------------------
if [[ -e /sys/module/br_netfilter ]]; then
  ok "br_netfilter 模块已加载"
else
  fail "br_netfilter 模块未加载"
fi


# --------------------------------------------------
# 5. sysctl 参数
# --------------------------------------------------
check_sysctl() {
  local key=$1
  local expect=$2
  local value
  value=$(sysctl -n "$key" 2>/dev/null)
  if [[ "$value" == "$expect" ]]; then
    ok "$key = $value"
  else
    fail "$key = $value（期望 $expect）"
  fi
}

check_sysctl net.bridge.bridge-nf-call-iptables 1
check_sysctl net.ipv4.ip_forward 1

# --------------------------------------------------
# 6. Docker
# --------------------------------------------------
if systemctl is-active --quiet docker; then
  ok "Docker 正在运行"
else
  fail "Docker 未运行"
fi

# --------------------------------------------------
# 7. CRI（强制 cri-dockerd）
# --------------------------------------------------
CRI_SOCKET="/var/run/cri-dockerd.sock"

if ! systemctl is-active --quiet cri-docker.socket; then
  fail "cri-dockerd 未运行"
elif ! command -v crictl &>/dev/null; then
  fail "crictl 未安装，无法验证 CRI"
elif ! crictl --runtime-endpoint "unix://$CRI_SOCKET" info >/dev/null 2>&1; then
  fail "cri-dockerd CRI API 不可用"
else
  ok "CRI 可用：cri-dockerd"
fi

if [[ -S "$CRI_SOCKET" ]]; then
  ok "CRI socket 存在: $CRI_SOCKET"
else
  fail "CRI socket 不存在: $CRI_SOCKET"
fi

# --------------------------------------------------
# 8. Kubernetes 组件
# --------------------------------------------------
for bin in kubeadm kubelet kubectl; do
  if command -v $bin &>/dev/null; then
    ok "$bin 已安装"
  else
    fail "$bin 未安装"
  fi
done

# --------------------------------------------------
# 9. 关键端口
# --------------------------------------------------
check_port() {
  local port=$1
  if ss -lnt | awk '{print $4}' | grep -q ":$port$"; then
    fail "端口 $port 已被占用"
  else
    ok "端口 $port 可用"
  fi
}

check_port 6443
check_port 10250

# --------------------------------------------------
# 10. Kubernetes 镜像拉取验证（致命）
# --------------------------------------------------
IMAGE_REPO="crpi-ckw9ia686aku4y4w.cn-shanghai.personal.cr.aliyuncs.com/tgtech"
K8S_VERSION="3.9"
TEST_IMAGE="$IMAGE_REPO/pause:$K8S_VERSION"

echo "[INFO] 测试 Docker 镜像拉取：$TEST_IMAGE"

if docker pull "$TEST_IMAGE" >/dev/null 2>&1; then
  ok "Kubernetes 镜像可正常拉取"
else
  fail "Docker 无法拉取 Kubernetes 镜像"
  warn "请确认："
  warn "1) docker login 私有仓库已完成"
  warn "2) 镜像 tag 与 Kubernetes 版本一致"
  warn "3) 网络 / DNS / 防火墙"
fi
# --------------------------------------------------
# 11. pause 镜像版本检查（Docker + cri-dockerd）
# --------------------------------------------------
#
# --------------------------------------------------
# 11. pause 镜像版本检查（版本自适应）
# --------------------------------------------------
#
echo "[INFO]===== 检查 CRI pause 镜像版本（自适应） ====="

CRI_SOCKET="/var/run/cri-dockerd.sock"

if ! command -v crictl &>/dev/null; then
  fail "crictl 未安装，无法检查 pause 镜像"
else
  # 1. 从 kubeadm 推导期望 pause 镜像
  EXPECTED_PAUSE_IMAGE=$(kubeadm config images list 2>/dev/null \
    | grep '/pause:' | head -n1)

  if [[ -z "$EXPECTED_PAUSE_IMAGE" ]]; then
    fail "无法从 kubeadm 获取期望的 pause 镜像"
  else
    ok "kubeadm 期望 pause 镜像: $EXPECTED_PAUSE_IMAGE"
  fi

  # 2. 从 cri-dockerd 读取当前 pause 镜像
  ACTUAL_PAUSE_IMAGE=$(crictl --runtime-endpoint "unix://${CRI_SOCKET}" info 2>/dev/null \
    | awk -F'"' '/sandboxImage/ {print $4}')

  if [[ -z "$ACTUAL_PAUSE_IMAGE" ]]; then
    fail "无法获取当前 CRI pause 镜像"
  else
    echo "[INFO] 当前 CRI pause 镜像: $ACTUAL_PAUSE_IMAGE"
  fi

  # 3. 对比
  if [[ "$EXPECTED_PAUSE_IMAGE" == "$ACTUAL_PAUSE_IMAGE" ]]; then
    ok "pause 镜像与 kubeadm 期望一致"
  else
    warn "pause 镜像与 kubeadm 期望不一致"
    warn "期望: $EXPECTED_PAUSE_IMAGE"
    warn "当前: $ACTUAL_PAUSE_IMAGE"
    warn "建议：在 init 前统一 pause 镜像（可使用 fix_cri_pause_version.sh）"
  fi
fi

# --------------------------------------------------
# 总结
# --------------------------------------------------
echo "-----------------------------------"
if [[ $fail_count -eq 0 ]]; then
  echo -e "${GREEN}环境检查通过：可以执行 kubeadm init${NC}"
  echo -e "${GREEN}CRI socket: unix://$CRI_SOCKET${NC}"
else
  echo -e "${RED}环境检查失败：$fail_count 项未通过，请修复后再初始化${NC}"
fi

