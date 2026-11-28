# TYBooks 部署总览（通用部分）

本文只写**与部署方式无关**的内容：前置条件、构建与交付、安全加固、备份与恢复、FAQ。

怎么把服务跑起来，看对应的手册：

| 部署方式 | 手册 | 适用场景 |
| --- | --- | --- |
| Docker Compose | [`../deploy-docker/DEPLOY.md`](../deploy-docker/DEPLOY.md) | 单机，或 PG 主从复制多节点 |
| Podman Pod | [`../deploy-podman/DEPLOY.md`](../deploy-podman/DEPLOY.md) | 单机本机运行 |
| K3s | [`../deploy-k3s/DEPLOY.md`](../deploy-k3s/DEPLOY.md) | 集群（NodePort + Nginx） |

---

## 一、前置条件（环境要求）

本项目只声明运行所需的环境，**不包含各发行版的安装步骤**——同一份清单要能在 Linux 服务器、macOS、Windows（Docker Desktop）上跑，装什么、怎么装由各平台自己决定。

### 运行节点

| 项 | 要求 | 说明 |
| --- | --- | --- |
| 容器运行时 | Docker Engine 20.10+ / Podman 4+ / K3s | 需支持 compose v2（若用 Compose） |
| 架构 | x86_64 或 arm64，且**与镜像架构一致** | 由 `npm run image:verify` 保证；不符时报 `platform does not match` |
| 内存 | ≥ 1 GB | 两个容器实测合计约 78 MB；1C1G 整机可用 ~490 MiB 可稳定运行 |
| 磁盘 | ≥ 5 GB 可用 | 两个镜像约 550 MB，另加数据卷与日志 |
| 网络 | 能访问 8080（或经 Nginx 的 443） | 端口按部署方式不同，见各自手册 |
| 镜像获取 | 能够 `load` 即可，**不要求能访问镜像仓库** | 网络受限时用 tar 导入，不依赖 `pull` |

> K3s 另有更高要求：控制平面实测 578 MB（峰值 635 MB），1 GB 内存无法运行，见 [`../deploy-k3s/DEPLOY.md`](../deploy-k3s/DEPLOY.md)。

### 构建节点（只需在打包镜像的机器上满足）

| 项 | 要求 | 说明 |
| --- | --- | --- |
| Node.js | 20+ | 生成前端 `dist/` |
| 容器工具 | Podman 或 Docker | 构建镜像并 `save` 成 tar |
| 磁盘 | ≥ 3 GB 可用 | 构建上下文 + 两个 tar |

### 脚本支持的环境

部署脚本（`scripts/`）都是 bash，对平台差异做了**显式降级**，不会静默失败：

| 平台 | 支持程度 | 说明 |
| --- | --- | --- |
| Linux | 完整 | `ops:doctor` 会实际检查端口（`ss`）与内存（`/proc/meminfo`） |
| macOS | 完整（系统自带 bash 3.2 已验证） | 无 `ss`/`/proc`，`doctor` 跳过这两项并提示，不算失败 |
| Windows | 需 Git Bash 或 WSL2 | PowerShell 无法运行 `.sh`；容器后端必须是 Docker Desktop 的 **Linux 容器**模式 |

> 脚本与文件统一使用 LF 行尾（`.gitattributes` 已锁定），Windows 检出不会破坏 shebang。

---

## 二、构建与交付

构建产物与运行时无关：`podman save` 与 `docker save` 产出的是同一种 docker-archive，两边都能 `load`。

### 1. 构建

```bash
npm run podman:build      # 默认 Podman 引擎，构建 linux/amd64 并导出 tar
npm run docker:build      # 同上，改用 Docker 引擎
```

两个命令调用的是同一个脚本（`scripts/image/build.sh`），只有 `ENGINE` 不同。默认镜像源统一为 `docker.m.daocloud.io/library`，需要官方源时显式覆盖：

```bash
REGISTRY=docker.io/library npm run podman:build
```

产物：`tybooks.tar`、`postgres.tar`，tag 与部署清单里声明的一致。

### 2. 校验（交付前必跑）

```bash
npm run image:verify
```

检查三件事：**架构是否为目标架构**、tag 是否与清单一致、应用镜像的版本标签是否等于 `package.json` 的 version。任何一项不符，退出码非 0，**不要上传**。

> 为什么必须校验：在 Apple Silicon 上构建时，若本地已有同 tag 的 arm64 基础镜像，脚本会跳过 `--platform linux/amd64` 的拉取，导出 arm64 的 tar，在 x86_64 服务器上启动即报 `platform does not match`。

只补一个包时不必重建整个应用：

```bash
npm run image:export -- pg     # 只重新导出 postgres.tar（app / pg / all）
```

### 3. 传输与导入

```bash
scp tybooks.tar postgres.tar <user>@<server>:/opt/<app>/
```

目标机器上：

```bash
docker load -i tybooks.tar     # 或 podman load / k3s ctr images import
docker load -i postgres.tar
```

**镜像源不可达时不要依赖 `pull`**：Compose 在本地找不到镜像会尝试拉取并长时间挂住。先 `load`，或在 override 里加 `pull_policy: never` 让它快速失败。

### 4. 升级版本

```bash
npm run version:bump -- 1.1.1   # 同步 package.json 与 4 个部署清单的镜像标签
npm run podman:build
npm run image:verify
```

`package.json` 的 `version` 是版本号唯一来源；`deploy-k3s/app/app.yaml`、`deploy-podman/pod.yaml`、`deploy-docker/{primary,standby}/docker-compose.yml` 由脚本自动改写。

---

## 三、安全加固

### 默认账号必须先改

