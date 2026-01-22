#!/usr/bin/env bash

set -e

cd cri-dockerd

echo ">>>>>>>>>>>>>>>>>>>>安装cri-docker到/user/local/bin/目录>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
sudo install -o root -g root -m 0755 cri-dockerd /usr/local/bin/cri-dockerd

echo ">>>>>>>>>>>>>>>>>>>>安装启动文件到/etc/systemd/system目录>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
sudo install packaging/systemd/* /etc/systemd/system
sudo sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service

echo ">>>>>>>>>>>>>>>>>>>>加载和启动>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
sudo systemctl daemon-reload
sudo systemctl enable --now cri-docker.socket


echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>验证>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
ls /var/run/cri-dockerd.sock
ls /var/run/containerd/containerd.sock

echo "=======================安装结束========================"
