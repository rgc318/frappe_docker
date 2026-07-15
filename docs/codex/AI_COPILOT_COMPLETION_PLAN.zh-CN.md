# AI Copilot 企业级收口执行计划

更新时间：2026-07-15

本文把 `AI_TECH_DESIGN.zh-CN.md`、模型治理设计和高并发设计转换为可实施、可验证、可回滚的交付计划。四个原始 Wave 已完成，本地功能基线约 98%；“详细设计完成”不计作代码完成，生产外部依赖也不能由本地占位配置伪造成完成。

## 当前执行状态

- Wave 1 已完成实现与聚焦验证：Backend 模型治理、Orchestrator 策略运行时、Web `/administration/ai/models` 均已落地。
- Wave 2 已完成本地生产化证据：共享异步客户端、分类并发池和稳定 429、可复现压测/SLO、OTLP trace、Qdrant/Langfuse 联合备份恢复演练及内部服务 Token 轮换均已通过。
- Wave 3 首期商品 Data Task 已完成 Backend + Web：确定性缺失描述扫描、手工建议、审批/执行职责分离、源数据漂移检查、幂等执行、安全回滚和审计均有测试与真实临时商品链路证据。
- Wave 4 已完成本地综合验收：Orchestrator 74 项、Backend 171 项、Web 20 套/139 项通过；迁移、三仓库 `diff --check`、敏感扫描、临时资源清理和分仓库提交均已完成。
- 开发与 Dev Container 启动配置已补齐：AI Orchestrator、Qdrant、专用 Worker 和 bundled Langfuse 默认纳入开发测试组合；Backend/Worker、Orchestrator 与 Langfuse 存储密钥保持分层。
- Embedding 当前状态：在线 v1 collection 健康，`erp-embedding` 单条/批量与 30 条中文质量门禁均已恢复通过；新的 v2 collection、完整权限/删除/恢复门禁和审批发布回滚尚未执行。正式生产 Langfuse Project Key、恢复根密钥、SSO 和 Secret Manager 轮换不能由本地环境伪造完成。

## 后续 Goal 范围

后续 Goal 不重复实现已经完成的四个 Wave，按以下顺序收口剩余 AI 模块：

1. 将 OTLP 上报从请求尾部直接等待改为批处理/有界异步队列或 OpenTelemetry Collector，并建立重试、积压、丢弃和故障指标及回归测试。
2. 收紧 bundled Langfuse 内部 Secret 暴露面，形成开发、staging、生产三套明确配置契约；生产使用外部 Secret Manager、SSO/RBAC、TLS、告警和保留策略。
3. 完成多副本 Orchestrator/Web/Worker、托管或 HA 数据服务、负载均衡和真实 staging 故障摘除/恢复/容量验收的部署基线。
4. `erp-embedding` 已恢复并通过当前 v1 在线质量门槛；如果底层模型权重或向量空间变化，完成新 Embedding collection 构建、扩大质量集、审批发布与回滚，不以相同别名或模拟结果替代真实发布。
5. 清理历史测试商品噪声并建立持续的数据质量、检索质量、成本和用户反馈门禁。

当前 Goal 进度：

