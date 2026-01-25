# Web应用部署配置

## 概述

这个Kubernetes配置文件用于部署一个基于Nginx的Web应用，包含Deployment和Service两个资源对象。

## 配置文件结构

### Deployment配置
- **应用名称**: web
- **容器镜像**: nginx:1.25
- **副本数量**: 3个Pod
- **标签选择器**: app=web

### Service配置
- **服务类型**: NodePort
- **端口映射**: 80端口（服务端口）→ 80端口（容器端口）
- **服务选择器**: app=web

## 部署方法

### 1. 应用部署
```bash
kubectl apply -f web.yml
```

### 2. 查看部署状态
```bash
# 查看Deployment状态
kubectl get deployment web

# 查看Pod状态
kubectl get pods -l app=web

# 查看Service状态
kubectl get service web
```

### 3. 访问应用
```bash
# 获取NodePort端口号
kubectl get service web -o jsonpath='{.spec.ports[0].nodePort}'

# 通过任意节点IP和NodePort端口访问
curl http://<节点IP>:<NodePort端口>
```

### 4. 删除部署
```bash
kubectl delete -f web.yml
```

## 可修改配置项及作用

### 1. Deployment配置可修改项

#### 应用名称和标签
```yaml
metadata:
  name: web                    # 可修改：应用部署名称
  labels:
    app: web                   # 可修改：应用标签
```
**作用**: 修改应用在Kubernetes中的标识符，便于管理和识别

#### 副本数量
```yaml
spec:
  replicas: 3                  # 可修改：Pod副本数量
```
**作用**: 控制应用的伸缩性，增加副本数量可提高应用可用性和负载能力

#### 容器配置
```yaml
containers:
- name: nginx                  # 可修改：容器名称
  image: nginx:1.25            # 可修改：容器镜像版本
```
**作用**: 
- 容器名称：便于识别和管理多个容器
- 镜像版本：升级Nginx版本或使用自定义镜像

### 2. Service配置可修改项

#### 服务类型
```yaml
spec:
  type: NodePort               # 可修改：服务类型
```
**可选值**:
- `ClusterIP`：集群内部访问（默认）
- `NodePort`：节点端口访问（当前配置）
- `LoadBalancer`：云提供商负载均衡器

**作用**: 控制服务的访问方式

#### 端口配置
```yaml
ports:
- port: 80                     # 可修改：服务端口
  targetPort: 80               # 可修改：容器端口
```
**作用**:
- 服务端口：集群内访问服务的端口
- 容器端口：容器内应用监听的端口

#### 端口映射（可添加）
```yaml
ports:
- port: 80
  targetPort: 80
  nodePort: 30080              # 可添加：指定NodePort端口（范围：30000-32767）
```
**作用**: 固定NodePort端口号，避免随机分配

## 高级配置建议

### 1. 资源限制（建议添加）
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "250m"
  limits:
    memory: "128Mi"
    cpu: "500m"
```

### 2. 健康检查（建议添加）
```yaml
livenessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 5
```

### 3. 环境变量（按需添加）
```yaml
env:
- name: NGINX_ENV
  value: "production"
```

## 故障排除

### 常见问题
1. **Pod启动失败**: 检查镜像拉取权限和网络连接
2. **服务无法访问**: 检查防火墙规则和NodePort范围
3. **应用无响应**: 检查容器健康检查和资源限制

### 调试命令
```bash
# 查看Pod详细状态
kubectl describe pod -l app=web

# 查看Pod日志
kubectl logs -l app=web

# 进入容器调试
kubectl exec -it <pod名称> -- /bin/bash
```