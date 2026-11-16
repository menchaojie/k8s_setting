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
# 10 / 11. 按 kubeadm-init.yml 推导期望 pause，并验证拉取与 CRI 配置
# --------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBEADM_CONFIG="${SCRIPT_DIR}/kubeadm-init.yml"
DEFAULT_IMAGE_REPO="crpi-ckw9ia686aku4y4w.cn-shanghai.personal.cr.aliyuncs.com/tgtech"

IMAGE_REPO="$DEFAULT_IMAGE_REPO"
K8S_VER=""
if [[ -f "$KUBEADM_CONFIG" ]]; then
  IMAGE_REPO="$(awk '/^[[:space:]]*imageRepository:/{print $2; exit}' "$KUBEADM_CONFIG")"
  K8S_VER="$(awk '/^[[:space:]]*kubernetesVersion:/{print $2; exit}' "$KUBEADM_CONFIG")"
  [[ -z "$IMAGE_REPO" ]] && IMAGE_REPO="$DEFAULT_IMAGE_REPO"
  ok "读取配置: $KUBEADM_CONFIG"
  echo "[INFO] imageRepository=$IMAGE_REPO"
  [[ -n "$K8S_VER" ]] && echo "[INFO] kubernetesVersion=$K8S_VER"
else
  warn "未找到 $KUBEADM_CONFIG，使用默认 imageRepository"
fi

# 用目标版本列出官方 pause，再换成个人仓前缀（避免 --config 混用 apiVersion 失败）
if [[ -n "$K8S_VER" ]]; then
  PAUSE_FROM_KUBEADM=$(kubeadm config images list --kubernetes-version="$K8S_VER" 2>/dev/null | grep '/pause:' | head -n1 || true)
else
  PAUSE_FROM_KUBEADM=$(kubeadm config images list 2>/dev/null | grep '/pause:' | head -n1 || true)
fi

PAUSE_TAG=""
if [[ -n "$PAUSE_FROM_KUBEADM" ]]; then
  PAUSE_TAG="${PAUSE_FROM_KUBEADM##*:}"
fi
[[ -z "$PAUSE_TAG" ]] && PAUSE_TAG="3.10.2"

EXPECTED_PAUSE_IMAGE="${IMAGE_REPO}/pause:${PAUSE_TAG}"

echo "[INFO] 测试 Docker 镜像拉取：$EXPECTED_PAUSE_IMAGE"
if docker pull "$EXPECTED_PAUSE_IMAGE" >/dev/null 2>&1; then
  ok "Kubernetes pause 镜像可正常拉取"
else
  fail "Docker 无法拉取 pause 镜像: $EXPECTED_PAUSE_IMAGE"
  warn "请确认："
  warn "1) docker login 私有仓库已完成"
  warn "2) 已同步 pause:${PAUSE_TAG} 到个人仓"
  warn "3) 网络 / DNS / 防火墙"
fi

echo "[INFO]===== 检查 CRI pause 镜像版本（自适应） ====="

if ! command -v crictl &>/dev/null; then
  fail "crictl 未安装，无法检查 pause 镜像"
else
  ok "期望 pause 镜像（按 imageRepository + kubeadm tag）: $EXPECTED_PAUSE_IMAGE"

  ACTUAL_PAUSE_IMAGE=$(crictl --runtime-endpoint "unix://${CRI_SOCKET}" info 2>/dev/null \
    | awk -F'"' '/sandboxImage/ {print $4; exit}')

  if [[ -z "$ACTUAL_PAUSE_IMAGE" ]]; then
    fail "无法获取当前 CRI pause 镜像"
  else
    echo "[INFO] 当前 CRI pause 镜像: $ACTUAL_PAUSE_IMAGE"
  fi

  ACTUAL_PAUSE_TAG="${ACTUAL_PAUSE_IMAGE##*:}"

  if [[ "$EXPECTED_PAUSE_IMAGE" == "$ACTUAL_PAUSE_IMAGE" ]]; then
    ok "pause 镜像与期望完全一致"
  elif [[ -n "$ACTUAL_PAUSE_TAG" && "$ACTUAL_PAUSE_TAG" == "$PAUSE_TAG" ]]; then
    ok "pause tag 一致（${PAUSE_TAG}）；仓库前缀不同可接受（个人仓场景）"
    echo "[INFO] 期望: $EXPECTED_PAUSE_IMAGE"
    echo "[INFO] 当前: $ACTUAL_PAUSE_IMAGE"
  else
    warn "pause 镜像与期望不一致"
    warn "期望: $EXPECTED_PAUSE_IMAGE"
    warn "当前: $ACTUAL_PAUSE_IMAGE"
    warn "建议：执行 ./04_manage_cri_pause_version.sh 对齐 pause:${PAUSE_TAG}"
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

