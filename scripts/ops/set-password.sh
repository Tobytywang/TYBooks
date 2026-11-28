#!/bin/bash
# 修改 admin 密码
#
# 背景：系统只提供 /auth/login 和 /auth/check，没有改密接口，
# 默认密码 admin123 由 server/db.js 写死。上线前必须改。
#
# 用法：
#   npm run ops:password -- '新密码'                    # 默认 deploy-docker
#   npm run ops:password -- deploy-podman '新密码'
#
# 密码通过环境变量传给容器内的 node 脚本，不在命令行里拼接 SQL。

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

arg1="${1:-}"
arg2="${2:-}"

if [ -n "${arg2}" ]; then
  target="${arg1}"
  password="${arg2}"
else
  # 只给一个参数时：若它像目标目录，说明漏了密码；否则当成密码
  if [ -n "${arg1}" ] && [ -f "${OPS_REPO_ROOT}/${arg1}/deploy.env" ]; then
    ops_die "缺少新密码：npm run ops:password -- ${arg1} '新密码'"
  fi
  target=""
  password="${arg1}"
fi

[ -n "${password}" ] || ops_die "用法：npm run ops:password -- [目标] '新密码'"

ops_load_target "${target}"
ADMIN_USER="${ADMIN_USER:-admin}"

echo "目标：${TARGET_NAME}（运行时 ${RUNTIME}，容器 ${APP_CONTAINER}）"

if [ "${#password}" -lt 8 ]; then
  echo "  提示：密码少于 8 位，建议加长"
fi

read -r -d '' NODE_CODE <<'JS' || true
import bcrypt from 'bcryptjs';
import pg from 'pg';
const client = new pg.Client({ connectionString: process.env.DATABASE_URL });
await client.connect();
const hash = bcrypt.hashSync(process.env.NEW_PASS, 12);
const r = await client.query(
  'UPDATE users SET password = $1 WHERE username = $2',
  [hash, process.env.ADMIN_USER]
);
console.log('已更新行数: ' + r.rowCount);
await client.end();
JS

echo "  正在写入新密码哈希..."
"${RUNTIME}" exec \
  -e NEW_PASS="${password}" \
  -e ADMIN_USER="${ADMIN_USER}" \
  "${APP_CONTAINER}" \
  node --input-type=module -e "${NODE_CODE}" || ops_die "更新失败（容器内是否缺少 bcryptjs/pg？）"

echo
case "${password}" in
  *'"'*|*'\'*)
    ops_note "密码含引号或反斜杠，跳过自动验证，请用浏览器登录确认"
    ;;
  *)
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
      -X POST "http://localhost:${APP_PORT}/api/auth/login" \
      -H 'Content-Type: application/json' \
      -d "{\"username\":\"${ADMIN_USER}\",\"password\":\"${password}\"}" 2>/dev/null)" || code="000"
    if [ "${code}" = "200" ]; then
      ops_ok "新密码登录验证通过"
    else
      ops_bad "新密码登录返回 ${code}，请用浏览器确认"
    fi
    ;;
esac

ops_note "已有 token 在 24 小时内仍然有效，不会被强制失效"
