#!/bin/bash
set -e

CONFIG_FILE=${1:-node_config.env}

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ 配置文件 $CONFIG_FILE 不存在"
    exit 1
fi
source "$CONFIG_FILE"

echo "✅ 配置文件加载完成"

# 1️⃣ 停止 kubelet 并 reset 节点
echo "1️⃣ 停止 kubelet 并 reset 节点"
sudo systemctl stop kubelet

# 生成 containerd 默认配置（保证 CRI 可用）
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
sleep 2

# 验证 CRI
if ! sudo crictl --runtime-endpoint $CRI_SOCKET info >/dev/null 2>&1; then
    echo "❌ containerd CRI 未就绪，请检查 /var/run/containerd/containerd.sock"
    exit 1
fi
echo "🌟 containerd CRI 已就绪"

sudo kubeadm reset --cri-socket $CRI_SOCKET -f || true

# 2️⃣ 清理 CNI / iptables / IPVS
sudo rm -rf /etc/cni/net.d/*
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
if command -v ipvsadm >/dev/null 2>&1; then
    sudo ipvsadm --clear
fi
rm -f $HOME/.kube/config

# 3️⃣ Join 集群
echo "2️⃣ 开始加入集群 $MASTER_IP"
sudo kubeadm join $MASTER_IP:6443 \
    --token $TOKEN \
    --discovery-token-ca-cert-hash $DISCOVERY_HASH \
    --cri-socket $CRI_SOCKET

echo "✅ 节点已加入集群，请在 master 上查看状态"

