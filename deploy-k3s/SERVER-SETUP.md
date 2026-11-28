# TYBooks 服务器初始化指南（TencentOS）

> 适用：全新初始化的 TencentOS Server（RHEL/CentOS 系、`x86_64`、单节点）。
> 目标：从零装好 K3s、Nginx 和 HTTPS 证书，之后按 `DEPLOY.md` 部署应用。

约定：

| 占位符            | 说明                            |
| ----------------- | ------------------------------- |
| `<YOUR_DOMAIN>` | 已解析到服务器公网 IP 的域名    |
| `<YOUR_EMAIL>`  | 申请 Let's Encrypt 证书用的邮箱 |
| `<SERVER_IP>`   | 服务器公网 IP                   |

以下命令默认带 `sudo`。如果你已经以 root 登录，直接去掉 `sudo` 执行即可；最小化安装的 TencentOS 可能没有安装 sudo。包含 `<<'EOF'` 的 here-doc 命令建议一次执行一段，避免整段粘贴时被终端截断。TencentOS 3.x/4.x 使用 `dnf`；较旧版本把 `dnf` 换成 `yum` 即可。

## 1. 系统预检

```bash
cat /etc/os-release          # 确认 TencentOS 版本
uname -m                     # 期望 x86_64
nproc && free -h && df -h /  # 至少 2 核 / 2GB 内存 / 10GB 可用磁盘
```

> K3s 控制平面本身就需要 500MB 以上，加上 PostgreSQL、应用和 Nginx，**1GB 内存会不稳定**，表现为 apiserver 超时、Pod CrashLoopBackOff、节点间歇 NotReady。建议 4GB，最低 2GB。

同时确认：

- 域名 A 记录已指向 `<SERVER_IP>`
- 腾讯云安全组放行 22、80、443（远程 kubectl 才需要 6443）
- 服务器时间准确，否则 K3s 的 TLS 证书会校验失败

## 2. 系统基础配置

以下操作会修改系统状态。建议先执行查看命令，确认当前值后再决定是否修改。

### 时间同步

先查看当前时区、时间服务和同步状态：

```bash
timedatectl
systemctl status chronyd --no-pager
chronyc tracking
```

判断方式：

- `timedatectl` 显示 `Time zone: Asia/Shanghai`、`NTP service: active`、`System clock synchronized: yes`：已经满足要求，跳过本节。
- 时区不是 `Asia/Shanghai`：执行 `set-timezone`。
- `NTP service` 不是 `active`，或 `System clock synchronized: no`：启用 chronyd。
- `chronyc tracking` 报连接失败或命令不存在：说明 chronyd 没运行，按上一条处理。
- 如果 `systemctl status chronyd` 提示 unit 不存在，先安装：`sudo dnf install -y chrony`。
- 如果已有 ntpd、systemd-timesyncd 等其他时间服务在运行，不要启用 chronyd，保留其中一个即可，否则会争抢时钟源。

只执行需要修改的部分：

```bash
# 时区不对时
sudo timedatectl set-timezone Asia/Shanghai

# NTP 未启用时
sudo systemctl enable --now chronyd
```

设置后再确认：

```bash
timedatectl
chronyc tracking
```

期望 `System clock synchronized: yes`，`chronyc tracking` 的 `Leap status` 为 `Normal`。

### 关闭 swap

kubelet 默认要求关闭 swap。先查看当前状态：

```bash
swapon --show
free -h
grep -n swap /etc/fstab
```

判断方式：

- `swapon --show` 没有输出，且 `free -h` 的 Swap 一行全是 0：说明已经关闭，跳过本节。
- `swapon --show` 有输出（例如 `/dev/vda2`、`/dev/zram0`）：需要关闭。
- `grep` 有结果：说明 `/etc/fstab` 里配置了 swap，重启后会被重新启用，需要一并注释。

确认需要关闭后执行：

```bash
sudo swapoff -a
sudo sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab
```

`sed` 会把 `/etc/fstab` 中包含 `swap` 的行注释掉。执行后再次检查：

```bash
swapon --show            # 应为空
free -h                  # Swap 一行应全为 0
grep -n swap /etc/fstab  # 相关行应以 # 开头
```

如果 Swap 已使用较多，`swapoff` 可能很慢甚至失败，建议在维护窗口执行。如果服务器使用 zram（`swapon --show` 显示 `/dev/zram0`），重启后系统可能重新启用它，需要在对应配置中禁用，或重启后再次确认。

