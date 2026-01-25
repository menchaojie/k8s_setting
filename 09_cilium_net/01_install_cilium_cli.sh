#!/usr/bin/env bash
set -e

echo "======================================================"
echo " Step 1: 下载并安装 Cilium CLI"
echo "======================================================"
echo
echo "该脚本将完成以下事情："
echo "  1. 从 GitHub 下载最新 cilium CLI"
echo "  2. 解压并放到 /usr/local/bin"
echo "  3. 验证 cilium version 是否可用"
echo
read -p "确认在【master 节点】上执行，按 Enter 继续..."

# 下载最新版本的 cilium CLI
echo
echo ">>> 下载 cilium CLI ..."
curl -L --fail --remote-name \
  https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz

echo
echo ">>> 解压 cilium CLI ..."
tar xzvf cilium-linux-amd64.tar.gz

echo
echo ">>> 移动到 /usr/local/bin（需要 sudo）..."
sudo mv cilium /usr/local/bin/

echo
echo ">>> 清理下载文件 ..."
rm -f cilium-linux-amd64.tar.gz

echo
echo ">>> 验证 cilium 是否可用："
cilium version

echo
echo "======================================================"
echo " Cilium CLI 安装完成"
echo "======================================================"

