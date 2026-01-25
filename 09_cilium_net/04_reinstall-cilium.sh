#!/bin/bash
set -e

echo "=== [Step A] 确认节点状态（NotReady 是正常的） ==="
kubectl get nodes -o wide

read -p "确认节点列表正常显示，按 Enter 继续..."

echo "=== [Step B] 检测 master 的 tailscale IP ==="
TS_IP=$(tailscale ip -4 | head -n1)

if [ -z "$TS_IP" ]; then
  echo "❌ 未检测到 tailscale IPv4 地址"
  exit 1
fi

echo "✔ 检测到 master tailscale IP: $TS_IP"
read -p "确认该 IP 正确，按 Enter 继续..."

echo "=== [Step C] 重新安装 Cilium（native routing + kube-proxy replacement） ==="

cilium uninstall || true
sleep 5

cilium install \
  --version 1.18.5 \
  --set cni.install=true \
  --set routingMode=native \
  --set autoDirectNodeRoutes=true \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=$TS_IP \
  --set k8sServicePort=6443

echo "=== [Step D] 等待 Cilium 组件就绪（这是关键一步） ==="
cilium status --wait

echo "=== [Step E] 查看节点状态 ==="
kubectl get nodes -o wide

echo "=== 完成：Cilium 应已成功接管集群网络 ==="