### 内核模块与转发

先查看当前模块和转发参数：

```bash
lsmod | grep -E 'overlay|br_netfilter' || echo "模块尚未加载"
sysctl net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables
```

`lsmod` 有输出表示模块已加载；`sysctl` 的值是 `1` 表示转发已开启。如果两项都已满足，本节可以跳过；`modprobe` 和 `sysctl` 本身也是幂等的，重复执行没有副作用。

如果 `lsmod` 没有输出，可以用 `modprobe -n -v overlay` 进一步判断：能列出 `insmod .../overlay.ko` 说明是可加载模块；没有输出通常说明已编译进内核；报 `Module not found` 才是真的缺失。`br_netfilter` 同理。需要时再加载模块并写入配置：

```bash
sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/modules-load.d/k3s.conf >/dev/null <<'EOF'
overlay
br_netfilter
EOF

sudo tee /etc/sysctl.d/90-k3s.conf >/dev/null <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
```

### SELinux

先查看状态和当前配置：

```bash
getenforce
grep '^SELINUX=' /etc/selinux/config
```

如果是 `Enforcing`，有两种选择：

推荐保留 Enforcing，安装 SELinux 支持包，并在安装 K3s 时追加 `--selinux`。先确认是否已安装：

```bash
rpm -q container-selinux || echo "container-selinux 尚未安装"
```

如果已安装，跳过下面的安装命令：

```bash
sudo dnf install -y container-selinux
```

如果仓库里没有 `container-selinux`，或不想处理 SELinux，可以改为 permissive（重启后生效，安全性略低）：

```bash
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
```

Nginx 反向代理到 NodePort 需要允许网络连接。先查看当前值：

```bash
getsebool httpd_can_network_connect
```

如果已经是 `on`，跳过；否则在 SELinux 为 `Enforcing` 或 `Permissive` 时执行：

```bash
sudo setsebool -P httpd_can_network_connect 1
```

如果 `getenforce` 显示 `Disabled`，这条命令会报错，可以跳过。

## 3. 防火墙

TencentOS 镜像可能默认关闭 firewalld，先检查：

```bash
systemctl is-active firewalld
```

如果输出 `active`，先查看当前规则，再放行必要端口：

```bash
sudo firewall-cmd --list-all
```

如果 `services` 和 `ports` 里已经包含所需项，对应命令可以跳过；否则执行：

```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https

# 需要从本机远程执行 kubectl 时
sudo firewall-cmd --permanent --add-port=6443/tcp

# 单节点可选，多节点必须
sudo firewall-cmd --permanent --add-port=8472/udp
sudo firewall-cmd --permanent --add-port=10250/tcp

sudo firewall-cmd --reload
sudo firewall-cmd --list-all
```

如果输出 `inactive`，以腾讯云安全组为准，不需要额外配置。

> NodePort 30080 只给本机 Nginx 使用，**不要**在安全组或 firewalld 中对外开放。

## 4. 安装 K3s

先确认是否已经安装：

```bash
k3s --version 2>/dev/null || echo "K3s 未安装"
systemctl is-active k3s
```

如果已经安装但参数不符合要求，修改 `/etc/rancher/k3s/config.yaml` 后重启；未安装再执行下面的命令。

使用 Rancher 国内镜像安装，并停用 Traefik 和 ServiceLB。这是官方 `get.k3s.io` 脚本的国内镜像，不是第三方脚本；生产环境建议先下载检查，并固定版本：

```bash
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh -o k3s-install.sh
less k3s-install.sh
```

```bash
INSTALL_K3S_VERSION=<K3S_VERSION> \
INSTALL_K3S_MIRROR=cn \
INSTALL_K3S_EXEC="--disable traefik --disable servicelb" \
sh k3s-install.sh
```

> 这三个变量必须和命令写在同一行，或先用 `export` 导出。单独一行写 `INSTALL_K3S_VERSION=...` 只是 shell 变量，不会传给安装脚本，结果是脚本去查最新稳定版、并从 GitHub 直连下载。

`<K3S_VERSION>` 以 K3s releases 页面的当前稳定版为准，例如 `v1.31.4+k3s1`。需要完整性校验时，可从 releases 的 `sha256sum-amd64.txt` 核对二进制，再配合 `INSTALL_K3S_SKIP_DOWNLOAD=true` 使用本地文件。

安装脚本执行时可以看两行日志判断参数是否生效：

