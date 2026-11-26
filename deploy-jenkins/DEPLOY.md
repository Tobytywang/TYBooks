# Jenkins K3s 部署指南

基于 K3s，将 Jenkins 部署在独立的 `ci` namespace 中，与业务应用（tybooks）隔离。Jenkins 通过 **NodePort + 现有 Nginx** 暴露，和主应用使用同一套入口方案。

> 服务器尚未安装 K3s 和 Nginx 时，先按 `../deploy-k3s/SERVER-SETUP.md` 完成基础环境。

## 一、安装/部署前需知

### 所需软件

| 软件   | 安装位置    | 说明                               |
| ------ | ----------- | ---------------------------------- |
| Podman | 本地        | 导出镜像                           |
| K3s    | 服务器      | 与 tybooks 共用，需已停用 Traefik  |
| Nginx  | 服务器      | 终止 TLS，反代到 NodePort          |
| scp    | 本地/服务器 | 传输镜像（通常系统自带）           |

### 暴露端口

| 端口       | 服务          | 说明                                      |
| ---------- | ------------- | ----------------------------------------- |
| 30081      | Jenkins Web   | NodePort，仅供本机 Nginx 访问             |
| 50000      | Jenkins Agent | ClusterIP，集群内部 Agent 通过 JNLP 连接  |

> 30081 不需要在安全组或 firewalld 中对外开放，外部访问统一走 Nginx 的 80/443。

### 持久化卷

| PVC 名称    | 存储类     | 大小 | 说明                                       |
| ----------- | ---------- | ---- | ------------------------------------------ |
| jenkins-pvc | local-path | 5Gi  | Jenkins 数据持久化（插件、配置、构建记录） |

### 配置文件

| 文件                     | 说明                                            |
| ------------------------ | ----------------------------------------------- |
| `namespace.yaml`       | ci Namespace 定义                               |
| `jenkins.yaml`         | PVC + StatefulSet + 两个 Service                |
| `nginx/jenkins.conf`   | Nginx TLS 反代模板                              |

### K8s 资源清单

| 资源          | 类型        | Namespace | 文件           |
| ------------- | ----------- | --------- | -------------- |
| ci            | Namespace   | -         | namespace.yaml |
| jenkins-pvc   | PVC         | ci        | jenkins.yaml   |
| jenkins       | StatefulSet | ci        | jenkins.yaml   |
| jenkins       | Service (NodePort) | ci | jenkins.yaml |
| jenkins-agent | Service (ClusterIP) | ci | jenkins.yaml |

### Jenkins 初始配置

| 项目           | 说明                                                                     |
| -------------- | ------------------------------------------------------------------------ |
| 初始管理员密码 | 存储在`/var/jenkins_home/secrets/initialAdminPassword`，首次访问时需要 |
| 数据目录       | `/var/jenkins_home`，挂载到 PVC 持久化                                 |
| fsGroup        | 1000，确保 Jenkins 进程对数据目录有写权限                                |

## 二、安装步骤

### 1. 本地：导出 Jenkins 镜像

```bash
podman pull docker.m.daocloud.io/library/jenkins/jenkins:lts
podman save docker.m.daocloud.io/library/jenkins/jenkins:lts -o jenkins.tar
scp jenkins.tar <user>@<server>:/tmp/
```

### 2. 服务器：确认 K3s 就绪

如果尚未安装，按 `../deploy-k3s/SERVER-SETUP.md` 第 4 节安装。本方案要求已停用 Traefik：

```bash
kubectl get pods -n kube-system | grep traefik || echo "Traefik 已停用"
kubectl get nodes
```

### 3. 服务器：导入镜像

```bash
sudo k3s ctr images import /tmp/jenkins.tar
sudo k3s ctr images ls | grep jenkins
```

期望看到 `docker.m.daocloud.io/library/jenkins/jenkins:lts`，和 `jenkins.yaml` 中的镜像名一致。

### 4. 服务器：部署

```bash
kubectl apply -f namespace.yaml
kubectl apply -f jenkins.yaml
kubectl wait --for=condition=ready pod -l app=jenkins -n ci --timeout=180s
kubectl get pods,svc -n ci
```

### 5. 服务器：配置 Nginx 和 TLS

把 `nginx/jenkins.conf` 复制到 Nginx 配置目录，替换域名和证书路径：

```bash
sudo cp nginx/jenkins.conf /etc/nginx/conf.d/jenkins.conf
sudo vi /etc/nginx/conf.d/jenkins.conf
sudo nginx -t && sudo systemctl reload nginx
```

需要替换：

- `server_name` 两处：`YOUR_JENKINS_DOMAIN`
- `ssl_certificate`：`/etc/nginx/ssl/YOUR_JENKINS_DOMAIN.pem`
- `ssl_certificate_key`：`/etc/nginx/ssl/YOUR_JENKINS_DOMAIN.key`

证书申请方式见 `../deploy-k3s/SERVER-SETUP.md` 第 7 节，把域名换成 Jenkins 的域名即可。

验证：

```bash
curl -I http://127.0.0.1:30081/login
curl -I https://YOUR_JENKINS_DOMAIN
```

### 6. 服务器：获取初始管理员密码

```bash
kubectl exec -it $(kubectl get pods -l app=jenkins -n ci -o jsonpath='{.items[0].metadata.name}') -n ci -- cat /var/jenkins_home/secrets/initialAdminPassword
```

浏览器打开 `https://YOUR_JENKINS_DOMAIN`，用该密码完成初始化。

### 7. 服务器：验证

```bash
kubectl get pods,svc -n ci
kubectl logs -n ci statefulset/jenkins --tail=50
```

### 8. 更新部署

```bash
# 本地重新导出
podman pull docker.m.daocloud.io/library/jenkins/jenkins:lts
podman save docker.m.daocloud.io/library/jenkins/jenkins:lts -o jenkins.tar
scp jenkins.tar <user>@<server>:/tmp/

# 服务器导入并重启
sudo k3s ctr images import /tmp/jenkins.tar
kubectl rollout restart statefulset jenkins -n ci
kubectl rollout status statefulset jenkins -n ci --timeout=180s
```

> Jenkins 直接暴露到公网有安全风险。建议在 Nginx 层加 Basic Auth、IP 白名单，或只允许内网/VPN 访问。
