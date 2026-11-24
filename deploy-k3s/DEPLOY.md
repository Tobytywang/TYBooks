# TYBooks K3s 部署指南

基于 K3s（轻量级 Kubernetes），将 tybooks 应用部署到生产环境。PG 使用 StatefulSet + PVC 持久化，App 使用 Deployment，Ingress 暴露服务。

## 一、安装/部署前需知

### 所需软件

| 软件        | 安装位置    | 说明                            |
| ----------- | ----------- | ------------------------------- |
| Node.js 20+ | 本地        | 构建前端                        |
| Podman      | 本地        | 构建和导出镜像                  |
| K3s         | 服务器      | 轻量级 K8s 集群（自带 kubectl） |
| scp         | 本地/服务器 | 传输镜像（通常系统自带）        |

### 暴露端口

| 端口 | 服务        | 说明                                                     |
| ---- | ----------- | -------------------------------------------------------- |
| 8080 | tybooks-app | 通过 Ingress 暴露，K3s 默认使用 NodePort 或 LoadBalancer |

> PG 的 5432 端口仅在集群内部可见（ClusterIP: None），不暴露到外部。

### 持久化卷

| PVC 名称     | 存储类     | 大小 | 说明          |
| ------------ | ---------- | ---- | ------------- |
| postgres-pvc | local-path | 1Gi  | PG 数据持久化 |

### 配置文件

| 文件                       | 说明                                                                              |
| -------------------------- | --------------------------------------------------------------------------------- |
| `.env.example`           | 环境变量模板（密码、域名）                                                        |
| `namespace.yaml`         | Namespace 定义                                                                    |
| `postgres/postgres.yaml` | PG 全部资源（ConfigMap + PVC + StatefulSet + Service） |
| `app/app.yaml`           | App 全部资源（Deployment + Service）                   |
| `ingress.yaml`           | Ingress 路由，需替换域名                                                          |

### K8s 资源清单

| 资源            | 类型               | Namespace | 文件                   |
| --------------- | ------------------ | --------- | ---------------------- |
| tybooks         | Namespace          | -         | namespace.yaml         |
| postgres-config | ConfigMap          | tybooks   | postgres/postgres.yaml |
| postgres-pvc    | PVC                | tybooks   | postgres/postgres.yaml |
| postgres        | StatefulSet        | tybooks   | postgres/postgres.yaml |
| postgres        | Service (Headless) | tybooks   | postgres/postgres.yaml |
| tybooks-app     | Deployment         | tybooks   | app/app.yaml           |
| tybooks-app     | Service            | tybooks   | app/app.yaml           |
| tybooks-ingress | Ingress            | tybooks   | ingress.yaml           |

### PG 运行参数

| 参数            | 值      | 说明             |
| --------------- | ------- | ---------------- |
| wal_level       | replica | 支持主从复制     |
| max_wal_senders | 3       | 最大复制连接数   |
| hot_standby     | on      | 从库支持只读查询 |

## 二、安装步骤

### 1. 本地：构建并导出镜像

```bash
npm run podman:build
scp tybooks.tar user@server:/tmp/
```

离线环境还需导出 PG 镜像：

```bash
podman pull docker.m.daocloud.io/library/postgres:16-alpine
podman save docker.m.daocloud.io/library/postgres:16-alpine -o postgres.tar
scp postgres.tar user@server:/tmp/
```

### 2. 服务器：安装 K3s

```bash
curl -sfL https://get.k3s.io | sh -
mkdir ~/.kube && sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config && chown $USER ~/.kube/config
```

### 3. 服务器：导入镜像

```bash
sudo k3s ctr images import /tmp/tybooks.tar
```

离线环境还需导入 PG 镜像：

```bash
sudo k3s ctr images import /tmp/postgres.tar
```

### 4. 服务器：创建 Secret

生成 JWT_SECRET：

```bash
JWT_SECRET=$(openssl rand -base64 32)
echo "JWT_SECRET: ${JWT_SECRET}"
```

创建 PostgreSQL Secret（将 `你的密码` 替换为实际密码，含特殊字符时用单引号包裹）：

```bash
kubectl create secret generic postgres-secret -n tybooks \
  --from-literal=POSTGRES_PASSWORD='你的密码' \
  --from-literal=REPLICATOR_PASSWORD='你的密码'
```

创建应用 Secret（将 `你的密码` 和 `${JWT_SECRET}` 替换为实际值）：

```bash
kubectl create secret generic app-secret -n tybooks \
  --from-literal=DATABASE_URL="postgresql://tybooks:你的密码@postgres:5432/tybooks" \
  --from-literal=DATABASE_URL_READONLY="postgresql://tybooks:你的密码@postgres:5432/tybooks" \
  --from-literal=JWT_SECRET="${JWT_SECRET}"
```

> 密码含单引号时用双引号包裹，同时含单引号和双引号时用转义。JWT_SECRET 用 `openssl rand -base64 32` 生成。

### 5. 服务器：部署

```bash
kubectl apply -f namespace.yaml
kubectl apply -f postgres/
kubectl wait --for=condition=ready pod -l app=postgres -n tybooks --timeout=120s
kubectl apply -f app/
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

### 7. 服务器：验证

```bash
kubectl get pods -n tybooks
kubectl get ingress -n tybooks
```

### 8. 更新部署

```bash
# 本地重新构建并传输
npm run podman:build
scp tybooks.tar user@server:/tmp/

# 服务器导入并重启
sudo k3s ctr images import /tmp/tybooks.tar
kubectl rollout restart deployment tybooks-app -n tybooks
```
