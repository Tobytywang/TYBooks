import { readFileSync, writeFileSync } from 'fs'
import { dirname, join } from 'path'
import { fileURLToPath } from 'url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const next = process.argv[2]

if (!next || !/^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$/.test(next)) {
  console.error('用法: npm run version:bump -- <版本号>，例如 1.0.1')
  process.exit(1)
}

const pkgPath = join(root, 'package.json')
const pkg = JSON.parse(readFileSync(pkgPath, 'utf8'))
const prev = pkg.version

if (prev === next) {
  console.error(`版本号已经是 ${next}`)
  process.exit(1)
}

pkg.version = next
writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n')

const lockPath = join(root, 'package-lock.json')
try {
  const lock = JSON.parse(readFileSync(lockPath, 'utf8'))
  lock.version = next
  if (lock.packages && lock.packages['']) {
    lock.packages[''].version = next
  }
  writeFileSync(lockPath, JSON.stringify(lock, null, 2) + '\n')
} catch {
  // package-lock.json 不存在时忽略
}

const manifests = [
  'deploy-k3s/app/app.yaml',
  'deploy-podman/pod.yaml',
  'deploy-docker/primary/docker-compose.yml',
  'deploy-docker/standby/docker-compose.yml',
]

const pattern = new RegExp(`docker\\.io/library/tybooks:${prev.replace(/\./g, '\\.')}`, 'g')
let changed = 0

for (const rel of manifests) {
  const path = join(root, rel)
  const source = readFileSync(path, 'utf8')
  const updated = source.replace(pattern, `docker.io/library/tybooks:${next}`)
  if (updated !== source) {
    writeFileSync(path, updated)
    changed++
  }
}

console.log(`版本号: ${prev} -> ${next}`)
console.log(`已更新 package.json、package-lock.json 和 ${changed} 个部署清单`)
console.log('下一步: npm run podman:build（或 npm run docker:build）')
