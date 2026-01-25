#!/usr/bin/env bash
set -e

read -p "请输入 Kubernetes 主版本（例如 1.28, 1.35）: " K8S_VERSION

if [[ ! "$K8S_VERSION" =~ ^1\.[0-9]+$ ]]; then
  echo "❌ 版本格式错误，应类似：1.28"
  exit 1
fi

APT_VERSION="v${K8S_VERSION}"

echo "================ Kubernetes ${APT_VERSION} 安装开始 ================"

echo ">>> 创建 keyrings 目录"
sudo mkdir -p /etc/apt/keyrings

echo ">>> 下载 Kubernetes GPG key"
curl -fsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/${APT_VERSION}/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo ">>> 添加 Kubernetes apt 源"
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://mirrors.aliyun.com/kubernetes-new/core/stable/${APT_VERSION}/deb/ /" \
| sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

echo ">>> apt update"
sudo apt-get update

echo ">>> 安装 kubelet kubeadm kubectl（锁定版本）"
sudo apt-get install -y kubelet kubeadm kubectl

echo ">>> 锁定版本，防止被 apt upgrade 意外升级"
sudo apt-mark hold kubelet kubeadm kubectl

echo ">>> 验证版本"
echo -n "kubelet:  "; kubelet --version
echo -n "kubeadm:  "; kubeadm version -o short
echo -n "kubectl:  "; kubectl version --client --short

echo "================ Kubernetes ${APT_VERSION} 安装完成 ================"

