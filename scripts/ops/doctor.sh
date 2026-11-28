#!/bin/bash
# 部署前检查：运行时、配置占位符、端口、镜像架构、内存与磁盘
#
# 用法：
#   npm run ops:doctor                         # 默认 deploy-docker
#   npm run ops:doctor -- deploy-podman
#
# 重点拦的是本次踩过的坑：镜像架构不符（arm64 包跑在 x86_64 上）、
# 配置里残留占位符、可用内存不足。

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
ops_load_target "${1:-}"

echo "目标：${TARGET_NAME}（运行时 ${RUNTIME}）"
echo

echo "=== 运行时 ==="
ops_ok "$("${RUNTIME}" --version 2>&1 | head -1)"

echo
echo "=== 配置文件 ==="
if [ -n "${CONFIG_FILE:-}" ]; then
  cfg="${TARGET_DIR}/${CONFIG_FILE}"
  if [ -f "${cfg}" ]; then
    pat="${PLACEHOLDER_PATTERN:-CHANGE_ME}"
    # 注意：grep -c 在 0 匹配时会输出 0 但退出码为 1，
    # 若写成 `|| echo 0` 会得到 "0\n0"，导致下面的整数比较报错。
    hits="$(grep -cE "${pat}" "${cfg}" 2>/dev/null)"
    hits="${hits:-0}"
    if [ "${hits}" -gt 0 ]; then
      ops_bad "${CONFIG_FILE} 仍含 ${hits} 处占位符（${pat}）"
      grep -nE "${pat}" "${cfg}" | head -5 | sed 's/^/      /'
    else
      ops_ok "${CONFIG_FILE} 无残留占位符"
    fi
  else
    ops_bad "缺少 ${CONFIG_FILE}（参考同名 .example 文件创建）"
  fi
else
  ops_note "未声明 CONFIG_FILE，跳过"
fi

echo
echo "=== 端口 ${APP_PORT} ==="
if command -v ss >/dev/null 2>&1; then
  if ss -lnt 2>/dev/null | awk 'NR>1{print $4}' | grep -qE "[:.]${APP_PORT}$"; then
    ops_note "端口 ${APP_PORT} 已被监听（若为本服务则正常）"
  else
    ops_ok "端口 ${APP_PORT} 未被占用"
  fi
else
  ops_note "无 ss 命令，跳过端口检查"
fi

echo
echo "=== 镜像（与主机架构比对）==="
want="$(ops_host_arch)"
if [ -n "${MANIFEST_FILE:-}" ] && [ -f "${TARGET_DIR}/${MANIFEST_FILE}" ]; then
  images="$(ops_manifest_images "${TARGET_DIR}/${MANIFEST_FILE}")"
  if [ -z "${images}" ]; then
    ops_bad "${MANIFEST_FILE} 里没找到 image: 声明"
  else
    while IFS= read -r img; do
      [ -n "${img}" ] || continue
      arch="$(ops_arch_of "${img}")"
      if [ "${arch}" = "none" ]; then
        ops_bad "本地缺少 ${img}（需要先 load/import）"
      elif [ "${arch}" = "${want}" ]; then
        ops_ok "${img}（${arch}）"
      elif [ "${want}" = "arm64" ] && [ "${arch}" = "amd64" ]; then
        ops_note "${img} 是 ${arch}，主机 ${want}：能跑但走模拟，明显变慢"
      else
        ops_bad "${img} 架构 ${arch} ≠ 主机 ${want}，容器会启动失败"
      fi
    done <<< "${images}"
  fi
else
  ops_note "未声明 MANIFEST_FILE，跳过镜像检查"
fi

echo
echo "=== 资源 ==="
if [ -r /proc/meminfo ]; then
  total="$(awk '/^MemTotal/{print int($2/1024)}' /proc/meminfo)"
  avail="$(awk '/^MemAvailable/{print int($2/1024)}' /proc/meminfo)"
  ops_note "内存 ${total} MiB，可用 ${avail} MiB"
  if [ "${avail}" -lt 300 ]; then
    ops_bad "可用内存不足 300 MiB，容器可能被 OOM"
  else
    ops_ok "可用内存充足"
  fi
else
  ops_note "非 Linux 或无 /proc/meminfo，跳过内存检查"
fi
if command -v df >/dev/null 2>&1; then
  ops_note "磁盘 $(df -h / | awk 'NR==2{print $4" 可用，已用 "$5}')"
fi

ops_summary
