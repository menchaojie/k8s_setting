#!/bin/bash
set -e

echo "[1/5] 停止 kubelet..."
sudo systemctl stop kubelet

# 检测 CRI
if [ -S /var/run/cri-dockerd.sock ]; then
    CRI_SOCKET="unix:///var/run/cri-dockerd.sock"
    echo "[+] Docker CRI detected, using $CRI_SOCKET"
elif [ -S /var/run/containerd/containerd.sock ]; then
    CRI_SOCKET="unix:///var/run/containerd/containerd.sock"
    echo "[+] containerd detected, using $CRI_SOCKET"
else
    echo "[-] No CRI detected! Exiting."
    exit 1
fi

echo "[2/5] 重置 kubeadm..."
sudo kubeadm reset -f --cri-socket=$CRI_SOCKET --ignore-preflight-errors=Swap

echo "[3/5] 清理旧证书和配置..."
sudo rm -rf /etc/kubernetes/pki
sudo rm -rf /etc/kubernetes/*.conf
sudo rm -rf ~/.kube

echo "[4/5] 删除旧的 etcd 数据和 kubelet 状态..."
sudo rm -rf /var/lib/etcd
sudo rm -rf /var/lib/kubelet/*

echo "[5/5] 检查端口 6443 占用..."
if lsof -i :6443 >/dev/null; then
    echo "[-] Port 6443 is still in use! Please kill the process occupying it before proceeding."
    lsof -i :6443
    exit 1
fi

echo "环境清理完成，CRI socket: $CRI_SOCKET"
