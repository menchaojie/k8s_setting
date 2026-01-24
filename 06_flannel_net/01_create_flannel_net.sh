echo ">>>>>>>>>>>>>>>>>>>先拉去所需镜像:"
grep image kube-flannel.yml | awk '{print $2}'|sort -u |while read img; do
    docker pull "$img"
done
echo ">>>>>>>>>>>>>>>>>>>镜像拉取结束."

echo ">>>>>>>>>>>>>>>>>>>现有镜像为:"
docker images

read -p ">>>>>>>>>>>>>>>>>>按Enter创建Flannel网络:" 
kubectl apply -f kube-flannel.yml

echo "===================Flannel网络创建完成==================="
