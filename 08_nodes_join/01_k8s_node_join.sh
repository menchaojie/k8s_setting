#!/bin/bash
set -e

CONFIG_FILE=${1:-node_config.env}

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ 配置文件 $CONFIG_FILE 不存在"
    exit 1
fi

# 加载配置
source "$CONFIG_FILE"
echo "✅ 配置文件加载完成"
echo "MASTER_IP=$MASTER_IP"
echo "CRI_SOCKET=$CRI_SOCKET"

# 确保 containerd 正常
echo "🌟 确保 containerd 运行"
sudo systemctl restart containerd
sudo systemctl status containerd | grep "active (running)" >/dev/null || {
    echo "❌ containerd 未启动，请先排查"
    exit 1
}

# join 集群（不使用 --image-repository 避免 unknown flag）
echo "🌟 开始加入集群 $MASTER_IP"
sudo kubeadm join $MASTER_IP:6443 \
    --token $TOKEN \
    --discovery-token-ca-cert-hash $DISCOVERY_HASH \
    --cri-socket $CRI_SOCKET

echo "✅ Join 命令已执行，请在 master 节点查看 Node 状态"

