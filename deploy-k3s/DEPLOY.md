# TYBooks K3s 部署指南

> 适用环境：x86_64 服务器、可上网但镜像源受限、有公网域名并已运行 Nginx、全新部署（无需迁移旧数据）。

## 0. 方案概览

- 本地 macOS 用 Podman 构建 `linux/amd64` 镜像，导出 tar 传到服务器
- 服务器安装 K3s 并**停用自带 Traefik**
- 应用通过 **NodePort 30080** 暴露，只监听本机
- 由服务器上**已有的 Nginx** 终止 TLS，反代到 `127.0.0.1:30080`
- PostgreSQL 使用 StatefulSet + local-path PVC，仅在集群内访问
- 不使用 cert-manager，证书沿用 Nginx 现有配置

访问链路：

```
浏览器 → Nginx(443) → 127.0.0.1:30080 (K3s NodePort)
        → tybooks-app:8080 → postgres:5432
```

## 1. 部署前检查（服务器）

```bash
uname -m
# 期望输出 x86_64

ss -lntp | grep -E ':80|:443'
# 期望看到 nginx 进程

ss -lntp | grep 30080
# 应无输出，确认 NodePort 未被占用
```

同时确认：

- 域名 A 记录已指向服务器公网 IP
- 安全组/防火墙放行 80、443（30080 不需要对外放行）
- 磁盘剩余空间 ≥ 5GB（镜像 + PVC）
- 如需在本地远程执行 kubectl，再放行 6443

## 2. 本地构建镜像（Mac）

```bash
podman machine start
npm run podman:build
```

`npm run podman:build` 实际调用 `deploy-k3s/build.sh`，它会：

1. 检查 Podman 是否就绪
2. 检查并按需拉取 `docker.m.daocloud.io/library/postgres:16-alpine`
3. 执行前端构建 `npm run build`
4. 以 `linux/amd64` 构建应用镜像 `docker.io/library/tybooks:latest`
5. 将 PG 镜像打上 `docker.io/library/postgres:16-alpine` 标签
6. 导出 `tybooks.tar` 与 `postgres.tar`

构建完成后确认两个镜像名：

```bash
podman images | grep -E 'tybooks|postgres'
```

期望看到：

```
docker.io/library/tybooks        latest
docker.io/library/postgres       16-alpine
```

传输到服务器：

```bash
scp tybooks.tar postgres.tar <user>@<server>:/tmp/
```

## 3. 服务器安装 K3s

使用 Rancher 国内镜像安装，并停用 Traefik：

```bash
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh \
  | INSTALL_K3S_MIRROR=cn INSTALL_K3S_EXEC="--disable traefik" sh -
```

配置 kubectl：

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER ~/.kube/config
kubectl get nodes
```

如果 K3s 已经安装过但没有停用 Traefik，新增配置后重启：

```bash
sudo tee /etc/rancher/k3s/config.yaml >/dev/null <<'EOF'
disable:
  - traefik
EOF
sudo systemctl restart k3s
```

**镜像源受限时的兜底方案（air-gap）**：如果 `kubectl get pods -A` 看到系统 Pod 卡在 `ImagePullBackOff`，改用离线安装。先在能访问 Rancher 镜像的机器下载与目标版本一致的 `k3s` 二进制和 `k3s-airgap-images-amd64.tar.zst`，再执行：

```bash
sudo mkdir -p /var/lib/rancher/k3s/agent/images/
sudo cp k3s-airgap-images-amd64.tar.zst /var/lib/rancher/k3s/agent/images/
chmod +x k3s && sudo mv k3s /usr/local/bin/k3s

curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh \
  | INSTALL_K3S_MIRROR=cn INSTALL_K3S_SKIP_DOWNLOAD=true \
    INSTALL_K3S_EXEC="--disable traefik" sh -
```

## 4. 导入镜像并核对名称

```bash
sudo k3s ctr images import /tmp/tybooks.tar
sudo k3s ctr images import /tmp/postgres.tar
sudo k3s ctr images ls | grep -E 'tybooks|postgres'
```

必须能看到这两个名字：

```
docker.io/library/tybooks:latest
docker.io/library/postgres:16-alpine
```

如果名字不一致（例如出现 `localhost/tybooks:latest`），用下面的命令补充标签，否则 Pod 会报 `ErrImageNeverPull`：

```bash
sudo k3s ctr images tag <现有镜像名> <需要的镜像名>
```

## 5. 创建 Namespace 和 Secret

```bash
cd <项目目录>/deploy-k3s
kubectl apply -f namespace.yaml

JWT_SECRET=$(openssl rand -base64 32)

kubectl create secret generic postgres-secret -n tybooks \
  --from-literal=POSTGRES_PASSWORD='YOUR_DB_PASSWORD'

kubectl create secret generic app-secret -n tybooks \
  --from-literal=DATABASE_URL='postgresql://tybooks:YOUR_DB_PASSWORD@postgres:5432/tybooks' \
  --from-literal=DATABASE_URL_READONLY='postgresql://tybooks:YOUR_DB_PASSWORD@postgres:5432/tybooks' \
  --from-literal=JWT_SECRET="$JWT_SECRET"
```

注意事项：

- 数据库密码只用字母和数字，避免出现在 URL 里时需要转义
- 不要省略 `JWT_SECRET`，否则会退回代码中的默认密钥
- Secret 已存在需要修改时，用下面的方式覆盖：

```bash
kubectl create secret generic app-secret -n tybooks \
  --from-literal=... \
  --dry-run=client -o yaml | kubectl apply -f -
