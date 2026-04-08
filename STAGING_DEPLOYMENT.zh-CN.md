# myapp 正式测试环境部署文档

本文档用于指导在独立测试服务器上部署 `myapp` 的正式测试环境。

适用范围：

- 当前仓库根目录为 `frappe_docker`
- 业务应用为 `apps/myapp`
- 目标是部署一个接近生产、可公网访问、可长期复用的测试环境

不适用范围：

- `pwd.yml` 一次性 demo 环境
- 本地开发容器
- 直接复用当前开发机站点

---

## 1. 目标与原则

正式测试环境的目标是：

- 使用独立服务器或独立虚拟机
- 使用独立站点，不复用开发站点
- 使用独立数据库、Redis、sites 数据卷
- 支持公网访问
- 支持后续反复升级、迁移、备份和恢复

当前项目的部署原则：

- 部署根目录仍然以 `frappe_docker` 为准
- `myapp` 不需要新建新的 app，直接安装现有 `myapp`
- 站点需要新建，例如：
  - `staging.example.com`
- `myapp` 推荐通过自定义镜像接入当前 bench
- 正式测试环境不要直接使用当前仓库里偏开发态的 `compose.yaml`

说明：

- 当前根目录的 `compose.yaml` 已带有开发特征，例如本地源码挂载、调试端口、`bench serve`
- 这些配置不适合直接用于正式测试环境
- 建议单独生成测试环境专用 compose 文件

---

## 2. 推荐部署方式

当前阶段推荐采用：

- 服务器上拉取 `frappe_docker`
- 使用 GitHub Actions 构建并推送“已包含 `myapp` 的自定义镜像”
- 测试服务器通过 `staging.env` 引用该镜像
- 新建独立 site
- 在该 site 上安装 `erpnext` 与 `myapp`

这是当前最适合本项目的方案，因为：

- 你们的 `myapp` 当前是独立 git 仓库
- 它不是 `frappe_docker` 根仓库的标准子模块
- 因此不能假设测试机上 `git clone frappe_docker` 后会天然带有完整 `myapp`
- 正式测试环境不应继续映射业务源码目录

镜像中的 `myapp` 获取方式：

- 由 GitHub Actions 在构建镜像时从远程仓库拉取
- 测试服务器本身不需要保存 `apps/myapp` 源码目录

---

## 3. 服务器准备

建议准备：

- Linux 服务器，推荐 Ubuntu LTS
- Docker
- Docker Compose v2
- git
- 公网 IP
- 一个测试域名，例如：
  - `staging.example.com`

建议目录：

```text
/opt/myapp-staging/
  ├── frappe_docker/
  ├── env/
  └── generated/
```

推荐用途：

- `frappe_docker/`
  - 存放部署代码仓库
- `env/`
  - 存放测试环境专用 `.env`
- `generated/`
  - 存放通过 `docker compose config` 生成的最终 compose 文件

---

## 4. 拉取部署仓库

在测试服务器上执行：

```bash
mkdir -p /opt/myapp-staging
cd /opt/myapp-staging

git clone <你的 frappe_docker 仓库地址> frappe_docker
cd frappe_docker
```

说明：

- 这里拉取的是部署骨架
- 不是直接依赖开发机目录拷贝
- 后续更新测试环境主要通过“切换镜像 tag + 重新部署”完成

---

## 5. SSH 准备

正式测试环境建议通过 SSH 登录服务器进行部署和维护。

需要区分三类 SSH 文件：

- 本地 `~/.ssh/known_hosts`
  - 保存“服务器身份公钥”
  - 用于校验你连接的是不是那台目标服务器
- 本地私钥，例如：
  - `~/.ssh/id_ed25519`
  - 用于你本机发起身份认证
- 服务器端 `~/.ssh/authorized_keys`
  - 保存“允许登录该服务器用户的公钥”

规则：

- 访问方需要有自己的一套公钥/私钥
- 被访问服务器需要把访问方的公钥保存到：
  - `~/.ssh/authorized_keys`
- `known_hosts` 只保存在访问方本地，不需要传给服务器

如果服务器有多台开发机或 CI 需要登录：

- 仍然只需要一个 `authorized_keys` 文件
- 每个访问来源追加一行公钥即可

