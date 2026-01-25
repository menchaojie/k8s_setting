#!/usr/bin/env bash
set -euo pipefail

echo "===== 🚨 Cilium 完全卸载脚本（Final Boss） ====="
echo
read -p "⚠️  这将彻底删除 Cilium（Y/N）: " confirm
[[ "$confirm" != "Y" ]] && echo "已取消" && exit 0

########################################
# 基础工具
########################################
run() {
  echo -e "\n==> $*"
  eval "$*" || true
}

########################################
# Step 0. 权限检查
########################################
if [[ $EUID -ne 0 ]]; then
  echo "❌ 请使用 sudo/root 运行该脚本"
  exit 1
fi

########################################
# Step 1. 尝试 cilium-cli 卸载（不强求）
########################################
if command -v cilium >/dev/null 2>&1; then
  echo
  echo "== Step 1. 使用 cilium-cli 卸载（如果存在） =="
  cilium uninstall --wait=false || true
else
  echo "cilium-cli 不存在，跳过"
fi

########################################
# Step 2. 强制删除 Kubernetes 资源
########################################
echo
echo "== Step 2. 强制删除 Kubernetes 资源 =="

run "kubectl delete daemonset cilium cilium-envoy -n kube-system --ignore-not-found"
run "kubectl delete deployment cilium-operator -n kube-system --ignore-not-found"
run "kubectl delete service cilium-agent -n kube-system --ignore-not-found"
run "kubectl delete configmap cilium-config -n kube-system --ignore-not-found"
run "kubectl delete sa cilium cilium-operator -n kube-system --ignore-not-found"
run "kubectl delete clusterrole,clusterrolebinding -l k8s-app=cilium --ignore-not-found"

########################################
# Step 3. 删除 Cilium CRD（关键）
########################################
echo
echo "== Step 3. 删除 Cilium CRD（关键） =="

kubectl get crd | grep cilium | awk '{print $1}' | while read -r crd; do
  kubectl delete crd "$crd" --ignore-not-found || true
done

########################################
# Step 4. 清理 CNI 配置（最关键）
########################################
echo
echo "== Step 4. 清理 CNI 配置 =="

run "rm -rf /etc/cni/net.d/*"

########################################
# Step 5. 清理 Cilium 本地状态 / BPF
########################################
echo
echo "== Step 5. 清理 Cilium 本地状态 / BPF =="

run "rm -rf /var/lib/cilium"
run "rm -rf /sys/fs/bpf/cilium"
run "rm -rf /run/cilium"

########################################
# Step 6. 清理 Cilium 网络设备
########################################
echo
echo "== Step 6. 清理 Cilium 网络设备 =="

for dev in cilium_host cilium_net cilium_vxlan; do
  ip link delete "$dev" 2>/dev/null || true
done

########################################
# Step 7. 刷新 iptables（可选但推荐）
########################################
echo
echo "== Step 7. 刷新 iptables =="

iptables -F || true
iptables -t nat -F || true
iptables -t mangle -F || true

########################################
# Step 8. 重启 kubelet
########################################
echo
echo "== Step 8. 重启 kubelet =="

systemctl restart kubelet

########################################
# 完成
########################################
echo
echo "✅ Cilium 已彻底清理完成"
echo
echo "👉 下一步：安装新的 CNI（Flannel / Calico 等）"
echo "👉 此时 node NotReady / coredns Pending 属于正常现象"

