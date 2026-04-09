# 本地测试数据迁移到 Staging

本文档用于把本地开发站点的数据迁移到远程 `staging` 站点。

适用场景：

- 本地开发环境已经整理出一份可用测试数据
- 远程正式测试环境已经完成首次部署
- 希望直接把本地账号、权限、基础配置、附件和业务测试数据迁到远程站点

不建议直接跳过备份覆盖远端站点。

---

## 1. 原则

迁移的基本原则是：

1. 先备份本地站点
2. 先备份远程 staging 站点
3. 再恢复本地备份到远程 staging
4. 恢复后执行 `migrate` 和健康检查

注意：

- 数据是跟着 `site` 走的，不是跟着 `app` 走的
- `restore` 会覆盖目标站点当前数据库和附件文件
- 恢复后，远端站点会继承本地备份里的账号、权限、业务数据和附件
- 环境相关配置仍应以远端 `site_config.json` 和 `staging.env` 为准

---

## 2. 本地准备

先确认本地站点已经是你想迁移的状态。

如果想迁移一份“干净测试库”，建议先：

- 保留基础主数据
- 清空事务单据
- 禁用测试账号

然后执行备份：

```bash
docker exec frappe_docker-backend-1 bash -lc 'cd /home/frappe/frappe-bench && bench --site localhost backup --with-files'
```

备份完成后，确认容器内的备份文件，例如：

```bash
docker exec frappe_docker-backend-1 bash -lc 'ls -1 /home/frappe/frappe-bench/sites/localhost/private/backups | tail -n 4'
```

常见产物包括：

- `*-database.sql.gz`
- `*-files.tar`
- `*-private-files.tar`
- `*-site_config_backup.json`

建议使用**清理之后重新生成的备份**。

不要误用清理前的旧备份。

---

## 3. 导出本地备份文件

将容器内备份导出到本机临时目录：

```bash
mkdir -p /tmp/localhost-restore-backup-clean

docker cp frappe_docker-backend-1:/home/frappe/frappe-bench/sites/localhost/private/backups/20260409_180423-localhost-database.sql.gz /tmp/localhost-restore-backup-clean/
docker cp frappe_docker-backend-1:/home/frappe/frappe-bench/sites/localhost/private/backups/20260409_180423-localhost-files.tar /tmp/localhost-restore-backup-clean/
docker cp frappe_docker-backend-1:/home/frappe/frappe-bench/sites/localhost/private/backups/20260409_180423-localhost-private-files.tar /tmp/localhost-restore-backup-clean/
docker cp frappe_docker-backend-1:/home/frappe/frappe-bench/sites/localhost/private/backups/20260409_180423-localhost-site_config_backup.json /tmp/localhost-restore-backup-clean/
```

如果文件名不同，请替换成你本次实际生成的备份文件名。

---

## 4. 上传到远程服务器

先在远程服务器准备临时目录：

```bash
ssh -p 10022 vivy@39.104.204.79 'mkdir -p /srv/frappe_docker/tmp/restore-localhost-20260409'
```

然后上传备份文件：

```bash
scp -P 10022 /tmp/localhost-restore-backup-clean/* vivy@39.104.204.79:/srv/frappe_docker/tmp/restore-localhost-20260409/
```

上传后可在远程核对：

```bash
ssh -p 10022 vivy@39.104.204.79 'ls -lh /srv/frappe_docker/tmp/restore-localhost-20260409'
```

---

## 5. 在远程恢复到 Staging

推荐直接在远程服务器上使用：

- `/home/rgc318/python-project/frappe_docker/deploy/staging/restore-staging.sh`

示例：

```bash
ssh -p 10022 vivy@39.104.204.79
cd /srv/frappe_docker

SITE_NAME=staging.example.com \
RESTORE_DIR=/srv/frappe_docker/tmp/restore-localhost-20260409 \
./deploy/staging/restore-staging.sh
```

这个脚本会自动完成：

- 确保 `backend/db/redis` 相关服务已启动
- 先对当前远端 `staging` 站点做安全备份
- 把数据库、公有文件、私有文件复制进 backend 容器
- 执行 `bench restore`
- 执行 `bench migrate`
- 清缓存
- 关闭维护模式

如果目录里有多套备份，脚本默认使用最新的 `*-database.sql.gz`。

也可以显式指定前缀：

```bash
SITE_NAME=staging.example.com \
RESTORE_DIR=/srv/frappe_docker/tmp/restore-localhost-20260409 \
RESTORE_PREFIX=/srv/frappe_docker/tmp/restore-localhost-20260409/20260409_180423-localhost \
./deploy/staging/restore-staging.sh
```

---

## 6. 恢复后检查

先跑 staging 健康检查：

```bash
cd /srv/frappe_docker
./deploy/staging/check-staging.sh
```

如果返回：

- `Homepage: OK (200)`
- `Ping API: OK (200)`

说明站点已恢复成功并可访问。

如果当前还是内网单站点测试模式，建议在：

- `/srv/frappe_docker/deploy/staging/staging.env`

中保留：

```env
FRAPPE_SITE_NAME_HEADER=staging.example.com
```

这样直接通过：

- `http://<局域网IP>:28080`

访问时，也会正确路由到 `staging.example.com`。

---

## 7. 这次实际踩到的坑

### 7.1 恢复错用了清理前备份

现象：

- 远端恢复完成
- 但 `Sales Order`、`Purchase Order` 等事务数据仍然很多

根因：

- 使用了清理动作之前生成的本地旧备份

解决：

- 在本地清理完成后重新执行一次 `bench backup --with-files`
- 只使用清理后的新备份恢复到 staging

### 7.2 恢复后短暂返回 `503`

现象：

- 容器正常
- 首页返回 `503`

根因：

- 站点仍处于 maintenance mode

解决：

- `restore-staging.sh` 在恢复尾部自动执行：
  - `bench --site <site> set-maintenance-mode off`

### 7.3 直接访问 IP 返回 `404`

现象：

- `curl -I http://127.0.0.1:28080` 返回 `404`
- 但加 `Host: staging.example.com` 后返回 `200`

根因：

- 请求头的 `Host` 不是站点名

解决：

- 在 `staging.env` 中设置：

```env
FRAPPE_SITE_NAME_HEADER=staging.example.com
```

---

## 8. 推荐的长期方式

建议把“本地整理数据 -> 迁移到 staging”收成固定流程：

1. 本地清理测试数据
2. 本地重新备份
3. 上传到远程 `/srv/frappe_docker/tmp/...`
4. 运行 `restore-staging.sh`
5. 运行 `check-staging.sh`

这样 staging 就可以持续使用一份：

- 主数据完整
- 事务数据干净
- 账号和附件可用

的标准测试库。
