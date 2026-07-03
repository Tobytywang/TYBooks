# TYBooks Podman 部署指南

## 1. 构建镜像
```bash
podman build --build-arg REGISTRY=docker.m.daocloud.io/library -t tybooks:latest .
```

## 2. 修改配置
编辑 `pod.yaml`，将 `CHANGE_ME` 替换为实际密码

## 3. 启动
```bash
podman play kube pod.yaml
```

## 4. 验证
```bash
podman pod ls
podman logs tybooks-app
curl http://localhost:8080/api/books
```

## 5. 停止
```bash
podman pod stop tybooks
podman pod rm tybooks
```

## 数据持久化
PG 数据存储在 `./pg-data` 目录，停止容器后数据不丢失

## 从 Docker 迁移数据
```bash
docker exec tybooks-pg pg_dump -U tybooks tybooks > backup.sql
podman exec -i tybooks-postgres psql -U tybooks -d tybooks < backup.sql
```

## 注意事项
- Podman mirror 可能不生效，构建时需指定 `--build-arg REGISTRY=镜像源`
- 同一 Pod 内容器共享网络，app 通过 `localhost:5432` 连接 PG
- macOS 上 Podman 运行在 VM 中，`podman play kube` 会自动处理端口映射
