# Staging 站点初始化

本文档描述正式测试环境第一次建站时的推荐流程。

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

## 1. 宿主机执行

先确认 backend 服务已正常启动：

```bash
docker compose \
  --env-file deploy/staging/staging.env \
  -f compose.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.https.yaml \
  ps
```

## 2. 新建站点

以下命令在宿主机执行，它会进入 backend 容器里调用 bench：

```bash
docker compose \
  --env-file deploy/staging/staging.env \
  -f compose.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.https.yaml \
  exec backend \
  bash -lc "bench new-site staging.example.com --admin-password <admin-password> --db-root-password <db-root-password>"
```

建议：

- `staging.example.com` 直接使用最终测试域名
- `admin-password` 使用独立测试环境密码
- `db-root-password` 与 `staging.env` 中的数据库根密码保持一致

## 3. 安装应用

先安装 `erpnext`，再安装 `myapp`：

```bash
docker compose \
  --env-file deploy/staging/staging.env \
  -f compose.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.https.yaml \
  exec backend \
  bash -lc "bench --site staging.example.com install-app erpnext"

docker compose \
  --env-file deploy/staging/staging.env \
  -f compose.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.https.yaml \
  exec backend \
  bash -lc "bench --site staging.example.com install-app myapp"
```

## 4. 执行迁移

```bash
docker compose \
  --env-file deploy/staging/staging.env \
  -f compose.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.https.yaml \
  exec backend \
  bash -lc "bench --site staging.example.com migrate"
```

## 5. 设置默认站点

如果当前 bench 只有一个站点，这一步通常不是必须；如果后续会有多个站点，建议显式设置：

```bash
docker compose \
  --env-file deploy/staging/staging.env \
  -f compose.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.https.yaml \
  exec backend \
  bash -lc "bench use staging.example.com"
```

## 6. 后续更新

后续更新镜像后，建议使用：

```bash
SITE_NAME=staging.example.com ./deploy/staging/deploy-staging.sh
```

该脚本会：

- `docker compose pull`
- `docker compose up -d`
- 自动执行 `bench --site <site> migrate`

## 7. 首次初始化完成后建议检查

- 可以正常打开测试域名
- 后台可以登录
- `myapp` 模块菜单存在
- 商品图片 `/files/...` 可以正常访问
- 私有 PDF 仍通过登录态或接口访问
