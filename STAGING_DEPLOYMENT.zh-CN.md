# myapp 正式测试环境部署文档

本文档总结 `myapp` 正式测试环境从镜像构建、服务器初始化、首次部署到首次建站的完整流程，并记录这次实际部署中遇到的问题与对应解决方案。

> 状态说明（2026-07-12）：本文是可重复执行的部署与故障处理 runbook，不用于声明外部 staging 环境此刻是否已初始化、在线或已部署到哪个版本。实时部署状态、最近验证和临时阻塞以 `docs/codex/CURRENT_HANDOFF.zh-CN.md` 为准；执行本文件中的“当前建议”前，应先核对目标服务器和对应 workflow 的实际状态。

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
   - 由 GitHub Actions 同时构建包含 `myapp` 的 ERPNext 镜像和独立 AI Orchestrator 镜像
   - 两个镜像使用同一发布标签并推送到 `GHCR`
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
- AI Orchestrator 使用独立镜像；staging Compose 同时启动 Qdrant、一次性卷初始化和专用 `ai-vector` Worker
- AI Orchestrator 源码位于独立 `rgc318/myapp-ai` 仓库；父仓库通过 `services/myapp-ai` 子模块固定构建提交，staging workflow 必须递归检出子模块，并把 AI commit 写入 OCI 镜像元数据
- Backend/Worker 只接收 Gateway 所需 AI 配置，LiteLLM/Langfuse Provider 密钥只进入 Orchestrator
- 部署前 `validate-staging-env.sh` 对镜像、Provider、内部 Token、向量设置和 Langfuse 配置失败关闭
- `myapp` 的 Python 依赖由 `apps/myapp/pyproject.toml` 管理，镜像构建阶段会刷新 `apps/frappe` 与 `apps/myapp` 的 editable 安装并执行 `pip check`
- `rgc-backend-kit` 已发布到公共 PyPI，staging 镜像会通过 `myapp` 依赖自动安装，不需要在服务器或容器中手动安装 JWT 工具包
- 第一次部署时允许“容器已起来但站点尚未初始化”

### 1.1 分支与发布流程

当前建议采用三层分支模型：

- `main`
  - 稳定发布分支
  - 只合入已经验证过、可以部署或打包的版本
  - 后端 staging 部署、移动端 release APK 等正式发布动作以 `main` 为基准
- `develop`
  - 日常集成测试分支
  - 功能分支完成后先合入 `develop` 做联调和检查
  - 默认只跑检查类 workflow，不自动发布 APK，也不自动部署服务器
- `feature/*` / `fix/*`
  - 单个功能或修复分支
  - 从 `develop` 拉出，完成后合回 `develop`
  - 待一批改动验证稳定后，再由 `develop` 合入 `main`

推荐流转顺序：

```text
feature/* -> develop -> main -> build/deploy/release
```

操作约定：

- 不建议日常直接推送开发中代码到 `main`
- 需要正式测试包或 staging 镜像时，再把确认过的 `develop` 合入 `main`
- 如果只是临时验证后端镜像或部署脚本，优先使用 `workflow_dispatch` 手动触发
- `Build myapp staging image` 的 `myapp_ref` 应优先选择已验证的 `main`、tag 或明确 commit；只有调试时才建议填 `develop`
- AI 镜像默认从 workflow 所在父仓库提交固定的 `services/myapp-ai` gitlink 构建。需要升级 AI 时，先在 AI 仓库完成验证和推送，再更新父仓库子模块指针；不要在 workflow 中隐式追踪远程分支最新提交
- `Build myapp staging image` 的 `frappe_ref` 与 `erpnext_ref` 默认固定为 `v16.18.3`，不要在常规 staging 发布中使用浮动 `version-16`
- `image_tag` 建议使用唯一 tag，例如 `staging-20260526-bff502e`，不要只依赖 `staging-latest` 判断部署内容
- `Deploy staging stack` 与 `Init staging site` 会让服务器上的 `frappe_docker` 切换到当前 workflow 运行所选择的分支；例如在 Actions 页面选择 `develop` 运行，就会部署 `frappe_docker@develop` 的部署脚本

---

## 2. 关键文件

### 部署与构建

- `/home/rgc318/python-project/frappe_docker/.github/workflows/lint.yml`
- `/home/rgc318/python-project/frappe_docker/.github/workflows/build_myapp_staging_image.yml`
- `/home/rgc318/python-project/frappe_docker/.github/workflows/deploy_staging.yml`
- `/home/rgc318/python-project/frappe_docker/.github/workflows/init_staging_site.yml`
- `/home/rgc318/python-project/frappe_docker/images/custom/myapp-staging/Containerfile`

`images/custom/myapp-staging/Containerfile` 在 bench 初始化完成后会显式执行：

