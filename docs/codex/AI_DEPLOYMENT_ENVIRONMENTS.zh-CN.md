# AI 与 Langfuse 三环境部署契约

更新时间：2026-07-16

本文定义 development、staging、production 的 AI Orchestrator、Qdrant 和 Langfuse 部署边界。功能设计、模型治理和业务权限仍分别以 Backend 与 Orchestrator 技术设计为准。

源码与部署边界：AI Orchestrator 源码位于独立仓库 `rgc318/myapp-ai`，父部署仓库通过 `services/myapp-ai` 子模块固定已验证提交。AI 仓库负责依赖锁、Standalone Compose、Redis/Qdrant、合成集成测试、服务级文档、源码 CI/安全门禁和 GHCR 镜像发布；父仓库负责完整 ERP Compose、Dev Container、bundled Langfuse、staging/production 和跨服务 Secret 编排。部署证据必须能同时追溯父仓库提交与 AI 提交或镜像 digest。

## 1. 共同不可变边界

- Web/Mobile 只调用 Frappe Gateway，不直连 Orchestrator、LiteLLM、Langfuse 或 Qdrant。
- Frappe Backend/Worker 只获得 Gateway URL、内部服务 Token、向量开关/alias、排除商品前缀、环境和保留期，不获得模型供应商或 Langfuse 存储密钥。
- Orchestrator 可以获得 LiteLLM Key、Langfuse Project Key 和 Qdrant 地址，但不得获得 Langfuse PostgreSQL、ClickHouse、Redis、MinIO 根密钥。
- generation OTLP 使用有界异步批处理 Dispatcher；观测失败、队列满或重试耗尽不得阻断 AI/ERP 主链路。
- 默认 `MYAPP_AI_LANGFUSE_CAPTURE_CONTENT=0`。原文采集必须经过数据分类、保留、访问、跨境和删除策略评审。
- Embedding collection 通过不可变版本、full gate、审批和 alias 原子切换发布，不得原地覆盖在线 collection。

## 2. Development / Dev Container

用途：个人开发、功能联调、固定评测、故障注入和恢复演练。

- `./start-dev.sh` 和 Dev Container 默认启动 bundled Langfuse、AI Orchestrator、Qdrant 与专用 `ai-vector` Worker。
- 只开发 Orchestrator 时，可在 `services/myapp-ai` 使用其 `.env.example`、`compose.yaml` 和 `scripts/standalone-up.sh` 独立启动 Orchestrator、Redis、Qdrant；该模式不启动 ERP 或 Langfuse 存储。
- AI 仓库 `make integration` 使用合成 OpenAI/Frappe Provider 验证 Chat 与向量 upsert/search/delete，不访问真实 ERP 或计费模型。
- Dev Container 在宿主机执行 `git submodule update --init --recursive`；直接使用脚本或 Compose 前也必须保证 `services/myapp-ai` 已初始化到父仓库固定提交。
- development 默认以 `MYAPP_AI_VECTOR_EXCLUDED_ITEM_PREFIXES=HTTP-` 排除明确 HTTP 测试商品；扩展前缀前必须审计历史交易引用。
- bundled Langfuse 是单节点六服务组合，不代表生产 HA。
- Web 和 MinIO 只绑定 loopback；PostgreSQL、ClickHouse、Redis 和 MinIO Console 不发布宿主机端口。
- `.env.langfuse.local` 是被忽略的恢复根配置；`sync-langfuse-runtime-env.sh` 原子生成权限 `0600` 的分服务文件：
  - Web/Worker 应用运行时；
  - Web 初始化与 NextAuth；
  - PostgreSQL；
  - ClickHouse；
  - Redis；
  - MinIO；
  - Orchestrator Project Key/投递参数。
- `./sync-langfuse-runtime-env.sh --reconcile` 在 Orchestrator 已运行时会强制重建该容器，并等待观测增强健康检查确认 `langfuse_configured=true`、`langfuse_delivery.enabled=true`；未运行时只生成配置，下一次启动自动应用。
- `start-dev.sh` / `start-prod.sh` 会在 Compose 启动前调用 `validate-secret-env-files.sh`，拒绝任何带 group/other 权限的实际 Secret env 文件，并等待服务健康后才返回。
- 存储容器只获得自身凭据；Worker 不获得初始化管理员密码；Orchestrator 不获得存储密钥。
- 明确不需要观测时才使用 `./start-dev.sh --without-observability`。

