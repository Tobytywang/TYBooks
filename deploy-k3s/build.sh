#!/bin/bash
# TYBooks 本地构建脚本
# 用途：在 macOS 上构建 linux/amd64 镜像并导出，供 x86_64 服务器上的 K3s 离线导入
# 用法：项目根目录执行 npm run podman:build，或 bash deploy-k3s/build.sh

set -euo pipefail

REGISTRY="docker.m.daocloud.io/library"
PG_SRC="${REGISTRY}/postgres:16-alpine"
PG_DST="docker.io/library/postgres:16-alpine"
APP_IMAGE="docker.io/library/tybooks:latest"
PLATFORM="linux/amd64"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

echo "=== 1/6 检查 Podman ==="
if ! podman info >/dev/null 2>&1; then
  echo "错误：Podman 未就绪。macOS 上请先执行 podman machine start"
  exit 1
fi

echo "=== 2/6 检查 PostgreSQL 镜像 ==="
if podman image inspect "${PG_SRC}" >/dev/null 2>&1; then
  echo "已存在 ${PG_SRC}"
else
  echo "未找到 ${PG_SRC}，开始拉取..."
  podman pull --platform "${PLATFORM}" "${PG_SRC}"
fi

echo "=== 3/6 构建前端 ==="
npm run build

echo "=== 4/6 构建应用镜像（${PLATFORM}）==="
podman build \
  --platform "${PLATFORM}" \
  --build-arg REGISTRY="${REGISTRY}" \
  -t "${APP_IMAGE}" .

echo "=== 5/6 统一 PostgreSQL 镜像名 ==="
podman tag "${PG_SRC}" "${PG_DST}"

echo "=== 6/6 导出镜像 ==="
podman save "${APP_IMAGE}" -o tybooks.tar
podman save "${PG_DST}" -o postgres.tar

echo
echo "构建完成："
ls -lh tybooks.tar postgres.tar
echo
echo "下一步："
echo "  scp tybooks.tar postgres.tar <user>@<server>:/tmp/"
