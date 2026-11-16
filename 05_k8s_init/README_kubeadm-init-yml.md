# kubeadm-init.yml 修改说明

`kubeadm init --config kubeadm-init.yml` 会按本文件初始化控制面。换机器或换版本时，**至少核对下面字段**，不要直接沿用旧环境的 IP / 主机名 / 版本。

## 文件结构

文件由两段 YAML 组成，用 `---` 分隔：

| 段 | kind | 作用 |
|----|------|------|
| 第一段 | `InitConfiguration` | 本机如何暴露 API、节点名、CRI socket |
| 第二段 | `ClusterConfiguration` | 集群版本、镜像仓、Pod/Service 网段 |

两段的 `apiVersion` 应一致。当前 kubeadm **1.36** 推荐：

```yaml
apiVersion: kubeadm.k8s.io/v1beta4
```

不要一段 `v1beta4`、一段 `v1beta3`，可能导致 `kubeadm config images list --config` / `init` 解析失败。

## 必改字段清单

### 1. `advertiseAddress`（最容易错）

```yaml
localAPIEndpoint:
  advertiseAddress: 172.16.0.183
```

- **填什么**：控制面网卡的内网 IP（节点互通用的那个），一般是 `eth0`。
- **怎么查**：

```bash
hostname
ip -br a
```

示例（本机 yanhuo）：

```text
eth0  UP  172.16.0.183/12
```

则应写 `172.16.0.183`，**不要**再写旧集群的 `100.64.0.4`。

- **为什么重要**：证书 SAN、apiServer 通告地址、worker `kubeadm join` 的目标都依赖它。

### 2. `nodeRegistration.name`

```yaml
nodeRegistration:
  name: k8s-master-yanhuo
```

- 建议与 `hostname` 一致，会出现在 `kubectl get nodes`。
- 改主机名后记得同步改这里。

### 3. `criSocket`

```yaml
criSocket: unix:///var/run/cri-dockerd.sock
```

本仓库走 Docker + cri-dockerd，保持上述路径。若改用 containerd，需改成对应 socket。

### 4. `kubernetesVersion`

```yaml
kubernetesVersion: v1.36.6
```

- 必须与已安装的 `kubeadm` / `kubelet` 主版本匹配（patch 建议一致）。
- 查看：

```bash
kubeadm version -o short
kubelet --version
```

- 改版本后：重新同步镜像（`05_prepare_k8s_init_images.sh`），并对齐 cri-dockerd 的 pause（`04_manage_cri_pause_version.sh`）。

### 5. `imageRepository`

```yaml
imageRepository: crpi-ckw9ia686aku4y4w.cn-shanghai.personal.cr.aliyuncs.com/tgtech
```

- kubeadm 会从该前缀拉 `kube-apiserver`、`pause`、`etcd` 等。
- 仓里必须已有对应 **版本 tag** 的镜像；换版本先跑镜像同步脚本。
- 使用个人仓时，cri-dockerd 的 pause 也建议指向同一仓库的同 tag（如 `pause:3.10.2`）。

### 6. `networking.podSubnet` / `serviceSubnet`

```yaml
networking:
  podSubnet: 10.0.0.0/16
  serviceSubnet: 10.96.0.0/12
```

- `podSubnet` 必须与后续 CNI（Flannel / Cilium）配置一致。
- 与宿主机物理网段、Docker 网桥冲突时需调整。
- `serviceSubnet` 一般保持 `10.96.0.0/12`，除非环境有冲突。

## 推荐修改步骤

1. 查本机信息：

```bash
hostname
ip -br a
kubeadm version -o short
```

2. 编辑 `kubeadm-init.yml`，至少更新：
   - `advertiseAddress`
   - `name`
   - `kubernetesVersion`（如有升级）
   - 两段均为 `apiVersion: kubeadm.k8s.io/v1beta4`

3. 校验配置（在 `05_k8s_init` 目录）：

```bash
kubeadm config validate --config kubeadm-init.yml
kubeadm config images list --config kubeadm-init.yml
```

4. 预检通过后初始化：

```bash
./01_init_k8s_preflight.sh
./06_k8s-init.sh
```

## 本次（k8s-master-yanhuo）已落地的值

| 字段 | 值 |
|------|-----|
| apiVersion（两段） | `kubeadm.k8s.io/v1beta4` |
| advertiseAddress | `172.16.0.183`（eth0） |
| name | `k8s-master-yanhuo` |
| criSocket | `unix:///var/run/cri-dockerd.sock` |
| kubernetesVersion | `v1.36.6` |
| imageRepository | 阿里云个人仓 `.../tgtech` |
| podSubnet | `10.0.0.0/16` |
| serviceSubnet | `10.96.0.0/12` |

旧值参考：曾使用 `advertiseAddress: 100.64.0.4`、节点名 `k8s-master` / `tx-server`、版本 `v1.28.15`，以及混用 `v1beta3`，换机后不可照搬。

## 相关脚本

| 脚本 | 关系 |
|------|------|
| `01_init_k8s_preflight.sh` | 会读取本 yml 的 `imageRepository` / `kubernetesVersion` 做 pause 检查 |
| `05_prepare_k8s_init_images.sh` | 把 kubeadm 所需镜像同步到个人仓 |
| `04_manage_cri_pause_version.sh` | 配置 cri-dockerd 的 pause 镜像 |
| `06_k8s-init.sh` | `kubeadm init --config kubeadm-init.yml` |
| `07_reset_k8s_init.sh` | 重置失败或重装时使用 |
