#!/bin/bash
set -e

echo "===== 修复 Kubernetes 网络内核条件 ====="

# 1. 加载 br_netfilter 模块（立即生效）
if lsmod | grep -q br_netfilter; then
  echo "[OK] br_netfilter 模块已加载"
else
  echo "[INFO] 加载 br_netfilter 模块..."
  sudo modprobe br_netfilter
  echo "[OK] br_netfilter 模块已加载"
fi

# 2. 设置 sysctl 参数（立即生效）
echo "[INFO] 设置 sysctl 参数..."
sudo sysctl -w net.bridge.bridge-nf-call-iptables=1
sudo sysctl -w net.ipv4.ip_forward=1

# 3. 写入永久配置（开机自动生效）
echo "[INFO] 写入永久配置..."

sudo tee /etc/modules-load.d/k8s.conf >/dev/null <<EOF
br_netfilter
EOF

sudo tee /etc/sysctl.d/k8s.conf >/dev/null <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# 4. 重新加载 sysctl
sudo sysctl --system >/dev/null

# 5. 验证
echo "----- 验证结果 -----"
lsmod | grep br_netfilter
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.ipv4.ip_forward

echo "[SUCCESS] Kubernetes 网络内核条件已修复"
