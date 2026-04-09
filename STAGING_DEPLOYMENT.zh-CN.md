# myapp 正式测试环境部署文档

本文档总结 `myapp` 正式测试环境从镜像构建、服务器初始化、首次部署到首次建站的完整流程，并记录这次实际部署中遇到的问题与对应解决方案。

适用范围：

- 根目录为 `frappe_docker`
- 业务应用为 `apps/myapp`
- 后端通过自定义镜像部署
- 测试服务器部署目录固定为 `/srv/frappe_docker`

不适用范围：

- `pwd.yml` 一次性 demo
- 本地开发环境
- 继续在服务器映射 `apps/myapp` 源码目录的旧方案

---

## 1. 当前采用的正式方案

当前测试环境采用的是：

1. `Lint`
   - 校验根仓库脚本、YAML、JSON、workflow 和基础格式
2. `Build myapp staging image`
   - 由 GitHub Actions 构建包含 `myapp` 的镜像
   - 推送到 `GHCR`
3. `Deploy staging stack`
   - 由 GitHub Actions 通过 SSH 登录测试服务器
   - 拉取最新镜像
   - 启动或更新 staging 容器栈
4. 首次建站
   - 使用 `init-site.sh`
   - 或单独运行 `Init staging site` workflow
5. 后续升级
   - 继续通过 `Deploy staging stack`
   - 若站点已存在，则自动执行 `bench migrate`

核心原则：

- 测试服务器只保留 `frappe_docker` 部署骨架
- 测试服务器不再映射 `apps/myapp` 源码目录
- `myapp` 通过镜像烘焙进入 bench
- 第一次部署时允许“容器已起来但站点尚未初始化”

---

## 2. 关键文件

### 部署与构建

- `/home/rgc318/python-project/frappe_docker/.github/workflows/lint.yml`
- `/home/rgc318/python-project/frappe_docker/.github/workflows/build_myapp_staging_image.yml`
- `/home/rgc318/python-project/frappe_docker/.github/workflows/deploy_staging.yml`
- `/home/rgc318/python-project/frappe_docker/.github/workflows/init_staging_site.yml`

### staging 运行文件

- `/home/rgc318/python-project/frappe_docker/deploy/staging/compose.staging.yaml`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/compose.mariadb.staging.yaml`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/staging.env.example`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/init-staging-server.sh`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/start-staging.sh`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/deploy-staging.sh`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/rollback-staging.sh`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/backup-staging.sh`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/check-staging.sh`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/init-site.sh`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/INIT_SITE.zh-CN.md`

---

## 3. 服务器准备

测试服务器当前信息：

- 主机：`39.104.204.79`
- SSH 端口：`10022`
- 用户：`vivy`
- 部署目录：`/srv/frappe_docker`

服务器需要准备：

- Docker
- Docker Compose v2
- git
- 能访问 `GHCR`
- 对 GitHub 仓库有读取能力（仅用于 `git pull frappe_docker`）

推荐目录边界：

- `/srv/frappe_docker`
  - 部署骨架
- `/srv/frappe_docker/deploy/staging/staging.env`
  - 服务器实例化配置
- Docker volumes
  - 保存 `sites`、数据库、Redis、bench env

---

## 4. SSH 与 GitHub Actions Secrets

### 4.1 SSH 三个角色

- 本地/CI 私钥
  - 用于发起 SSH 认证
- 服务器 `authorized_keys`
  - 保存允许登录的公钥
- 本地 `known_hosts`
  - 保存服务器身份指纹

### 4.2 GitHub Actions 需要的 secrets

在仓库：

- `Settings`
- `Secrets and variables`
- `Actions`

中配置以下 repository secrets：

- `STAGING_SSH_HOST`
- `STAGING_SSH_PORT`
- `STAGING_SSH_USER`
- `STAGING_SSH_PRIVATE_KEY`
- `GHCR_USERNAME`
- `GHCR_TOKEN`
- `STAGING_SITE_ADMIN_PASSWORD`