例如目标服务器用户为 `vivy` 时：

- 服务器端公钥位置：
  - `/home/vivy/.ssh/authorized_keys`

如果首次连接时遇到 host key 校验问题，可在本地执行：

```bash
mkdir -p ~/.ssh
ssh-keyscan -p 10022 39.104.204.79 >> ~/.ssh/known_hosts
```

---

## 6. 镜像准备

推荐方式：

- 在 GitHub Actions 中构建 staging 镜像
- 推送到 GHCR
- 测试服务器只负责拉取镜像

工作流位置：

- `/home/rgc318/python-project/frappe_docker/.github/workflows/build_myapp_staging_image.yml`
- `/home/rgc318/python-project/frappe_docker/.github/workflows/deploy_staging.yml`

镜像建议形态：

- `ghcr.io/<github-owner>/myapp-erpnext:staging-latest`
- 以及按日期或 commit 保留唯一 tag

说明：

- `myapp` 不需要放进测试服务器源码目录
- `myapp` 会在 CI 构建镜像时被远程拉取并烘焙进镜像
- 测试服务器 compose 只需要引用该镜像
- 推荐把测试服务器部署目录固定在：
  - `/srv/frappe_docker`

GitHub Actions SSH 部署建议准备以下 secrets：

- `STAGING_SSH_HOST`
- `STAGING_SSH_PORT`
- `STAGING_SSH_USER`
- `STAGING_SSH_PRIVATE_KEY`
- `GHCR_USERNAME`
- `GHCR_TOKEN`

---

## 7. 生成测试环境专用 env 文件

创建测试环境 env 文件，例如：

```bash
mkdir -p /opt/myapp-staging/env
cp /opt/myapp-staging/frappe_docker/example.env /opt/myapp-staging/env/staging.env
```

至少修改以下项：

```env
ERPNEXT_VERSION=v16.7.3

DB_PASSWORD=<强密码>
DB_HOST=
DB_PORT=

LETSENCRYPT_EMAIL=ops@example.com

SITES_RULE=Host(`staging.example.com`)

HTTP_PUBLISH_PORT=80
HTTPS_PUBLISH_PORT=443
```

如果使用内置 MariaDB 与 Redis：

- `DB_HOST` 保持空
- `DB_PORT` 保持空
- Redis 配置保持空

如果使用外部数据库：

- 填写 `DB_HOST`
- 填写 `DB_PORT`
- 确保数据库连通

---

## 8. 推荐 compose 组合

正式测试环境推荐使用以下组合：

- 基础：
  - `compose.yaml`
- 数据库：
  - `overrides/compose.mariadb.yaml`
- Redis：
  - `overrides/compose.redis.yaml`
- 代理：
  - 对内测试：`overrides/compose.noproxy.yaml`
  - 公网 HTTPS：`overrides/compose.https.yaml`

如果目标是正式测试环境并需要公网访问，建议直接使用 HTTPS。

生成最终 compose：

```bash
mkdir -p /opt/myapp-staging/generated

docker compose \
  --env-file /opt/myapp-staging/env/staging.env \
  -f /opt/myapp-staging/frappe_docker/compose.yaml \
  -f /opt/myapp-staging/frappe_docker/overrides/compose.mariadb.yaml \
  -f /opt/myapp-staging/frappe_docker/overrides/compose.redis.yaml \
  -f /opt/myapp-staging/frappe_docker/overrides/compose.https.yaml \
  config > /opt/myapp-staging/generated/staging.compose.yaml
```

说明：

- 这里建议先生成最终 compose，而不是每次临时手敲很多 `-f`
- 生成后的文件更适合审查、备份和重复部署

---

## 9. 启动基础容器栈

```bash
docker compose \
  --project-name myapp-staging \
  -f /opt/myapp-staging/generated/staging.compose.yaml \
  up -d
```

先确认容器启动正常：

```bash
docker compose \
  --project-name myapp-staging \
  -f /opt/myapp-staging/generated/staging.compose.yaml \
  ps
```

重点检查：

- backend
- frontend
- websocket
- queue-short
- queue-long
- scheduler
- mariadb
- redis-cache
- redis-queue

---

## 10. 新建正式测试站点

正式测试环境应新建独立站点，不复用本地开发站点。

