#!/usr/bin/env bash
set -e

ARCH=amd64

# GitHub 加速前缀（按可用性可增减；失败后回退官方源）
MIRROR_PREFIXES=(
  "https://ghfast.top/"
  "https://ghproxy.net/"
)

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
# 2. 下载二进制包（已存在则先校验，避免半截包被误跳过）
# -------------------------------------------------
NEED_DOWNLOAD=1
if [ -f "${TAR_FILE}" ] && [ -s "${TAR_FILE}" ]; then
  if tar tzf "${TAR_FILE}" >/dev/null 2>&1; then
    echo ">>>>>>>>>>>>>>>>>>> 文件已存在且校验通过，跳过下载: ${TAR_FILE}"
    NEED_DOWNLOAD=0
  else
    echo ">>>>>>>>>>>>>>>>>>> 已存在文件损坏或不完整，将重新下载: ${TAR_FILE}"
    rm -f "${TAR_FILE}"
  fi
fi

if [ "${NEED_DOWNLOAD}" -eq 1 ]; then
  rm -f "${TAR_FILE}" "${TAR_FILE}.partial"
  read -p ">>>>>>>>>>>>>>>>>> 按 Enter 开始下载主要文件..."
  download_with_mirrors "${DOWNLOAD_URL}" "${TAR_FILE}"
  echo ">>>>>>>>>>>>>>>>>>>>> 下载完成: ${TAR_FILE}"
fi

# -------------------------------------------------
# 3. 解压并准备 systemd 单元
# -------------------------------------------------
echo ">>>>>>>>>>>>>>>>>>>解压下载的文件<<<"
tar xzvf "${TAR_FILE}"

echo ">>>>>>>>>>>>>>>>>>>创建目录<<<"
cd cri-dockerd
mkdir -p packaging/systemd
cd packaging/systemd

echo ">>>>>>>>>>>>>>>>>>>下载 service 文件<<<"
download_with_mirrors "${SVC_BASE}/cri-docker.service" "cri-docker.service"

echo ">>>>>>>>>>>>>>>>>>>下载 socket 文件<<<"
download_with_mirrors "${SVC_BASE}/cri-docker.socket" "cri-docker.socket"

echo ">>>================所需文件已准备就绪==============<<<"
