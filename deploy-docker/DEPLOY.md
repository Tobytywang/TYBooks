# TYBooks Docker Compose 部署

> 前置条件、构建与交付、安全加固、备份与恢复、FAQ 见 [docs/DEPLOYMENT.md](../docs/DEPLOYMENT.md)。
> 本文只讲 Compose 专属部分：拓扑、服务器准备、部署验收、端口收窄、停止清理。

## 一、拓扑与文件

支持两种形态，清单不同、部署命令相同：

```
单节点：  app(8080) ── postgres(5432, 仅回环)
主从：    Primary: app + postgres(主)  ──复制──►  Standby: app + postgres(从)
```

| 端口 | 服务 | 节点 |
| --- | --- | --- |
| 8080 | tybooks-app | Primary / Standby |
| 5432 | PostgreSQL | Primary / Standby，默认只绑 `127.0.0.1` |

| 文件 | 作用 |
| --- | --- |
| `primary/docker-compose.yml` | 主库 + 应用 |
| `standby/docker-compose.yml` | 从库 + 应用 |
| `.env.example` | 环境变量模板（密码、IP、密钥） |
| `env.sh` | 供 `init.sh` / `setup.sh` 加载同一个 `.env` |
| `primary/init.sh` | 运行期初始化：创建复制用户 + 写 `pg_hba` |
| `standby/setup.sh` | 运行期初始化：清空从库数据并 `pg_basebackup` |
| `deploy.env` | 给 `scripts/ops/` 的目标描述（运行时、容器名、端口） |

数据卷：`pg-data` → `/var/lib/postgresql/data`（每个节点各一份）。

| 环境变量 | 说明 |
| --- | --- |
| `POSTGRES_PASSWORD` | PG 应用用户密码，**只用字母数字**（会拼进 `DATABASE_URL`） |
| `JWT_SECRET` | JWT 密钥，所有节点必须一致 |
| `REPLICATOR_PASSWORD` | 复制用户密码（仅主从模式） |
| `PRIMARY_IP` | 主库内网 IP（仅 Standby 填写） |
| `STANDBY_IPS` | 从库 IP，逗号分隔（仅 Primary 填写） |

PG 运行参数（`primary/docker-compose.yml` 中固定）：`wal_level=replica`、`max_wal_senders=3`、`hot_standby=on`。

## 二、服务器准备

### 1. 目录约定

```
/opt/tybooks/deploy-docker/
├── .env
├── .env.example
└── primary/docker-compose.yml
```

`.env` 必须放在 `primary/`、`standby/` 的**上一级**：Compose 只读当前目录的 `.env`，所以后续所有命令都要带 `--env-file ../.env`。

### 2. 准备 `.env`

```bash
cd /opt/tybooks/deploy-docker
cp -n .env.example .env        # -n：已存在则不覆盖
chmod 600 .env
```

把 `<YOUR_*>` 占位符替换为实际值，单节点时只填两个：

```bash
POSTGRES_PASSWORD=Tybooks2026abc
JWT_SECRET=<openssl rand -hex 32 的输出>
# REPLICATOR_PASSWORD / PRIMARY_IP / STANDBY_IPS 留空
```

> ⚠️ 占位符是 `<YOUR_*>` 形式。**替换完之前不要 `source .env`**——bash 会把 `<` 当重定向。Compose 读 `.env` 不受影响。

确认无残留：

```bash
grep -n 'YOUR_' .env || echo "占位符已清空"
```

### 3. （1 GB 机器建议）加内存上限

Compose 会自动合并同目录的 `docker-compose.override.yml`，不用改原文件：

```yaml
services:
  app:
    mem_limit: 256m
  postgres:
    mem_limit: 384m
```

### 4. 启动前体检

```bash
npm run ops:doctor -- deploy-docker
```

检查运行时、占位符、端口、**镜像架构**、可用内存。任意一项 `✗` 都不要继续。

## 三、部署与验收

### 1. 加载镜像

```bash
docker load -i /opt/tybooks/tybooks.tar
docker load -i /opt/tybooks/postgres.tar
docker image inspect postgres:16-alpine --format '{{.Os}}/{{.Architecture}}'   # 需要 linux/amd64
```

### 2. 启动 Primary

```bash
cd primary
docker compose --env-file ../.env up -d
docker compose --env-file ../.env ps
docker compose --env-file ../.env logs --tail 20 app
```

首次启动日志会先出现一次 `数据库连接失败 (1/10)`（PG 初始化慢几秒），随后是：

```
Created default admin user (username: admin, password: admin123)
Seeded 11 genres
Seeded 52 books
Server running at http://localhost:8080
```

**单节点部署到此结束**，跳到第 5 步验收。

### 3. 主从模式：初始化 Primary

```bash
bash init.sh      # 建 replicator 用户 + 按 STANDBY_IPS 写 pg_hba，幂等
```

### 4. 主从模式：Standby

> `setup.sh` 会**清空从库的 PostgreSQL 数据目录**并从主库重新拉取。执行前确认该节点没有要保留的数据。

```bash
cd standby
bash setup.sh                                  # pg_basebackup + 启动从库
docker compose --env-file ../.env up -d app    # 启动应用
```

扩展新 Standby：改 Primary 的 `.env` 追加 `STANDBY_IPS` → 在 Primary 重跑 `bash init.sh` → 新节点执行第 4 步。

### 5. 验收

```bash
npm run ops:verify -- deploy-docker
```

它一次给出：容器状态、`/api/version`、`/api/books` 条数、登录接口、资源占用。全绿即通过。

手工兜底：

```bash
curl -s localhost:8080/api/version
```

### 6. 更新应用

```bash
npm run version:bump -- 1.1.1
npm run podman:build
npm run image:verify
scp tybooks.tar <user>@<node>:/opt/tybooks/

# 服务器上
docker load -i /opt/tybooks/tybooks.tar
cd /opt/tybooks/deploy-docker/primary
docker compose --env-file ../.env up -d     # 检测到镜像变化会自动重建 app 容器
```

`docker load` 只新增标签，不删除旧标签；Postgres 容器不受影响。

## 四、端口暴露面收窄

默认 `8080:8080` 绑在 `0.0.0.0`，公网可直接访问。等 Nginx 顶在前面后改成只绑回环：

```yaml
# docker-compose.override.yml
services:
  app:
    ports:
      - "127.0.0.1:8080:8080"
```

这样外部必须走 `443 → Nginx → 127.0.0.1:8080`，Nginx 上的限流/鉴权才真正生效。

## 五、停止与清理

```bash
cd primary
docker compose --env-file ../.env down        # 停止并删除容器，保留数据卷
docker compose --env-file ../.env down -v     # ⚠️ 连数据卷一起删
```

> `down -v` 会清空 `users` 表，下次启动重新写入 `admin / admin123`——**改过的密码会丢**。

清理悬空镜像（重复 load 产生的旧版本）：

```bash
docker image prune -f
```

**若该机器以前装过 k3s**，残留的 `containerd-shim` 不会随服务停止而退出，会继续占用内存和端口。先按 [`../deploy-k3s/DEPLOY.md`](../deploy-k3s/DEPLOY.md) 的「完全卸载与清理」处理，再部署本方案。