```

## 6. 部署 PostgreSQL 和 App

```bash
kubectl apply -f postgres/
kubectl wait --for=condition=ready pod -l app=postgres -n tybooks --timeout=180s

kubectl apply -f app/
kubectl rollout status deployment/tybooks-app -n tybooks --timeout=120s

kubectl get pods,svc -n tybooks
```

本机验证：

```bash
curl http://127.0.0.1:30080/api/auth/check
# 期望返回 {"authenticated":false}
```

首次启动时应用会自动建表，写入 11 个分类和约 50 本示例书，并创建默认账号 `admin / admin123`。

## 7. 配置 Nginx 反向代理

把 `nginx/tybooks.conf` 复制为 `/etc/nginx/conf.d/tybooks.conf`（部分发行版是 `/etc/nginx/sites-enabled/`），替换其中的域名和证书路径：

```bash
sudo cp nginx/tybooks.conf /etc/nginx/conf.d/tybooks.conf
sudo vi /etc/nginx/conf.d/tybooks.conf
sudo nginx -t && sudo systemctl reload nginx
```

验证 HTTPS：

```bash
curl -I https://YOUR_DOMAIN
```

如果 Nginx 运行在容器里，`127.0.0.1:30080` 指向的是容器自身，需要改成宿主机 IP，或让该容器使用 host 网络。

## 8. 首次登录与修改默认密码

浏览器打开 `https://YOUR_DOMAIN`，用 `admin / admin123` 登录后立即改密。

先在本地 Mac 的项目根目录生成新密码的 bcrypt 哈希：

```bash
node -e "console.log(require('bcryptjs').hashSync('YOUR_NEW_PASSWORD',12))"
```

把输出的哈希字符串粘贴到下面的命令中，在服务器上执行：

```bash
kubectl exec -n tybooks postgres-0 -- psql -U tybooks -d tybooks \
  -c "UPDATE users SET password='粘贴上一步的哈希' WHERE username='admin';"
```

如果不需要示例书籍，可以清空：

```bash
kubectl exec -n tybooks postgres-0 -- psql -U tybooks -d tybooks -c "TRUNCATE books;"
```

## 9. 更新应用

本地重新构建并传输：

```bash
npm run podman:build
scp tybooks.tar <user>@<server>:/tmp/
```

服务器导入并重建 Pod：

```bash
sudo k3s ctr images import /tmp/tybooks.tar
kubectl rollout restart deployment/tybooks-app -n tybooks
kubectl rollout status deployment/tybooks-app -n tybooks --timeout=120s
```

当前使用 `latest` 标签 + `imagePullPolicy: Never`，导入会覆盖同名标签。若发现 Pod 仍在使用旧镜像，改为版本号标签：修改 `build.sh` 中的 `APP_IMAGE` 和 `app/app.yaml` 中的 `image`，再用 `kubectl set image` 更新。

## 10. 备份与恢复

手动备份：

```bash
sudo mkdir -p /var/backups/tybooks
kubectl exec -n tybooks postgres-0 -- pg_dump -U tybooks tybooks \
  | gzip > /var/backups/tybooks/tybooks-$(date +%F).sql.gz
```

每天凌晨 3 点自动备份（写入 crontab，注意 `%` 需要转义）：

```cron
0 3 * * * kubectl exec -n tybooks postgres-0 -- pg_dump -U tybooks tybooks | gzip > /var/backups/tybooks/tybooks-$(date +\%F).sql.gz
```

恢复：

```bash
gunzip -c /var/backups/tybooks/tybooks-2026-01-01.sql.gz \
  | kubectl exec -i -n tybooks postgres-0 -- psql -U tybooks -d tybooks
```

## 11. 常见问题

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| Pod 状态 `ErrImageNeverPull` | 镜像未导入或名称不一致 | `sudo k3s ctr images ls` 核对，必要时 `ctr images tag` |
| Pod 状态 `ImagePullBackOff` | 清单引用了不存在的镜像名 | 确认 PG 是 `docker.io/library/postgres:16-alpine` |
| Pod 一直 `Pending` | PVC 未绑定或磁盘不足 | `kubectl describe pvc -n tybooks` |
| App 反复 `CrashLoopBackOff` | Secret 缺失或连不上数据库 | `kubectl logs deploy/tybooks-app -n tybooks` |
| Nginx 返回 502 | NodePort 后端未就绪 | 检查 Pod Ready，`curl 127.0.0.1:30080/api/auth/check` |
| K3s 系统 Pod 拉镜像失败 | 镜像源受限 | 改用第 3 节的 air-gap 安装 |
| 80/443 启动冲突 | Traefik 未停用 | 按第 3 节禁用 Traefik 并重启 K3s |

## 文件清单

| 文件 | 用途 |
| --- | --- |
| `build.sh` | 本地构建 linux/amd64 镜像并导出 tar |
| `namespace.yaml` | 创建 `tybooks` Namespace |
| `postgres/postgres.yaml` | ConfigMap + PVC + StatefulSet + Headless Service |
| `app/app.yaml` | Deployment + NodePort Service |
| `nginx/tybooks.conf` | Nginx TLS 反向代理模板 |
| `.env.example` | 部署参数模板（密码、JWT、域名、端口） |