```
[INFO]  Using <K3S_VERSION> as release          ← 没有 "Finding release for channel" 说明版本变量生效
[INFO]  Downloading binary <镜像地址>/...        ← 地址是 rancher 镜像而非 github.com 说明镜像变量生效
```

如果已经按默认参数装过，安装脚本可以重跑（同版本基本幂等）；也可以只补配置文件：

```bash
mkdir -p /etc/rancher/k3s
cat > /etc/rancher/k3s/config.yaml <<'EOF'
disable:
  - traefik
  - servicelb
EOF
systemctl restart k3s
```

如果安装停在 `nothing provides container-selinux >= 3:2.191.0-1`，说明 SELinux 处于启用状态，脚本要装 `k3s-selinux`，但 TencentOS 仓库里的 `container-selinux` 版本不够。先确认：

```bash
getenforce
rpm -q container-selinux
dnf list --showduplicates container-selinux
```

处理方式：

- SELinux 已关闭（`getenforce` 为 `Disabled`）但脚本仍尝试安装时，直接加 `INSTALL_K3S_SKIP_SELINUX_RPM=true` 重跑。脚本判断的不只是 enforcing 状态，还会尝试安装策略包。

```bash
INSTALL_K3S_VERSION=<K3S_VERSION> \
INSTALL_K3S_MIRROR=cn \
INSTALL_K3S_EXEC="--disable traefik --disable servicelb" \
INSTALL_K3S_SKIP_SELINUX_RPM=true \
sh k3s-install.sh
```

- 需要 SELinux 时先尝试升级：`dnf makecache && dnf update -y container-selinux`，版本满足后重跑安装脚本。
- 不需要 SELinux 时，把 `/etc/selinux/config` 改为 `SELINUX=disabled` 并重启，再重跑。注意 permissive 仍会被视为启用。
- 必须保持 Enforcing 时，需要从可信的 EL9 源补齐满足版本要求的 `container-selinux`。
- 变量名以脚本实际内容为准，可用 `grep -n 'SELINUX' k3s-install.sh` 确认。

如果 SELinux 保持 `Enforcing` 且已安装 `container-selinux`，追加 `--selinux`：

```bash
INSTALL_K3S_EXEC="--disable traefik --disable servicelb --selinux"
```

先查看是否已有 kubeconfig：

```bash
ls -l ~/.kube/config 2>/dev/null || echo "尚无 kubeconfig"
```

如果已存在，先备份：

```bash
cp ~/.kube/config ~/.kube/config.bak.$(date +%F)
```

配置 kubectl：

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER ~/.kube/config
kubectl get nodes
kubectl get pods -A
```

预期 `node` 为 `Ready`，`kube-system` 下的 `coredns`、`local-path-provisioner`、`metrics-server` 正常运行。

如果系统 Pod 卡在 `ImagePullBackOff`，说明镜像源受限，改用 air-gap 方式。先查看已有的 air-gap 镜像：

```bash
sudo ls -l /var/lib/rancher/k3s/agent/images/ 2>/dev/null || echo "目录不存在"
```

**K3s 已安装，只是拉不到系统镜像**：下载与当前版本匹配的离线镜像包，放入自动导入目录后重启，不需要重装。

> Rancher 镜像站主要镜像 `k3s` 二进制和校验文件，不一定包含 `k3s-airgap-images-amd64.tar.zst`；如果返回 404，跳到下面的 `registries.yaml` 镜像方案，或从 GitHub releases 下载后传到服务器。

```bash
# 版本号与已安装的 K3s 一致；v1.37.2+k3s1 对应 v1.37.2-k3s1
cd /tmp
curl -fL -o k3s-airgap-images-amd64.tar.zst \
  https://rancher-mirror.rancher.cn/k3s/<K3S_VERSION_DASH>/k3s-airgap-images-amd64.tar.zst

sudo mkdir -p /var/lib/rancher/k3s/agent/images/
sudo cp /tmp/k3s-airgap-images-amd64.tar.zst /var/lib/rancher/k3s/agent/images/
sudo systemctl restart k3s
```

**K3s 尚未安装（完全离线）**：同时下载 `k3s` 二进制和离线镜像包，再用 `INSTALL_K3S_SKIP_DOWNLOAD=true` 安装。

```bash
# 在能访问 Rancher 镜像的机器下载后传到服务器
curl -fL -O https://rancher-mirror.rancher.cn/k3s/<K3S_VERSION_DASH>/k3s
curl -fL -O https://rancher-mirror.rancher.cn/k3s/<K3S_VERSION_DASH>/k3s-airgap-images-amd64.tar.zst

