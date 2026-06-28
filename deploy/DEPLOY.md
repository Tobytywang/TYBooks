# TYBooks 部署指南

## 1. 准备
所有节点安装 Docker，复制 deploy/ 目录，cp .env.example .env 并填写实际值

## 2. Primary 节点（必须）
```
cd primary
docker compose up -d          # 启动主库 + app（单节点部署到此结束）
bash init.sh                  # 有 Standby 时执行，配置复制用户和 pg_hba
```

## 3. Standby 节点（可选，每个节点重复）
```
cd standby
bash setup.sh                 # 从主库拉取备份 + 启动从库
docker compose up -d app      # 启动 app
```

## 4. 扩展新 Standby
1. 更新 Primary 的 .env 中 STANDBY_IPS（追加新 IP）
2. 在 Primary 上重新执行 bash init.sh（幂等，重复安全）
3. 在新 Standby 上重复步骤 3
