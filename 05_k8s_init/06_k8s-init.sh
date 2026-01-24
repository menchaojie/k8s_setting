echo ">>>>>>>>>>>>>>>>>>>先拉去所需镜像:"
kubeadm config images list --config kubeadm-init.yml | while read img; do
  docker pull "$img"
done
echo ">>>>>>>>>>>>>>>>>>>镜像拉取结束."

echo ">>>>>>>>>>>>>>>>>>>现有镜像为:"
docker images

read -p ">>>>>>>>>>>>>>>>>>按Enter键继续安装:" 
sudo kubeadm init --config kubeadm-init.yml | tee k8s_intall_logs.log

echo "===================初始化完成==================="
