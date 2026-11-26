# TYBooks 服务器初始化指南（TencentOS）

> 适用：全新初始化的 TencentOS Server（RHEL/CentOS 系、`x86_64`、单节点）。
> 目标：从零装好 K3s、Nginx 和 HTTPS 证书，之后按 `DEPLOY.md` 部署应用。

约定：

| 占位符 | 说明 |
| --- | --- |
| `<YOUR_DOMAIN>` | 已解析到服务器公网 IP 的域名 |
| `<YOUR_EMAIL>` | 申请 Let's Encrypt 证书用的邮箱 |
| `<SERVER_IP>` | 服务器公网 IP |

以下命令默认使用有 `sudo` 权限的普通用户，或在 root 下直接执行。TencentOS 3.x/4.x 使用 `dnf`；较旧版本把 `dnf` 换成 `yum` 即可。

## 1. 系统预检

```bash
cat /etc/os-release          # 确认 TencentOS 版本
uname -m                     # 期望 x86_64
nproc && free -h && df -h /  # 建议至少 2 核 / 2GB 内存 / 10GB 可用磁盘
```

同时确认：

- 域名 A 记录已指向 `<SERVER_IP>`
- 腾讯云安全组放行 22、80、443（远程 kubectl 才需要 6443）
- 服务器时间准确，否则 K3s 的 TLS 证书会校验失败

## 2. 系统基础配置

### 时间同步

```bash
timedatectl set-timezone Asia/Shanghai
systemctl enable --now chronyd
chronyc tracking
```

### 关闭 swap

kubelet 默认要求关闭 swap：

```bash
swapon --show
sudo swapoff -a
sudo sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab
```

### 内核模块与转发

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

先查看状态：

```bash
getenforce
```

如果是 `Enforcing`，有两种选择：

推荐保留 Enforcing，安装 SELinux 支持包，并在安装 K3s 时追加 `--selinux`：

```bash
sudo dnf install -y container-selinux
```

如果仓库里没有 `container-selinux`，或不想处理 SELinux，可以改为 permissive（重启后生效，安全性略低）：

```bash
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
```

Nginx 反向代理到 NodePort 需要允许网络连接。SELinux 为 `Enforcing` 或 `Permissive` 时执行：

```bash
sudo setsebool -P httpd_can_network_connect 1
```

如果 `getenforce` 显示 `Disabled`，这条命令会报错，可以跳过。

## 3. 防火墙

TencentOS 镜像可能默认关闭 firewalld，先检查：

```bash
systemctl is-active firewalld
```

如果输出 `active`，放行必要端口：

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

使用 Rancher 国内镜像安装，并停用 Traefik 和 ServiceLB：

```bash
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh \
  | INSTALL_K3S_MIRROR=cn \
    INSTALL_K3S_EXEC="--disable traefik --disable servicelb" sh -
```

如果 SELinux 保持 `Enforcing` 且已安装 `container-selinux`，追加 `--selinux`：

```bash
INSTALL_K3S_EXEC="--disable traefik --disable servicelb --selinux"
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

如果系统 Pod 卡在 `ImagePullBackOff`，说明镜像源受限，需要改用 air-gap 安装，步骤见 `DEPLOY.md` 第 3 节。

查看 K3s 日志：

```bash
sudo journalctl -u k3s -f
```

## 5. 安装 Nginx

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

移除默认站点，避免它抢占 80 端口的默认响应：

```bash
sudo mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak 2>/dev/null || true
sudo mkdir -p /var/www/letsencrypt
```

## 6. 先让 HTTP 通，再申请证书

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

| 现象 | 原因与处理 |
| --- | --- |
| `kubectl` 报权限错误 | 没复制 kubeconfig 或没有 chown，重做第 4 节 |
| 系统 Pod `ImagePullBackOff` | 镜像源受限，改用 `DEPLOY.md` 的 air-gap 安装 |
| Nginx 启动失败 | `nginx -t` 看具体行；常见是证书路径不存在或 80 端口被占用 |
| 证书申请失败 | 检查域名解析、80 端口、安全组，以及 `/var/www/letsencrypt` 权限 |
| `curl https` 返回 502 | 应用未部署或 Pod 未就绪，属预期 |
| SELinux 拒绝 Nginx 连接 | `sudo ausearch -m avc -ts recent`，确认 `httpd_can_network_connect` 已开启 |
| Pod 网络不通 | 检查 firewalld 是否放行 `8472/udp`，或临时停止 firewalld 验证 |
| `dnf` 找不到 nginx | `dnf makecache` 后重试，或使用 `yum` |
