#!/usr/bin/env bash
set -e

#----------------------------------------
# 基本配置
#----------------------------------------
SRC_REGISTRY="registry.aliyuncs.com/google_containers"
DST_REGISTRY="crpi-ckw9ia686aku4y4w.cn-shanghai.personal.cr.aliyuncs.com/tgtech"

echo "================ Kubernetes 镜像准备脚本 ================"

read -p "是否手动指定 Kubernetes 版本？(y/N): " USE_MANUAL

if [[ "$USE_MANUAL" == "y" || "$USE_MANUAL" == "Y" ]]; then
  read -p "请输入 Kubernetes 版本（如 1.28.15）: " K8S_VERSION
  echo "[INFO] 使用指定版本：$K8S_VERSION"
  IMAGE_LIST=$(kubeadm config images list --kubernetes-version="${K8S_VERSION}")
else
  echo "[INFO] 使用 kubeadm 自动判定的稳定版本"
  IMAGE_LIST=$(kubeadm config images list)
fi

echo
echo ">>> kubeadm 需要的镜像列表："
echo "$IMAGE_LIST"
echo

read -p "确认开始同步这些镜像到私有仓库？按 Enter 继续..."

#----------------------------------------
# 同步镜像
#----------------------------------------
for full_image in ${IMAGE_LIST}; do
  image_name=$(echo "$full_image" | awk -F'/' '{print $NF}')

  echo
  echo "================================================="
  echo "[INFO] 处理镜像: $image_name"
  echo "================================================="

  echo "[STEP] 拉取 ${SRC_REGISTRY}/${image_name}"
  docker pull ${SRC_REGISTRY}/${image_name}

  echo "[STEP] 打 tag -> ${DST_REGISTRY}/${image_name}"
  docker tag ${SRC_REGISTRY}/${image_name} ${DST_REGISTRY}/${image_name}

  echo "[STEP] 推送到私有仓库"
  docker push ${DST_REGISTRY}/${image_name}

  echo "[STEP] 清理本地中转镜像"
  docker rmi ${SRC_REGISTRY}/${image_name}

  echo "[DONE] ${image_name} 同步完成"
done

echo
echo "================ 镜像同步完成 ================"