```bash
./env/bin/pip install --force-reinstall \
  -e apps/frappe \
  -e apps/erpnext \
  -e apps/myapp
./env/bin/python - <<'PY'
import frappe
import erpnext
import rgc_backend_kit
import xlsxwriter
import myapp
PY
./env/bin/pip check
```

镜像实际构建时会在同一次 `pip install` 中安装 Frappe、ERPNext 与 `myapp`。这样 resolver 会同时看到宿主框架约束与业务 app 依赖，避免 PyJWT 这类共享依赖被分段安装过程来回覆盖。这一步会读取 Frappe、ERPNext 与 `myapp` 的 `pyproject.toml`，强制刷新 app 的 editable 元数据，并通过 import smoke test 验证 `XlsxWriter`、`rgc-backend-kit>=0.1.1,<0.2.0` 等运行依赖。`XlsxWriter` 与 `PyJWT` 由固定的 Frappe `v16.18.3` 自身声明和约束，不在 `myapp` 或 staging 额外 requirements 中重复维护。workflow 还会传入 `CACHE_BUST` 构建参数，避免 `myapp_ref=develop` 这类分支引用因为 Docker 缓存而没有重新拉取。后续新增 Python 包时，应优先写入对应 app 的 `pyproject.toml`。

staging 镜像部署不再挂载 `/home/frappe/frappe-bench/env` 持久卷；虚拟环境属于镜像内容，只持久化 `sites` 数据。这样每次切换镜像时都会使用镜像内经过验证的 Python 依赖，避免旧 `bench-env-vol` 覆盖新镜像中的依赖。

### staging 运行文件

- `/home/rgc318/python-project/frappe_docker/deploy/staging/compose.staging.yaml`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/compose.mariadb.staging.yaml`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/staging.env.example`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/init-staging-server.sh`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/start-staging.sh`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/deploy-staging.sh`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/rollback-staging.sh`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/backup-staging.sh`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/restore-staging.sh`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/check-staging.sh`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/init-site.sh`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/INIT_SITE.zh-CN.md`
- `/home/rgc318/python-project/frappe_docker/deploy/staging/DATA_MIGRATION.zh-CN.md`

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

手动触发时建议显式确认这些输入：

- `Use workflow from`: 与部署脚本版本一致，例如 `develop`
- `myapp_ref`: 要烘焙进镜像的 `myapp` 分支、tag 或 commit
- `frappe_ref`: 默认 `v16.18.3`
- `erpnext_ref`: 默认 `v16.18.3`
- `image_tag`: 唯一 tag，例如 `staging-20260526-bff502e`

`myapp` 不是从测试服务器本地目录挂载进去，而是在构建阶段从远程仓库拉取并打包。

### 5.2 镜像建议命名

- `ghcr.io/<github-owner>/myapp-erpnext:staging-latest`

后续也建议保留带日期或 commit 的 tag，便于回滚。

### 5.3 本地构建代理边界

正式发布仍建议由 GitHub Actions 构建。需要在 Linux 本机执行
`deploy/staging/build-staging-image.sh` 时，脚本支持以下仅作用于 Docker build 的覆盖变量：

- `BUILD_HTTP_PROXY`
- `BUILD_HTTPS_PROXY`
- `BUILD_NO_PROXY`
- `BUILD_NETWORK`，默认 `default`

宿主代理若只监听 `127.0.0.1`，容器默认网络不能访问宿主回环地址。可显式使用：

```bash
BUILD_NETWORK=host \
BUILD_HTTP_PROXY=http://127.0.0.1:10808 \
BUILD_HTTPS_PROXY=http://127.0.0.1:10808 \
ENV_FILE=deploy/staging/staging.env \
  ./deploy/staging/build-staging-image.sh
```

若继承的宿主代理不适用于 Docker Builder，可用空值明确关闭：

```bash
BUILD_HTTP_PROXY= BUILD_HTTPS_PROXY= \
ENV_FILE=deploy/staging/staging.env \
  ./deploy/staging/build-staging-image.sh
```

代理凭据不得写入 Git 跟踪文件或构建日志。

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

---

## 8. staging CORS 配置

如果有以下来源要直接从浏览器访问 staging 后端：

- Cloudflare Pages 预览域名
- 自定义 Web 预览域名
- 本地 `localhost` 调试
- 公网 `IP:port` 形式的预览地址

则必须把这些完整 origin 加入 Frappe 的 `allow_cors`。

当前 staging 实际读取的配置文件是：

- Docker volume 内的 `sites/common_site_config.json`
- 容器内路径：`/home/frappe/frappe-bench/sites/common_site_config.json`

本次联调里实际加入过的值包括：

- `https://myapp-mobile-staging.pages.dev`
- `https://mobile-staging.rgcdev.top`
- `http://localhost:8081`
- `http://39.104.204.79:18089`

### 8.1 修改建议

最稳的做法是从运行中的 backend 容器内修改：

