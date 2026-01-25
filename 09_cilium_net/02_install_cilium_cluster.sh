#!/usr/bin/env bash
set -e

echo "======================================================"
echo " Step 2: 在集群中安装 Cilium（替换 flannel）"
echo "======================================================"
echo
echo "⚠️ 重要前提："
echo "  - 本脚本【只在 master 节点执行】"
echo "  - flannel 必须被完全卸载"
echo "  - 所有节点需要清理 CNI 遗留文件"
echo
read -p "确认你理解以上前提，按 Enter 继续..."

# ------------------------------------------------------
# Step A: 卸载 flannel（Kubernetes 层面）
# ------------------------------------------------------
echo
echo ">>> Step A: 卸载 flannel（如果存在）"
echo "这一步会删除 kube-flannel 命名空间"
echo
read -p "确认继续卸载 flannel，按 Enter ..."

kubectl delete ns kube-flannel --ignore-not-found=true

echo
echo ">>> 等待 flannel 相关 Pod 完全消失 ..."
kubectl get pods -A | grep flannel || echo "（未发现 flannel Pod）"

# ------------------------------------------------------
# Step B: 提示用户在【所有节点】清理 CNI 文件
# ------------------------------------------------------
echo
echo "======================================================"
echo " Step B: 手动在【所有节点】执行以下命令"
echo "======================================================"
echo
echo "在 tx-server 和 k8s-node01 上【分别执行】："
echo
cat <<'EOF'
sudo rm -f /etc/cni/net.d/*
sudo rm -rf /run/flannel
sudo systemctl restart kubelet
EOF
echo
echo "这一步非常关键，用于清理 flannel 遗留的 CNI 配置"
echo
read -p "请确认【所有节点】都已执行完成，按 Enter 继续..."

# ------------------------------------------------------
# Step C: 确认节点状态
# ------------------------------------------------------
echo
echo ">>> Step C: 查看节点状态（此时可能 NotReady，这是正常的）"
kubectl get nodes

read -p "确认节点列表正常显示，按 Enter 继续..."

# ------------------------------------------------------
# Step D: 获取 master 的 tailscale IP
# ------------------------------------------------------
echo
echo ">>> Step D: 获取 master 的 tailscale IP"
echo "将用于 Cilium 连接 kube-apiserver"

TS_IP=$(tailscale ip -4 | head -n1)

if [ -z "$TS_IP" ]; then
  echo "❌ 未能获取 tailscale IP，请确认 tailscale 正在运行"
  exit 1
fi

echo "✔ 检测到 master tailscale IP: $TS_IP"
echo
read -p "确认该 IP 正确，按 Enter 继续..."

# ------------------------------------------------------
# Step E: 安装 Cilium
# ------------------------------------------------------
echo
echo ">>> Step E: 安装 Cilium（native routing + tailscale）"
echo
echo "关键特性："
echo "  - 不使用 VXLAN / overlay"
echo "  - 直接基于 tailscale IP 路由 Pod"
echo "  - 启用 kube-proxy replacement"
echo
read -p "确认开始安装 Cilium，按 Enter ..."

cilium install \
  --set routingMode=native \
  --set autoDirectNodeRoutes=true \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="$TS_IP" \
  --set k8sServicePort=6443

# ------------------------------------------------------
# Step F: 等待 Cilium 就绪
# ------------------------------------------------------
echo
echo ">>> Step F: 等待 Cilium 组件就绪"
cilium status --wait

# ------------------------------------------------------
# Step G: 验证结果
# ------------------------------------------------------
echo
echo "======================================================"
echo " Cilium 安装完成，进行基础验证"
echo "======================================================"
echo

kubectl get pods -n kube-system | grep cilium || true
kubectl get nodes

echo
echo "下一步建议："
echo "  kubectl run test --image=nginx --restart=Never"
echo "  kubectl get pod test -o wide"
echo
echo "======================================================"
echo " Cilium 集群网络已接管完成"
echo "======================================================"