sudo mkdir -p /var/lib/rancher/k3s/agent/images/
sudo cp k3s-airgap-images-amd64.tar.zst /var/lib/rancher/k3s/agent/images/
chmod +x k3s && sudo mv k3s /usr/local/bin/k3s

curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh \
  | INSTALL_K3S_SKIP_DOWNLOAD=true \
    INSTALL_K3S_SKIP_SELINUX_RPM=true \
    INSTALL_K3S_EXEC="--disable traefik --disable servicelb" sh -
```

如果离线包下载不到，也可以给 containerd 配置 Docker Hub 镜像源。创建 `/etc/rancher/k3s/registries.yaml`：

```yaml
mirrors:
  docker.io:
    endpoint:
      # 腾讯云内网镜像
      - "https://mirror.ccs.tencentyun.com"
      # 或 daocloud
      # - "https://docker.m.daocloud.io"
```

然后重启 K3s。前提是服务器能访问该镜像源。

查看 K3s 日志：

```bash
sudo journalctl -u k3s -f
```

## 5. 安装 Nginx

先确认是否已经安装：

```bash
nginx -v 2>/dev/null || echo "Nginx 未安装"
systemctl is-active nginx
```

如果已经安装，跳过 `dnf install`，直接确认服务状态。未安装再执行：

```bash
sudo dnf install -y nginx
nginx -v
sudo systemctl enable --now nginx
sudo systemctl status nginx --no-pager
```

如果提示找不到包，先刷新缓存再试：

```bash
sudo dnf makecache
sudo dnf install -y nginx
```

先查看默认站点是否存在：

```bash
sudo ls -l /etc/nginx/conf.d/default.conf 2>/dev/null || echo "默认站点不存在"
```

移除默认站点，避免它抢占 80 端口的默认响应：

```bash
sudo mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak 2>/dev/null || true
sudo mkdir -p /var/www/letsencrypt
```

## 6. 先让 HTTP 通，再申请证书

先查看是否已有配置：

```bash
sudo ls -l /etc/nginx/conf.d/tybooks.conf 2>/dev/null || echo "尚未配置"
```

如果已存在，先备份：

```bash
sudo cp /etc/nginx/conf.d/tybooks.conf /etc/nginx/conf.d/tybooks.conf.bak.$(date +%F)
```

写入一个临时的 HTTP 配置（同时为 ACME 验证预留路径）：

```bash
sudo tee /etc/nginx/conf.d/tybooks.conf >/dev/null <<'EOF'
server {
    listen 80;
    server_name <YOUR_DOMAIN>;

    location /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
    }

    location / {
        return 200 "tybooks server ready\n";
        add_header Content-Type text/plain;
    }
}
EOF

sudo nginx -t && sudo systemctl reload nginx
curl -I http://<YOUR_DOMAIN>
```

必须返回 `200`。如果失败，先检查 DNS 解析和安全组，再继续。

## 7. 申请证书

### 方式一：acme.sh（推荐 TencentOS）

先查看是否已有证书和 acme.sh：

```bash
sudo ls -l /etc/nginx/ssl/<YOUR_DOMAIN>.pem 2>/dev/null || echo "证书尚未签发"
sudo ls -l /root/.acme.sh/acme.sh 2>/dev/null || echo "acme.sh 尚未安装"
```

如果证书已经存在，可以跳过签发，只确认续期任务。

acme.sh 需要以 root 安装，否则自动续期时没有权限重载 Nginx：

```bash
sudo -i
curl https://get.acme.sh | sh -s email=<YOUR_EMAIL>
source ~/.bashrc

~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
~/.acme.sh/acme.sh --issue -d <YOUR_DOMAIN> -w /var/www/letsencrypt

mkdir -p /etc/nginx/ssl
~/.acme.sh/acme.sh --install-cert -d <YOUR_DOMAIN> \
  --key-file       /etc/nginx/ssl/<YOUR_DOMAIN>.key \
  --fullchain-file /etc/nginx/ssl/<YOUR_DOMAIN>.pem \
  --reloadcmd      "systemctl reload nginx"