推荐站点名直接和域名一致，例如：

- `staging.example.com`

执行：

```bash
docker compose \
  --project-name myapp-staging \
  -f /opt/myapp-staging/generated/staging.compose.yaml \
  exec backend \
  bash -lc "bench new-site staging.example.com --admin-password <管理员密码> --db-root-password <数据库 root 密码>"
```

说明：

- 如果使用容器内 MariaDB，`--db-root-password` 一般就是你设置的 `DB_PASSWORD`
- 也可以按你们安全策略单独设置

---

## 11. 安装 ERPNext 与 myapp

新站点创建后，安装应用：

```bash
docker compose \
  --project-name myapp-staging \
  -f /opt/myapp-staging/generated/staging.compose.yaml \
  exec backend \
  bash -lc "bench --site staging.example.com install-app erpnext"
```

然后安装 `myapp`：

```bash
docker compose \
  --project-name myapp-staging \
  -f /opt/myapp-staging/generated/staging.compose.yaml \
  exec backend \
  bash -lc "bench --site staging.example.com install-app myapp"
```

最后执行迁移：

```bash
docker compose \
  --project-name myapp-staging \
  -f /opt/myapp-staging/generated/staging.compose.yaml \
  exec backend \
  bash -lc "bench --site staging.example.com migrate"
```

说明：

- 当前镜像已包含 `myapp` 时，这一步不再需要执行 `bench get-app`
- 测试服务器本身不保存 `apps/myapp` 源码目录
- 只需要让 site 安装该 app 即可

---

## 12. 配置公网访问

要让公网可访问服务和文件，关键是：

- 测试域名解析到服务器公网 IP
- 反向代理正确工作
- site 名与访问域名尽量一致

推荐：

- 域名：`staging.example.com`
- site 名：`staging.example.com`

这样可以保证：

- API 访问稳定
- `/files/...` 公有文件链接稳定
- 多站点路由最自然

如果使用 `compose.https.yaml`：

- 确保 DNS 已解析到公网 IP
- 确保 80/443 端口开放
- 确保 `LETSENCRYPT_EMAIL` 已配置

---

## 13. 商品图片、附件、PDF 的公网访问策略

### 商品图片

当前商品图片走 Frappe `File` 公有文件路径。

典型 URL：

```text
https://staging.example.com/files/xxx.jpg
```

只要站点公网访问正常，这类文件通常即可直接访问。

### 私有 PDF

当前归档 PDF 属于私有文件。

典型路径：

```text
/private/files/xxx.pdf
```

这类文件不应直接当成裸公网静态文件使用。

正确方式：

- 通过已登录态访问
- 或通过业务接口下载

### 当前项目策略

- 商品图片：
  - 公有访问
  - 适合列表、详情、移动端直接展示
- 归档 PDF：
  - 私有访问
  - 适合鉴权下载和留档

---

## 14. 测试环境初始化建议

建议部署完成后至少执行以下初始化：

1. 创建管理员测试账号
2. 创建正式测试公司
3. 创建正式测试仓库
4. 安装或导入标准 UOM
5. 导入必要客户、供应商、商品测试数据
6. 配置移动端后端地址为公网域名

例如移动端应配置为：

```text
https://staging.example.com
```

不要继续使用：

- `localhost`
- `127.0.0.1`
- 内网开发 IP

---

## 15. 升级流程建议

正式测试环境更新建议流程：

1. 先在本地完成代码提交并推送远程仓库
2. 通过 GitHub Actions 构建并推送新镜像
3. 测试机更新 `CUSTOM_TAG` 或继续使用 `staging-latest`
4. 执行：
   - `SITE_NAME=staging.example.com ./deploy/staging/deploy-staging.sh`
5. 做冒烟测试

也就是说，正式测试环境的升级主线是：

- 构建镜像
- 推送镜像
- 测试机拉新镜像
- 重启容器
- 执行 migrate

推荐脚本：

- 初始化服务器：
  - `./deploy/staging/init-staging-server.sh`
- 启动：
  - `./deploy/staging/start-staging.sh`
- 升级：
  - `SITE_NAME=staging.example.com ./deploy/staging/deploy-staging.sh`
- 检查：
  - `./deploy/staging/check-staging.sh`

