# TYBooks K3s 部署

> 前置条件、构建与交付、FAQ 见 [docs/DEPLOYMENT.md](../docs/DEPLOYMENT.md)。
> 本文只讲 K3s 专属部分：拓扑、集群资源、部署验收、卸载清理。
> 全新服务器的环境准备（内核参数、swap、安装 K3s/Nginx）见 [`SERVER-SETUP.md`](SERVER-SETUP.md)——那是**参考手册**，不是项目运行必需。

## 0. 资源要求（实测）

| 项 | 数值 | 说明 |
| --- | --- | --- |
| K3s 控制平面 | **578 MB**（峰值 635 MB） | 单节点、含 containerd 与 shim，不含业务 |
| K3s 常驻工作集 | 271 MB | `/var/lib/rancher/k3s/data`，不可裁剪 |
| 站点负载 | 约 125 MB | App + PG |

**1 GB 内存跑不了 K3s**：页缓存装不下 271 MB 的工作集，会持续缺页抖动，表现为 apiserver 超时、addon 探针失败重启。**最低 2 GB，推荐 4 GB。**

## 1. 方案与文件

```
浏览器 → Nginx(443) → 127.0.0.1:30080 (NodePort)
        → tybooks-app:8080 → postgres:5432
```

- K3s **停用自带 Traefik 与 servicelb**，入口交给宿主机已有的 Nginx
- PostgreSQL 用 StatefulSet + `local-path` PVC，仅在集群内访问
- 不使用 cert-manager，证书沿用 Nginx 现有配置

| 文件 | 作用 |
| --- | --- |
| `namespace.yaml` | 创建 `tybooks` Namespace |
| `app/app.yaml` | Deployment + NodePort Service(30080) |
| `postgres/postgres.yaml` | ConfigMap + PVC + StatefulSet + Headless Service |
| `nginx/tybooks.conf` | 宿主机 Nginx 的 TLS 反向代理模板 |
| `.env.example` | 部署参数速查（密码、JWT、域名、端口），**不进入集群** |

## 2. 服务器准备

```bash
uname -m                                     # 期望 x86_64
ss -lntp | grep -E ':80|:443'                # 期望看到 nginx
ss -lntp | grep 30080 || echo "NodePort 空闲"
```

确认：域名 A 记录已指向公网 IP；安全组放行 80/443（**30080 不需要对外**）；磁盘 ≥ 5 GB。

### 2.1 停用 Traefik 与 servicelb

```bash
sudo cat /etc/rancher/k3s/config.yaml 2>/dev/null || echo "尚无配置"
```

需要时追加并重启：

```yaml
# /etc/rancher/k3s/config.yaml
disable:
  - traefik
  - servicelb
```

```bash
sudo systemctl restart k3s
```

### 2.2 导入镜像

```bash
sudo k3s ctr images ls | grep -E 'tybooks|postgres' || echo "尚未导入"
sudo k3s ctr images import /tmp/tybooks.tar
sudo k3s ctr images import /tmp/postgres.tar
```

必须能看到这两个名字：

```
docker.io/library/tybooks:<version>
docker.io/library/postgres:16-alpine
```

名字不一致时补标签，否则 Pod 报 `ErrImageNeverPull`：

```bash
sudo k3s ctr images tag <现有镜像名> <需要的镜像名>
```

### 2.3 创建 Namespace 与 Secret

```bash
kubectl get ns tybooks 2>/dev/null || echo "Namespace 尚未创建"
kubectl get secret -n tybooks postgres-secret app-secret 2>/dev/null || echo "Secret 尚未创建"
```

```bash
cd <项目目录>/deploy-k3s
kubectl apply -f namespace.yaml

JWT_SECRET=$(openssl rand -base64 32)

kubectl create secret generic postgres-secret -n tybooks \
  --from-literal=POSTGRES_PASSWORD='<YOUR_POSTGRES_PASSWORD>'

kubectl create secret generic app-secret -n tybooks \
  --from-literal=DATABASE_URL='postgresql://tybooks:<YOUR_POSTGRES_PASSWORD>@postgres:5432/tybooks' \
  --from-literal=DATABASE_URL_READONLY='postgresql://tybooks:<YOUR_POSTGRES_PASSWORD>@postgres:5432/tybooks' \
  --from-literal=JWT_SECRET="$JWT_SECRET"
```

- 数据库密码只用字母数字，避免 URL 转义问题
- 不要省略 `JWT_SECRET`，否则回退到代码内默认密钥
- Secret 已存在要改值时，用 `--dry-run=client -o yaml | kubectl apply -f -` 覆盖

## 3. 部署与验收

```bash
kubectl apply -f postgres/
kubectl wait --for=condition=ready pod -l app=postgres -n tybooks --timeout=180s

kubectl apply -f app/
kubectl rollout status deployment/tybooks-app -n tybooks --timeout=120s
kubectl get pods,svc -n tybooks
```

首次启动会建表、写入 11 个分类与约 50 本示例书，并创建 `admin / admin123`。

本机验证：

```bash
curl http://127.0.0.1:30080/api/auth/check      # 期望 {"authenticated":false}
curl http://127.0.0.1:30080/api/version         # 期望 {"name":"tybooks","version":"<version>"}
```

### 3.1 配置 Nginx

