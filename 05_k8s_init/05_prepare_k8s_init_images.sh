#!/bin/bash
#
# 同步 Kubernetes 核心镜像到私有镜像仓库
# 说明：
#   1. 从阿里云 registry 拉取镜像（解决国外 registry 拉取慢的问题）
#   2. 重新打 tag 到私有镜像仓库 (比如阿里云镜像)
#
#
#   3. 其中有个coredns镜像,可能会同步出问题, 需要单独处理
#
#   

#-----------------------------
# 基本变量配置
#-----------------------------
K8S_VERSION="1.35.0"                                     # 指定 Kubernetes 版本
SRC_REGISTRY="registry.aliyuncs.com/google_containers"    # 源镜像仓库（阿里云公共镜像）
DST_REGISTRY="crpi-ckw9ia686aku4y4w.cn-shanghai.personal.cr.aliyuncs.com/tgtech" #目标私有仓库（阿里云私有镜像）

#-----------------------------
# Step 1: 获取该版本所需镜像列表
#-----------------------------
# kubeadm config images list会列出部署该版本 Kubernetes 所需的所有镜像,并提取最后一个字段
#-----------------------------
echo "[INFO] 获取 Kubernetes $K8S_VERSION 镜像列表..."
images=$(kubeadm config images list --kubernetes-version="${K8S_VERSION}" | awk -F'/' '{print $NF}')

#-----------------------------
# Step 2: 循环同步每个镜像
#-----------------------------
for image in ${images}; do
    echo
    echo "==============================="
    echo "[INFO] 正在处理镜像: ${image}"
    echo "==============================="

    # 拉取镜像（从阿里云源）
    echo "[STEP] 拉取 ${SRC_REGISTRY}/${image}"
    docker pull ${SRC_REGISTRY}/${image}

    # 打上私有仓库标签
    echo "[STEP] 重新打标签为 ${DST_REGISTRY}/${image}"
    docker tag ${SRC_REGISTRY}/${image} ${DST_REGISTRY}/${image}

    # 推送到私有 Harbor 仓库
    echo "[STEP] 推送到 Harbor：${DST_REGISTRY}/${image}"
    docker push ${DST_REGISTRY}/${image}

    # 删除中转镜像，只保留目标镜像
    echo "[STEP] 删除本地中转镜像 ${SRC_REGISTRY}/${image}"
    docker rmi ${SRC_REGISTRY}/${image}

    echo "[DONE] 镜像 ${image} 已同步至私有镜像仓库。"
done
