# AI 可观测性、备份恢复与密钥轮换运行手册

更新时间：2026-07-15

## 1. 范围与事实源

- AI generation/trace 使用 Langfuse OTLP HTTP：`/api/public/otel/v1/traces`。
- 用户反馈和固定评测 score 继续使用 Langfuse score ingestion；OTLP traces 不替代 score API。
- Qdrant 在线 collection 通过 snapshot 备份，不直接复制运行中的 RocksDB 文件。
- Langfuse 的 PostgreSQL、ClickHouse、MinIO 和 Redis 必须作为同一恢复点处理。
- 备份不包含 `.env.ai.local`、`.env.langfuse.local` 或任何密钥；生产恢复依赖外部 Secret Manager 中与 manifest 指纹匹配的密钥版本。

## 2. OTLP 运行契约

Orchestrator 使用共享异步 Langfuse Client 和有界后台 Dispatcher 发送 OTLP JSON。AI 请求只构建脱敏 payload 并执行 `put_nowait`；后台按批发送、有限重试和优雅排空，包含：

- 32 位十六进制 trace ID 和 16 位 span ID。
- `langfuse.observation.type=generation`。
- 模型、Prompt 名称/版本、Token、Run、Conversation、策略版本、环境和 release。
- 默认只发送输入、输出和反馈 comment 的 SHA-256、字符数和字节数。
- Langfuse 不可用、队列满或重试耗尽时失败开放，模型调用和 ERP 反馈本地保存不受阻断，也不等待 Langfuse 网络超时。

默认运行参数：队列 1000、批量 20、聚合窗口 250ms、最多重试 2 次、关闭排空 5 秒。`/health.langfuse_delivery` 暴露 `queue_depth`、`queued_total`、`sent_total`、`batch_success_total`、`batch_failure_total`、`retry_total`、`dropped_total` 和不含敏感内容的 `last_error`。生产告警至少覆盖 Worker 未运行、持续积压、批次失败和丢弃增长。

注意：generation 入队成功不代表已经持久化；最终交付以 `sent_total`、Langfuse 查询和告警为准。用户 feedback/eval score 保持独立 ingestion 契约。

真实验收 trace `6c4a83af7ecd4956bf84a154e0d47513` 已通过 Langfuse Public API 查询：

- trace name：`myapp-ai:general`
- observation type：`GENERATION`
- model：`opencode-deepseek-v4-flash`
- version：`erp-readonly-v5`
- input/output：均为哈希摘要
- feedback：`accepted=true`、`observability_synced=true`

2026-07-15 异步 Dispatcher 真实验收：最小 Chat 返回 HTTP 200 和 trace ID 后，后台指标达到 `queued_total=1`、`sent_total=1`、`queue_depth=0`、`retry_total=0`、`dropped_total=0`；Backend 容器未重建。

## 3. 创建一致性备份

```bash
cd /home/rgc318/python-project/frappe_docker
./backup-ai-state.sh
```

流程：

1. 在线创建并下载 Qdrant collection snapshot。
2. 记录 PostgreSQL project、ClickHouse trace/observation、MinIO object 和 Qdrant point/维度计数。
3. 先停止 Langfuse Web/Worker，再 clean stop PostgreSQL、ClickHouse、Redis、MinIO。
4. 归档四个 named volume。
5. 重新启动完整 Langfuse 栈。
6. 生成 `manifest.json`，保存 SHA-256、文件大小、源计数和 Langfuse secret 文件指纹。

默认备份目录 `backups/ai/<UTC timestamp>/` 已被 Git 忽略。备份含观测数据，必须上传到加密、访问受控且有保留策略的外部存储。

2026-07-15 本地演练：

- 备份大小约 264 MiB。
- Qdrant：582 points、1024 维。
- PostgreSQL projects：1。
- ClickHouse traces/observations：116/116。
- MinIO objects：540。
- clean-stop 备份和服务恢复约 1 分钟内完成。

## 4. 隔离恢复演练

```bash
./restore-ai-state-drill.sh backups/ai/<UTC timestamp>
```

恢复脚本不会覆盖在线 Langfuse 或在线 Qdrant collection：

- 创建独立 Compose project、网络和临时 named volumes。
- 校验全部备份文件 SHA-256 和 Langfuse secret 指纹。
- 恢复 PostgreSQL、ClickHouse、Redis、MinIO 并启动临时 Langfuse Web/Worker。
- 通过 Public API、数据库计数和 MinIO object 数验证。
- 把 Qdrant snapshot 上传到临时 collection，核对 points 和 vector size。
- 成功或失败退出时都删除临时 project、卷和 Qdrant collection。

本轮证据：`ai-recovery-reports/restore-drill-20260715T062000Z.json`。全部检查通过：

- PostgreSQL projects：1 = 1。
- ClickHouse traces：116 = 116。
- ClickHouse observations：116 = 116。
- MinIO objects：540 = 540。
- Langfuse API traces：116 = 116。
- Qdrant points：582 = 582，vector size：1024 = 1024。

初始目标：RPO 6 小时、RTO 30 分钟。正式生产必须由定时任务和外部备份平台执行，且至少每季度做一次隔离恢复演练。

## 5. AI 内部服务 Token 轮换

```bash
./rotate-ai-service-token.sh
```

脚本行为：

1. 生成新的随机 256-bit Token，并以 `0600` 原子更新 `.env.ai.local`。
2. 强制重建 Backend、三个 Queue、Scheduler 和 Orchestrator，保证调用方和接收方同时切换。
3. 验证旧 Token 返回 401、新 Token 返回 200。
4. 任一步失败会恢复原文件并重新创建服务。
5. 报告只保存 Token SHA-256 前 12 位指纹，不保存 Token。

本轮证据：`ai-recovery-reports/service-token-rotation-20260715T062614Z.json`，旧指纹返回 401、新指纹返回 200，Orchestrator 健康。

## 6. Langfuse 密钥与访问治理

- `LANGFUSE_ENCRYPTION_KEY`、数据库密码和对象存储密钥属于恢复根密钥，不得只修改环境文件后直接重启；必须按 Langfuse 支持的迁移流程和外部 Secret Manager 版本化轮换。
- Project public/secret key 应通过 Langfuse 管理面创建新 Key，先双 Key 验证 Orchestrator，再撤销旧 Key；首次初始化变量不会修改已有数据库中的 Key。
- Web/MinIO 只绑定 loopback；PostgreSQL、ClickHouse、Redis 和 MinIO Console 不发布宿主机端口。
- 生产接入 SSO 前，管理员账号必须使用唯一强密码、最小管理员人数和定期访问复核。
- AI Auditor 只读检查 trace/score/发布审计，不获得模型策略修改或用户管理权限。

当前已完成内部服务 Token 真实轮换。Langfuse Project Key 和恢复根密钥的生产轮换仍需在正式 Secret Manager/SSO 环境执行，不能在本地通过修改初始化变量伪造完成。

## 7. 故障与回滚

- OTLP/Score 写入失败：保持失败开放，检查 Langfuse Web/Worker、Redis、MinIO 和 ClickHouse；不得阻断 ERP 主链路。
- Qdrant snapshot 创建失败：停止 Embedding 发布，不切换 alias；修复磁盘、`nofile` 或 snapshot 路径后重试。
- 恢复计数不一致：临时恢复环境保持隔离，禁止切换线上 DNS/alias，保存报告并升级给 Vector/Observability Owner。
- Secret 指纹不匹配：恢复脚本失败关闭；从 Secret Manager 取正确版本，不得用新密钥强启旧加密数据。