```bash
docker exec staging-backend-1 python3 -c '...'
```

原因：

- 宿主机上的 Docker volume 路径可能没有当前 SSH 用户写权限
- 直接改容器内的 `common_site_config.json` 更贴近 Frappe 实际读取位置

### 8.2 修改后必须重启的服务

修改 `allow_cors` 后，至少重启：

- `staging-backend-1`
- `staging-frontend-1`
- `staging-websocket-1`

例如：

```bash
cd /srv/frappe_docker
docker compose -p staging restart backend frontend websocket
```

### 8.3 如何验证是否生效

推荐直接带 `Origin` 做预检请求：

```bash
curl -sS -X OPTIONS -D - -o /dev/null \
  -H "Origin: http://39.104.204.79:18089" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: content-type" \
  https://erpnext.rgcdev.top/api/method/login
```

如果生效，响应头里应包含：

- `Access-Control-Allow-Origin: <对应 origin>`
- `Access-Control-Allow-Credentials: true`

### 8.4 经验说明

- CORS 放开后，只代表浏览器可以发请求
- 如果前端与后端仍然是跨站关系，登录后的 Cookie / Session 仍可能不稳定
- 因此对长期使用的 Web 预览，依然更推荐同主域名访问，而不是公网 `IP:port`

```env
ERPNEXT_VERSION=v16.18.3

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

FRAPPE_BRANCH=v16.18.3
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
2. 通过 `Deploy staging stack` 部署到测试服务器，`image_tag` 使用上一步构建出的同一个唯一 tag
3. workflow 自动：
   - 切换服务器 `/srv/frappe_docker` 到当前 workflow 选择的分支
   - `git pull --ff-only origin <当前分支>`
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

如果要把本地开发站点的数据恢复到远程 staging，推荐使用：

```bash
SITE_NAME=staging.example.com \
RESTORE_DIR=/srv/frappe_docker/tmp/restore-localhost-20260409 \
./deploy/staging/restore-staging.sh
```

该脚本会：

- 先对当前 staging 站点做一份安全备份
- 再恢复指定目录中的数据库、公有文件和私有文件
- 自动执行 `migrate`
- 自动清缓存并关闭维护模式

更完整的本地到 staging 数据迁移说明见：

- `/home/rgc318/python-project/frappe_docker/deploy/staging/DATA_MIGRATION.zh-CN.md`

---

## 12. 本地数据迁移到 Staging

当前推荐的数据迁移路径是：

1. 在本地把站点整理成目标状态
2. 在本地执行 `bench backup --with-files`
3. 把备份文件上传到：
   - `/srv/frappe_docker/tmp/<restore-dir>`
4. 在服务器上运行：
   - `./deploy/staging/restore-staging.sh`
5. 执行：
   - `./deploy/staging/check-staging.sh`

这样迁过去的通常包括：

- 用户账号
- 权限配置
- ERPNext 和 `myapp` 的业务数据
- 公有/私有附件文件
- 大部分站点级配置

注意：

- 数据是跟着 `site` 走的，不是跟着 `app` 走的
- 恢复会覆盖目标站点当前数据库和文件
- 远端 `staging.env`、镜像 tag、部署骨架仍按远端环境维护
- 建议只使用“清理之后重新生成”的最新本地备份

---

## 13. 访问方式补充

### 13.1 站点已建好但直接访问 IP 返回 404

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

## 14. 本次实际遇到的问题与解决方案

### 14.1 本地 Docker 构建出网不稳定

现象：

- `bench init` 在 Docker build 中拉取 `frappe`
- `git clone` / `uv` / `PyPI` 访问不稳定

结论：

- 本地 Docker 构建阶段代理链路不稳定

解决：

- 不在测试服务器或本机构建最终镜像
- 改用 GitHub Actions 构建并推送 GHCR 镜像

### 14.2 GitHub Actions deploy SSH 失败

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

### 14.3 服务器 `git pull` 被拒绝

现象：

- `Your local changes would be overwritten by merge`

原因：

- 服务器上 `deploy/staging/*.sh` 只有 mode 变化（`100644 -> 100755`）

解决：

- 在服务器执行：

```bash
cd /srv/frappe_docker
git checkout -- deploy/staging/*.sh
git pull --ff-only origin <当前部署分支>
```

### 14.4 staging 启动后 `No module named 'myapp'`

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

### 14.5 数据库端口冲突

现象：

- `Bind for 0.0.0.0:3307 failed: port is already allocated`

原因：

- 公共 `overrides/compose.mariadb.yaml` 固定暴露宿主机 `3307`
- 服务器已有其他服务占用该端口

解决：

- 新增：
  - `/home/rgc318/python-project/frappe_docker/deploy/staging/compose.mariadb.staging.yaml`
- staging 数据库不再映射宿主机端口

### 14.6 首次部署时 `bench migrate` 报站点不存在

现象：

- `Error: 404 Not Found: staging.example.com does not exist.`

原因：

- 首次部署时基础栈已启动
- 但站点尚未执行 `new-site`
- 老逻辑默认直接 migrate

解决：

- `deploy-staging.sh` 先检查站点是否存在
- 不存在时跳过 migrate，并提示先建站

### 14.7 首次部署健康检查返回 404

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

### 14.8 新增脚本或文档后 `Lint` 因 formatter 失败

现象：

- GitHub Actions 中：
  - `prettier` 失败
  - `shfmt` 失败
- 日志中出现：
  - `files were modified by this hook`

原因：

- 这不是业务逻辑错误，而是格式未完全符合仓库当前 formatter 规则
- 仓库根目录使用：
  - `/home/rgc318/python-project/frappe_docker/.pre-commit-config.yaml`
    中定义的规则
- 其中：
  - `prettier` 会处理 Markdown / YAML / JSON
  - `shfmt` 会处理 `deploy/staging/*.sh`
  - `shellcheck` 会检查 shell 脚本写法
- 只要这些工具还能自动改文件，CI 就会直接失败

这次实际踩到的点包括：

- `STAGING_DEPLOYMENT.zh-CN.md`
  - 被 `prettier` 调整列表缩进
- `deploy/staging/backup-staging.sh`
  - 被 `shellcheck` 指出字符串写法问题
  - 被 `shfmt` 调整 heredoc 和重定向排版
- `deploy/staging/rollback-staging.sh`
  - 被 `shfmt` 调整重定向空格

解决：

- 不要只看“代码能不能运行”
- 还要确保文件经过和 CI 一致的 formatter 输出

经验建议：

1. 新增或修改 `deploy/staging/*.sh` 后
   - 优先关注：
     - `shellcheck`
     - `shfmt`
2. 修改大文档后
   - 优先关注：
     - `prettier`
3. 当日志里只看到：
   - `files were modified by this hook`
     时，说明不是“工具坏了”，而是 formatter 还想继续改文件
4. 如果本地缺少 `shfmt` 等环境
   - 可以先以 GitHub Actions 最新 run 为准
   - 把 formatter 改动再收回仓库

判断技巧：

- `prettier` 日志中，只有未显示 `(unchanged)` 的文件，才是它真正改过的文件
- `shfmt` 虽然不总是把文件名打印得很明显，但它只会作用于：
  - `deploy/staging/*.sh`
  - `start-dev.sh`
  - `start-prod.sh`
  - `stop.sh`
  - `install_x11_deps.sh`

### 14.9 第一次恢复错用了清理前的旧备份

现象：

- staging 恢复完成
- 健康检查通过
- 但事务数据数量仍然很大

原因：

- 使用的是本地清理动作之前生成的旧备份
- 备份文件时间点早于清理时间点

解决：

- 在本地数据清理完成后重新执行一次：

```bash
bench --site localhost backup --with-files
```

- 只恢复最新的清理后备份
- 恢复前可先核对关键表数量，确认本地事务数据已经为 `0`

### 14.10 恢复后短暂返回 503

现象：

- 容器正常
- 首页返回 `503`

原因：

- 站点恢复后仍处于 maintenance mode

解决：

- `restore-staging.sh` 在恢复末尾自动执行：
  - `bench --site <site> set-maintenance-mode off`
- 若手动恢复，也应在恢复完成后显式关闭维护模式

### 14.11 代理恢复后不要整体回退构建加固

现象：

- 本地构建最初失败时，宿主代理确实已经失效。
- 代理恢复后，容易把同一轮构建修改全部视为临时绕过。

结论：

- 代理恢复只消除了一个外部故障，不代表构建链路中的其他问题不存在。
- 恢复代理后的完整构建仍实际遇到 Git/GnuTLS 瞬时中断、Frappe v16.18.3 资产构建期 Redis 依赖，以及逐 app 安装导致的 Python 依赖版本漂移。
- 因此保留显式代理覆盖/清空、有限重试、BuildKit cache、分阶段资产构建、builder 临时 Redis、uv 联合解析和 import/`pip check` 门禁。
- 上述机制默认不要求工作站代理；CI 可继续在不设置 `BUILD_*_PROXY` 的情况下正常构建。
- 若未来升级 Frappe 后准备移除临时 Redis，必须先通过完整无缓存镜像构建，并确认最终 runtime 镜像仍不包含 `redis-server`。

长期诊断与回退准则见：

- `docs/codex/KNOWN_ISSUES.zh-CN.md` 的“代理恢复后是否回退 staging 镜像构建加固”

---

## 15. 当前建议

以下步骤描述“镜像构建和栈部署已成功、站点尚未初始化”这一条件下的操作顺序，不代表当前外部环境必然处于该状态。

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
