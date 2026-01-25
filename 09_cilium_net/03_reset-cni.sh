#!/bin/bash
set -e

echo "=== [Step 1] 停止 kubelet ==="
sudo systemctl stop kubelet

echo "=== [Step 2] 清理旧 CNI 配置 ==="
sudo rm -rf /etc/cni/net.d/*
sudo rm -rf /opt/cni/bin/*

echo "=== [Step 3] 清理 flannel / cilium 运行时残留 ==="
sudo rm -rf /run/flannel
sudo rm -rf /var/run/cilium
sudo rm -rf /var/lib/cilium

echo "=== [Step 4] 确认 CNI 目录为空 ==="
ls -ld /etc/cni/net.d /opt/cni/bin

read -p "确认以上目录已清空，按 Enter 继续..."

echo "=== [Step 5] 启动 kubelet ==="
sudo systemctl start kubelet

echo "=== 完成：节点已回到“无 CNI 裸状态” ==="