- 第 1 项已完成第一阶段实现和真实验证。Orchestrator generation OTLP 已使用有界后台批处理 Dispatcher，77 项全测通过；真实调用确认请求成功后后台 `queued_total=1`、`sent_total=1` 且无重试/丢弃。
- 第 2 项本地可实施部分已完成：bundled Langfuse 拆分 Web、应用、PostgreSQL、ClickHouse、Redis、MinIO 和 Orchestrator 专属 `0600` env；真实重建前后 projects=1、traces=122、objects=552 保持一致。三环境契约已形成，`start-prod.sh` 默认不启动 bundled Langfuse。
- 第 5 项本地收口已完成：新增 `MYAPP_AI_VECTOR_EXCLUDED_ITEM_PREFIXES=HTTP-` 全链路过滤、管理员 dry-run/幂等清理 API、critical 审计和 30 条版本化中文检索质量 runner。真实清理只从 Qdrant 移除 439 个测试 points；ERP Item 582、Sales Order 854、alias、1024 维和 SKU001～SKU010 均保持。
- 外部 Provider 后续已修复：`erp-embedding` 字符串单条、数组单条和两条批量均 HTTP 200、1024 维；当前 Orchestrator 在线检索与 30 条质量门禁通过，Top-1 96.67%、Top-3 100%、Provider error 0、p95 211.745ms。在线 v1 维持 143 个非排除 points；在未完成新向量空间 full gate 前仍不创建或发布 v2。
- 第 2/3 项剩余需要正式 Secret Manager、SSO/RBAC、TLS、告警平台、托管/HA 数据服务和真实 staging 环境，不能在本地伪造完成。

## 1. 不可变边界

- Web/Mobile 只调用 MyApp Gateway，不直连 Orchestrator、LiteLLM、Langfuse 或 Qdrant。
- Frappe 始终是用户、角色、公司、记录级权限和正式业务写入的事实源。
- AI 只能查询、解释、生成建议或草稿，不能创建、提交、取消正式单据，也不能直接执行 SQL。
- 模型、Prompt、工具策略、Embedding collection 和预算变更必须版本化、可审计、可回滚。
- 供应商密钥只保存在 LiteLLM/部署密钥层，不进入 MyApp 数据表、浏览器、审计正文或 Git。

## 2. 交付波次

### Wave 1：模型治理控制面

Backend：

- `MyApp AI Model Registry`：模型别名、能力、健康、数据区域、留存、成本和 Embedding 空间元数据。
- `MyApp AI Model Policy`：场景、公司/角色范围、主模型、降级链、超时、并发、预算和灰度。
- `MyApp AI Model Policy Version`：不可变策略快照、内容哈希、评测、审批、发布和回滚来源。
- `MyApp AI Model Usage Daily`：按日期、环境、公司、场景、策略版本和模型聚合使用量。
- `MyApp AI Audit Event`：发布、回滚、预算提升、供应商区域变化和 Embedding 切换审计。
- 角色：`AI Model Manager`、`AI Model Approver`、`AI Auditor`；生产发布默认起草人与审批人分离。

Gateway：

- 模型治理概览、模型同步、策略列表/保存/验证/审批/发布/回滚和用量汇总。
- 所有写接口使用 POST、幂等键、权限检查、原因和事务锁。

Orchestrator：

- 按发布策略解析 capability，返回 `policy_code`、`policy_version`、`model_alias` 和降级原因。
- 短 TTL 缓存与最后有效快照；Frappe 暂时不可用时不能回退到客户端参数。
- 稳定哈希灰度、分类并发池、预算动作、同能力降级和短时熔断。

Web：

- `/administration/ai/models` 提供模型注册、场景策略、审批发布、回滚、预算用量、评测和异常视图。
- 发布前必须展示影响范围、评测差异、预算变化、降级链和回滚目标。

### Wave 2：高并发 P0 与生产运维

- Orchestrator 对 LiteLLM、Qdrant 和 Langfuse 使用共享异步连接池与明确的连接/读取超时。
- Chat、SSE、structured、eval 和 embedding 使用独立并发池；超限快速返回 429，不无界排队。
- 建立独立 `ai-vector` 队列、批量 Embedding、在线检索与索引重建隔离。
- 建立可复现压测：Chat 10/20/50/100，并发 SSE 20/50/100/200，检索 20/50/100，草稿 5/10/20，Embedding 32/64/128 每批。
- Langfuse 从 legacy ingestion 迁移到 OTLP traces。
- 完成 Qdrant snapshot，以及 Langfuse PostgreSQL/ClickHouse/MinIO 联合备份恢复、告警、访问治理和密钥轮换演练。
- 压测后确定 SLO、错误预算和告警负责人；副本数量本身不作为容量证明。

