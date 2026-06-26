#!/bin/bash
set -e

echo "=== TYBooks 从库初始化 ==="

# 检查环境变量
if [ -z "${SERVER_A_IP}" ] || [ -z "${REPLICATOR_PASSWORD}" ] || [ -z "${POSTGRES_PASSWORD}" ]; then
  echo "错误：请先设置环境变量 SERVER_A_IP, REPLICATOR_PASSWORD, POSTGRES_PASSWORD"
  echo "可以从 deploy/.env 文件中加载：source ../.env"
  exit 1
fi

# 停止从库 PostgreSQL（如运行中）
echo "停止从库 PostgreSQL..."
docker compose stop postgres || true

# 清空从库数据目录
echo "清空从库数据目录..."
docker compose run --rm -v pg-data:/var/lib/postgresql/data postgres sh -c \
  "rm -rf /var/lib/postgresql/data/*"

# 从主库拉取基础备份
echo "从主库拉取基础备份（${SERVER_A_IP}）..."
docker compose run --rm -v pg-data:/var/lib/postgresql/data postgres pg_basebackup \
  -h "${SERVER_A_IP}" \
  -p 5432 \
  -U replicator \
  -D /var/lib/postgresql/data \
  -Fp \
  -Xs \
  -P \
  -R

# 配置 primary_conninfo（pg_basebackup -R 会自动创建 standby.signal 和 postgresql.auto.conf）
# 但我们需要确保密码正确
echo "配置 primary_conninfo..."
docker compose run --rm -v pg-data:/var/lib/postgresql/data postgres sh -c \
  "echo \"primary_conninfo = 'host=${SERVER_A_IP} port=5432 user=replicator password=${REPLICATOR_PASSWORD}'\" >> /var/lib/postgresql/data/postgresql.auto.conf"

# 启动从库
echo "启动从库 PostgreSQL..."
docker compose up -d postgres

# 等待 PostgreSQL 就绪
echo "等待 PostgreSQL 启动..."
until docker compose exec -T postgres pg_isready -U tybooks > /dev/null 2>&1; do
  sleep 1
done
echo "PostgreSQL 已就绪"

# 验证复制状态
echo "验证从库状态..."
RECOVERY=$(docker compose exec -T postgres psql -U tybooks -d tybooks -t -c "SELECT pg_is_in_recovery();")
echo "pg_is_in_recovery() = ${RECOVERY}"

if echo "${RECOVERY}" | grep -q "t"; then
  echo "=== 从库初始化完成，正在以 standby 模式运行 ==="
  echo ""
  echo "请在主库验证复制连接："
  echo "  docker compose exec -T postgres psql -U tybooks -d tybooks -c 'SELECT * FROM pg_stat_replication;'"
  echo ""
  echo "启动应用：docker compose up -d app"
else
  echo "=== 警告：从库似乎未以 standby 模式运行 ==="
  echo "请检查配置"
fi