---

## 16. 备份建议

正式测试环境也应具备基础备份能力。

至少备份：

- `sites` 卷
- 数据库
- 私有文件
- 公有文件

官方文档中推荐可用：

- `bench --site all backup`

你们当前建议至少保留：

- 每日备份
- 最近 7 天

如需定时执行，可在宿主机使用 cron 调度。

---

## 17. 常见问题

### Q1：需要新建新的 app 吗？

不需要。

当前只需要：

- 使用现有 `myapp`
- 将它接入当前 bench
- 然后安装到新站点

### Q2：需要新建新站点吗？

需要，且强烈建议需要。

正式测试环境应使用独立 site，不应直接复用开发站点。

### Q3：测试服务器需要 `git clone` 或 `bench get-app myapp` 吗？

正式测试环境当前推荐：

- 不需要

因为：

- `myapp` 已经通过自定义镜像烘焙进 bench
- 测试服务器本身只需要拉镜像，不需要再拉业务源码

补充：

- 在镜像构建阶段，`myapp` 仍然会从远程仓库拉取
- 只是这一步发生在 GitHub Actions，不发生在测试服务器

### Q4：部署根目录是不是 `frappe_docker`？

是。

因为：

- `compose.yaml`
- `overrides/`
- `images/`
- `resources/`

这些都在 `frappe_docker` 根目录。

### Q5：当前仓库里的开发态 compose 可以直接用于正式测试环境吗？

不建议。

因为当前 `compose.yaml` 已带开发特征，应先生成测试环境专用 compose。

### Q6：测试服务器是否需要映射 `apps/myapp` 源码目录？

不需要。

正式测试环境更推荐：

- 代码进镜像
- 数据进 volume
- 服务器不挂业务源码目录

---

## 17. 推荐的最小完整流程

```bash
# 1. 拉取部署仓库
git clone <frappe_docker 仓库地址> /opt/myapp-staging/frappe_docker

# 2. 准备 env
cp /opt/myapp-staging/frappe_docker/example.env /opt/myapp-staging/env/staging.env

# 3. 生成 compose
docker compose \
  --env-file /opt/myapp-staging/env/staging.env \
  -f /opt/myapp-staging/frappe_docker/compose.yaml \
  -f /opt/myapp-staging/frappe_docker/overrides/compose.mariadb.yaml \
  -f /opt/myapp-staging/frappe_docker/overrides/compose.redis.yaml \
  -f /opt/myapp-staging/frappe_docker/overrides/compose.https.yaml \
  config > /opt/myapp-staging/generated/staging.compose.yaml

# 4. 启动容器
docker compose \
  --project-name myapp-staging \
  -f /opt/myapp-staging/generated/staging.compose.yaml \
  up -d

# 5. 拉取业务 app
docker compose \
  --project-name myapp-staging \
  -f /opt/myapp-staging/generated/staging.compose.yaml \
  exec backend \
  bash -lc "bench get-app git@github.com:rgc318/myapp.git"

# 6. 新建站点
docker compose \
  --project-name myapp-staging \
  -f /opt/myapp-staging/generated/staging.compose.yaml \
  exec backend \
  bash -lc "bench new-site staging.example.com --admin-password <管理员密码> --db-root-password <数据库 root 密码>"

# 7. 安装应用
docker compose \
  --project-name myapp-staging \
  -f /opt/myapp-staging/generated/staging.compose.yaml \
  exec backend \
  bash -lc "bench --site staging.example.com install-app erpnext"

docker compose \
  --project-name myapp-staging \
  -f /opt/myapp-staging/generated/staging.compose.yaml \
  exec backend \
  bash -lc "bench --site staging.example.com install-app myapp"

# 8. migrate
docker compose \
  --project-name myapp-staging \
  -f /opt/myapp-staging/generated/staging.compose.yaml \
  exec backend \
  bash -lc "bench --site staging.example.com migrate"
```

---

## 18. 后续建议

当前完成正式测试环境后，建议下一步继续做：

1. 生成测试环境专用 compose 文件，纳入版本管理
2. 为 `myapp` 增加更正式的镜像化部署方案
3. 增加自动备份
4. 增加测试环境初始化脚本
5. 增加一份脱敏测试数据恢复流程
