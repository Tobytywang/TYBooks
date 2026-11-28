# TYBooks

书库管理系统：Vue 3 + Express + PostgreSQL，支持书籍浏览、评分、书评和分类管理。

> 本文是项目总览。部署步骤见各部署目录下的 `DEPLOY.md`；全新服务器（K3s + Nginx）的初始化见 `deploy-k3s/SERVER-SETUP.md`。

## 本地开发

```bash
npm install
npm run dev:all
```

需要本地 PostgreSQL，连接串通过根目录 `.env` 的 `DATABASE_URL` 配置。

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

| 方案 | 目录 | 适用场景 | 状态 |
| --- | --- | --- | --- |
| Docker Compose | `deploy-docker/` | 单机或 PostgreSQL 主从复制多节点 | ✅ 当前生产在用（1C1G 实测可用） |
| Podman Pod | `deploy-podman/` | 单机本地运行 | ✅ 本机开发/测试 |
| K3s | `deploy-k3s/` | Kubernetes 生产部署（NodePort + 现有 Nginx） | ⚠️ 控制平面实测 578 MB，1C1G 不可行，需 2C4G 以上 |

每个目录下的 `DEPLOY.md` 是对应的操作手册。**前置条件、构建与交付、安全加固、备份与恢复、FAQ 是三种方式共用的，统一写在 [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md)**；各 `DEPLOY.md` 只讲自己专属的部分。

## 构建入口

| 命令 | 说明 |
| --- | --- |
| `npm run podman:build` | 调用 `scripts/image/build.sh`（ENGINE=podman），默认 `linux/amd64` + 导出 tar；可用 `PLATFORM`、`REGISTRY`、`NPM_REGISTRY`、`EXPORT`、`APP_IMAGE`、`VERSION` 覆盖 |
| `npm run docker:build` | 调用 `scripts/image/build.sh`（ENGINE=docker），默认 `linux/amd64` + 导出 tar；可用同上 |
| `npm run image:export` | 调用 `scripts/image/export.sh`，只导出 tar、不重建应用，用于"只补一个包"；可传 `app` / `pg` / `all`（默认），如 `npm run image:export -- pg` |
| `npm run image:verify` | 调用 `scripts/image/verify-tars.sh`，校验 tar 的架构、tag、版本，**交付前必跑**；架构不符时退出码非 0 |

> `image:export` 与 `podman:build`/`docker:build` 结束时都会自动调用 `image:verify`。
> 为什么必须校验架构：在 Apple Silicon 上构建时，若本地已有同 tag 的 arm64 基础镜像，
> 脚本会跳过 `--platform linux/amd64` 的拉取，导出 arm64 的 tar，导致在 x86_64 服务器上
> 启动时报 `platform does not match`。`image:verify` 就是拦这个的。

## 运维入口

部署运维动作只写一份（`scripts/ops/`），目标差异放在各部署目录的 `deploy.env` 里。
默认目标是 `deploy-docker`，换目标用 `-- <目录>`。

| 命令 | 说明 |
| --- | --- |
| `npm run ops:doctor` | 部署前检查：运行时、配置占位符、端口、**镜像架构**、内存磁盘 |
| `npm run ops:verify` | 部署后验收：容器状态、`/api/version`、`/api/books`、登录、资源占用 |
| `npm run ops:password` | 改 admin 密码：`npm run ops:password -- '新密码'` |
| `npm run ops:backup` | pg_dump 备份 + 按天轮转（`KEEP_DAYS` 默认 7，`BACKUP_DIR` 可覆盖） |

```bash
npm run ops:doctor
npm run ops:verify
npm run ops:password -- 'NewPass123'
KEEP_DAYS=30 npm run ops:backup

# 换成 podman 目标
npm run ops:verify -- deploy-podman
```

> 加一种部署方式 = 新增一个 `<目录>/deploy.env`（`RUNTIME`、容器名、端口、占位符正则），
> 不用复制任何脚本。



## 版本号

- 唯一来源：`package.json` 的 `version`
- 镜像标签：`<version>` 与 `latest`，导出的 tar 使用版本标签
- 部署清单：K3s、Podman、Docker Compose 中的 image 固定为版本标签
- 升级：`npm run version:bump -- x.y.z`，同步更新 `package.json` 与四个部署清单
- 运行时可见：状态页、`GET /api/version`、镜像的 `APP_VERSION` 环境变量与 `org.opencontainers.image.version` 标签
