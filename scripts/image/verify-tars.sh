#!/bin/bash
# 校验导出的镜像 tar：文件完整性、tag 名称、目标架构、版本标签
#
# 用途：交付到服务器之前必跑。曾经出现过 postgres.tar 里是 arm64 镜像、
#       在 x86_64 服务器上起不来的问题（构建脚本复用了本地已有镜像）。
#
# 用法：
#   bash scripts/image/verify-tars.sh
#   EXPECT_ARCH=arm64 bash scripts/image/verify-tars.sh
#   APP_TAR=other.tar bash scripts/image/verify-tars.sh
#
# 可覆盖的环境变量：
#   APP_TAR      应用镜像包，默认 tybooks.tar
#   PG_TAR       数据库镜像包，默认 postgres.tar
#   EXPECT_ARCH  期望架构，默认 amd64（服务器为 x86_64）
#   VERSION      期望版本，默认取 package.json 的 version
#   APP_IMAGE    应用镜像名（不含 tag）
#   PG_IMAGE     数据库镜像名（含 tag）

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

VERSION="${VERSION:-$(node -p "require('./package.json').version" 2>/dev/null || echo '')}"

python3 - \
  "${APP_TAR:-tybooks.tar}" \
  "${PG_TAR:-postgres.tar}" \
  "${EXPECT_ARCH:-amd64}" \
  "${VERSION}" \
  "${APP_IMAGE:-docker.io/library/tybooks}" \
  "${PG_IMAGE:-docker.io/library/postgres:16-alpine}" <<'PY'
import json
import os
import sys
import tarfile

app_tar, pg_tar, expect_arch, version, app_image, pg_image = sys.argv[1:7]
app_repo = f"{app_image}:{version}"

failures = 0


def inspect(path):
    """返回 (info, errors)。info 为 None 表示连读取都失败。"""
    if not os.path.isfile(path):
        return None, [f"文件不存在: {path}"]
    try:
        with tarfile.open(path, "r:*") as tf:
            try:
                manifest = json.load(tf.extractfile("manifest.json"))
            except KeyError:
                return None, ["缺少 manifest.json（不是 docker-archive 格式）"]
            if not manifest:
                return None, ["manifest.json 为空"]
            entry = manifest[0]
            cfg = json.load(tf.extractfile(entry["Config"]))
    except Exception as exc:  # noqa: BLE001 - 展示原始错误即可
        return None, [f"读取失败: {exc}"]

    info = {
        "repos": entry.get("RepoTags") or [],
        "os": cfg.get("os"),
        "arch": cfg.get("architecture"),
        "labels": (cfg.get("config") or {}).get("Labels") or {},
    }
    errors = []
    if info["os"] != "linux":
        errors.append(f"os 应为 linux，实际为 {info['os']}")
    if info["arch"] != expect_arch:
        errors.append(f"架构应为 {expect_arch}，实际为 {info['arch']}")
    return info, errors


def report(path, expected_repo, check_version=False):
    global failures
    print(f"\n{path}")
    info, errors = inspect(path)
    if info is None:
        for err in errors:
            print(f"  ✗ {err}")
        failures += 1
        return

    print(f"  tag       {', '.join(info['repos']) or '(无)'}")
    print(f"  platform  {info['os']}/{info['arch']}")

    if expected_repo not in info["repos"]:
        errors.append(f"tag 不匹配，期望 {expected_repo}")

    if check_version:
        label = info["labels"].get("org.opencontainers.image.version")
        print(f"  version   {label or '(无标签)'}")
        if label != version:
            errors.append(f"版本标签应为 {version}，实际为 {label}")

    if errors:
        for err in errors:
            print(f"  ✗ {err}")
        print(f"  ✗ 失败")
        failures += 1
    else:
        print("  ✓ 通过")


report(app_tar, app_repo, check_version=True)
report(pg_tar, pg_image)

print()
if failures:
    print(f"校验失败：{failures} 个产物有问题，不要上传到服务器。")
    sys.exit(1)
print("校验通过：所有产物架构、tag、版本均正确。")
PY
