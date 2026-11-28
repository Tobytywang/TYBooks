#!/bin/bash
# 只导出镜像 tar，不重建应用（用于"只补一个包"的场景）
#
# 典型场景：应用镜像没变，但 postgres 包架构不对，只想重出 postgres.tar。
# 重建整个应用（qemu 模拟下要几分钟）是浪费。
#
# 用法：
#   bash scripts/image/export.sh          # app + pg
#   bash scripts/image/export.sh app      # 只导出 tybooks.tar
#   bash scripts/image/export.sh pg       # 只导出 postgres.tar
#
# 可覆盖的环境变量：
#   ENGINE     podman（默认）或 docker
#   PLATFORM   目标平台，默认 linux/amd64；设为 native 用本机架构
#   REGISTRY   基础镜像源，默认 docker.m.daocloud.io/library
#   APP_IMAGE  应用镜像名（不含 tag），默认 docker.io/library/tybooks
#   VERSION    版本号，默认取 package.json
#
# 导出结束会自动调用 image/verify-tars.sh 校验，失败则退出码非 0。

set -euo pipefail

TARGET="${1:-all}"
case "${TARGET}" in
  all|app|pg) ;;
  *) echo "用法: bash scripts/image/export.sh [all|app|pg]"; exit 1 ;;
esac

ENGINE="${ENGINE:-podman}"
case "${ENGINE}" in
  podman|docker) ;;
  *) echo "错误：ENGINE 必须是 podman 或 docker"; exit 1 ;;
esac

PLATFORM="${PLATFORM:-linux/amd64}"
APP_IMAGE="${APP_IMAGE:-docker.io/library/tybooks}"
PG_DST="docker.io/library/postgres:16-alpine"

# 默认统一走国内镜像源：两个引擎行为一致，
# 需要官方源时显式传 REGISTRY=docker.io/library
DEFAULT_REGISTRY="docker.m.daocloud.io/library"
REGISTRY="${REGISTRY:-${DEFAULT_REGISTRY}}"
PG_SRC="${REGISTRY}/postgres:16-alpine"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${ROOT_DIR}"

VERSION="${VERSION:-$(node -p "require('./package.json').version")}"
IMAGE_VERSIONED="${APP_IMAGE}:${VERSION}"

if [ "${PLATFORM}" = "native" ]; then
  WANT_ARCH="$("${ENGINE}" info --format '{{.Host.Arch}}')"
  PLATFORM_FLAG=""
else
  WANT_ARCH="${PLATFORM#*/}"
  PLATFORM_FLAG="--platform ${PLATFORM}"
fi

if ! "${ENGINE}" info >/dev/null 2>&1; then
  echo "错误：${ENGINE} 未就绪"
  [ "${ENGINE}" = "podman" ] && echo "macOS 上请先执行 podman machine start"
  exit 1
fi

save_image() {
  local img="$1" out="$2"
  echo "  写出 ${out}"
  if [ "${ENGINE}" = "podman" ]; then
    "${ENGINE}" save --format docker-archive -o "${out}" "${img}"
  else
    "${ENGINE}" save -o "${out}" "${img}"
  fi
}

export_app() {
  echo "=== 应用镜像 ==="
  if ! "${ENGINE}" image inspect "${IMAGE_VERSIONED}" >/dev/null 2>&1; then
    echo "错误：本地没有 ${IMAGE_VERSIONED}"
    echo "      请先执行 npm run podman:build（或 docker:build）"
    exit 1
  fi
  local arch
  arch="$("${ENGINE}" image inspect "${IMAGE_VERSIONED}" --format '{{.Architecture}}')"
  echo "  本地镜像架构：${arch}（需要 ${WANT_ARCH}）"
  if [ "${arch}" != "${WANT_ARCH}" ]; then
    echo "错误：${IMAGE_VERSIONED} 架构不符，请用 PLATFORM=${PLATFORM} 重新构建"
    exit 1
  fi
  save_image "${IMAGE_VERSIONED}" tybooks.tar
}

export_pg() {
  echo "=== 数据库镜像 ==="
  local arch
  arch="$("${ENGINE}" image inspect "${PG_SRC}" --format '{{.Architecture}}' 2>/dev/null || echo none)"
  if [ "${arch}" = "none" ]; then
    echo "  本地无 ${PG_SRC}，拉取..."
    "${ENGINE}" pull ${PLATFORM_FLAG} "${PG_SRC}"
  elif [ "${arch}" != "${WANT_ARCH}" ]; then
    echo "  本地 ${PG_SRC} 是 ${arch}，需要 ${WANT_ARCH}，重新拉取..."
    "${ENGINE}" pull ${PLATFORM_FLAG} "${PG_SRC}"
  else
    echo "  本地已有 ${PG_SRC} (${arch})"
  fi

  if [ "${PG_SRC}" != "${PG_DST}" ]; then
    "${ENGINE}" tag "${PG_SRC}" "${PG_DST}"
  fi
  save_image "${PG_DST}" postgres.tar
}

case "${TARGET}" in
  all) export_app; echo; export_pg ;;
  app) export_app ;;
  pg)  export_pg ;;
esac

echo
EXPECT_ARCH="${WANT_ARCH}" bash "${SCRIPT_DIR}/verify-tars.sh"

echo
echo "上传命令："
case "${TARGET}" in
  all) echo "  scp tybooks.tar postgres.tar <user>@<server>:/opt/tybooks/" ;;
  app) echo "  scp tybooks.tar <user>@<server>:/opt/tybooks/" ;;
  pg)  echo "  scp postgres.tar <user>@<server>:/opt/tybooks/" ;;
esac
