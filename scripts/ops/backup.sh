#!/bin/bash
# 备份 PostgreSQL（pg_dump + gzip，按天轮转）
#
# 用法：
#   npm run ops:backup                        # 默认 deploy-docker
#   npm run ops:backup -- deploy-podman
#   KEEP_DAYS=30 npm run ops:backup
#   BACKUP_DIR=/var/backups/tybooks npm run ops:backup
#
# 注意：容器的数据在 Docker/Podman 卷里，直接拷文件是不一致的，
# 必须用 pg_dump 逻辑导出。

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
ops_load_target "${1:-}"

BACKUP_DIR="${BACKUP_DIR:-${TARGET_DIR}/backup}"
KEEP_DAYS="${KEEP_DAYS:-7}"
PG_USER="${PG_USER:-tybooks}"
PG_DB="${PG_DB:-tybooks}"

mkdir -p "${BACKUP_DIR}" || ops_die "无法创建备份目录 ${BACKUP_DIR}"
file="${BACKUP_DIR}/tybooks-$(date +%Y%m%d-%H%M%S).sql.gz"

echo "目标：${TARGET_NAME}"
echo "备份到：${file}"

if ! "${RUNTIME}" exec "${PG_CONTAINER}" pg_dump -U "${PG_USER}" "${PG_DB}" | gzip > "${file}"; then
  rm -f "${file}"
  ops_die "pg_dump 失败（容器是否在运行？用户 ${PG_USER} 是否存在？）"
fi

if ! gzip -t "${file}" 2>/dev/null; then
  rm -f "${file}"
  ops_die "备份文件校验失败，已删除"
fi

ops_ok "备份完成（$(ls -lh "${file}" | awk '{print $5}')）"

if [ "${KEEP_DAYS}" -gt 0 ]; then
  old="$(find "${BACKUP_DIR}" -name 'tybooks-*.sql.gz' -type f -mtime +"${KEEP_DAYS}" -print 2>/dev/null)"
  if [ -n "${old}" ]; then
    echo "${old}" | sed 's/^/  清理 /'
    echo "${old}" | while IFS= read -r f; do rm -f "${f}"; done
  fi
fi

echo
ops_note "目录：${BACKUP_DIR}（保留 ${KEEP_DAYS} 天）"
ops_note "恢复：gunzip -c <文件> | ${RUNTIME} exec -i ${PG_CONTAINER} psql -U ${PG_USER} -d ${PG_DB}"
