#!/usr/bin/env bash

set -euo pipefail


TAINT_KEY="node-role.kubernetes.io/control-plane"
TAINT_EFFECT="NoSchedule"

usage() {
  echo "Usage:"
  echo "  $0 allow   [node-name]   # 删除 control-plane NoSchedule taint"
  echo "  $0 forbid  [node-name]   # 添加 control-plane NoSchedule taint"
  exit 1
}

ACTION="${1:-}"
NODE="${2:-}"

if [[ -z "$ACTION" ]]; then
  usage
fi

# 自动获取节点名（默认取当前 context 下第一个 node）
if [[ -z "$NODE" ]]; then
  NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
fi

# 检查节点是否存在
if ! kubectl get node "$NODE" >/dev/null 2>&1; then
  echo "❌ Node '$NODE' not found"
  exit 1
fi

# 检查 taint 是否存在
has_taint() {
  kubectl get node "$NODE" -o jsonpath='{.spec.taints}' \
    | grep -q "$TAINT_KEY"
}

case "$ACTION" in
  allow)
    if has_taint; then
      echo "➡ Removing taint from node '$NODE'"
      kubectl taint nodes "$NODE" "$TAINT_KEY:$TAINT_EFFECT-"
      echo "✅ Node '$NODE' is now schedulable"
    else
      echo "ℹ Node '$NODE' already has no control-plane taint"
    fi
    ;;
  forbid)
    if has_taint; then
      echo "ℹ Node '$NODE' already has control-plane taint"
    else
      echo "➡ Adding taint to node '$NODE'"
      kubectl taint nodes "$NODE" "$TAINT_KEY:$TAINT_EFFECT"
      echo "✅ Node '$NODE' is now protected from scheduling"
    fi
    ;;
  *)
    usage
    ;;
esac
