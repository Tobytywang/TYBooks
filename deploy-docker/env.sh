#!/bin/bash
# 公共环境变量加载，由 primary/init.sh 与 standby/setup.sh source
# 读取 deploy-docker/.env，与 compose 命令的 --env-file ../.env 指向同一文件

ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_DIR}/.env"

if [ -f "${ENV_FILE}" ]; then
  echo "加载环境变量: ${ENV_FILE}"
  set -a
  source "${ENV_FILE}"
  set +a
else
  echo "警告：未找到 ${ENV_FILE}，请先复制 .env.example 为 .env"
fi
