#!/bin/bash
# 部署后验收：容器状态、关键接口、资源占用
#
# 用法：
#   npm run ops:verify                        # 默认 deploy-docker
#   npm run ops:verify -- deploy-podman
#   EXPECT_VERSION=1.1.0 npm run ops:verify
#
# 退出码非 0 表示有检查未通过，可直接用于 CI。

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
ops_load_target "${1:-}"

# 期望版本：优先环境变量，其次 package.json（服务器上没 node 就跳过比对）
if [ -z "${EXPECT_VERSION:-}" ] && command -v node >/dev/null 2>&1 \
   && [ -f "${OPS_REPO_ROOT}/package.json" ]; then
  EXPECT_VERSION="$(node -p "require('${OPS_REPO_ROOT}/package.json').version" 2>/dev/null || true)"
fi

echo "目标：${TARGET_NAME}（运行时 ${RUNTIME}，端口 ${APP_PORT}）"
echo

echo "=== 容器 ==="
ops_ps || ops_bad "无法列出容器"
for c in "${APP_CONTAINER}" "${PG_CONTAINER}"; do
  if ops_running "${c}"; then
    ops_ok "${c} 运行中"
  else
    ops_bad "${c} 未运行"
  fi
done

echo
echo "=== 接口 ==="
version_json="$(curl -fsS --max-time 10 "http://localhost:${APP_PORT}/api/version" 2>/dev/null)" || version_json=""
if [ -n "${version_json}" ]; then
  ops_ok "/api/version -> ${version_json}"
  if [ -n "${EXPECT_VERSION}" ]; then
    case "${version_json}" in
      *"\"${EXPECT_VERSION}\""*) ops_ok "版本匹配 ${EXPECT_VERSION}" ;;
      *) ops_bad "版本不匹配，期望 ${EXPECT_VERSION}" ;;
    esac
  fi
else
  ops_bad "/api/version 无响应（容器未就绪或端口不对）"
fi

books_json="$(curl -fsS --max-time 10 "http://localhost:${APP_PORT}/api/books" 2>/dev/null)" || books_json=""
if [ -n "${books_json}" ]; then
  count="$(printf '%s' "${books_json}" | grep -o '"id":' | wc -l | tr -d ' ')"
  ops_ok "/api/books -> ${count} 本"
else
  ops_bad "/api/books 无响应"
fi

login_code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
  -X POST "http://localhost:${APP_PORT}/api/auth/login" \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}' 2>/dev/null)" || login_code="000"
if [ "${login_code}" = "200" ]; then
  ops_ok "登录接口 200（提示：若已改过密码，请忽略这项）"
else
  ops_bad "登录接口返回 ${login_code}"
fi

echo
echo "=== 资源占用 ==="
"${RUNTIME}" stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}\t{{.PIDS}}' \
  || ops_note "无法读取 stats，可用 ${RUNTIME} stats --no-stream 手动查看"
if [ -r /proc/meminfo ]; then
  echo
  ops_note "主机内存：$(awk '/^MemTotal/{t=$2} /^MemAvailable/{a=$2} END{printf "总计 %d MiB，可用 %d MiB", t/1024, a/1024}' /proc/meminfo)"
fi

ops_summary
