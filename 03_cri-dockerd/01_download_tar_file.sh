#!/usr/bin/env bash
set -e

ARCH=amd64
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

BIN_PATH="cri-dockerd/cri-dockerd"
SVC_PATH="cri-dockerd/packaging/systemd/cri-docker.service"
SOCK_PATH="cri-dockerd/packaging/systemd/cri-docker.socket"

# GitHub 加速前缀（按可用性可增减；失败后回退官方源）
MIRROR_PREFIXES=(
  "https://ghfast.top/"
  "https://ghproxy.net/"
)

artifacts_ready() {
  [ -s "${BIN_PATH}" ] && [ -s "${SVC_PATH}" ] && [ -s "${SOCK_PATH}" ]
}

# 通过镜像或官方地址下载；成功后原子替换为目标文件名
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

# -------------------------------------------------
# 0. 最终产物已齐 → 直接退出（幂等，不查 latest）
# -------------------------------------------------
if artifacts_ready; then
  echo ">>>================所需文件已准备就绪（跳过下载/解压）==============<<<"
  echo "  - ${BIN_PATH}"
  echo "  - ${SVC_PATH}"
  echo "  - ${SOCK_PATH}"
  exit 0
fi

# -------------------------------------------------
# 1. 解析最新版本（API 也可走镜像）
# -------------------------------------------------
API_URL="https://api.github.com/repos/Mirantis/cri-dockerd/releases/latest"
API_JSON=""

for prefix in "${MIRROR_PREFIXES[@]}" ""; do
  try_url="${prefix}${API_URL}"
  echo ">>> 获取最新版本: ${try_url}"
  if API_JSON=$(curl -fsSL --connect-timeout 10 --max-time 30 "${try_url}" 2>/dev/null); then
    break
  fi
  API_JSON=""
done

if [ -z "${API_JSON}" ]; then
  echo "❌ 无法获取 cri-dockerd 最新版本信息"
  exit 1
fi

CRI_DOCKERD_VERSION=$(printf '%s\n' "${API_JSON}" | grep '"tag_name"' | head -n1 | cut -d '"' -f 4)

if [ -z "${CRI_DOCKERD_VERSION}" ]; then
  echo "❌ 未能解析 tag_name"
  exit 1
fi

VERSION_NO_V=${CRI_DOCKERD_VERSION#v}
TAR_FILE="cri-dockerd-${VERSION_NO_V}.${ARCH}.tgz"
DOWNLOAD_URL="https://github.com/Mirantis/cri-dockerd/releases/download/${CRI_DOCKERD_VERSION}/${TAR_FILE}"
SVC_BASE="https://raw.githubusercontent.com/Mirantis/cri-dockerd/refs/heads/master/packaging/systemd"

echo ">>>>>>>>>>>>>>>>>>>>>> 最新 cri-dockerd 版本: ${CRI_DOCKERD_VERSION}"
echo ">>>>>>>>>>>>>>>>>>>>>> 目标文件: ${TAR_FILE}"

# -------------------------------------------------
# 2. 处理 tarball：没包 / 完好 / 损坏
# -------------------------------------------------
NEED_DOWNLOAD=1
if [ ! -f "${TAR_FILE}" ] || [ ! -s "${TAR_FILE}" ]; then
  echo ">>>>>>>>>>>>>>>>>>> 文件不存在，将下载: ${TAR_FILE}"
elif tar tzf "${TAR_FILE}" >/dev/null 2>&1; then
  echo ">>>>>>>>>>>>>>>>>>> 文件已存在且完好，跳过下载: ${TAR_FILE}"
  NEED_DOWNLOAD=0
else
  echo ">>>>>>>>>>>>>>>>>>> 文件损坏或不完整，将重新下载: ${TAR_FILE}"
  rm -f "${TAR_FILE}"
fi

if [ "${NEED_DOWNLOAD}" -eq 1 ]; then
  rm -f "${TAR_FILE}" "${TAR_FILE}.partial"
  read -p ">>>>>>>>>>>>>>>>>> 按 Enter 开始下载主要文件..."
  download_with_mirrors "${DOWNLOAD_URL}" "${TAR_FILE}"
  echo ">>>>>>>>>>>>>>>>>>>>> 下载完成: ${TAR_FILE}"
fi

# -------------------------------------------------
# 3. 按需解压二进制
# -------------------------------------------------
mkdir -p cri-dockerd/packaging/systemd

if [ -s "${BIN_PATH}" ]; then
  echo ">>>>>>>>>>>>>>>>>>> 二进制已存在，跳过解压: ${BIN_PATH}"
else
  echo ">>>>>>>>>>>>>>>>>>> 解压下载的文件"
  tar xzvf "${TAR_FILE}"
fi

if [ ! -s "${BIN_PATH}" ]; then
  echo "❌ 解压后未找到二进制: ${BIN_PATH}"
  exit 1
fi

# -------------------------------------------------
# 4. 按需下载 systemd unit
# -------------------------------------------------
if [ -s "${SVC_PATH}" ]; then
  echo ">>>>>>>>>>>>>>>>>>> service 已存在，跳过下载: ${SVC_PATH}"
else
  echo ">>>>>>>>>>>>>>>>>>> 下载 service 文件"
  download_with_mirrors "${SVC_BASE}/cri-docker.service" "${SVC_PATH}"
fi

if [ -s "${SOCK_PATH}" ]; then
  echo ">>>>>>>>>>>>>>>>>>> socket 已存在，跳过下载: ${SOCK_PATH}"
else
  echo ">>>>>>>>>>>>>>>>>>> 下载 socket 文件"
  download_with_mirrors "${SVC_BASE}/cri-docker.socket" "${SOCK_PATH}"
fi

echo ">>>================所需文件已准备就绪==============<<<"
echo "  - ${BIN_PATH}"
echo "  - ${SVC_PATH}"
echo "  - ${SOCK_PATH}"