### Wave 3：数据治理与主动助手

- `MyApp AI Data Task` 生命周期：`review_required → approved → executed → rolled_back`，并支持 `rejected`、`failed`；`queued/analyzed` 保留为异步扩展状态。
- 首批覆盖商品资料完整性和受控字段建议；交易、库存、发票和收付款类不进入首期可执行字段集。
- 任务保存证据、前值、建议值、模型/Prompt/策略版本、审批人和执行结果。
- 发起、审批、执行职责分离；执行只调用已有 `update_product_v2`，使用幂等键、源数据漂移检查并支持安全回滚。
- Web 提供任务列表、证据对比、审批/驳回、执行结果和审计链。

### Wave 4：综合发布验收

- 固定 offline full gate 和受控 live full gate 均通过；子集评测不能充当发布门禁。
- 覆盖越权访问、Prompt Injection、Schema、写操作诱导、预算拒绝、灰度稳定性和回滚。
- 演练 LiteLLM 429、供应商 5xx、Qdrant 停止、Redis 延迟、Langfuse 停止、SSE 中断和单副本摘除。
- 验证备份恢复后 trace、策略版本、向量 collection 和审计链可核对。
- Backend、Web、Orchestrator、部署配置和文档分别完成测试、`diff --check`、敏感信息检查与仓库归属提交。

## 3. 需求—证据追踪矩阵

| 要求 | 权威设计 | 主要实现位置 | 完成证据 |
|---|---|---|---|
| 模型注册与健康 | `AI_MODEL_GOVERNANCE_TECH_DESIGN.zh-CN.md` §4.1 | Backend governance service/Gateway | 迁移、权限单测、真实 LiteLLM 同步与健康查询 |
| 策略审批发布回滚 | 同上 §4.2-§6 | Backend + Orchestrator + Web | 双人审批、幂等发布、灰度稳定、回滚真实链路 |
| 预算/降级/熔断 | 同上 §7 | Orchestrator + usage aggregation | 预算拒绝、同能力降级、熔断/半开测试与指标 |
| Embedding 切换 | 同上 §8 | Backend vector governance + Qdrant | 双 collection 补建、质量门禁、原子切换和回滚 |
| 高并发 P0 | `AI_HIGH_CONCURRENCY_TECH_DESIGN.zh-CN.md` §4-§13 | Orchestrator + Compose + workers | 压测报告、429、连接池、独立队列、故障注入 |
| 生产观测与恢复 | `AI_TECH_DESIGN.zh-CN.md` §10 | OTLP + Langfuse/Qdrant 运维脚本 | 联合备份恢复、告警、密钥轮换演练报告 |
| 数据治理任务 | `AI_TECH_DESIGN.zh-CN.md` §6.4 | Backend task service/Gateway + Web | 生命周期、双人审批、幂等执行、审计与回滚测试 |
| 安全边界 | `AI_TECH_DESIGN.zh-CN.md` §2/§7 | 全链路 | 无越权、无直连、无 AI 正式写入、敏感信息扫描 |

## 4. 分仓库交付边界

- `apps/myapp`：数据模型、迁移、权限、服务、Gateway、任务和后端测试。
- `frontend/myapp-web`：模型治理与数据任务管理页面、领域 service 和 Jest。
- 父仓库：`services/myapp-ai`、Compose、队列/观测/备份/压测脚本、路线图和交接；后端完成提交后更新子模块指针。
- `frontend/myapp-mobile`：本轮不纳入首期管理功能；不得覆盖现有未提交改动。

## 5. 完成定义

只有当上述四个 Wave 的实现、真实验收、恢复演练、文档和分仓库交付证据全部存在时，AI Copilot 企业级收口才可标记完成。局部单测通过、页面可访问、容器健康或设计文档完成均不能单独证明 Goal 完成。
