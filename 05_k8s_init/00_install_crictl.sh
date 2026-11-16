#!/usr/bin/env bash
set -euo pipefail

echo "===== 安装 crictl（cri-tools）====="

CRI_SOCKET="unix:///var/run/cri-dockerd.sock"
CRICTL_YAML="/etc/crictl.yaml"
APT_LIST="/etc/apt/sources.list.d/kubernetes.list"

# -------------------------------------------------
# 1. 已安装则提示并可跳过重装
# -------------------------------------------------
if command -v crictl >/dev/null 2>&1; then
  echo "[INFO] 已检测到 crictl: $(command -v crictl)"
  crictl --version || true
  read -p "是否重新安装 cri-tools？(y/N): " REINSTALL
  if [[ "${REINSTALL}" != "y" && "${REINSTALL}" != "Y" ]]; then
    echo "[INFO] 跳过 apt 安装，继续配置 / 验证"
  else
    NEED_INSTALL=1
  fi
else
  NEED_INSTALL=1
fi

# -------------------------------------------------
# 2. 通过已配置的 Kubernetes apt 源安装 cri-tools
# -------------------------------------------------
if [[ "${NEED_INSTALL:-0}" -eq 1 ]]; then
  if [[ ! -f "${APT_LIST}" ]]; then
    echo "[FAIL] 未找到 ${APT_LIST}"
    echo "       请先执行 04_k8s_core_tools/01_install_kubeadm--core-tools.sh 配置 K8s apt 源"
    exit 1
  fi

  echo "[INFO] 使用 apt 源安装 cri-tools（与 kubeadm 同源）"
  echo "       源文件: ${APT_LIST}"
  sed 's/^/       /' "${APT_LIST}"

  sudo apt-get update
  sudo apt-get install -y cri-tools

  if ! command -v crictl >/dev/null 2>&1; then
    echo "[FAIL] cri-tools 安装后仍找不到 crictl"
    exit 1
  fi
fi

# -------------------------------------------------
# 3. 写入默认 endpoint（指向 cri-dockerd）
# -------------------------------------------------
echo "[INFO] 写入 ${CRICTL_YAML}"
sudo tee "${CRICTL_YAML}" >/dev/null <<EOF
runtime-endpoint: ${CRI_SOCKET}
image-endpoint: ${CRI_SOCKET}
timeout: 10
debug: false
EOF

# -------------------------------------------------
# 4. 验证
# -------------------------------------------------
echo "[INFO] 验证 crictl"
crictl --version

if [[ -S /var/run/cri-dockerd.sock ]]; then
  if crictl info >/dev/null 2>&1; then
    echo "[OK] crictl 可连接 cri-dockerd"
  else
    echo "[WARN] crictl 已安装，但暂时无法 info（请确认 cri-docker.socket/service 已启动）"
    echo "       可手动检查: systemctl status cri-docker.socket --no-pager"
  fi
else
  echo "[WARN] 未找到 /var/run/cri-dockerd.sock（请先完成 03_cri-dockerd 安装）"
fi

echo "===== crictl 安装完成 ====="
echo "下一步可执行: ./01_init_k8s_preflight.sh"
