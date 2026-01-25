cat <<'EOF'
将使用以下命令,增加终端对k8s命令的tab补全功能:

echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'source <(kubeadm completion bash)' >> ~/.bashrc
source ~/.bashrc

EOF

read -p "=================  按Enter键继续  =================="


echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'source <(kubeadm completion bash)' >> ~/.bashrc
source ~/.bashrc
