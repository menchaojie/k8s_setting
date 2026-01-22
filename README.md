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

2. Before installation, make sure that the directory looks like this:

```bash
├── cri-dockerd
│   ├── cri-dockerd
│   └── packaging
│       └── systemd
│           ├── cri-docker.service
│           └── cri-docker.socket
└── cri-dockerd-0.3.22.amd64.tgz
```

Note: In k8s, different components work differently as follows:

| 组件                 | 角色        | 是否需要一直 running |
| ------------------ | --------- | -------------- |
| docker.service     | Docker 引擎 | 是              |
| cri-docker.socket  | CRI 入口    | 是（监听）          |
| cri-docker.service | CRI 实现    | 否（按需）          |
| kubelet            | K8s 节点核心  | 是              |


## master

tx-server

## node01

swift
