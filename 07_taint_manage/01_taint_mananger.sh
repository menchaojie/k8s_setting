#!/usr/bin/env bash

set -euo pipefail

# 常量定义
readonly TAINT_KEY="node-role.kubernetes.io/control-plane"
readonly TAINT_EFFECT="NoSchedule"

# 函数定义
usage() {
    cat <<EOF
Usage: $0 <command> [node-name]

Commands:
  allow    Remove control-plane taint from node (make it schedulable)
  forbid   Add control-plane taint to node (protect from scheduling)
  status   Show current taint status of node(s)

Examples:
  $0 allow                    # Remove taint from first node
  $0 forbid node01           # Add taint to specific node
  $0 status                  # Show taint status for all nodes
  $0 status node01           # Show taint status for specific node
  $0 allow $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

EOF
    exit 1
}

log_info() {
    echo "ℹ $*"
}

log_success() {
    echo "✅ $*"
}

log_warning() {
    echo "⚠ $*"
}

log_error() {
    echo "❌ $*" >&2
}

# 检查kubectl是否可用
check_prerequisites() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
}

# 获取默认节点名
get_default_node() {
    kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || {
        log_error "No nodes found in current context"
        exit 1
    }
}

# 检查节点是否存在
node_exists() {
    local node="$1"
    kubectl get node "$node" &>/dev/null
}

# 检查taint是否存在
has_taint() {
    local node="$1"
    kubectl get node "$node" -o jsonpath='{.spec.taints[*].key}' 2>/dev/null | grep -q "$TAINT_KEY"
}

# 移除taint
remove_taint() {
    local node="$1"
    if has_taint "$node"; then
        log_info "Removing taint from node '$node'"
        if kubectl taint nodes "$node" "$TAINT_KEY:$TAINT_EFFECT-"; then
            log_success "Node '$node' is now schedulable"
        else
            log_error "Failed to remove taint from node '$node'"
            return 1
        fi
    else
        log_info "Node '$node' already has no control-plane taint"
    fi
}

# 添加taint
add_taint() {
    local node="$1"
    if has_taint "$node"; then
        log_info "Node '$node' already has control-plane taint"
    else
        log_info "Adding taint to node '$node'"
        if kubectl taint nodes "$node" "$TAINT_KEY:$TAINT_EFFECT"; then
            log_success "Node '$node' is now protected from scheduling"
        else
            log_error "Failed to add taint to node '$node'"
            return 1
        fi
    fi
}

# 显示当前taint状态
show_current_status() {
    local node="$1"
    log_info "Current taint status for node '$node':"
    kubectl describe node "$node" | grep -E "(Taints|Name:)" | head -3
}

# 显示所有节点的taint状态
show_all_nodes_status() {
    log_info "Taint status for all nodes:"
    echo
    kubectl get nodes -o wide | head -1
    kubectl get nodes -o wide | tail -n +2 | while read line; do
        local node_name=$(echo "$line" | awk '{print $1}')
        local taint_status=$(kubectl describe node "$node_name" 2>/dev/null | grep "Taints:" || echo "Taints: <none>")
        echo "$line" | awk -v taint="$taint_status" '{printf "%-50s %s\n", $0, taint}'
    done
}

# 显示详细taint状态
show_detailed_status() {
    local node="$1"
    if [[ "$node" == "all" ]]; then
        show_all_nodes_status
    else
        log_info "Detailed taint status for node '$node':"
        kubectl describe node "$node" | grep -A 10 -B 1 "Taints:"
    fi
}

# 主函数
main() {
    local action="${1:-}"
    local node="${2:-}"
    
    # 参数验证
    if [[ -z "$action" ]]; then
        usage
    fi
    
    # 检查前置条件
    check_prerequisites
    
    # 设置默认节点
    if [[ -z "$node" ]]; then
        node=$(get_default_node)
        log_info "Using default node: $node"
    fi
    
    # 验证节点存在
    if ! node_exists "$node"; then
        log_error "Node '$node' not found"
        exit 1
    fi
    
    # 显示当前状态
    show_current_status "$node"
    
    # 执行操作
    case "$action" in
        allow)
            remove_taint "$node"
            ;;
        forbid)
            add_taint "$node"
            ;;
        status)
            if [[ "$node" == "all" || -z "$node" ]]; then
                show_detailed_status "all"
            else
                show_detailed_status "$node"
            fi
            exit 0
            ;;
        *)
            log_error "Invalid action: $action"
            usage
            ;;
    esac
    
    # 显示操作后状态（仅对allow/forbid操作）
    if [[ "$action" == "allow" || "$action" == "forbid" ]]; then
        echo
        show_current_status "$node"
    fi
}

# 脚本入口
main "$@"