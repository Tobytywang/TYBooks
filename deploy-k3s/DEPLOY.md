# TYBooks K3s 部署指南

## 本地：构建镜像

```bash
npm run build
podman build --build-arg REGISTRY=docker.m.daocloud.io/library -t tybooks:latest .
podman save tybooks:latest -o /tmp/tybooks.tar
scp /tmp/tybooks.tar user@server:/tmp/
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
podman build --build-arg REGISTRY=docker.m.daocloud.io/library -t tybooks:latest .
podman save tybooks:latest -o /tmp/tybooks.tar
scp /tmp/tybooks.tar user@server:/tmp/

# 服务器导入并重启
sudo k3s ctr images import /tmp/tybooks.tar
kubectl rollout restart deployment tybooks-app -n tybooks
```
