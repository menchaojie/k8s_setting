#!/bin/bash

set -e

echo "===> [1/7] 停止 kubelet（如果存在）"
sudo systemctl stop kubelet 2>/dev/null || true

echo "===> [2/7] 卸载 Kubernetes 组件（kubeadm / kubelet / kubectl）"
sudo apt-get purge -y kubeadm kubelet kubectl || true

echo "===> [3/7] 清理 Kubernetes 核心目录"
sudo rm -rf /etc/kubernetes
sudo rm -rf /var/lib/kubelet
sudo rm -rf /var/lib/etcd

echo "===> [4/7] 清理 CNI 网络残留（如果装过网络插件）"
sudo rm -rf /etc/cni
sudo rm -rf /opt/cni
sudo rm -rf /var/lib/cni

echo "===> [5/7] 清理 kubeconfig（避免 kubectl 幻觉）"
rm -rf ~/.kube

echo "===> [6/7] 移除 Kubernetes apt 源（如果存在）"
sudo rm -f /etc/apt/sources.list.d/kubernetes.list

echo "===> [7/7] 刷新 apt 状态"
sudo apt-get update

echo
echo "✅ Kubernetes 已彻底卸载完成"
echo "👉 这台机器现在不再是 Kubernetes 节点"
echo "👉 可以放心重新安装任意版本"
