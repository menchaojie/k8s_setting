cat <<'EOF'

==================下载pause镜像, 使用下述命令===============
docker pull crpi-ckw9ia686aku4y4w.cn-shanghai.personal.cr.aliyuncs.com/tgtech/pause:3.10.1

EOF

read -p "============按 Enter 键继续======================"
docker pull crpi-ckw9ia686aku4y4w.cn-shanghai.personal.cr.aliyuncs.com/tgtech/pause:3.10.1

echo " ============= 查看下载结果 ======================="
docker images|grep pause

echo " ============= 重启kubelet ======================="
sudo systemctl restart kubelet
sudo systemctl status kubelet


echo " =====================结束 ======================="


