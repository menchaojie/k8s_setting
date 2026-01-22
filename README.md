# k8s_setting



## host-setting

### hostname

1. use command hostnamectl

2. modify 

## docker env

1. install the docker evironment

reference: [aliyun mirror docker-ce](https://developer.aliyun.com/mirror/docker-ce?spm=a2c6h.13651102.0.0.57e31b11dCQH1l)

2. to clean the docker env for reinstall

3. used for commen users, not root

## cri-dockerd

1. down load the files. If it is difficult to download though terminal, can down load from browser.
   [binary files](https://github.com/Mirantis/cri-dockerd/releases)
   [systemd files](https://github.com/Mirantis/cri-dockerd/tree/master/packaging/systemd)

2. before installation, make sure that the dir is like:

```bash
├── cri-dockerd
│   ├── cri-dockerd
│   └── packaging
│       └── systemd
│           ├── cri-docker.service
│           └── cri-docker.socket
└── cri-dockerd-0.3.22.amd64.tgz
```



## master

tx-server

## node01

swift
