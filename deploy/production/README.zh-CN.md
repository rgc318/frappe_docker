# 单节点生产启动安全边界

`start-prod.sh` 是单节点启动工具，不是完整生产发布流水线。2026-09-13 增加的静态校验修复了双代理抢占 80 端口、开发服务器、源码挂载、运行时安装依赖及内部服务端口暴露；没有代替正式发布审批、镜像 provenance 核对、备份恢复、迁移或高可用验收。

## 配置要求

- Docker Compose >= 2.24.4，支持 `!override` / `!reset`；启动机需 Python 3。
- 受限 `.env` 中配置 `MYAPP_PRODUCTION_ERP_IMAGE` 与 `MYAPP_PRODUCTION_AI_IMAGE`，填写已批准镜像的完整引用（推荐 digest，也可使用受 Registry 不可变策略保护的发布标签）。ERP 镜像必须已经包含 myapp、依赖和构建资源；全部 ERP 服务使用同一镜像。不接受无 tag 或 latest/develop/main/master/stable 等浮动标签。脚本不构建镜像，也不根据本地源码伪造运行版本。
- 显式配置至少 16 字符的非占位 `DB_PASSWORD`；同时需要真实 `SITES_RULE`、`LETSENCRYPT_EMAIL` 和既有 AI restricted env 文件。不要把测试占位值用于正式部署。
- 修改 DB_PASSWORD env **不会轮换已有数据库卷中的密码**。已有环境必须先制定账号密码轮换与回滚方案，不可直接改 env 后启动期待密码同步。
- 生产 override 必须最后加载，包括 `--with-observability` 时。`stop.sh --prod` 使用相同组合；不得叠加 `compose.traefik.yaml`。旧版本启动过的 dashboard proxy 可能成为 orphan，需只读确认容器及占用后单独处理，脚本不会自动删容器。
- 只暴露 HTTPS proxy 的 80/443；开发环境仍用原 `start-dev.sh`，不受此 override 影响。bundled Langfuse 的 loopback 管理端口仍保留，正式网络/SSO/TLS 管理需单独验收。

## 无部署验证

```bash
python3 -m unittest discover -s deploy/production -p 'test_*.py'
bash -n start-prod.sh stop.sh
```

测试使用合成镜像/域名/密码并加 `--no-env-resolution`，覆盖真实 Compose 合并（含/不含 Langfuse）、拒绝开发命令/源码挂载/build/调试端口/弱密码/双代理。不启动服务、不拉镜像、不改 Secret 文件。

正式配置静态检查可复用启动脚本内 `docker compose ... config --format json | python3 deploy/production/validate_compose.py` 的完整参数组合。不要把 `config` 完整输出打印到日志，其中含展开后的密钥。通过只说明静态约束满足，不证明镜像可运行、标签不可变、数据库已迁移或生产已验收。

本轮没有运行 `start-prod.sh`、`stop.sh` 或任何部署/密码轮换。