exit
```

确认续期任务存在（root 的 crontab）：

```bash
sudo crontab -l | grep acme
systemctl is-active crond
```

如果 `get.acme.sh` 访问不了，在 root shell 中从 Gitee 安装：

```bash
sudo -i
git clone https://gitee.com/neilpang/acme.sh.git
cd acme.sh && ./acme.sh --install -m <YOUR_EMAIL>
exit
```

### 方式二：certbot（仓库提供时）

先查看是否已安装：

```bash
command -v certbot 2>/dev/null || echo "certbot 尚未安装"
rpm -q epel-release || echo "epel-release 尚未安装"
```

两者都已安装时，跳过下面的安装命令：

```bash
sudo dnf install -y epel-release
sudo dnf install -y certbot python3-certbot-nginx

sudo certbot certonly --webroot -w /var/www/letsencrypt \
  -d <YOUR_DOMAIN> --deploy-hook "systemctl reload nginx"
```

证书路径是 `/etc/letsencrypt/live/<YOUR_DOMAIN>/fullchain.pem` 和 `privkey.pem`，下一步配置 Nginx 时要改成这两个路径。

### 已有证书

把证书和私钥放到 `/etc/nginx/ssl/`，命名为 `<YOUR_DOMAIN>.pem` 和 `<YOUR_DOMAIN>.key`，跳过本节。

## 8. 启用 HTTPS 反向代理

如果服务器上还没有 `deploy-k3s` 目录，先在本地执行：

```bash
scp -r deploy-k3s <user>@<server>:~/
```

先查看现有配置并备份：

```bash
sudo ls -l /etc/nginx/conf.d/tybooks.conf 2>/dev/null || echo "尚未配置"
sudo cp /etc/nginx/conf.d/tybooks.conf /etc/nginx/conf.d/tybooks.conf.bak.$(date +%F) 2>/dev/null || true
```

然后用仓库里的模板覆盖临时配置：

```bash
sudo cp ~/deploy-k3s/nginx/tybooks.conf /etc/nginx/conf.d/tybooks.conf
sudo vi /etc/nginx/conf.d/tybooks.conf
```

需要替换：

- `server_name` 两处：`<YOUR_DOMAIN>`
- `ssl_certificate`：`/etc/nginx/ssl/<YOUR_DOMAIN>.pem`
- `ssl_certificate_key`：`/etc/nginx/ssl/<YOUR_DOMAIN>.key`

如果用的是 certbot，改成 `/etc/letsencrypt/live/...` 下的路径。

检查并重载：

```bash
sudo nginx -t && sudo systemctl reload nginx
curl -I https://<YOUR_DOMAIN>
```

此时应用还没部署，返回 `502` 是预期结果——Nginx 已经工作，但 `127.0.0.1:30080` 还没有后端。

## 9. 验证清单

```bash
kubectl get nodes
kubectl get pods -A
systemctl is-active nginx
curl -I http://<YOUR_DOMAIN>     # 期望 301
curl -I https://<YOUR_DOMAIN>    # 应用未部署时 502，部署后 200
```

检查证书有效期：

```bash
openssl s_client -connect <YOUR_DOMAIN>:443 -servername <YOUR_DOMAIN> </dev/null 2>/dev/null \
  | openssl x509 -noout -dates
```

## 10. 下一步

基础环境完成，回到 `DEPLOY.md` 继续：

1. 把 `tybooks.tar`、`postgres.tar` 和 `deploy-k3s/` 传到服务器
2. 导入镜像并用 `k3s ctr images ls` 核对名称
3. 创建 `postgres-secret` 和 `app-secret`
4. 依次 apply `postgres/` 和 `app/`
5. 验证 `/api/version`，登录后修改默认密码，配置备份

## 11. 常见问题

| 现象                          | 原因与处理                                                                     |
| ----------------------------- | ------------------------------------------------------------------------------ |
| `kubectl` 报权限错误        | 没复制 kubeconfig 或没有 chown，重做第 4 节                                    |
| 系统 Pod `ImagePullBackOff` | 镜像源受限，改用本节 air-gap 安装                                              |
| Nginx 启动失败                | `nginx -t` 看具体行；常见是证书路径不存在或 80 端口被占用                    |
| 证书申请失败                  | 检查域名解析、80 端口、安全组，以及 `/var/www/letsencrypt` 权限              |
| `curl https` 返回 502       | 应用未部署或 Pod 未就绪，属预期                                                |
| SELinux 拒绝 Nginx 连接       | `sudo ausearch -m avc -ts recent`，确认 `httpd_can_network_connect` 已开启 |
| Pod 网络不通                  | 检查 firewalld 是否放行 `8472/udp`，或临时停止 firewalld 验证                |
| `dnf` 找不到 nginx          | `dnf makecache` 后重试，或使用 `yum`                                       |