## 3. Staging

用途：生产同构验证、部署回滚、权限、容量、故障摘除和恢复演练。

- 使用 `deploy/staging/compose.staging.yaml` 和独立 ERP/AI 镜像标签。
- 不启动本地 bundled Langfuse。通过 `MYAPP_AI_LANGFUSE_HOST/PUBLIC_KEY/SECRET_KEY` 接入独立受控 Langfuse；三项必须全部配置或全部为空。
- `validate-staging-env.sh` 对 Secret 文件权限、镜像、占位符、Provider、短 Token、向量依赖和部分 Langfuse 配置失败关闭；`staging.env` 必须为 `0600` 或更严格。
- Backend/Worker 继续只接收 Gateway-safe 配置；Provider/Langfuse Project Key 只进入 Orchestrator。
- staging 必须验证：迁移、Backend→Orchestrator 认证、OTLP Dispatcher 指标、向量 alias/points/维度、模型固定评测、备份恢复、回滚和故障摘除。配置了 Langfuse 三项连接参数时，`check-staging.sh` 同样要求 `langfuse_configured=true` 与 `langfuse_delivery.enabled=true`。
- `deploy/staging/staging.env` 只能作为受限服务器过渡文件；正式环境应由 Secret Manager 或编排平台在部署时注入。

## 4. Production

用途：正式业务流量和受审计观测。

- `start-prod.sh` 默认不启动 bundled Langfuse。`--with-observability` 只用于明确接受单节点风险的受控小规模环境，不作为企业生产推荐方案。
- 推荐外部受控 Langfuse，Web/Worker 多副本；PostgreSQL、ClickHouse、Redis 和 S3 对象存储使用托管或等价 HA 服务，并跨故障域部署。
- Orchestrator 至少两个副本，由负载均衡执行 readiness、优雅摘流和超时控制；Redis 分布式限流/预算/熔断和策略快照不得退化为进程内状态。
- 所有外部入口使用 TLS；内部服务使用网络策略、安全组或 mTLS 等价隔离。Langfuse UI 必须接入企业 SSO、最小 RBAC 和定期访问复核。
- LiteLLM Key、内部服务 Token、Langfuse Project Key、数据库/对象存储根密钥必须由 Secret Manager 版本化管理；轮换需要双 Key/灰度验证和回滚，不得只修改初始化 env。
- 至少告警：模型错误/429/超时、SSE 中断、预算拒绝、OTLP Worker 停止/积压/失败/丢弃、Qdrant 延迟/容量/snapshot、RQ 积压、数据库和对象存储容量。
- 必须定义 trace/score/对象/备份保留期、删除责任人、RPO/RTO、季度恢复演练和审计导出流程。

## 5. 本地可验证门禁

```bash
./sync-ai-gateway-env.sh
./sync-langfuse-runtime-env.sh --reconcile
./validate-secret-env-files.sh \
  .env .env.ai.local .env.ai.gateway.local .env.langfuse.local

docker compose \
  --env-file .env \
  --env-file .env.ai.local \
  --env-file .env.langfuse.local \
  -f compose.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.noproxy.yaml \
  -f overrides/compose.langfuse.yaml \
  config --quiet

ENV_FILE=deploy/staging/staging.env ./deploy/staging/validate-staging-env.sh
```

配置解析之外，还必须检查实际容器环境的键集合，确保 Backend 无 Provider/Langfuse Secret、Orchestrator 无存储 Secret、各存储容器只含自身凭据。密钥值不得输出到日志或报告。

## 6. 尚需外部环境完成

- 正式 Secret Manager、SSO/RBAC、TLS 证书、DNS 和网络策略。
- 多副本 Orchestrator/Langfuse、托管或 HA 数据服务和负载均衡真实故障摘除。
- 正式告警平台、负责人、保留/删除策略和定时备份平台。
- 当前 `erp-embedding` 已恢复并通过 v1 在线质量门槛；新向量空间仍需在正式环境完成 collection 构建、权限/删除/恢复质量门禁、审批发布和回滚。

这些项目不能用本地占位密钥、单机 Compose 健康或 mock Provider 结果替代。
