# Staging 站点初始化

本文档描述正式测试环境第一次建站时的推荐流程。当前推荐优先使用 `init-site.sh`，仅在需要排障时手动执行分步骤命令。

## 前提

- 宿主机目录已经准备好 `frappe_docker`
- 已复制：
  - `deploy/staging/staging.env.example` -> `deploy/staging/staging.env`
- staging 容器已经启动：
  - `./deploy/staging/start-staging.sh`
- 当前镜像已经包含：
  - `frappe`
  - `erpnext`
  - `myapp`

## 1. 推荐方式：使用初始化脚本

在宿主机执行：

```bash
SITE_NAME=staging.example.com \
ADMIN_PASSWORD='<admin-password>' \
./deploy/staging/init-site.sh
```

该脚本会自动完成：

- 检查 staging 容器是否已启动
- 检查 site 是否已存在
- 不存在时执行 `bench new-site`
- 安装 `erpnext`
- 安装 `myapp`
- 执行 `migrate`
- 校正站点数据库用户授权（默认 `db_user@'%'`）
- 可选执行 `bench use`

可用环境变量：

- `SITE_NAME`
  - 必填，站点名称
- `ADMIN_PASSWORD`
  - 必填，管理员密码
- `INSTALL_ERPNEXT`
  - 默认 `1`
- `INSTALL_MYAPP`
  - 默认 `1`
- `SET_DEFAULT_SITE`
  - 默认 `1`

如果你不想手动在服务器上执行，也可以使用 GitHub Actions：

- `Init staging site`

它会通过 SSH 到测试服务器执行同一个 `init-site.sh`，但需要事先配置：

- `STAGING_SITE_ADMIN_PASSWORD`

## 2. 排障方式：手动执行

如果初始化脚本执行中需要更细粒度排查，再按下面的分步命令手动执行。

### 2.1 宿主机执行

先确认 backend 服务已正常启动：

```bash
docker compose \
  --env-file deploy/staging/staging.env \
  -f deploy/staging/compose.staging.yaml \
  -f overrides/compose.redis.yaml \
  -f deploy/staging/compose.mariadb.staging.yaml \
  -f overrides/compose.noproxy.yaml \
  ps
```

### 2.2 新建站点

以下命令在宿主机执行，它会进入 backend 容器里调用 bench：

```bash
docker compose \
  --env-file deploy/staging/staging.env \
  -f deploy/staging/compose.staging.yaml \
  -f overrides/compose.redis.yaml \
  -f deploy/staging/compose.mariadb.staging.yaml \
  -f overrides/compose.noproxy.yaml \
  exec backend \
  bash -lc "bench new-site staging.example.com --admin-password <admin-password> --db-root-password <db-root-password>"
```

建议：

- `staging.example.com` 直接使用最终测试域名
- `admin-password` 使用独立测试环境密码
- `db-root-password` 与 `staging.env` 中的数据库根密码保持一致

### 2.3 安装应用

先安装 `erpnext`，再安装 `myapp`：

```bash
docker compose \
  --env-file deploy/staging/staging.env \
  -f deploy/staging/compose.staging.yaml \
  -f overrides/compose.redis.yaml \
  -f deploy/staging/compose.mariadb.staging.yaml \
  -f overrides/compose.noproxy.yaml \
  exec backend \
  bash -lc "bench --site staging.example.com install-app erpnext"

docker compose \
  --env-file deploy/staging/staging.env \
  -f deploy/staging/compose.staging.yaml \
  -f overrides/compose.redis.yaml \
  -f deploy/staging/compose.mariadb.staging.yaml \
  -f overrides/compose.noproxy.yaml \
  exec backend \
  bash -lc "bench --site staging.example.com install-app myapp"
```

### 2.4 执行迁移

```bash
docker compose \
  --env-file deploy/staging/staging.env \
  -f deploy/staging/compose.staging.yaml \
  -f overrides/compose.redis.yaml \
  -f deploy/staging/compose.mariadb.staging.yaml \
  -f overrides/compose.noproxy.yaml \
  exec backend \
  bash -lc "bench --site staging.example.com migrate"
```

### 2.5 设置默认站点

如果当前 bench 只有一个站点，这一步通常不是必须；如果后续会有多个站点，建议显式设置：

```bash
docker compose \
  --env-file deploy/staging/staging.env \
  -f deploy/staging/compose.staging.yaml \
  -f overrides/compose.redis.yaml \
  -f deploy/staging/compose.mariadb.staging.yaml \
  -f overrides/compose.noproxy.yaml \
  exec backend \
  bash -lc "bench use staging.example.com"
```

## 3. 后续更新

后续更新镜像后，建议使用：

```bash
SITE_NAME=staging.example.com ./deploy/staging/deploy-staging.sh
```

该脚本会：

- `docker compose pull`
- `docker compose up -d`
- 若站点已存在，自动校正一次站点数据库用户授权（默认 `db_user@'%'`）
- 自动执行 `bench --site <site> migrate`

如果某个新镜像版本异常，需要切回旧 tag，可以使用：

```bash
ROLLBACK_TAG=staging-20260409-abc123 SITE_NAME=staging.example.com ./deploy/staging/rollback-staging.sh
```

建议在较大版本升级前先执行一次备份：

```bash
SITE_NAME=all ./deploy/staging/backup-staging.sh
```

## 4. IP 访问补充

如果站点已经创建成功，但直接访问：

- `http://127.0.0.1:28080`
- `http://<局域网IP>:28080`

仍然返回 `404`，通常不是建站失败，而是请求 `Host` 没命中站点名。

可以先验证：

```bash
curl -I -H 'Host: staging.example.com' http://127.0.0.1:28080
```

如果这里返回 `200`，说明站点本身已经可用。

此时建议在 `deploy/staging/staging.env` 中设置：

```env
FRAPPE_SITE_NAME_HEADER=staging.example.com
```

然后重启 staging：

```bash
./deploy/staging/stop-staging.sh
./deploy/staging/start-staging.sh
```

## 5. 首次初始化完成后建议检查

- 可以正常打开测试域名
- 后台可以登录
- `myapp` 模块菜单存在
- 商品图片 `/files/...` 可以正常访问
- 私有 PDF 仍通过登录态或接口访问