当前建议值：

- `STAGING_SSH_HOST=39.104.204.79`
- `STAGING_SSH_PORT=10022`
- `STAGING_SSH_USER=vivy`
- `GHCR_USERNAME=<你的 GitHub 用户名>`
- `GHCR_TOKEN=<具有 read:packages 的 classic PAT>`
- `STAGING_SITE_ADMIN_PASSWORD=<首次建站管理员密码>`

说明：

- `STAGING_SSH_PRIVATE_KEY` 必须保存完整私钥内容
- 不能保存 `.pub`
- 不能只保存单行公钥

### 4.3 推荐的 CI 专用密钥

推荐单独生成一把无 passphrase 的 CI 私钥，例如：

```bash
ssh-keygen -t ed25519 -N "" -C "github-actions-staging" -f ~/.ssh/github_actions_staging_ci
```

将公钥追加到服务器：

```bash
printf '\n%s\n' "$(cat ~/.ssh/github_actions_staging_ci.pub)" >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

本地验证：

```bash
ssh -i ~/.ssh/github_actions_staging_ci -p 10022 vivy@39.104.204.79
```

如果本地这条能成功，说明：

- 私钥和公钥是配对的
- 服务器端 `authorized_keys` 没问题

---

## 5. 镜像构建

### 5.1 构建方式

镜像构建不是在测试服务器上完成，而是通过 GitHub Actions：

- `Build myapp staging image`

在 CI 中构建并推送到 GHCR。

镜像内容包括：

- `frappe`
- `erpnext`
- `myapp`

`myapp` 不是从测试服务器本地目录挂载进去，而是在构建阶段从远程仓库拉取并打包。

### 5.2 镜像建议命名

- `ghcr.io/<github-owner>/myapp-erpnext:staging-latest`

后续也建议保留带日期或 commit 的 tag，便于回滚。

---

## 6. 服务器初始化

第一次在服务器上准备 staging 环境时执行：

```bash
cd /srv/frappe_docker
./deploy/staging/init-staging-server.sh
```

这个脚本会：

- 创建必要目录
- 生成 `deploy/staging/staging.env`
- 准备 staging 相关脚本的执行权限

它不会：

- 启动容器
- 建站
- 安装 app

---

## 7. staging.env 推荐配置

第一次建议先用内网模式跑通：

```env
ERPNEXT_VERSION=v16.7.3

STAGING_MODE=internal

CUSTOM_IMAGE=ghcr.io/<github-owner>/myapp-erpnext
CUSTOM_TAG=staging-latest
PULL_POLICY=always

DB_PASSWORD=<强密码>
DB_PASSWORD_SECRETS_FILE=
DB_HOST=
DB_PORT=

REDIS_CACHE=
REDIS_QUEUE=

FRAPPE_SITE_NAME_HEADER=

STAGING_BASE_URL=http://127.0.0.1:28080

HTTP_PUBLISH_PORT=28080
HTTPS_PUBLISH_PORT=28443

UPSTREAM_REAL_IP_ADDRESS=
UPSTREAM_REAL_IP_HEADER=
UPSTREAM_REAL_IP_RECURSIVE=

PROXY_READ_TIMEOUT=120
CLIENT_MAX_BODY_SIZE=50m

