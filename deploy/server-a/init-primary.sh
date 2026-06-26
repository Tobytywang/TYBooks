#!/bin/bash
set -e

echo "=== TYBooks 主库初始化 ==="

# 等待 PostgreSQL 就绪
echo "等待 PostgreSQL 启动..."
until docker compose exec -T postgres pg_isready -U tybooks > /dev/null 2>&1; do
  sleep 1
done
echo "PostgreSQL 已就绪"

# 创建复制用户
echo "创建复制用户 replicator..."
docker compose exec -T postgres psql -U tybooks -d tybooks -c \
  "DO \$\$ BEGIN
     IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'replicator') THEN
       CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD '${REPLICATOR_PASSWORD}';
     END IF;
   END \$\$;"

# 配置 pg_hba.conf 允许复制连接
echo "配置 pg_hba.conf..."
docker compose exec -T postgres sh -c \
  "echo 'host replication replicator ${SERVER_B_IP}/32 md5' >> /var/lib/postgresql/data/pg_hba.conf"

# 重载 PostgreSQL 配置
echo "重载 PostgreSQL 配置..."
docker compose exec -T postgres psql -U tybooks -d tybooks -c "SELECT pg_reload_conf();"

echo "=== 主库初始化完成 ==="
echo "复制用户: replicator"
echo "请在服务器B上运行 setup-standby.sh 初始化从库"
