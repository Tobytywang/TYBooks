#!/bin/bash
# TYBooks 镜像构建脚本（Docker 与 Podman 共用）
#
# 用法：
#   ENGINE=podman npm run podman:build
#   ENGINE=docker npm run docker:build
#
# 可覆盖的环境变量：
#   ENGINE       podman 或 docker（必填）
#   VERSION      镜像版本号，默认取 package.json 的 version
#   PLATFORM     构建平台，默认 linux/amd64；设为 native 则使用本机架构
#   REGISTRY     基础镜像源，默认 docker.m.daocloud.io/library
#   NPM_REGISTRY npm 源，默认 https://registry.npmmirror.com
#   APP_IMAGE    应用镜像名（不含 tag），默认 docker.io/library/tybooks
#   EXPORT       1=导出 tar，0=只构建

set -euo pipefail

ENGINE="${ENGINE:-}"
case "${ENGINE}" in
  podman|docker) ;;
  *) echo "错误：ENGINE 必须是 podman 或 docker"; exit 1 ;;
esac

# 默认统一走国内镜像源：两个引擎行为一致，
# 需要官方源时显式传 REGISTRY=docker.io/library
DEFAULT_REGISTRY="docker.m.daocloud.io/library"

VERSION="${VERSION:-}"
PLATFORM="${PLATFORM:-linux/amd64}"
REGISTRY="${REGISTRY:-${DEFAULT_REGISTRY}}"
NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmmirror.com}"
APP_IMAGE="${APP_IMAGE:-docker.io/library/tybooks}"
PG_DST="docker.io/library/postgres:16-alpine"
PG_SRC="${REGISTRY}/postgres:16-alpine"
EXPORT="${EXPORT:-1}"

PLATFORM_FLAG=""
if [ "${PLATFORM}" != "native" ]; then
  PLATFORM_FLAG="--platform ${PLATFORM}"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${ROOT_DIR}"

if [ -z "${VERSION}" ]; then
  VERSION="$(node -p "require('./package.json').version")"
fi

IMAGE_VERSIONED="${APP_IMAGE}:${VERSION}"
IMAGE_LATEST="${APP_IMAGE}:latest"

echo "=== 1/6 检查 ${ENGINE} ==="
if ! "${ENGINE}" info >/dev/null 2>&1; then
  echo "错误：${ENGINE} 未就绪"
  if [ "${ENGINE}" = "podman" ]; then
    echo "macOS 上请先执行 podman machine start"
  else
    echo "请确认 Docker 服务已启动"
  fi
  exit 1
fi

echo "=== 2/6 检查 PostgreSQL 镜像 ==="
# 只判断"是否存在"是不够的：在 Apple Silicon 上，本地早已有 arm64 版本，
# 会跳过 --platform 拉取，最终导出 arm64 的 tar，在 x86_64 服务器上无法启动。
if [ "${PLATFORM}" = "native" ]; then
  WANT_ARCH="$("${ENGINE}" info --format '{{.Host.Arch}}')"
else
  WANT_ARCH="${PLATFORM#*/}"
fi
HAVE_ARCH="$("${ENGINE}" image inspect "${PG_SRC}" --format '{{.Architecture}}' 2>/dev/null || echo none)"

if [ "${HAVE_ARCH}" = "none" ]; then
  echo "未找到 ${PG_SRC}，开始拉取..."
  "${ENGINE}" pull ${PLATFORM_FLAG} "${PG_SRC}"
elif [ "${HAVE_ARCH}" != "${WANT_ARCH}" ]; then
  echo "架构不匹配（本地 ${HAVE_ARCH}，需要 ${WANT_ARCH}），重新拉取 ${PG_SRC}"
  "${ENGINE}" pull ${PLATFORM_FLAG} "${PG_SRC}"
else
  echo "已存在 ${PG_SRC} (${HAVE_ARCH})"
fi

echo "=== 3/6 构建前端 ==="
npm run build

echo "=== 4/6 构建应用镜像（${ENGINE}，${PLATFORM}，版本 ${VERSION}）==="
"${ENGINE}" build \
  ${PLATFORM_FLAG} \
  --build-arg REGISTRY="${REGISTRY}" \
  --build-arg APP_VERSION="${VERSION}" \
  --build-arg NPM_REGISTRY="${NPM_REGISTRY}" \
  -t "${IMAGE_VERSIONED}" \
  -t "${IMAGE_LATEST}" .

echo "=== 5/6 统一 PostgreSQL 镜像名 ==="
if [ "${PG_SRC}" != "${PG_DST}" ]; then
  "${ENGINE}" tag "${PG_SRC}" "${PG_DST}"
fi

if [ "${EXPORT}" = "1" ]; then
  echo "=== 6/6 导出镜像 ==="
  "${ENGINE}" save "${IMAGE_VERSIONED}" -o tybooks.tar
  "${ENGINE}" save "${PG_DST}" -o postgres.tar

  echo
  echo "=== 校验导出产物 ==="
  EXPECT_ARCH="${WANT_ARCH}" bash "${SCRIPT_DIR}/verify-tars.sh"

  echo
  echo "构建完成："
  ls -lh tybooks.tar postgres.tar
  echo
  echo "镜像标签："
  echo "  ${IMAGE_VERSIONED}"
  echo "  ${IMAGE_LATEST}"
  echo
  echo "下一步："
  echo "  scp tybooks.tar postgres.tar <user>@<server>:/tmp/"
  if [ "${ENGINE}" = "docker" ]; then
    echo "  docker load -i /tmp/tybooks.tar && docker load -i /tmp/postgres.tar"
  fi
else
  echo "=== 6/6 跳过导出（EXPORT=0）==="
  echo
  echo "构建完成：${IMAGE_VERSIONED}"
  if [ "${ENGINE}" = "podman" ]; then
    echo "本地运行：podman play kube deploy-podman/pod.yaml"
  fi
fi
