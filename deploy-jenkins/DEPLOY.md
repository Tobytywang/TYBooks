# Jenkins K3s 部署指南

基于 K3s，将 Jenkins 部署在独立的 `ci` namespace 中，与业务应用（tybooks）隔离。Jenkins 作为 CI/CD 基础设施，可跨 namespace 部署任意项目。

## 一、安装/部署前需知

### 所需软件

| 软件   | 安装位置    | 说明                               |
| ------ | ----------- | ---------------------------------- |
| Podman | 本地        | 导出镜像                           |
| K3s    | 服务器      | 轻量级 K8s 集群（与 tybooks 共用） |
| scp    | 本地/服务器 | 传输镜像（通常系统自带）           |

### 暴露端口

| 端口  | 服务          | 说明                                  |
| ----- | ------------- | ------------------------------------- |
| 8080  | Jenkins Web   | 通过 Ingress 暴露                     |
| 50000 | Jenkins Agent | 集群内部使用，供 Agent 通过 JNLP 连接 |

### 持久化卷

| PVC 名称    | 存储类     | 大小 | 说明                                       |
| ----------- | ---------- | ---- | ------------------------------------------ |
| jenkins-pvc | local-path | 5Gi  | Jenkins 数据持久化（插件、配置、构建记录） |

### 配置文件

| 文件               | 说明                                            |
| ------------------ | ----------------------------------------------- |
| `namespace.yaml` | ci Namespace 定义                               |
| `jenkins.yaml`   | Jenkins 全部资源（PVC + StatefulSet + Service） |
| `ingress.yaml`   | Ingress 路由，需替换域名                        |

### K8s 资源清单

| 资源            | 类型        | Namespace | 文件           |
| --------------- | ----------- | --------- | -------------- |
| ci              | Namespace   | -         | namespace.yaml |
| jenkins-pvc     | PVC         | ci        | jenkins.yaml   |
| jenkins         | StatefulSet | ci        | jenkins.yaml   |
| jenkins         | Service     | ci        | jenkins.yaml   |
| jenkins-ingress | Ingress     | ci        | ingress.yaml   |

### Jenkins 初始配置

| 项目           | 说明                                                                     |
| -------------- | ------------------------------------------------------------------------ |
| 初始管理员密码 | 存储在`/var/jenkins_home/secrets/initialAdminPassword`，首次访问时需要 |
| 数据目录       | `/var/jenkins_home`，挂载到 PVC 持久化                                 |
| fsGroup        | 1000，确保 Jenkins 进程对数据目录有写权限                                |

## 二、安装步骤

### 1. 本地：导出 Jenkins 镜像

```bash
podman pull docker.m.daocloud.io/library/jenkins/jenkins:lts
podman save docker.m.daocloud.io/library/jenkins/jenkins:lts -o jenkins.tar
scp jenkins.tar user@server:/tmp/
```

### 2. 服务器：安装 K3s（如已安装可跳过）

```bash
curl -sfL https://get.k3s.io | sh -
mkdir -p ~/.kube && sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config && sudo chown $USER ~/.kube/config
```

验证：

```bash
kubectl get nodes
```

### 3. 服务器：导入镜像

```bash
sudo k3s ctr images import /tmp/jenkins.tar
```

### 4. 服务器：修改配置

编辑 `ingress.yaml` 中的域名为实际域名（如 jenkins.example.com）

### 5. 服务器：部署

```bash
kubectl apply -f namespace.yaml
kubectl apply -f jenkins.yaml
kubectl wait --for=condition=ready pod -l app=jenkins -n ci --timeout=180s
kubectl apply -f ingress.yaml
```

### 6. 服务器：配置 TLS（cert-manager + Let's Encrypt）

如果尚未安装 cert-manager：

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
```

等待 cert-manager 就绪：

```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=120s
```

创建 ClusterIssuer：

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: traefik
EOF
```

> 将 `your-email@example.com` 替换为你的邮箱。证书签发需要域名已解析到服务器 IP。

### 7. 服务器：获取初始管理员密码

```bash
kubectl exec -it $(kubectl get pods -l app=jenkins -n ci -o jsonpath='{.items[0].metadata.name}') -n ci -- cat /var/jenkins_home/secrets/initialAdminPassword
```

### 8. 服务器：验证

```bash
kubectl get pods -n ci
kubectl get ingress -n ci
```

### 9. 更新部署

```bash
# 本地重新导出
podman pull docker.m.daocloud.io/library/jenkins/jenkins:lts
podman save docker.m.daocloud.io/library/jenkins/jenkins:lts -o jenkins.tar
scp jenkins.tar user@server:/tmp/

# 服务器导入并重启
sudo k3s ctr images import /tmp/jenkins.tar
kubectl rollout restart statefulset jenkins -n ci
```
