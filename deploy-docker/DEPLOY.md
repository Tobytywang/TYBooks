# TYBooks Docker 部署指南

基于 Docker Compose，支持单节点部署和 PG 主从复制多节点部署。

## 一、安装/部署前需知

### 所需软件

| 软件           | 安装位置 | 说明                 |
| -------------- | -------- | -------------------- |
| Docker         | 所有节点 | 运行容器             |
| Docker Compose | 所有节点 | 编排多容器           |
| Node.js 20+    | 构建节点 | 构建前端与应用镜像   |

### 暴露端口

| 端口 | 服务        | 节点              |
| ---- | ----------- | ----------------- |
| 5432 | PostgreSQL  | Primary + Standby |
| 8080 | tybooks-app | Primary + Standby |

### 数据卷

| 卷名    | 挂载路径                 | 说明                            |
| ------- | ------------------------ | ------------------------------- |
| pg-data | /var/lib/postgresql/data | PG 数据持久化（每个节点各一个） |

### 配置文件

| 文件                           | 说明                                                |
| ------------------------------ | --------------------------------------------------- |
| `.env`                       | 环境变量（密码、IP、密钥），从`.env.example` 复制 |
| `env.sh`                     | 脚本共用的环境变量加载逻辑                          |
| `primary/docker-compose.yml` | Primary 节点容器编排                                |
| `standby/docker-compose.yml` | Standby 节点容器编排                                |

### 环境变量

| 变量                | 说明                                        |
| ------------------- | ------------------------------------------- |
| POSTGRES_PASSWORD   | PG 应用用户密码                             |
| REPLICATOR_PASSWORD | PG 复制用户密码（多节点时需要）             |
| PRIMARY_IP          | Primary 节点内网 IP（Standby 上填写）       |
| STANDBY_IPS         | Standby 节点 IP（逗号分隔，Primary 上填写） |
| JWT_SECRET          | JWT 密钥（所有节点必须一致）                |

### PG 运行参数

| 参数            | 值      | 说明             |
| --------------- | ------- | ---------------- |
| wal_level       | replica | 支持主从复制     |
| max_wal_senders | 3       | 最大复制连接数   |
| hot_standby     | on      | 从库支持只读查询 |

## 二、安装步骤

### 1. 准备配置

复制 `.env.example` 为 `.env`（放在 `deploy-docker/` 根目录），替换所有占位符：

```bash
cp .env.example .env
```

`.env` 在 `deploy-docker/` 根目录，而 compose 文件位于 `primary/`、`standby/` 子目录。Compose 默认只读取当前目录的 `.env`，因此后续所有 `docker compose` 命令都必须带 `--env-file ../.env`；`init.sh` 和 `setup.sh` 会自动加载同一个文件。

### 2. 构建应用镜像

Compose 使用本地镜像 `docker.io/library/tybooks:<version>`，首次部署前需要构建。在需要运行 App 的节点上执行（需要 Node.js 20+）：

```bash
npm run docker:build
```

`npm run docker:build` 实际调用 `scripts/build-image.sh`（ENGINE=docker），默认构建 `linux/amd64` 并导出两个 tar。如果直接在本机构建（架构与运行节点一致），可用 `PLATFORM=native npm run docker:build`；镜像源受限时可用 `REGISTRY=docker.m.daocloud.io/library npm run docker:build`。

镜像版本来自 `package.json` 的 `version`，构建脚本会打出「版本号」和 `latest` 两个标签，导出的 tar 使用版本标签。升级版本执行 `npm run version:bump -- x.y.z`，它会同步更新 `package.json` 和四个部署清单。

如果节点上没有 Node.js，可以在本地构建后分发：

```bash
npm run docker:build
scp tybooks.tar postgres.tar <user>@<node>:/tmp/
# 在目标节点执行
docker load -i /tmp/tybooks.tar
docker load -i /tmp/postgres.tar
```

### 3. Primary 节点（必须）

```bash
cd primary
docker compose --env-file ../.env up -d
```

单节点部署到此结束。如需主从复制，继续执行：

```bash
bash init.sh   # 创建复制用户 + 配置 pg_hba
```

### 4. Standby 节点（可选，每个节点重复）

```bash
cd standby
bash setup.sh                                 # 从主库拉取备份 + 启动从库
docker compose --env-file ../.env up -d app   # 启动应用
```

### 5. 扩展新 Standby

1. 更新 Primary 的 `.env` 中 STANDBY_IPS（追加新 IP）
2. 在 Primary 上重新执行 `bash init.sh`（幂等，重复安全）
3. 在新 Standby 上重复步骤 4

### 6. 更新应用

```bash
npm run version:bump -- 1.1.1   # 同步 package.json 与部署清单
npm run docker:build
scp tybooks.tar <user>@<node>:/tmp/
```

在目标节点加载新镜像并重建容器：

```bash
docker load -i /tmp/tybooks.tar
cd primary
docker compose --env-file ../.env up -d
```

`docker compose up -d` 会检测到镜像版本变化并重建 App 容器；Postgres 容器不受影响。
