#!/usr/bin/env bash
set -e

echo "===== 切换 Ubuntu APT 源为阿里云（24.04 / noble） ====="

UBUNTU_SOURCES="/etc/apt/sources.list.d/ubuntu.sources"
BACKUP="/etc/apt/sources.list.d/ubuntu.sources.bak.$(date +%Y%m%d%H%M%S)"

# -------------------------------------------------
# Step 1: 基本检查
# -------------------------------------------------
if [ ! -f "$UBUNTU_SOURCES" ]; then
  echo "❌ 未找到 $UBUNTU_SOURCES"
  echo "该系统可能不是 Ubuntu 24.04，终止"
  exit 1
fi

CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
if [ "$CODENAME" != "noble" ]; then
  echo "⚠ 当前系统代号为 $CODENAME（脚本为 noble 准备）"
  echo "继续执行，但请确认你知道自己在做什么"
fi

# -------------------------------------------------
# Step 2: 备份原始源
# -------------------------------------------------
echo ">>> 备份原 ubuntu.sources"
sudo cp "$UBUNTU_SOURCES" "$BACKUP"
echo "✔ 备份完成: $BACKUP"

# -------------------------------------------------
# Step 3: 写入阿里云源
# -------------------------------------------------
echo ">>> 写入阿里云 Ubuntu 源"

sudo tee "$UBUNTU_SOURCES" > /dev/null <<EOF
Types: deb
URIs: http://mirrors.aliyun.com/ubuntu
Suites: noble noble-updates noble-backports noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

echo "✔ 阿里云源写入完成"

# -------------------------------------------------
# Step 4: 清理并更新索引
# -------------------------------------------------
echo ">>> 清理 apt 索引缓存"
sudo rm -rf /var/lib/apt/lists/*

echo ">>> apt update"
sudo apt update

# -------------------------------------------------
# Step 5: 基础验证
# -------------------------------------------------
echo ">>> 验证常见包可见性"

for pkg in tree curl gnupg; do
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    echo "✔ 包可见: $pkg"
  else
    echo "❌ 包不可见: $pkg"
  fi
done

echo "===== 阿里云 APT 源切换完成 ====="

