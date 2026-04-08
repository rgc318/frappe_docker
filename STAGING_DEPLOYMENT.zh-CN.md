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
- `myapp` 推荐通过 `bench get-app` 接入当前 bench
- 正式测试环境不要直接使用当前仓库里偏开发态的 `compose.yaml`

说明：

- 当前根目录的 `compose.yaml` 已带有开发特征，例如本地源码挂载、调试端口、`bench serve`
- 这些配置不适合直接用于正式测试环境
- 建议单独生成测试环境专用 compose 文件

---

## 2. 推荐部署方式

当前阶段推荐采用：

- 服务器上拉取 `frappe_docker`
- 使用 `bench get-app` 拉取 `myapp`
- 新建独立 site
- 在该 site 上安装 `erpnext` 与 `myapp`

这是当前最适合本项目的方案，因为：

- 你们的 `myapp` 当前是独立 git 仓库
- 它不是 `frappe_docker` 根仓库的标准子模块
- 因此不能假设测试机上 `git clone frappe_docker` 后会天然带有完整 `myapp`

后续如果要进一步生产化，可再升级为：

- 构建包含 `myapp` 的自定义镜像
- 测试环境只拉镜像，不在部署时再拉 git

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
- 后续更新测试环境也应通过 git pull / 切 tag / 切分支完成

---

## 5. 生成测试环境专用 env 文件

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

## 6. 推荐 compose 组合

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

## 7. 启动基础容器栈

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

## 8. 在 bench 中拉取 myapp

这是关键步骤。

不要新建新的 app，也不要手工拼一个新 app。

直接把现有 `myapp` 拉进当前 bench：

```bash
docker compose \
  --project-name myapp-staging \
  -f /opt/myapp-staging/generated/staging.compose.yaml \
  exec backend \
  bash -lc "bench get-app git@github.com:rgc318/myapp.git"
```

如果服务器没有配置 SSH key，也可以使用 HTTPS 仓库地址：

```bash
bench get-app https://github.com/rgc318/myapp.git
```

说明：

- 推荐用 `bench get-app`
- 不推荐手工 `git clone` 到 `apps/`
- `bench get-app` 更符合 Frappe bench 标准流程

拉取完成后确认：

```bash
docker compose \
  --project-name myapp-staging \
  -f /opt/myapp-staging/generated/staging.compose.yaml \
  exec backend \
  bash -lc "ls -la apps"
```

应能看到：

- `frappe`
- `erpnext`
- `myapp`

---

## 9. 新建正式测试站点

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

## 10. 安装 ERPNext 与 myapp

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

---

## 11. 配置公网访问

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

## 12. 商品图片、附件、PDF 的公网访问策略

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

## 13. 测试环境初始化建议

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

## 14. 升级流程建议

正式测试环境更新建议流程：

1. 先在本地完成代码提交并推送远程仓库
2. 测试机上 `git pull`
3. 如果 `myapp` 仓库有更新：
   - 在 bench 中更新 app 代码
4. 执行：
   - `bench --site staging.example.com migrate`
5. 重启相关容器
6. 做冒烟测试

如果后续采用自定义镜像，则升级流程可进一步改成：

- 构建镜像
- 推送镜像
- 测试机拉新镜像
- 重启容器
- 执行 migrate

---

## 15. 备份建议

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

## 16. 常见问题

### Q1：需要新建新的 app 吗？

不需要。

当前只需要：

- 使用现有 `myapp`
- 将它接入当前 bench
- 然后安装到新站点

### Q2：需要新建新站点吗？

需要，且强烈建议需要。

正式测试环境应使用独立 site，不应直接复用开发站点。

### Q3：`myapp` 用 `git clone` 还是 `bench get-app`？

推荐：

- `bench get-app`

因为它更符合 Frappe bench 管理 app 的标准方式。

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

