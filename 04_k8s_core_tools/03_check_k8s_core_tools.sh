#!/usr/bin/env bash
set -e

echo "===== Kubernetes 核心三件套自检 ====="

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
NC="\033[0m"

FAIL_COUNT=0

fail() {
  echo -e "${RED}✘ $1${NC}"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

ok() {
  echo -e "${GREEN}✔ $1${NC}"
}

warn() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

# 从文本中提取第一个 vX.Y.Z / X.Y.Z
extract_version() {
  printf '%s\n' "$1" | grep -Eo 'v?[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | sed 's/^v//'
}

# 取主版本 X.Y
major_minor() {
  printf '%s\n' "$1" | cut -d. -f1,2
}

# -------------------------------------------------
# 1. 命令是否存在
# -------------------------------------------------
echo ">>> [1/5] 命令存在性"

declare -A BIN_PATHS
for bin in kubeadm kubelet kubectl; do
  if path="$(command -v "$bin" 2>/dev/null)"; then
    BIN_PATHS[$bin]="$path"
    ok "$bin 已安装: $path"
  else
    fail "$bin 未安装或不在 PATH"
  fi
done

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo
  echo -e "${RED}===== 自检失败：缺少核心命令，后续检查已跳过 =====${NC}"
  exit 1
fi

# -------------------------------------------------
# 2. 版本可运行
# -------------------------------------------------
echo
echo ">>> [2/5] 版本输出"

KUBELET_RAW="$(kubelet --version 2>&1)"
KUBEADM_RAW="$(kubeadm version -o short 2>&1)"
KUBECTL_RAW="$(kubectl version --client 2>&1)"

echo "    kubelet:  $KUBELET_RAW"
echo "    kubeadm:  $KUBEADM_RAW"
echo "    kubectl:"
printf '%s\n' "$KUBECTL_RAW" | sed 's/^/      /'

KUBELET_VER="$(extract_version "$KUBELET_RAW")"
KUBEADM_VER="$(extract_version "$KUBEADM_RAW")"
KUBECTL_VER="$(extract_version "$KUBECTL_RAW")"

for pair in "kubelet:$KUBELET_VER" "kubeadm:$KUBEADM_VER" "kubectl:$KUBECTL_VER"; do
  name="${pair%%:*}"
  ver="${pair#*:}"
  if [ -n "$ver" ]; then
    ok "$name 版本可解析: v$ver"
  else
    fail "$name 无法解析版本号"
  fi
done

# -------------------------------------------------
# 3. 三者主版本一致
# -------------------------------------------------
echo
echo ">>> [3/5] 版本一致性"

if [ -n "$KUBELET_VER" ] && [ -n "$KUBEADM_VER" ] && [ -n "$KUBECTL_VER" ]; then
  MM_KUBELET="$(major_minor "$KUBELET_VER")"
  MM_KUBEADM="$(major_minor "$KUBEADM_VER")"
  MM_KUBECTL="$(major_minor "$KUBECTL_VER")"

  if [ "$MM_KUBELET" = "$MM_KUBEADM" ] && [ "$MM_KUBEADM" = "$MM_KUBECTL" ]; then
    ok "主版本一致: $MM_KUBELET（kubelet/kubeadm/kubectl）"
    if [ "$KUBELET_VER" = "$KUBEADM_VER" ] && [ "$KUBEADM_VER" = "$KUBECTL_VER" ]; then
      ok "完整 patch 版本一致: v$KUBELET_VER"
    else
      warn "主版本一致，但 patch 不完全相同: kubelet=v$KUBELET_VER kubeadm=v$KUBEADM_VER kubectl=v$KUBECTL_VER"
    fi
  else
    fail "主版本不一致: kubelet=$MM_KUBELET kubeadm=$MM_KUBEADM kubectl=$MM_KUBECTL"
  fi
else
  fail "版本解析不完整，无法比较一致性"
fi

# -------------------------------------------------
# 4. apt hold 状态
# -------------------------------------------------
echo
echo ">>> [4/5] apt-mark hold 状态"

HOLD_LIST="$(apt-mark showhold 2>/dev/null || true)"
for pkg in kubelet kubeadm kubectl; do
  if printf '%s\n' "$HOLD_LIST" | grep -qx "$pkg"; then
    ok "$pkg 已 hold（不会被 apt upgrade 意外升级）"
  else
    warn "$pkg 未 hold（建议: sudo apt-mark hold kubelet kubeadm kubectl）"
  fi
done

# -------------------------------------------------
# 5. apt 源是否指向对应主版本（可选）
# -------------------------------------------------
echo
echo ">>> [5/5] Kubernetes apt 源"

APT_LIST="/etc/apt/sources.list.d/kubernetes.list"
if [ -f "$APT_LIST" ]; then
  ok "存在 $APT_LIST"
  echo "    内容:"
  sed 's/^/      /' "$APT_LIST"

  if [ -n "$KUBEADM_VER" ]; then
    EXPECT_REPO="v$(major_minor "$KUBEADM_VER")"
    if grep -q "/${EXPECT_REPO}/" "$APT_LIST"; then
      ok "apt 源与已装主版本匹配: $EXPECT_REPO"
    else
      warn "apt 源路径可能与已装版本 $EXPECT_REPO 不一致，请人工确认"
    fi
  fi
else
  warn "未找到 $APT_LIST（可能用手装包或源文件名不同）"
fi

# -------------------------------------------------
# 汇总
# -------------------------------------------------
echo
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo -e "${GREEN}===== 自检通过：核心三件套可用 =====${NC}"
  exit 0
else
  echo -e "${RED}===== 自检失败：$FAIL_COUNT 项未通过 =====${NC}"
  exit 1
fi
