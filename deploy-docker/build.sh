#!/bin/bash
# TYBooks Docker 构建脚本（与 deploy-k3s/build.sh 对称，用于 Docker Compose 部署）
#
# 可覆盖的环境变量：
#   VERSION    镜像版本号，默认取 package.json 的 version
#   PLATFORM   构建平台，默认 linux/amd64；设为 native 则使用本机架构
#   REGISTRY   基础镜像源，默认 docker.io/library；镜像受限时可换成 daocloud
#   NPM_REGISTRY  npm 源，默认 https://registry.npmmirror.com
#   APP_IMAGE  应用镜像名（不含 tag），默认 docker.io/library/tybooks
#   EXPORT     1=导出 tybooks.tar/postgres.tar，0=只构建，默认 1
#
# 用法：
#   npm run docker:build                          # linux/amd64 + 导出 tar
#   PLATFORM=native EXPORT=0 npm run docker:build # 本机构建，不导出
#   VERSION=1.0.1 npm run docker:build            # 临时覆盖版本号

set -euo pipefail

REGISTRY="${REGISTRY:-docker.io/library}"
PG_SRC="${REGISTRY}/postgres:16-alpine"
PG_DST="docker.io/library/postgres:16-alpine"
APP_IMAGE="${APP_IMAGE:-docker.io/library/tybooks}"
PLATFORM="${PLATFORM:-linux/amd64}"
EXPORT="${EXPORT:-1}"
VERSION="${VERSION:-}"
NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmmirror.com}"

PLATFORM_FLAG=""
if [ "${PLATFORM}" != "native" ]; then
  PLATFORM_FLAG="--platform ${PLATFORM}"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

if [ -z "${VERSION}" ]; then
  VERSION="$(node -p "require('./package.json').version")"
fi

IMAGE_VERSIONED="${APP_IMAGE}:${VERSION}"
IMAGE_LATEST="${APP_IMAGE}:latest"

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

echo "=== 4/6 构建应用镜像（${PLATFORM}，版本 ${VERSION}）==="
docker build \
  ${PLATFORM_FLAG} \
  --build-arg REGISTRY="${REGISTRY}" \
  --build-arg APP_VERSION="${VERSION}" \
  --build-arg NPM_REGISTRY="${NPM_REGISTRY}" \
  -t "${IMAGE_VERSIONED}" \
  -t "${IMAGE_LATEST}" .

echo "=== 5/6 统一 PostgreSQL 镜像名 ==="
if [ "${PG_SRC}" != "${PG_DST}" ]; then
  docker tag "${PG_SRC}" "${PG_DST}"
fi

if [ "${EXPORT}" = "1" ]; then
  echo "=== 6/6 导出镜像 ==="
  docker save "${IMAGE_VERSIONED}" -o tybooks.tar
  docker save "${PG_DST}" -o postgres.tar

  echo
  echo "构建完成："
  ls -lh tybooks.tar postgres.tar
  echo
  echo "镜像标签："
  echo "  ${IMAGE_VERSIONED}"
  echo "  ${IMAGE_LATEST}"
  echo
  echo "下一步："
  echo "  scp tybooks.tar postgres.tar <user>@<node>:/tmp/"
  echo "  docker load -i /tmp/tybooks.tar && docker load -i /tmp/postgres.tar"
else
  echo "=== 6/6 跳过导出（EXPORT=0）==="
  echo
  echo "构建完成：${IMAGE_VERSIONED}"
fi
