#!/bin/bash
# TYBooks Docker 构建脚本（与 deploy-k3s/build.sh 对称，用于 Docker Compose 部署）
#
# 可覆盖的环境变量：
#   PLATFORM   构建平台，默认 linux/amd64；设为 native 则使用本机架构
#   REGISTRY   基础镜像源，默认 docker.io/library；镜像受限时可换成 daocloud
#   APP_IMAGE  应用镜像名，默认 docker.io/library/tybooks:latest
#   EXPORT     1=导出 tybooks.tar/postgres.tar，0=只构建，默认 1
#
# 用法：
#   npm run docker:build                          # linux/amd64 + 导出 tar
#   PLATFORM=native EXPORT=0 npm run docker:build # 本机构建，不导出

set -euo pipefail

REGISTRY="${REGISTRY:-docker.io/library}"
PG_SRC="${REGISTRY}/postgres:16-alpine"
PG_DST="docker.io/library/postgres:16-alpine"
APP_IMAGE="${APP_IMAGE:-docker.io/library/tybooks:latest}"
PLATFORM="${PLATFORM:-linux/amd64}"
EXPORT="${EXPORT:-1}"

PLATFORM_FLAG=""
if [ "${PLATFORM}" != "native" ]; then
  PLATFORM_FLAG="--platform ${PLATFORM}"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

echo "=== 1/6 检查 Docker ==="
if ! docker info >/dev/null 2>&1; then
  echo "错误：Docker 未就绪，请确认 Docker 服务已启动"
  exit 1
fi

echo "=== 2/6 检查 PostgreSQL 镜像 ==="
if docker image inspect "${PG_SRC}" >/dev/null 2>&1; then
  echo "已存在 ${PG_SRC}"
else
  echo "未找到 ${PG_SRC}，开始拉取..."
  docker pull ${PLATFORM_FLAG} "${PG_SRC}"
fi

echo "=== 3/6 构建前端 ==="
npm run build

echo "=== 4/6 构建应用镜像（${PLATFORM}）==="
docker build \
  ${PLATFORM_FLAG} \
  --build-arg REGISTRY="${REGISTRY}" \
  -t "${APP_IMAGE}" .

echo "=== 5/6 统一 PostgreSQL 镜像名 ==="
if [ "${PG_SRC}" != "${PG_DST}" ]; then
  docker tag "${PG_SRC}" "${PG_DST}"
fi

if [ "${EXPORT}" = "1" ]; then
  echo "=== 6/6 导出镜像 ==="
  docker save "${APP_IMAGE}" -o tybooks.tar
  docker save "${PG_DST}" -o postgres.tar

  echo
  echo "构建完成："
  ls -lh tybooks.tar postgres.tar
  echo
  echo "下一步："
  echo "  scp tybooks.tar postgres.tar <user>@<node>:/tmp/"
  echo "  docker load -i /tmp/tybooks.tar && docker load -i /tmp/postgres.tar"
else
  echo "=== 6/6 跳过导出（EXPORT=0）==="
  echo
  echo "构建完成：${APP_IMAGE}"
fi