```bash
sudo ls -l /etc/nginx/conf.d/tybooks.conf 2>/dev/null || echo "尚未配置"
sudo cp nginx/tybooks.conf /etc/nginx/conf.d/tybooks.conf   # 已存在先备份再覆盖
sudo vi /etc/nginx/conf.d/tybooks.conf                      # 替换域名与证书路径
sudo nginx -t && sudo systemctl reload nginx
curl -I https://<YOUR_DOMAIN>
```

> 若 Nginx 跑在容器里，`127.0.0.1:30080` 指向容器自身，需改成宿主机 IP 或让该容器使用 host 网络。

### 3.2 改默认密码（K3s 目标暂未接入 `ops:password`）

```bash
# 本地生成哈希
node -e "console.log(require('bcryptjs').hashSync('<YOUR_NEW_PASSWORD>',12))"

# 服务器上先确认账号存在
kubectl exec -n tybooks postgres-0 -- psql -U tybooks -d tybooks -c "SELECT username FROM users;"

# 再更新（把哈希粘进去）
kubectl exec -n tybooks postgres-0 -- psql -U tybooks -d tybooks \
  -c "UPDATE users SET password='<上一步的哈希>' WHERE username='admin';"
```

### 3.3 备份（K3s 目标暂未接入 `ops:backup`）

```bash
sudo mkdir -p /var/backups/tybooks
kubectl exec -n tybooks postgres-0 -- pg_dump -U tybooks tybooks \
  | gzip > /var/backups/tybooks/tybooks-$(date +%F).sql.gz

# 恢复
gunzip -c /var/backups/tybooks/tybooks-2026-01-01.sql.gz \
  | kubectl exec -i -n tybooks postgres-0 -- psql -U tybooks -d tybooks
```

定时任务（注意 `%` 在 crontab 中要转义）：

```cron
0 3 * * * kubectl exec -n tybooks postgres-0 -- pg_dump -U tybooks tybooks | gzip > /var/backups/tybooks/tybooks-$(date +\%F).sql.gz
```

> `scripts/ops/*` 依赖 `docker`/`podman exec`，**不适用于 K3s 目标**；K3s 的运维命令以上面的 `kubectl` 形式为准。

## 4. 更新应用

```bash
npm run version:bump -- 1.1.1
npm run podman:build
npm run image:verify
scp tybooks.tar <user>@<server>:/tmp/

# 服务器
sudo k3s ctr images import /tmp/tybooks.tar
kubectl apply -f app/
kubectl rollout status deployment/tybooks-app -n tybooks --timeout=120s
```

`app/app.yaml` 的 image 固定为版本标签，导入后 apply 即触发滚动更新。回滚把 image 改回旧版本重新 apply 即可，旧镜像仍在 containerd 中。

## 5. 完全卸载与清理

**这一步很重要**：`systemctl stop k3s` 只杀主进程，containerd 启动的容器沙箱（`containerd-shim-runc-v2`）会被 init 接管并继续运行，内存和端口都不会释放。

### 5.1 停止并禁用服务

```bash
sudo systemctl disable --now k3s
```

### 5.2 清理残留容器（关键）

```bash
ls -l /usr/local/bin/k3s-*.sh

sudo /usr/local/bin/k3s-killall.sh      # 只清理容器/沙箱，保留安装
# 或彻底卸载（同时删除 /var/lib/rancher/k3s，回收约 500 MB 磁盘）
sudo /usr/local/bin/k3s-uninstall.sh
```

### 5.3 确认清理干净

```bash
pgrep -af 'k3s|containerd|local-path' || echo "已清空"
ss -lntp | grep -E ':6443|:10250|:8472' || echo "端口已释放"
```

### 5.4 顺带瘦身

K3s 的事件与报错会把 journald 撑大：

```bash
sudo journalctl --vacuum-size=200M
sudo systemctl restart systemd-journald
```

### 5.5 实测参考（1 核 1 GB，从 K3s 迁到 Compose）

| 阶段 | used | available |
| --- | --- | --- |
| 停服务前（含残留 shim） | 895 MiB | 62 MiB |
| `systemctl disable --now k3s` 之后 | 402 MiB | 555 MiB |
| 清理 shim + journald 瘦身后 | 377 MiB | 579 MiB |

释放的大头（约 493 MiB）发生在**停服务**那一步；清理 shim 和 journal 只回收约 65 MiB，但能让端口和内存彻底干净。

## 6. K3s 专属 FAQ

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| Pod `ErrImageNeverPull` | 镜像未导入或名称不一致 | `sudo k3s ctr images ls` 核对，必要时 `ctr images tag` |
| Pod `ImagePullBackOff` | 清单引用了不存在的镜像名 | 确认 PG 是 `docker.io/library/postgres:16-alpine` |
| Pod 一直 `Pending` | PVC 未绑定或磁盘不足 | `kubectl describe pvc -n tybooks` |
| App 反复 `CrashLoopBackOff` | Secret 缺失或连不上数据库 | `kubectl logs deploy/tybooks-app -n tybooks` |
| Nginx 502 | NodePort 后端未就绪 | 检查 Pod Ready，`curl 127.0.0.1:30080/api/auth/check` |
| 80/443 启动冲突 | Traefik 未停用 | 按 2.1 禁用并重启 K3s |
| `kubectl get pods -A` 超时 | 内存不足导致 apiserver 响应超时 | 见第 0 节；`dmesg`/`journalctl -u k3s` 查证 |
