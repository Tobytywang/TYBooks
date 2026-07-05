# TYBooks K3s 部署指南

## 前置依赖

### 本地
- Node.js 20+
- Podman

### 服务器
- K3s（安装后自带 kubectl）
- scp（通常系统自带）

## 本地：构建镜像

```bash
npm run podman:build
scp tybooks.tar user@server:/tmp/
```

### 离线环境：导出 PostgreSQL 镜像

如果服务器无法访问外网，需要本地导出 PG 镜像一并传输：

```bash
podman pull docker.m.daocloud.io/library/postgres:16-alpine
podman save postgres:16-alpine -o postgres.tar
scp postgres.tar user@server:/tmp/
```

## 服务器：安装 K3s

```bash
curl -sfL https://get.k3s.io | sh -
mkdir ~/.kube && sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config && chown $USER ~/.kube/config
```

## 服务器：导入镜像

```bash
sudo k3s ctr images import /tmp/tybooks.tar
```

离线环境还需导入 PG 镜像：

```bash
sudo k3s ctr images import /tmp/postgres.tar
```

## 服务器：修改配置

编辑 `postgres/postgres.yaml` 和 `app/app.yaml` 中的 `CHANGE_ME` 为实际密码
编辑 `ingress.yaml` 中的域名为实际域名

## 服务器：部署

```bash
kubectl apply -f namespace.yaml
kubectl apply -f postgres/
kubectl wait --for=condition=ready pod -l app=postgres -n tybooks --timeout=120s
kubectl apply -f app/
kubectl apply -f ingress.yaml
```

## 服务器：验证

```bash
kubectl get pods -n tybooks
kubectl get ingress -n tybooks
```

## 更新部署

```bash
# 本地重新构建并传输
npm run podman:build
scp tybooks.tar user@server:/tmp/

# 服务器导入并重启
sudo k3s ctr images import /tmp/tybooks.tar
kubectl rollout restart deployment tybooks-app -n tybooks
```
