#!/bin/bash
set -e

# 支持配置文件，也可直接指定 CRI socket
CONFIG_FILE=${1:-node_config.env}
CRI_SOCKET=${2:-/var/run/containerd/containerd.sock}

# 加载配置文件（可选）
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    echo "✅ 配置文件 $CONFIG_FILE 加载完成"
fi

echo "1️⃣ 停止 kubelet 并 reset 节点"
sudo systemctl stop kubelet

# kubeadm reset
sudo kubeadm reset --cri-socket $CRI_SOCKET -f || true

echo "2️⃣ 清理 CNI 配置和 iptables"
sudo rm -rf /etc/cni/net.d/*
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F

# 清理 IPVS（如果已安装）
if command -v ipvsadm >/dev/null 2>&1; then
    sudo ipvsadm --clear
else
    echo "⚠️ ipvsadm 未安装，跳过清理 IPVS 表"
fi

echo "3️⃣ 清理 kubeconfig 文件"
rm -f $HOME/.kube/config

echo "✅ 节点已 reset 并清理完成"