FRAPPE_BRANCH=version-16
FRAPPE_PATH=https://github.com/frappe/frappe
```

说明：

- `28080` / `28443` 是因为服务器上 `80`、`8080`、`8000` 已被别的服务占用
- 内网阶段不需要：
  - `LETSENCRYPT_EMAIL`
  - `SITES_RULE`
  - `NGINX_PROXY_HOSTS`

---

## 8. 首次部署顺序

当前推荐的首次部署顺序是：

1. 通过 `Lint`
2. 手动运行 `Build myapp staging image`
3. 手动运行 `Deploy staging stack`
4. 使用 `init-site.sh` 创建站点
5. 再次运行 `check-staging.sh`

为什么不是先建站？

- 因为 `new-site` 必须依赖已经启动起来的 backend / db / redis 容器
- 所以必须先把基础栈部署起来

---

## 9. 首次部署后的预期状态

第一次运行 `Deploy staging stack` 时，以下情况都属于正常：

- 镜像正常拉取
- 容器栈成功启动
- 首页返回 `404`
- `/api/method/ping` 返回 `404`
- `deploy-staging.sh` 跳过 `migrate`

这说明：

- staging 基础栈已启动
- 但站点还没创建

当前脚本已经支持这个场景，不会再把“未建站的 404”当成失败。

---

## 10. 首次建站

首次建站请按：

- `/home/rgc318/python-project/frappe_docker/deploy/staging/INIT_SITE.zh-CN.md`

执行。当前推荐优先使用独立初始化脚本，而不是把建站逻辑塞进日常 deploy。

推荐命令：

```bash
cd /srv/frappe_docker
SITE_NAME=staging.example.com \
ADMIN_PASSWORD='<admin-password>' \
./deploy/staging/init-site.sh
```

如果你们希望把首次建站也纳入 GitHub Actions，而不是手动 SSH 到服务器，可以单独运行：

- `Init staging site`

它与日常 `Deploy staging stack` 分开，避免把一次性初始化动作混进常规发布流程。

该脚本会自动完成：

- 检查 staging 容器是否已启动
- 检查站点是否已存在
- 不存在时执行 `bench new-site`
- 安装 `erpnext`
- 安装 `myapp`
- 执行 `migrate`
- 可选执行 `bench use`

底层核心动作仍然是：

1. `bench new-site <site>`
2. `bench --site <site> install-app erpnext`
3. `bench --site <site> install-app myapp`
4. `bench --site <site> migrate`

建站完成后，后续 `Deploy staging stack` 就可以自动对该站点执行 `migrate`。

---

## 11. 后续升级流程

后续每次更新的标准流程：

1. 代码更新后，通过 `Build myapp staging image` 构建新镜像
2. 通过 `Deploy staging stack` 部署到测试服务器
3. workflow 自动：
   - `git pull --ff-only origin main`
   - `docker login ghcr.io`
   - `docker compose pull`
   - `docker compose up -d`
   - 若站点存在则自动 `bench migrate`
4. 通过 `check-staging.sh` 做部署后检查

如果某次镜像发布后需要快速回退，可在服务器执行：

```bash
ROLLBACK_TAG=staging-20260409-abc123 SITE_NAME=staging.example.com ./deploy/staging/rollback-staging.sh
```

该脚本会：

- 修改 `deploy/staging/staging.env` 中的 `CUSTOM_TAG`
- 重启 staging 栈
- 若站点存在则自动 `migrate`
- 默认执行一次 `check-staging.sh`

建议在较大升级前先执行一次备份：

```bash
SITE_NAME=all ./deploy/staging/backup-staging.sh
```

默认会在服务器上生成：

- `/srv/frappe_docker/backups/staging/*.tar.gz`
- `/srv/frappe_docker/backups/staging/*.metadata`

归档内容包括：

- `sites/common_site_config.json`
- 目标站点的 `site_config.json`
- `private/backups` 下由 `bench backup --with-files` 生成的数据库和文件备份

---

## 12. 访问方式补充

### 12.1 站点已建好但直接访问 IP 返回 404

现象：

- `curl -I http://127.0.0.1:28080` 返回 `404`
- 但：

```bash
curl -I -H 'Host: staging.example.com' http://127.0.0.1:28080
```

返回 `200`

原因：

- Frappe/NGINX 默认按请求里的 `Host` 头路由站点
- 直接访问 `127.0.0.1:28080` 或 `局域网IP:28080` 时，`Host` 不是 `staging.example.com`
- 所以请求没有命中刚创建好的站点

解决：

- 在：
  - `/srv/frappe_docker/deploy/staging/staging.env`
  中设置：

```env
FRAPPE_SITE_NAME_HEADER=staging.example.com
```

- 然后重启 staging：

```bash
cd /srv/frappe_docker
./deploy/staging/stop-staging.sh
./deploy/staging/start-staging.sh
```

说明：

- 这是 `frappe_docker` 官方支持的环境变量机制
- 适合当前“内网 IP + 单站点 staging”的阶段
- 后续切正式域名后，可以再恢复按真实 Host 路由

---

## 13. 本次实际遇到的问题与解决方案

### 13.1 本地 Docker 构建出网不稳定

现象：

- `bench init` 在 Docker build 中拉取 `frappe`
- `git clone` / `uv` / `PyPI` 访问不稳定

结论：

- 本地 Docker 构建阶段代理链路不稳定

解决：

- 不在测试服务器或本机构建最终镜像
- 改用 GitHub Actions 构建并推送 GHCR 镜像

### 13.2 GitHub Actions deploy SSH 失败

现象：

- `missing server host`
- `unable to authenticate`

原因：

- `STAGING_SSH_*` secrets 未配置完整
- 或 `STAGING_SSH_PRIVATE_KEY` 内容错误
- 或端口、用户名带换行/空格

解决：

- 增加 workflow secrets 校验
- 使用无 passphrase 的 CI 专用 SSH 密钥
- 本地先用同一把私钥验证可以登录服务器

### 13.3 服务器 `git pull` 被拒绝

现象：

- `Your local changes would be overwritten by merge`

原因：

- 服务器上 `deploy/staging/*.sh` 只有 mode 变化（`100644 -> 100755`）

解决：

- 在服务器执行：

```bash
cd /srv/frappe_docker
git checkout -- deploy/staging/*.sh
git pull --ff-only origin main
```

### 13.4 staging 启动后 `No module named 'myapp'`

现象：

- `configurator` 一直重启
- 日志里出现：
  - `ModuleNotFoundError: No module named 'myapp'`

原因：

- staging 还在沿用开发态 `compose.yaml`
- 其中挂载了宿主机 `./apps/myapp`
- 服务器上并没有这份源码目录
- 结果把镜像里已经带的 `myapp` 覆盖没了

解决：

- 新增：
  - `/home/rgc318/python-project/frappe_docker/deploy/staging/compose.staging.yaml`
- staging 改为只使用镜像中的 `myapp`

### 13.5 数据库端口冲突

现象：

- `Bind for 0.0.0.0:3307 failed: port is already allocated`

原因：

- 公共 `overrides/compose.mariadb.yaml` 固定暴露宿主机 `3307`
- 服务器已有其他服务占用该端口

解决：

- 新增：
  - `/home/rgc318/python-project/frappe_docker/deploy/staging/compose.mariadb.staging.yaml`
- staging 数据库不再映射宿主机端口

### 13.6 首次部署时 `bench migrate` 报站点不存在

现象：

- `Error: 404 Not Found: staging.example.com does not exist.`

原因：

- 首次部署时基础栈已启动
- 但站点尚未执行 `new-site`
- 老逻辑默认直接 migrate

解决：

- `deploy-staging.sh` 先检查站点是否存在
- 不存在时跳过 migrate，并提示先建站

### 13.7 首次部署健康检查返回 404

现象：

- `curl: (22) The requested URL returned error: 404`

原因：

- 第一次部署时没有站点
- 首页和 `/api/method/ping` 返回 `404` 是正常现象

解决：

- `check-staging.sh` 已支持：
  - 若首页和 ping 都是 `404`
  - 则判定为“基础栈已起来，但站点未初始化”
  - 不再视为失败

---

## 14. 当前建议

如果此时：

- `Build myapp staging image` 已成功
- `Deploy staging stack` 已成功

那么下一步就应该是：

- 通过 `/home/rgc318/python-project/frappe_docker/deploy/staging/init-site.sh`
  创建第一个 staging 站点

建站完成后，再次运行：

```bash
./deploy/staging/check-staging.sh
```

以及后续所有更新都走：

- `Deploy staging stack`

即可。
