#!/usr/bin/env bash

set -e

echo ">>>>>>>>>>>>>>>>>>>>>>下载 gpg key:"
curl -fsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.35/deb/Release.key |sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo ">>>>>>>>>>>>>>>>>>>>>增加 apt 源:"
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.35/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

echo ">>>>>>>>>>>>>>>>>>>>>apt 更新:"
sudo apt-get update

echo ">>>>>>>>>>>>>>>>>>>>>安装 kubelet kubeadm kubectl等核心工具:"
sudo apt-get install -y kubelet kubeadm kubectl

echo ">>>>>>>>>>>>>>>>>>>验证 kubelet :"
kubelet --version

echo ">>>>>>>>>>>>>>>>>>>验证 kubeadm :"
kubeadm version

echo ">>>>>>>>>>>>>>>>>>>验证 kubectl :"
kubectl version --client

echo "=======================安装结束=========================="
