#!/usr/bin/env bash

set -e

echo "当前的主机名称是:"
OLD_HOSTNAME=$(hostname)
echo "$OLD_HOSTNAME"
echo "请输入你想更改的主机名（例如：k8s-master 或 k8s-node01）："
read -r NEW_HOSTNAME

if [[ -z "$NEW_HOSTNAME" ]]; then
  echo "主机名不能为空"
  exit 1
fi

if [[ "$OLD_HOSTNAME" == "$NEW_HOSTNAME" ]]; then
  echo "新主机名与当前主机名相同，无需更改"
  exit 0
fi

echo "正在设置 hostname 为: $NEW_HOSTNAME"
read -p "设置信息正确，按回车继续..."

# 先搜索并替换 hosts 文件中的旧主机名
echo "正在搜索 /etc/hosts 中的旧主机名 '$OLD_HOSTNAME'..."
if grep -q "$OLD_HOSTNAME" /etc/hosts; then
  echo "找到旧主机名 '$OLD_HOSTNAME'，正在替换为 '$NEW_HOSTNAME'..."
  sudo sed -i "s/$OLD_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts
  echo "替换完成，查看 /etc/hosts 内容："
  grep -E "(127\.0\.|localhost)" /etc/hosts
  read -p "检查替换结果，按回车继续..."
else
  echo "未在 /etc/hosts 中找到旧主机名 '$OLD_HOSTNAME'"
  read -p "按回车继续设置..."
fi

sudo hostnamectl set-hostname "$NEW_HOSTNAME"

echo "更新 /etc/hosts..."
read -p "准备更新 hosts 文件，按回车继续..."

# # 删除旧的 127.0.1.1 行
# sudo sed -i '/^127\.0\.1\.1/d' /etc/hosts

# 确保 localhost 行包含 hostname（k8s 需要）
if grep -q "^127.0.0.1" /etc/hosts; then
  sudo sed -i "s/^127.0.0.1.*/127.0.0.1 localhost $NEW_HOSTNAME/" /etc/hosts
else
  echo "127.0.0.1 localhost $NEW_HOSTNAME" | sudo tee -a /etc/hosts
fi

# # 添加标准的本机映射（Ubuntu 推荐）
# echo "127.0.1.1 $NEW_HOSTNAME" | sudo tee -a /etc/hosts

echo "重启 systemd-hostnamed..."
sudo systemctl restart systemd-hostnamed

echo "完成。当前 hostname:"
hostname
