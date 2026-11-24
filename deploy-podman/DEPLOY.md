# TYBooks Podman 部署指南

基于 Podman Pod，PG + App 运行在同一 Pod 内，共享网络命名空间。

## 一、安装/部署前需知

### 所需软件

| 软件   | 安装位置 | 说明           |
| ------ | -------- | -------------- |
| Podman | 本地     | 运行容器和 Pod |

### 暴露端口

| 端口 | 服务        | 说明                            |
| ---- | ----------- | ------------------------------- |
| 8080 | tybooks-app | 应用 HTTP 端口（hostPort 映射） |

> PG 的 5432 端口仅在 Pod 内部可见，app 通过 `localhost:5432` 访问，未暴露到宿主机。

### 数据卷

| 卷名    | 宿主路径  | 容器路径                 | 说明                           |
| ------- | --------- | ------------------------ | ------------------------------ |
| pg-data | /var/lib/tybooks/pg-data | /var/lib/postgresql/data | PG 数据持久化（hostPath 类型） |

### 配置文件

| 文件         | 说明                                                                   |
| ------------ | ---------------------------------------------------------------------- |
| `pod.yaml` | Pod 定义（容器、环境变量、卷），需替换 CHANGE_ME 为实际密码（共 3 处） |

### 注意事项

- Podman mirror 可能不生效，构建时需指定 `--build-arg REGISTRY=镜像源`
- 同一 Pod 内容器共享网络，app 通过 `localhost:5432` 连接 PG
- macOS 上 Podman 运行在 VM 中，`podman play kube` 会自动处理端口映射

## 二、安装步骤

### 1. 构建镜像

```bash
podman build --build-arg REGISTRY=docker.m.daocloud.io/library -t tybooks:latest .
```

### 2. 修改配置

编辑 `pod.yaml`，将 `CHANGE_ME` 替换为实际密码（共 3 处：POSTGRES_PASSWORD、DATABASE_URL、DATABASE_URL_READONLY）

### 3. 启动

```bash
podman play kube pod.yaml
```

### 4. 验证

```bash
podman pod ls
podman logs tybooks-app
curl http://localhost:8080/api/books
```

### 5. 停止

```bash
podman pod stop tybooks
podman pod rm tybooks
```

### 6. 从 Docker 迁移数据

```bash
# 查看 Docker 中运行的 postgres 容器名
docker ps --filter ancestor=postgres:16-alpine --format '{{.Names}}'

# 导出数据（将 <容器名> 替换为实际容器名）
docker exec <容器名> pg_dump -U tybooks tybooks > backup.sql

# 导入到 Podman
podman exec -i tybooks-postgres psql -U tybooks -d tybooks < backup.sql
```
