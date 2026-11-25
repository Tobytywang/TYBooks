# TYBooks 架构说明

> 本文描述当前架构、数据初始化与部署方案。具体操作步骤见各部署目录下的 `DEPLOY.md`。

## 技术栈

- 前端：Vue 3 + Vite + TypeScript，Vue Router
- 后端：Express 4 + node-postgres（pg）
- 数据库：PostgreSQL 16
- 运行时：Node.js 20（容器镜像 `node:20-slim`）
- 服务端口：8080

## 数据模型

`server/db.js` 在启动时自动建表：

| 表 | 说明 |
| --- | --- |
| books | 书籍（emoji、标题、作者、分类、状态、评分、书评、标签） |
| users | 登录用户（密码为 bcrypt 哈希） |
| genres | 分类（名称、颜色、排序） |

## 数据库连接

| 变量 | 用途 |
| --- | --- |
| `DATABASE_URL` | 写库连接 |
| `DATABASE_URL_READONLY` | 读库连接；未设置时回退到 `DATABASE_URL` |
| `JWT_SECRET` | JWT 签名密钥；未设置时使用代码内默认值，生产必须显式配置 |

应用启动时最多重试 10 次数据库连接，全部失败后退出。

## 初始化数据

首次启动且对应表为空时自动写入：

- 默认账号 `admin / admin123`，上线前必须修改
- 11 个分类
- 约 50 本示例书籍

## 部署方案

| 方案 | 目录 | 适用场景 |
| --- | --- | --- |
| Docker Compose | `deploy-docker/` | 单机或 PostgreSQL 主从复制多节点 |
| Podman Pod | `deploy-podman/` | 单机本地运行 |
| K3s | `deploy-k3s/` | Kubernetes 生产部署（NodePort + 现有 Nginx） |
| Jenkins | `deploy-jenkins/` | CI/CD 基础设施，与业务 namespace 隔离 |

每个目录下的 `DEPLOY.md` 是对应的操作手册。

## 构建入口

| 命令 | 说明 |
| --- | --- |
| `npm run podman:build` | 调用 `deploy-k3s/build.sh`，默认 `linux/amd64` + 导出 tar；可用 `PLATFORM`、`REGISTRY`、`EXPORT`、`APP_IMAGE` 覆盖 |
| `npm run docker:build` | 调用 `deploy-docker/build.sh`，默认 `linux/amd64` + 导出 tar；可用 `PLATFORM`、`REGISTRY`、`EXPORT`、`APP_IMAGE` 覆盖 |

## 迁移历史

- 数据存储已由 SQLite 迁移到 PostgreSQL 16，后端使用 `pg.Pool` 并支持读写分离
- 原 `deploy/` 目录已重命名为 `deploy-docker/`
- K3s 部署方案已由 Traefik + cert-manager 调整为 NodePort + 现有 Nginx
