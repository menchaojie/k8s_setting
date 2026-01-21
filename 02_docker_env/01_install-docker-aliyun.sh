#!/usr/bin/env bash
set -e

echo "===== Docker 安装脚本（Aliyun，工程级） ====="

ARCH=$(dpkg --print-architecture)
CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
DOCKER_GPG=/etc/apt/keyrings/docker.gpg
DOCKER_LIST=/etc/apt/sources.list.d/docker.list

# -------------------------------------------------
# Step 1: 检查并安装基础依赖（这一段是对的）
# -------------------------------------------------
echo ">>> Step 1: 检查基础依赖"

REQUIRED_PKGS=(ca-certificates curl gnupg)
MISSING_PKGS=()

for pkg in "${REQUIRED_PKGS[@]}"; do
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    echo "    ✔ $pkg 已安装"
  else
    echo "    ✘ $pkg 未安装"
    MISSING_PKGS+=("$pkg")
  fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
  sudo apt update
  sudo apt install -y "${MISSING_PKGS[@]}"
else
  echo ">>> 基础依赖齐全，跳过安装"
fi

# -------------------------------------------------
# Step 2: 强制重建 Docker GPG Key（关键修改点）
# -------------------------------------------------
echo ">>> Step 2: 重建 Docker GPG Key"

sudo install -m 0755 -d /etc/apt/keyrings
sudo rm -f "$DOCKER_GPG"

curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o "$DOCKER_GPG"

sudo chmod a+r "$DOCKER_GPG"

# -------------------------------------------------
# Step 3: 强制重建 Docker 软件源（关键修改点）
# -------------------------------------------------
echo ">>> Step 3: 重建 Docker 软件源"

sudo rm -f "$DOCKER_LIST"

echo "deb [arch=${ARCH} signed-by=${DOCKER_GPG}] https://mirrors.aliyun.com/docker-ce/linux/ubuntu ${CODENAME} stable" \
  | sudo tee "$DOCKER_LIST" > /dev/null

# -------------------------------------------------
# Step 4: 清理 apt 缓存并安装 Docker（关键补充）
# -------------------------------------------------
echo ">>> Step 4: 安装 Docker"

sudo rm -rf /var/lib/apt/lists/*
sudo apt update

if command -v docker >/dev/null 2>&1; then
  echo "    ✔ Docker 已安装：$(docker --version)"
else
  sudo apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
fi

# -------------------------------------------------
# Step 5: 启动并验证 Docker
# -------------------------------------------------
echo ">>> Step 5: 验证 Docker 服务"

sudo systemctl enable docker >/dev/null
sudo systemctl start docker

sudo docker info >/dev/null 2>&1 \
  && echo "    ✔ Docker 运行正常" \
  || { echo "    ❌ Docker 异常"; exit 1; }

echo "===== Docker 安装完成 ====="

