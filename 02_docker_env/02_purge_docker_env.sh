#!/usr/bin/env bash
set -e

echo "===== 开始彻底清理 Docker 环境 ====="

# -------------------------------------------------
# Step 1: 停止 Docker 服务
# -------------------------------------------------
echo ">>> 停止 Docker 服务"

sudo systemctl stop docker || true
sudo systemctl stop containerd || true

# -------------------------------------------------
# Step 2: 卸载 Docker 相关包
# -------------------------------------------------
echo ">>> 卸载 Docker 相关包"

sudo apt purge -y \
  docker-ce \
  docker-ce-cli \
  docker-ce-rootless-extras \
  docker-buildx-plugin \
  docker-compose-plugin \
  containerd.io || true

# -------------------------------------------------
# Step 3: 删除 Docker 数据目录
# -------------------------------------------------
echo ">>> 删除 Docker 数据目录"

sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

# -------------------------------------------------
# Step 4: 删除 Docker 配置
# -------------------------------------------------
echo ">>> 删除 Docker 配置文件"

sudo rm -rf /etc/docker

# -------------------------------------------------
# Step 5: 清理 Docker apt 源 & GPG key
# -------------------------------------------------
echo ">>> 清理 Docker apt 源和 GPG key"

sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -f /etc/apt/keyrings/docker.gpg

# -------------------------------------------------
# Step 6: 清理 apt 缓存
# -------------------------------------------------
echo ">>> 清理 apt 缓存"

sudo apt clean
sudo rm -rf /var/lib/apt/lists/*
sudo apt update

echo "===== Docker 环境已彻底清理完成 ====="

