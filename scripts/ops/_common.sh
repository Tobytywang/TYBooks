#!/bin/bash
# 部署运维共享库（被 scripts/ops/*.sh source，不单独执行）
#
# 设计：把「运维动作」写一份，把「目标差异」放进 deploy-*/deploy.env。
# 这样加一个部署方式 = 加一个 deploy.env，而不是复制一套脚本。
#
# deploy.env 支持的变量：
#   RUNTIME            必填，docker 或 podman
#   APP_CONTAINER      必填，应用容器名
#   PG_CONTAINER       必填，数据库容器名
#   APP_PORT           可选，默认 8080
#   CONFIG_FILE        可选，需要检查占位符的文件（如 .env / pod.yaml）
#   PLACEHOLDER_PATTERN 可选，占位符正则，默认 CHANGE_ME
#   MANIFEST_FILE      可选，声明镜像的文件（用于架构检查）

set -uo pipefail

OPS_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OPS_FAIL=0

ops_die()  { echo "错误：$*" >&2; exit 1; }
ops_ok()   { echo "  ✓ $*"; }
ops_bad()  { echo "  ✗ $*"; OPS_FAIL=$((OPS_FAIL + 1)); }
ops_note() { echo "  · $*"; }

# 列出所有带 deploy.env 的部署目标
ops_targets() {
  local f
  for f in "${OPS_REPO_ROOT}"/deploy-*/deploy.env; do
    [ -f "${f}" ] || continue
    basename "$(dirname "${f}")"
  done
}

ops_default_target() {
  if [ -f "${OPS_REPO_ROOT}/deploy-docker/deploy.env" ]; then
    echo "deploy-docker"
  else
    ops_targets | head -1
  fi
}

# ops_load_target [目标]
#   目标可以是仓库内的目录名（deploy-docker / deploy-podman），
#   也可以直接是包含 deploy.env 的绝对路径（服务器上不按仓库结构摆放时用）。
# 加载后可用：TARGET_NAME / TARGET_DIR / RUNTIME / APP_CONTAINER / PG_CONTAINER / APP_PORT ...
ops_load_target() {
  local target="${1:-}"
  [ -n "${target}" ] || target="$(ops_default_target)"

  if [ -d "${target}" ] && [ -f "${target}/deploy.env" ]; then
    TARGET_DIR="$(cd "${target}" && pwd)"
    TARGET_NAME="$(basename "${TARGET_DIR}")"
  else
    [ -n "${target}" ] || ops_die "没有可用的部署目标（需要 deploy-*/deploy.env）"
    TARGET_NAME="${target}"
    TARGET_DIR="${OPS_REPO_ROOT}/${target}"
    [ -d "${TARGET_DIR}" ] || ops_die "目标目录不存在：${target}（可选：$(ops_targets | tr '\n' ' ')）"
    [ -f "${TARGET_DIR}/deploy.env" ] || ops_die "${target}/deploy.env 不存在"
  fi

  # shellcheck disable=SC1090
  source "${TARGET_DIR}/deploy.env"

  : "${RUNTIME:?${TARGET_NAME}/deploy.env 缺少 RUNTIME}"
  : "${APP_CONTAINER:?${TARGET_NAME}/deploy.env 缺少 APP_CONTAINER}"
  : "${PG_CONTAINER:?${TARGET_NAME}/deploy.env 缺少 PG_CONTAINER}"
  APP_PORT="${APP_PORT:-8080}"

  command -v "${RUNTIME}" >/dev/null 2>&1 || ops_die "未找到命令：${RUNTIME}"
  "${RUNTIME}" info >/dev/null 2>&1 || ops_die "${RUNTIME} 未就绪（daemon 未启动？）"
}

ops_ps()       { "${RUNTIME}" ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'; }
ops_running()  { "${RUNTIME}" ps --format '{{.Names}}' 2>/dev/null | grep -qx "$1"; }
ops_exec_app() { "${RUNTIME}" exec "${APP_CONTAINER}" "$@"; }
ops_exec_pg()  { "${RUNTIME}" exec "${PG_CONTAINER}" "$@"; }

# 镜像架构；不存在返回 none（去掉输出里的空白，避免空行混进变量）
ops_arch_of() {
  local arch
  arch="$("${RUNTIME}" image inspect "$1" --format '{{.Architecture}}' 2>/dev/null | tr -d '[:space:]')"
  if [ -n "${arch}" ]; then
    echo "${arch}"
  else
    echo none
  fi
}

# 本机架构，换算成镜像体系里的叫法
ops_host_arch() {
  local m
  m="$(uname -m)"
  case "${m}" in
    x86_64)  echo amd64 ;;
    aarch64) echo arm64 ;;
    arm64)   echo arm64 ;;
    *)       echo "${m}" ;;
  esac
}

# 从 manifest 文件里提取声明的镜像名（compose 的 image: 或 pod.yaml 的 image:）
ops_manifest_images() {
  local f="$1"
  [ -f "${f}" ] || return 0
  grep -oE 'image:[[:space:]]*[^[:space:]#]+' "${f}" \
    | sed -E 's/^image:[[:space:]]*//' \
    | tr -d '"' | tr -d "'" \
    | sort -u
}

ops_summary() {
  echo
  if [ "${OPS_FAIL}" -eq 0 ]; then
    echo "全部通过"
    return 0
  fi
  echo "有 ${OPS_FAIL} 项未通过"
  return 1
}
