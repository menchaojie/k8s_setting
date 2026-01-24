cat <<'EOF'

>>>>>>>>>>>>>>>>>>>>>>将执行如下授权命令:
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

EOF

read -p ">>>>>>>>>>>>>>按Enter键为普通用户授予权限:"

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "==============执行结束=================="
