#!/usr/bin/env bash
set -e

ARCH=amd64

CRI_DOCKERD_VERSION=$(curl -fsSL https://api.github.com/repos/Mirantis/cri-dockerd/releases/latest \
  | grep '"tag_name"' \
  | cut -d '"' -f 4)

VERSION_NO_V=${CRI_DOCKERD_VERSION#v}
TAR_FILE="cri-dockerd-${VERSION_NO_V}.${ARCH}.tgz"
DOWNLOAD_URL="https://github.com/Mirantis/cri-dockerd/releases/download/${CRI_DOCKERD_VERSION}/${TAR_FILE}"

echo ">>>>>>>>>>>>>>>>>>>>>> 最新 cri-dockerd 版本: ${CRI_DOCKERD_VERSION}"
echo ">>>>>>>>>>>>>>>>>>>>>> 目标文件: ${TAR_FILE}"

if [ -f "${TAR_FILE}" ]; then
  echo ">>>>>>>>>>>>>>>>>>> 文件已存在，跳过下载: ${TAR_FILE}"
else
  read -p ">>>>>>>>>>>>>>>>>> 文件不存在，按 Enter 开始下载主要文件..."
  wget "${DOWNLOAD_URL}"
  echo ">>>>>>>>>>>>>>>>>>>>> 下载完成: ${TAR_FILE}"
fi


#
#   unzip filse
#

echo ">>>>>>>>>>>>>>>>>>>解压下载的文件<<<"
tar xzvf ${TAR_FILE}

echo ">>>>>>>>>>>>>>>>>>>创建目录<<<"
cd cri-dockerd
mkdir -p packaging/systemd
cd packaging/systemd

echo ">>>>>>>>>>>>>>>>>>>下载service文件<<<"
curl -fsSL -o cri-docker.service \
  https://raw.githubusercontent.com/Mirantis/cri-dockerd/refs/heads/master/packaging/systemd/cri-docker.service

echo ">>>>>>>>>>>>>>>>>>>下载socket文件<<<"

curl -fsSL -o cri-docker.socket \
  https://raw.githubusercontent.com/Mirantis/cri-dockerd/refs/heads/master/packaging/systemd/cri-docker.socket

echo ">>>================所需文件已准备就绪==============<<<"

