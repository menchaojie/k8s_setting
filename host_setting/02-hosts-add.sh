#!/usr/bin/env bash

set -e

echo "检查当前hosts文件内容:"
cat /etc/hosts

echo "添加集群中其他主机"
# 定义集群主机映射变量
HOSTS_CONTENT="\
100.64.0.4 k8s-master
100.64.0.5 k8s-node01
"
echo "$HOSTS_CONTENT"

read -p "设置信息正确，按回车继续..."

# 使用变量添加到 hosts 文件
echo "$HOSTS_CONTENT" | sudo tee -a /etc/hosts

echo "添加后，hosts文件内容:"
cat /etc/hosts