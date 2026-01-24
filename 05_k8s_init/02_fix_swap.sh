#!/bin/bash

set -e

echo "===== 关闭 Swap（Kubernetes 要求） ====="

#1. 关闭当前 swap
if swapon --summary | grep -q .; then
  echo "[INFO] 检测到 Swap 已开启，正在关闭..."
  sudo swapoff -a
else
  echo "[OK] Swap 当前已关闭"
fi

#2. 注释 /etc/fstab 中的 swap
if grep -E '^\s*[^#].*\s+swap\s' /etc/fstab >/dev/null; then
  echo "[INFO] 正在禁用 /etc/fstab 中的 Swap 配置..."
  sudo sed -i.bak '/\sswap\s/s/^/#/' /etc/fstab
  echo "[OK] Swap 已从 /etc/fstab 中禁用（已备份为 /etc/fstab.bak）"
else
  echo "[OK] /etc/fstab 中未发现启用的 Swap"
fi

#3. 验证
if swapon --summary | grep -q .; then
  echo "[FAIL] Swap 仍然开启"
  exit 1
else
  echo "[SUCCESS] Swap 已完全关闭"
fi