首次启动会自动创建 `admin / admin123`（`server/db.js` 中固定）。系统**没有改密接口**，只能直接写库：

```bash
npm run ops:password -- 'NewPass123'                 # 默认目标 deploy-docker
npm run ops:password -- deploy-podman 'NewPass123'   # 指定目标
```

脚本会在容器内用 `bcryptjs` 生成哈希并更新 `users` 表，然后自动验证一次登录。

> `ops:*` 只支持 `deploy-docker` / `deploy-podman`（依赖 `docker`/`podman exec`）。
> K3s 目标请用 `kubectl exec` 的手工命令，见 [`../deploy-k3s/DEPLOY.md`](../deploy-k3s/DEPLOY.md)。

> 改密码不会让已签发的 token 失效，JWT 有效期 24 小时。

### 端口暴露面

默认 Compose 把应用映射到 `0.0.0.0:8080`，数据库只绑 `127.0.0.1:5432`。**应用那一段应该收窄到回环**，由 Nginx 终止 TLS 后反代——见各手册的「端口暴露面」一节。

### 登录没有速率限制

`/api/auth/login` 不限失败次数。对公网开放前，至少做到：安全组只放行必要来源，或在 Nginx 层对登录路径做 `limit_req`。

### 不要把 `.env` 权限放开

`.env` 含数据库密码与 JWT 密钥：

```bash
chmod 600 .env
```

---

## 四、备份与恢复

容器的数据在命名卷/PVC 里，**直接拷文件是不一致的**，必须逻辑导出。

### 备份

```bash
npm run ops:backup                      # 默认 deploy-docker
npm run ops:backup -- deploy-podman
KEEP_DAYS=30 npm run ops:backup         # 保留 30 天（默认 7）
BACKUP_DIR=/var/backups/tybooks npm run ops:backup
```

产出 `tybooks-YYYYmmdd-HHMMSS.sql.gz`，写完后会做 `gzip -t` 校验，损坏自动删除。默认目录是各 `deploy-*/backup/`（已在 `.gitignore` 中）。

### 定时任务

```cron
0 3 * * * cd /opt/tybooks && KEEP_DAYS=14 npm run ops:backup >> /var/log/tybooks-backup.log 2>&1
```

### 恢复

```bash
gunzip -c tybooks-20261128-030000.sql.gz \
  | docker exec -i primary-postgres-1 psql -U tybooks -d tybooks
```

`ops:backup` 结束时会打印与当前目标匹配的恢复命令（运行时和容器名都对好）。

> K3s 目标暂未接入 `ops:backup`，用 `kubectl exec ... pg_dump`，
> 命令见 [`../deploy-k3s/DEPLOY.md`](../deploy-k3s/DEPLOY.md) 的 3.3 节。

> **危险操作**：`docker compose down -v` 会删除数据卷。数据卷被清空后，下次启动会重新建表并**重新创建 `admin/admin123`**——改过的密码会丢失。

---

## 五、FAQ

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| 容器启动即退出，日志含 `platform does not match` | 镜像架构与主机不符（arm64 包跑在 x86_64 上） | 构建机执行 `npm run image:verify` 确认架构；用 `npm run image:export -- pg` 重出正确的包 |
| `compose up` 卡在 `Pulling` 十几分钟 | 本地没有镜像，去镜像仓库拉了，而仓库不可达 | 先 `docker load`；或在 override 加 `pull_policy: never` |
| `docker images` 显示 `tybooks:1.1.0`，清单要 `docker.io/library/tybooks:1.1.0` | Docker 省略了默认 registry 与 namespace 前缀，两者是同一个引用 | 用 `docker image inspect <两种写法> --format '{{.Id}}'` 对比，ID 相同即同一镜像 |
| 重复 `docker load` 会不会冲突 | 不会。同镜像按层去重；同 tag 不同内容会覆盖 tag，旧的变成悬空镜像 | `docker image prune -f` 清理悬空镜像 |
| `ops:*` 报「目标目录不存在」 | 传的目标既不是仓库内目录名，也不是含 `deploy.env` 的路径 | `npm run ops:verify -- deploy-docker`，或传绝对路径：`bash scripts/ops/verify.sh /opt/tybooks` |
| 密码明明正确却登录失败 | 浏览器自动填充/全角字符/首尾空格导致实际提交的值不同 | 无痕窗口手输；F12 → Network 看 `auth/login` 的 Request Payload |
| `ops:doctor` 报「仍含占位符」 | 配置模板里的 `<YOUR_*>` 还没替换 | 按各自手册准备配置；`doctor` 会列出具体行号 |
| 内存不足 / 磁盘 IO 打满 | 规格不够（K3s 控制平面就要 578 MB） | 见 `../deploy-k3s/DEPLOY.md` 的资源实测数据 |

---

## 六、命令速查

| 目的 | 命令 |
| --- | --- |
| 构建镜像 + 导出 tar | `npm run podman:build` |
| 只重新导出某个包 | `npm run image:export -- pg` |
| 校验产物（交付前必跑） | `npm run image:verify` |
| 部署前体检 | `npm run ops:doctor [-- <目标>]` |
| 部署后验收 | `npm run ops:verify [-- <目标>]` |
| 改 admin 密码 | `npm run ops:password -- [目标] '新密码'` |
| 备份数据库 | `npm run ops:backup [-- <目标>]` |
| 版本号 + 清单同步 | `npm run version:bump -- x.y.z` |

`ops:*` 的目标默认是 `deploy-docker`，换目标用 `-- deploy-podman`（`--` 是 npm 的参数分隔符，
它右边的内容原样传给脚本）。可用目标随 `deploy-*/deploy.env` 自动发现，K3s 目前未接入。
