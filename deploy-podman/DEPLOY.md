# TYBooks Podman Pod 部署

> 前置条件、构建与交付、安全加固、备份与恢复、FAQ 见 [docs/DEPLOYMENT.md](../docs/DEPLOYMENT.md)。
> 本文只讲 Podman Pod 专属部分。

适用于单机（尤其是开发机）快速起一套：PG 与 App 在同一个 Pod 内，共享网络命名空间，App 用 `localhost:5432` 连库。

## 一、拓扑与文件

```
Pod tybooks
├── postgres   5432（仅 Pod 内可见，不映射到宿主）
└── app        8080 → hostPort 8080
```

| 文件 | 作用 |
| --- | --- |
| `pod.yaml` | K8s Pod 格式的清单：容器、环境变量、卷、探针 |
| `deploy.env` | 给 `scripts/ops/` 的目标描述（运行时 `podman`、容器名 `tybooks-app`） |

**与 Compose 的机制差异**：`podman play kube` **不做变量插值**，所以配置只能内联在 `pod.yaml` 里，占位符是 `<YOUR_*>`（与其它部署方式统一）。

数据卷：hostPath `/var/lib/tybooks/pg-data` → `/var/lib/postgresql/data`。

> `pod.yaml` 里的 `postgres` 镜像走 `docker.m.daocloud.io/library/postgres:16-alpine`（本机已有的 tag）；应用镜像走 `docker.io/library/tybooks:<version>`。

## 二、准备

### 1. 替换占位符

```bash
cd deploy-podman
grep -n 'YOUR_' pod.yaml        # 应看到 4 处
```

编辑 `pod.yaml`，把 `<YOUR_POSTGRES_PASSWORD>`（3 处）和 `<YOUR_JWT_SECRET>`（1 处）替换为实际值。再次执行上面的命令应无输出。

数据卷用的是 hostPath，目录会被自动创建；本机测试时可改成别的路径避免污染。

### 2. 构建镜像（本机原生，不导出 tar）

`pod.yaml` 直接用本地镜像，所以不必导出 tar：

```bash
PLATFORM=native EXPORT=0 npm run podman:build
podman images | grep tybooks
```

## 三、部署与验收

### 1. 启动

```bash
podman pod ps | grep tybooks || echo "尚无 tybooks Pod"   # 已存在先按第四节清理
podman play kube pod.yaml
```

### 2. 验收

```bash
npm run ops:verify -- deploy-podman
```

### 3. 更新

```bash
npm run version:bump -- 1.1.1
PLATFORM=native EXPORT=0 npm run podman:build
podman pod rm -f tybooks && podman play kube pod.yaml    # Pod 需要重建才能用新镜像
```

## 四、停止与清理

```bash
podman pod ps | grep tybooks || echo "没有 tybooks Pod"
podman pod stop tybooks
podman pod rm tybooks
```

数据在宿主机的 `/var/lib/tybooks/pg-data`（rootful podman 下位于 Podman VM 内），需要一并清理时：

```bash
podman run --rm -v /var/lib:/host docker.io/library/postgres:16-alpine \
  sh -c 'rm -rf /host/tybooks'
```

> **注意**：删除数据目录后再次启动会重新建表并创建 `admin / admin123`。

## 五、从 Docker 迁移数据

```bash
# 确认源容器在运行（Exited 的先 docker start）
docker ps -a --filter ancestor=postgres:16-alpine --format '{{.Names}}\t{{.Status}}'

docker exec <容器名> pg_dump -U tybooks tybooks > backup.sql
podman exec -i tybooks-postgres psql -U tybooks -d tybooks < backup.sql
```

## 附：资源测量

`tools/measure-memory.sh` 会在本机起一套独立的 tybooks Pod（端口 18080、独立数据目录），测量稳定态内存与 VM 总占用，测完可保留或清理：

```bash
bash tools/measure-memory.sh            # 保留环境
KEEP=0 bash tools/measure-memory.sh     # 测完自动清理
```

> 该脚本依赖 macOS 上的 `podman machine ssh`，**仅适用于 macOS**；Linux 上的 rootful Podman 没有 `podman machine` 子命令。

实测参考（1 核 1 GB）：App 54–70 MB、PG 70 MB（含页缓存）、合计约 125 MB。
