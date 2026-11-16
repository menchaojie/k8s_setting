#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

TAR_FILE="cilium-linux-amd64.tar.gz"
DOWNLOAD_URL="https://github.com/cilium/cilium-cli/releases/latest/download/${TAR_FILE}"

# GitHub 加速前缀（失败后回退官方源）
MIRROR_PREFIXES=(
  "https://ghfast.top/"
  "https://ghproxy.net/"
)

download_with_mirrors() {
  local url="$1"
  local out="$2"
  local partial="${out}.partial"

  rm -f "${partial}"

  for prefix in "${MIRROR_PREFIXES[@]}"; do
    echo ">>> 尝试镜像: ${prefix}"
    if wget -c --timeout=30 --tries=2 -O "${partial}" "${prefix}${url}"; then
      if [ -s "${partial}" ]; then
        mv "${partial}" "${out}"
        echo ">>> 下载成功（镜像）: ${out}"
        return 0
      fi
    fi
    rm -f "${partial}"
  done

  echo ">>> 镜像均失败，回退官方源"
  if wget -c --timeout=60 --tries=3 -O "${partial}" "${url}"; then
    if [ -s "${partial}" ]; then
      mv "${partial}" "${out}"
      echo ">>> 下载成功（官方）: ${out}"
      return 0
    fi
  fi

  rm -f "${partial}"
  echo "❌ 下载失败: ${url}"
  return 1
}

echo "======================================================"
echo " Step 1: 下载并安装 Cilium CLI"
echo "======================================================"
echo
echo "该脚本将完成以下事情："
echo "  1. 优先经国内 GitHub 镜像下载 cilium CLI（失败回退官方）"
echo "  2. 解压并放到 /usr/local/bin"
echo "  3. 验证 cilium version 是否可用"
echo
read -p "确认在【master 节点】上执行，按 Enter 继续..."

# -------------------------------------------------
# 下载（已有完整包则跳过）
# -------------------------------------------------
NEED_DOWNLOAD=1
if [ -f "${TAR_FILE}" ] && [ -s "${TAR_FILE}" ]; then
  if tar tzf "${TAR_FILE}" >/dev/null 2>&1; then
    echo ">>> 文件已存在且完好，跳过下载: ${TAR_FILE}"
    NEED_DOWNLOAD=0
  else
    echo ">>> 已存在文件损坏或不完整，将重新下载: ${TAR_FILE}"
    rm -f "${TAR_FILE}"
  fi
else
  echo ">>> 文件不存在，将下载: ${TAR_FILE}"
fi

if [ "${NEED_DOWNLOAD}" -eq 1 ]; then
  rm -f "${TAR_FILE}" "${TAR_FILE}.partial"
  download_with_mirrors "${DOWNLOAD_URL}" "${TAR_FILE}"
fi

# -------------------------------------------------
# 安装
# -------------------------------------------------
echo
echo ">>> 解压 cilium CLI ..."
tar xzvf "${TAR_FILE}"

if [ ! -f cilium ]; then
  echo "❌ 解压后未找到 cilium 二进制"
  exit 1
fi

echo
echo ">>> 安装到 /usr/local/bin ..."
sudo install -o root -g root -m 0755 cilium /usr/local/bin/cilium
rm -f cilium

echo
echo ">>> 验证 cilium 是否可用："
cilium version

echo
echo "======================================================"
echo " Cilium CLI 安装完成"
echo "======================================================"
