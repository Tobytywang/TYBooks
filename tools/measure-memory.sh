#!/bin/bash
# 在 macOS 上用 Podman 测量 tybooks + postgres 的内存占用
# 用法：bash tools/measure-memory.sh
#       KEEP=0 bash tools/measure-memory.sh   # 测完自动清理

set -euo pipefail

KEEP="${KEEP:-1}"
TEST_DIR="$HOME/tybooks-test"
POD_NAME="tybooks"
HOST_PORT="18080"
DB_PASSWORD="Test123456"
JWT_SECRET="TestJwtSecret123"
PG_DATA="/var/lib/tybooks-test/pg-data"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if ! podman info >/dev/null 2>&1; then
  echo "Podman 未就绪，尝试启动 podman machine..."
  podman machine start
fi

echo "=== 清理旧的 tybooks Pod ==="
podman pod rm -f "${POD_NAME}" 2>/dev/null || true

echo "=== 生成测试用 pod.yaml ==="
mkdir -p "${TEST_DIR}"
sed \
  -e "s/<YOUR_POSTGRES_PASSWORD>/${DB_PASSWORD}/g" \
  -e "s/<YOUR_JWT_SECRET>/${JWT_SECRET}/g" \
  -e "s#/var/lib/tybooks/pg-data#${PG_DATA}#" \
  -e "s/hostPort: 8080/hostPort: ${HOST_PORT}/" \
  "${ROOT_DIR}/deploy-podman/pod.yaml" > "${TEST_DIR}/pod.yaml"

echo "=== 清理旧的测试数据目录 ==="
podman machine ssh -- "sudo rm -rf ${PG_DATA}" >/dev/null 2>&1 || true

echo "=== 启动测试 Pod ==="
podman play kube "${TEST_DIR}/pod.yaml"

echo "=== 等待 PostgreSQL 就绪 ==="
for i in $(seq 1 60); do
  if podman exec tybooks-postgres pg_isready -U tybooks >/dev/null 2>&1; then
    echo "PostgreSQL 已就绪（第 ${i} 次检查）"
    break
  fi
  sleep 2
done

echo "=== 等待应用响应 ==="
for i in $(seq 1 30); do
  if curl -fsS "http://localhost:${HOST_PORT}/api/version" >/dev/null 2>&1; then
    echo "应用已响应（第 ${i} 次检查）"
    break
  fi
  sleep 2
done

echo
echo "=== 版本接口 ==="
curl -s "http://localhost:${HOST_PORT}/api/version" || true
echo

echo
echo "=== 内存采样（10 轮，每轮间隔 5 秒）==="
NORM="$(mktemp)"
for i in $(seq 1 10); do
  echo "--- 第 ${i} 轮 ---"
  podman stats --no-stream --format '{{.Name}}|{{.MemUsage}}|{{.CPU}}|{{.PIDS}}' |
    awk -F'|' '
      function mb(v,  n,u) {
        gsub(/^[ \t]+|[ \t]+$/, "", v)
        if (match(v, /^[0-9.]+/)) { n = substr(v, RSTART, RLENGTH) + 0; u = substr(v, RLENGTH + 1) }
        else return 0
        if (u ~ /KiB|kB/) return n / 1024
        if (u ~ /MiB|MB/) return n
        if (u ~ /GiB|GB/) return n * 1024
        if (u ~ /B$/) return n / 1048576
        return n
      }
      {
        split($2, a, "/")
        used = mb(a[1])
        printf "%s|%.1f\n", $1, used
        printf "%-18s %8.1f MB  CPU %-8s PIDs %s\n", $1, used, $3, $4 > "/dev/stderr"
      }' >> "${NORM}"
  sleep 5
done

echo
echo "=== 峰值内存（按容器）==="
awk -F'|' '{ if ($2 + 0 > max[$1]) max[$1] = $2 + 0 }
END { for (n in max) printf "%-18s %8.1f MB\n", n, max[n] }' "${NORM}" | sort -k2 -nr
rm -f "${NORM}"

echo
echo "=== Podman VM 内存 ==="
podman machine ssh -- 'free -h'

echo
echo "=== Pod 状态 ==="
podman pod ps
podman ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'

if [ "${KEEP}" = "1" ]; then
  echo
  echo "测试环境保留中，应用地址：http://localhost:${HOST_PORT}"
  echo "清理命令："
  echo "  podman pod rm -f ${POD_NAME}"
  echo "  rm -rf ${TEST_DIR}"
  echo "  podman machine ssh -- 'sudo rm -rf ${PG_DATA}'"
else
  echo
  echo "清理测试环境..."
  podman pod rm -f "${POD_NAME}" >/dev/null 2>&1 || true
  rm -rf "${TEST_DIR}"
  podman machine ssh -- "sudo rm -rf ${PG_DATA}" >/dev/null 2>&1 || true
  echo "已清理"
fi
