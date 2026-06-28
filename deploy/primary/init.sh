#!/bin/bash
set -e

echo "=== TYBooks Primary 初始化 ==="

if [ -z "${POSTGRES_PASSWORD}" ]; then
  echo "错误：请先设置环境变量 POSTGRES_PASSWORD"
  echo "可以从 deploy/.env 文件中加载：source ../.env"
  exit 1
fi

echo "等待 PostgreSQL 启动..."
until docker compose exec -T postgres pg_isready -U tybooks > /dev/null 2>&1; do
  sleep 1
done
echo "PostgreSQL 已就绪"

echo "创建复制用户 replicator（如已存在则跳过）..."
docker compose exec -T postgres psql -U tybooks -d tybooks -c \
  "DO \$\$ BEGIN
     IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'replicator') THEN
       CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD '${REPLICATOR_PASSWORD}';
     END IF;
   END \$\$;"

if [ -n "${STANDBY_IPS}" ]; then
  echo "配置 pg_hba.conf 允许 Standby 复制连接..."
  IFS=',' read -ra IPS <<< "${STANDBY_IPS}"
  for IP in "${IPS[@]}"; do
    IP=$(echo "$IP" | xargs)
    ENTRY="host replication replicator ${IP}/32 md5"
    EXISTS=$(docker compose exec -T postgres sh -c "grep -c '${ENTRY}' /var/lib/postgresql/data/pg_hba.conf || true")
    if [ "${EXISTS}" = "0" ]; then
      docker compose exec -T postgres sh -c "echo '${ENTRY}' >> /var/lib/postgresql/data/pg_hba.conf"
      echo "  已添加: ${IP}"
    else
      echo "  已存在: ${IP}（跳过）"
    fi
  done
fi

echo "重载 PostgreSQL 配置..."
docker compose exec -T postgres psql -U tybooks -d tybooks -c "SELECT pg_reload_conf();"

echo "=== Primary 初始化完成 ==="
if [ -n "${STANDBY_IPS}" ]; then
  echo "复制用户: replicator"
  echo "允许的 Standby IP: ${STANDBY_IPS}"
  echo "请在各 Standby 节点上运行 bash setup.sh 初始化从库"
else
  echo "单节点模式，无 Standby 配置"
fi
