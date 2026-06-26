# TYBooks PostgreSQL 迁移 & Docker 部署计划

## 概述

将数据存储从 SQLite 迁移到 PostgreSQL，支持双服务器部署（主从复制 + 读写分离），容器化打包。

### 关键参数

| 参数 | 值 |
|---|---|
| PG 版本 | 16 |
| Web 端口 | 8080 |
| PG 端口 | 5432 |
| 密码 | 占位符，部署时替换 |
| Nginx | 已有配置，不生成 |
| 故障切换 | 手动（pg_ctl promote） |
| 读写分离 | 应用层（pool 写主库 / poolRead 读从库） |

---

## 阶段一：代码改造（SQLite → PostgreSQL）

### 改动清单

| # | 文件 | 改动 |
|---|---|---|
| 1 | `package.json` | 移除 `better-sqlite3`/`@types/better-sqlite3`，添加 `pg`/`@types/pg` |
| 2 | `.gitignore` | 加入 `.env` |
| 3 | `.env`（新建） | `DATABASE_URL=postgresql://tybooks:tybooks@localhost:5432/tybooks` |
| 4 | `server/db.js` | 重写：`pg.Pool`，`DATABASE_URL`/`DATABASE_URL_READONLY`，`SERIAL PRIMARY KEY`，`ON CONFLICT DO NOTHING`，导出 `pool` + `poolRead` + `initDB()` |
| 5 | `server/books.js` | 18 处：`async`，`$1`，`poolRead` 读 / `pool` 写，`RETURNING id` |
| 6 | `server/genres.js` | 10 处：同上，`e.code === '23505'` |
| 7 | `server/auth.js` | 1 处：异步 |
| 8 | `server/index.js` | 静态文件托管 + SPA fallback，去掉 `cors()`，端口改为 8080 |

### 验证步骤

1. 本地 Docker 启动 PostgreSQL：
   ```bash
   docker run -d --name tybooks-pg \
     -e POSTGRES_DB=tybooks \
     -e POSTGRES_USER=tybooks \
     -e POSTGRES_PASSWORD=tybooks \
     -p 5432:5432 \
     postgres:16-alpine
   ```
2. 配置 `.env`：`DATABASE_URL=postgresql://tybooks:tybooks@localhost:5432/tybooks`
3. `npm run build` 构建前端
4. `node server/index.js` 启动服务
5. 访问 `http://localhost:8080`，验证：
   - 页面正常显示
   - 书籍列表可加载
   - 新增/编辑/删除书籍正常
   - 分类管理正常
   - 登录/登出正常

---

## 阶段二：Docker 镜像

### 改动清单

| # | 文件 | 内容 |
|---|---|---|
| 1 | `Dockerfile` | 多阶段构建：builder（`npm ci` + `npm run build`）→ runtime（`npm ci --omit=dev` + `server/` + `dist/`），`node:20-slim`，暴露 8080 |
| 2 | `.dockerignore` | 排除 `node_modules`、`data`、`.git`、`.env`、`dist` |

### 验证步骤

1. `docker build -t tybooks .`
2. `docker run -d --name tybooks-test -p 8080:8080 -e DATABASE_URL=postgresql://tybooks:tybooks@host.docker.internal:5432/tybooks tybooks`
3. 访问 `http://localhost:8080`，验证页面和 API 正常

---

## 阶段三：部署配置

### 文件清单

```
deploy/
├── .env.example                # 环境变量模板
├── server-a/
│   ├── docker-compose.yml      # PG 主库 + App
│   ├── pg-primary.conf         # 主库 PG 配置
│   └── init-primary.sh         # 创建复制用户 + pg_hba + 重载
└── server-b/
    ├── docker-compose.yml      # PG 从库 + App
    ├── pg-standby.conf         # 从库 PG 配置
    └── setup-standby.sh        # pg_basebackup + standby + 启动 + 验证
```

### 部署流程

1. **服务器A**：`docker compose up -d` → 启动主库 + App
2. **服务器A**：`bash init-primary.sh` → 创建复制用户、配置 pg_hba、重载 PG
3. **服务器B**：`bash setup-standby.sh` → 从主库 pg_basebackup、配置 standby、启动从库 + App
4. **验证**：
   - 主库：`SELECT * FROM pg_stat_replication;`（应看到 replicator 连接）
   - 从库：`SELECT pg_is_in_recovery();`（应返回 `t`）
   - 两台 App 均可访问 `http://<IP>:8080`
   - 主库写入数据，从库可读到

---

## 阶段四：清理

### 操作清单

| # | 操作 |
|---|---|
| 1 | 删除 `data/` 目录（SQLite 数据不再需要） |
| 2 | 确认 `package.json` 中无 `better-sqlite3` 残留 |

### 验证步骤

1. `grep -r "better-sqlite3" server/` 无结果
2. `grep -r "sqlite" server/` 无结果
3. `ls data/` 不存在
4. 应用功能完整可用
