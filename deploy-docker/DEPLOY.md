# TYBooks Docker 部署指南

基于 Docker Compose，支持单节点部署和 PG 主从复制多节点部署。

## 一、安装/部署前需知

### 所需软件

| 软件           | 安装位置 | 说明       |
| -------------- | -------- | ---------- |
| Docker         | 所有节点 | 运行容器   |
| Docker Compose | 所有节点 | 编排多容器 |

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

复制 `.env.example` 为 `.env`，替换所有占位符：

```bash
cp .env.example .env
```

### 2. Primary 节点（必须）

```bash
cd primary
docker compose up -d
```

单节点部署到此结束。如需主从复制，继续执行：

```bash
bash init.sh   # 创建复制用户 + 配置 pg_hba
```

### 3. Standby 节点（可选，每个节点重复）

```bash
cd standby
bash setup.sh              # 从主库拉取备份 + 启动从库
docker compose up -d app   # 启动应用
```

### 4. 扩展新 Standby

1. 更新 Primary 的 `.env` 中 STANDBY_IPS（追加新 IP）
2. 在 Primary 上重新执行 `bash init.sh`（幂等，重复安全）
3. 在新 Standby 上重复步骤 3
