# AI 运行契约、就绪治理与发布一致性设计

更新时间：2026-09-05

本文定义 MyApp AI 从“各服务分别健康”升级为“端到端场景可接单”的运行契约、状态模型、错误协议、部署门禁和恢复策略。模型治理、Agent 工具循环、草稿确认和正式业务执行继续分别以现有 AI 业务操作台、Agent Runtime 和领域设计为事实源；本文不改变 Frappe 作为身份、权限、公司范围和 ERP 业务事实唯一权威的边界。

## 1. 背景与问题

2026-09-04 本地商品建档草稿出现以下现象：

- LiteLLM 和目标模型真实可用；
- AI Orchestrator 容器处于 `healthy`；
- 意图解析接口返回 HTTP 200；
- 商品草稿接口返回 HTTP 409；
- Web 最终显示 `AI_SERVICE_UNAVAILABLE`，使用户误认为模型或 AI 服务宕机。

实际原因是 Backend 已要求 `product-setup-draft-v7`，运行中的 Orchestrator 镜像仍注册 `product-setup-draft-v6`。请求在模型选择和 Provider 调用之前即因 Prompt 版本不一致被拒绝。Backend 的草稿错误解析只识别对象形式的 `detail`，而 Orchestrator 返回字符串形式的 409 `detail`，最终把契约冲突泛化为“服务不可用”。

该事件暴露的不是单一模型稳定性问题，而是四个系统性缺口：

1. Backend 与 Orchestrator 分别维护 Prompt 版本，独立测试可全部通过，组合运行仍可能漂移。
2. development 的 Backend 使用源码挂载，Orchestrator 使用构建镜像，两者更新时间不同。
3. 当前容器健康检查只证明进程可以响应，不证明跨服务契约、策略和场景可以执行。
4. 模型、Provider、策略、契约、依赖和业务错误没有在所有链路使用统一结构化错误语义。

## 2. 目标与非目标

### 2.1 目标

- 明确区分服务存活、运行时就绪、场景就绪、模型健康、模型能力和策略资格。
- Prompt、Schema、工具和运行制品发生变化时，部署前或启动后自动发现不兼容。
- 用户只能在真实模型或 Provider 故障时看到“模型不可用”。
- 配置、契约、策略、权限、预算和业务校验失败返回各自稳定错误码与恢复动作。
- development、staging 和 production 使用同一兼容性判定语义，只在发布严格度和依赖形态上不同。
- 保持模型调用重试、fallback、熔断、幂等、权限、审计和人工确认的现有安全边界。

### 2.2 非目标

- 不因运行治理问题迁移到 LangGraph、Google ADK、OpenAI Agents SDK 或其他 Agent 框架。
- 不把确定性写业务改造成开放 Agent 写操作。
- 不让 Web/Mobile 直连 Orchestrator、LiteLLM 或 Provider。
- 不用自动重试掩盖契约、认证、权限、Schema 或业务校验错误。
- 不把一次模型健康探测成功解释为模型长期可用。

## 3. 设计原则

1. **存活不等于就绪**：容器 Up、HTTP 200 和配置存在只能证明局部状态。
2. **场景级判定**：普通问答可用时，商品草稿异常不应把整个 AI 标记为不可用。
3. **协议与 Prompt 分离**：跨服务兼容性使用稳定协议/Schema 版本；Prompt revision 属于 Orchestrator 运行实现和审计事实。
4. **单一发布事实**：运行制品、协议、Prompt、Schema 和工具哈希进入同一 Release Manifest。
5. **失败关闭但准确表达**：不兼容时拒绝执行，但必须说明是契约问题，不能冒充模型故障。
6. **自动恢复有边界**：只对超时、网络、429 和 Provider 5xx 等瞬时错误有限重试或 fallback。
7. **状态必须带时间**：模型健康和策略快照必须有检查时间、过期时间和来源。
8. **实际运行事实优先**：页面展示以 Backend/Orchestrator 返回的 Run、模型和 readiness 为准，不以浏览器发送前状态推断。

## 4. 目标架构

```text
AI Release Manifest / Control Plane
  ├─ release_id
  ├─ protocol_version
  ├─ backend_revision
  ├─ orchestrator_revision
  ├─ prompt_manifest_sha256
  ├─ schema_manifest_sha256
  └─ tool_manifest_sha256
            │
            ▼
Frappe AI Gateway ── readiness handshake ── MyApp AI Orchestrator
       │                                           │
       │                                           ├─ Runtime Policy / Redis
       │                                           ├─ LiteLLM Model Gateway
       │                                           ├─ Qdrant
       │                                           └─ Langfuse / OpenTelemetry
       │
       ├─ read-only Agent / compatibility workflow
       ├─ structured draft workflow
       └─ confirmed domain service execution
```

Frappe 对外聚合端到端 readiness；Orchestrator 只声明自身运行契约和依赖状态。浏览器不直接比较版本，也不决定 fallback。

## 5. 状态模型

### 5.1 服务与场景状态

| 层级               | 状态                                                | 含义                                               |
| ------------------ | --------------------------------------------------- | -------------------------------------------------- |
| Service Liveness   | `alive / dead`                                      | 进程是否能响应                                     |
| Runtime Readiness  | `ready / degraded / blocked`                        | 核心配置、协议和必要依赖是否允许接单               |
| Scenario Readiness | `ready / degraded / blocked`                        | 指定场景是否具备兼容 Prompt/Schema、策略和模型能力 |
| Request Result     | `completed / waiting_approval / failed / cancelled` | 单次 Run 的事实终态                                |

`degraded` 只能用于存在明确、安全降级路径的场景。例如只读 Agent Policy 未就绪但兼容查询仍可在相同权限边界下完成；结构化写草稿没有兼容 Schema 时必须 `blocked`。

### 5.2 模型状态维度

模型不得继续由单个“可用/不可用”字段表达全部语义：

| 维度         | 示例                                                               |
| ------------ | ------------------------------------------------------------------ |
| 生命周期     | `discovered / validated / active / disabled / retired`             |
| 发现状态     | `listed / missing / unknown`                                       |
| 健康状态     | `available / degraded / unavailable / stale / unknown / half_open` |
| 原生协议能力 | `supports_json_schema / tools / vision / reasoning / embedding`    |
| 有效任务能力 | `supports_structured_output` 等经过真实任务探测的能力资格          |
| 策略资格     | `eligible / ineligible`                                            |
| 熔断状态     | `closed / open / half_open`                                        |
| 场景资格     | 按 scenario 判断是否可作为主模型或 fallback                        |

健康结果必须保存 `checked_at`、`expires_at`、连续失败次数、稳定错误码和探测来源。过期的成功/降级结果转为 `stale`，过期的 `unavailable` 转为 `half_open`，不能无限期沿用旧失败。能力同样不能只依赖静态声明：`supports_json_schema` 只表示 Provider 原生 strict JSON Schema，`supports_structured_output` 表示模型经过原生或受控 JSON 回退后实际生成并通过本地 Schema 校验。Phase 3 已实现 Backend 单一派生状态、默认 30 小时 TTL、Orchestrator Redis 15 秒分布式恢复探测租约，以及结构化输出独立资格。

## 6. 运行契约

### 6.1 三类版本

必须拆分以下概念：

- `protocol_version`：Backend 与 Orchestrator 的跨服务协议主版本。
- `schema_version`：具体请求、响应、工具和草稿候选结构版本。
- `prompt_version`：Orchestrator 实际使用的 Prompt revision，只用于审计、评测和可复现性。

Phase 2 已实现该分离：Backend 的新请求提交 `protocol_version`、`supported_schema_versions` 和 `client_capabilities`，不再钉死 Prompt revision；Orchestrator 选择当前已发布 Prompt，并在普通响应、SSE 终态事件和 Run 中返回实际 `prompt_version`。只有协议或 Schema 不兼容才返回结构化 409。

当前 Schema family 为 `chat-v1`、`agent-runtime-v1`、`intent-parse-v1`、`sales-order-draft-v1`、`purchase-order-draft-v1`、`inventory-adjustment-draft-v1` 和 `product-setup-draft-v1`。`/readyz` 同时返回每个场景需要的 family 与支持版本，Backend 启动门禁比较协议和这 7 个 family，不再因 Prompt revision 正常升级阻断新请求。

兼容边界保留两项例外：未携带 `protocol_version` 的旧客户端继续使用 Prompt 精确匹配，防止滚动迁移时静默改变旧契约；Agent resume 必须携带 Run 已持久化的实际 Prompt revision，Orchestrator 精确匹配后才允许继续原 checkpoint，避免使用不同 Prompt 解释旧状态。

### 6.2 Release Manifest

正式制品必须携带：

```json
{
  "release_id": "2026.09.04-<revision>",
  "protocol_version": "ai-runtime-contract-v1",
  "supported_protocol_range": ["ai-runtime-contract-v1"],
  "orchestrator_revision": "<git sha>",
  "capabilities": ["release-manifest-v1", "runtime-response-metadata-v1"],
  "schema_versions": {
    "chat": ["chat-v1"],
    "agent": ["agent-runtime-v1"]
  },
  "compatibility_matrix": {
    "general": { "chat": ["chat-v1"], "agent": ["agent-runtime-v1"] }
  },
  "prompt_manifest_sha256": "<sha256>",
  "schema_manifest_sha256": "<sha256>",
  "tool_manifest_sha256": "<sha256>"
}
```

Orchestrator 暴露运行时 Manifest；父部署制品再用同一 `release_id` 绑定 Backend revision、Orchestrator revision 与不可变镜像 tag/digest。staging/production 必须由 Manifest 机器校验，不再只依赖命名约定。回滚默认成对执行，只有兼容矩阵明确证明协议和全部场景 Schema 仍有交集时才允许独立回滚。

## 7. 健康与就绪接口

### 7.1 `/livez`

- 不访问 Provider、Redis、Frappe、Qdrant 或 Langfuse。
- 进程事件循环可响应即返回 HTTP 200。
- 仅用于容器/编排平台重启判定。

### 7.2 `/health`

- 保持兼容的诊断快照。
- 返回 runtime revision、协议、Prompt/工具 Manifest、配置能力和异步观测状态。
- 不应被解释为端到端可以接单。

### 7.3 `/readyz`

- 验证核心配置、运行协议、Prompt Registry、Runtime Policy 基础依赖和必要客户端初始化。
- 不执行计费模型推理。
- 返回 `ready`、`status`、`checks`、`scenarios` 和 Manifest。
- 核心条件失败返回 HTTP 503；自身结构完整但调用方契约不兼容由 Frappe 聚合层标记为 `blocked`。

### 7.4 Deep Health

- 由治理任务定时执行最小真实 Chat、strict JSON Schema/受控 JSON 回退、Function Calling、视觉和 Embedding 探测。
- 产生少量 Provider 调用和费用，不进入每个业务请求前置链路。
- 探测结果写入模型健康快照，并按 TTL 失效。
- 基础健康与各项能力结果独立：某项能力失败不能把仍可完成基础文本调用的模型整体标成不可用。
- 结构化探测只有原生请求明确返回 HTTP 400 时才允许兼容回退；超时、429、5xx 和网络错误保留上一次已验证资格并记录稳定错误码。

## 8. 统一错误协议

所有 AI 层错误使用统一公开信封：

```json
{
  "code": "AI_RUNTIME_CONTRACT_MISMATCH",
  "category": "contract",
  "layer": "orchestrator",
  "retryable": false,
  "message": "AI 运行版本不一致，请联系管理员同步服务版本。",
  "request_id": "...",
  "run_id": "...",
  "model_alias": null,
  "details": {
    "scenario": "product_setup_draft",
    "received_version": "product-setup-draft-v7",
    "expected_version": "product-setup-draft-v6"
  }
}
```

稳定错误类别至少包括：

| 类别          | 错误码示例                                                                                          | 自动重试 |
| ------------- | --------------------------------------------------------------------------------------------------- | -------- |
| Contract      | `AI_RUNTIME_CONTRACT_MISMATCH`、`AI_SCHEMA_VERSION_MISMATCH`、旧协议的 `AI_PROMPT_VERSION_MISMATCH` | 否       |
| Configuration | `AI_RUNTIME_NOT_READY`、`AI_SERVICE_AUTHENTICATION_FAILED`                                          | 否       |
| Policy        | `AI_POLICY_NOT_READY`、预算拒绝                                                                     | 否       |
| Capability    | `AI_SELECTED_MODEL_NO_VISION`、`structured_output_unverified`、工具能力未验证                       | 否       |
| Provider      | `MODEL_PROVIDER_REJECTED`、Provider timeout/429/5xx                                                 | 有边界   |
| Dependency    | Redis/Qdrant/Frappe 暂时不可用                                                                      | 按场景   |
| Business      | 权限、字段校验、版本冲突、库存或单据约束                                                            | 否       |

HTTP 状态与稳定错误码共同使用：409 表示契约/版本冲突，422 表示请求 Schema，429 表示限流或预算背压，502 表示 Provider 拒绝，503 表示依赖或 Runtime 暂不可用。Web 的恢复动作以 `code + retryable` 为准，不能仅按 HTTP 状态猜测。

## 9. 请求恢复与降级

- 契约、认证、权限、Schema 和确定性业务错误立即失败关闭。
- Provider 超时、网络、429 和 5xx 只在首个可见正文或正式工具副作用之前有限重试。
- 自动模式可以按已发布策略切换到具备相同场景能力的 fallback。
- 固定模型请求不得静默切换模型。
- 草稿生成不因模型失败自动重复创建新 Run；用户手动重试复用失败上下文并保留旧 Run。
- 只读兼容查询是明确、可观测的降级路径，不得伪造 Agent 工具轨迹。

## 10. 部署策略

### 10.1 Development

- `start-dev.sh` 构建后必须比较运行中 Backend 与 Orchestrator 的协议和全部 Schema family。
- Orchestrator 镜像记录源码 revision；当前源码与运行镜像不一致时提示重建。
- 可后续引入 Docker Compose Watch 改善开发循环，但不得把源码热更新语义带入 staging/production。

### 10.2 Staging

- Backend 和 Orchestrator 使用同一 immutable release tag/digest 集合。
- Backend 与 Worker 只访问内部 `ai-router`；HAProxy 使用 Docker DNS 发现 1 ～ 10 个 Orchestrator 副本、`leastconn` 分配请求，并以 `/readyz` 主动摘流和恢复入流。
- 启动和部署后门禁必须逐个直连副本，确认期望副本数、Docker health、readiness、镜像 ID、release ID、runtime revision、协议和三个 Manifest hash 完全一致，再确认 Router 返回同一运行身份。
- 部署后执行 liveness、readiness、契约握手和有界真实场景 canary；确定性失败自动停止发布流程。
- canary 默认只执行 readiness、意图、普通只读 Chat 和“生成但不确认”的结构化草稿，不写正式 ERP 单据。
- Provider timeout/429/5xx 最多对同一制品重试一次并保留 `partial`，契约、认证、Schema、能力和 Provider 4xx 直接 `failed`。
- 只有 `passed` 报告才能把 Backend revision、Orchestrator revision、镜像 ID/digest 和共同 release ID 登记为可回滚发布对。
- canary 后生成机器可读 SLO/告警状态；契约错误和确定性 canary 失败始终 critical，小于最小样本数时只能是 `warning`，不能伪装为 SLO PASS。
- stable/candidate 使用两个独立同版本副本池。`rollout.map` 持久化 fresh request 的 0～100% bucket，`release-affinity.map` 把 Agent resume 精确绑定到创建 checkpoint 的 release；未知 release 进入 `ai_affinity_missing` 并返回 503，不允许跨 release 猜测恢复。
- HAProxy Runtime API 通过 `prepare / clear / add / commit map` 原子更新两张 map，并在每个阶段核对持久 map、状态文件和真实采样分布。candidate 不健康时 fresh request 自动回退 stable，但 candidate 配置了流量却没有收到样本会阻断晋级。
- 发布状态机为 `active → draining → promoting → completed`。新版本达到 100% 后旧 stable 在 `AI_ROLLOUT_DRAIN_SECONDS` 内只承接旧 release resume；截止后先关闭旧 affinity，再把新版本收敛到 stable。灰度失败或人工 abort 则先把 fresh traffic 归零到旧 stable，并反向保留 candidate 直到其 checkpoint drain 完成。
- 对新 Runtime Policy 使用限公司、限角色、限百分比灰度。
- 契约不兼容、确定性 Schema/迁移失败和权限边界错误属于 staging blocker。

### 10.3 Production

- 至少两个 Orchestrator 副本，通过 readiness 摘流。
- 使用不可变制品、渐进发布、自动停止和成对回滚。
- Secret、策略、模型和 Prompt 发布分别版本化，但必须记录共同 Release provenance。
- Provider 波动使用模型网关、熔断和 fallback；控制面不一致不通过切换模型掩盖。

## 11. 测试门禁

### 11.1 单仓测试

- Orchestrator：Prompt Registry、结构化错误、`/livez`、`/health`、`/readyz`、Manifest。
- Backend：错误解析、场景 readiness 聚合、权限安全响应、Run 失败事实。
- Web：错误类别、恢复动作和场景级提示。

### 11.2 跨仓契约测试

父仓使用真实 Backend 与真实 Orchestrator、合成 Provider 执行：

1. 当前 Backend + 当前 Orchestrator 应 ready。
2. 当前 Backend + 旧 Orchestrator 应在启动门禁失败并给出差异。
3. 新 Orchestrator 返回结构化 409，Backend 保留稳定错误码。
4. 每个场景执行不计费的契约/Schema smoke。
5. Redis、Provider、Frappe 和缓存故障分别得到正确类别，不互相冒充。

独立仓库各自全绿不能替代这组组合门禁。

## 12. 可观测性与 SLO

浏览器 `request_id`、Frappe `run_id`、Orchestrator `trace_id` 和 LiteLLM Provider attempt 必须关联。至少记录：

- `ai_request_total` / `ai_request_success_total`
- `ai_pre_model_failure_total`
- `ai_contract_mismatch_total`
- `ai_scenario_readiness`
- `ai_provider_failure_total`
- `ai_model_fallback_total`
- `ai_model_health_snapshot_age_seconds`
- `ai_first_token_seconds`
- `ai_end_to_end_seconds`

建议初始 SLO：

- 已通过 readiness 的请求端到端成功率至少 99.5%，排除用户输入和权限拒绝。
- 生产 `AI_RUNTIME_CONTRACT_MISMATCH` 为 0；任一出现立即告警。
- readiness 失败后实例在一个探测周期内摘流。
- 模型健康结果超过 TTL 后不再作为“确定不可用”事实。

staging 已实现 `myapp-ai-slo-report-v1` 机器判定。输入可以是一次或多次 canary 报告，以及现有 `myapp-ai-load-report-v1` 压测报告；输出统一包含目标值、样本数、成功率、p95、契约错误、fallback、违规项和告警列表。默认目标为成功率 99.5%、至少 20 个样本、p95 不超过 30 秒、契约错误为 0。单次 3 个业务场景 canary 通常只足以证明功能，不足以证明 SLO，因此默认生成 `AI_SLO_INSUFFICIENT_SAMPLE` warning；最终候选可用 `AI_SLO_REQUIRE_PASS=1` 强制要求压测样本达到门槛。Webhook 仅在显式配置后发送，且可选择是否把投递失败作为发布阻断。

## 13. 分阶段实施

### Phase 0：错误语义与本地恢复

- Orchestrator Prompt 冲突返回结构化 `AI_PROMPT_VERSION_MISMATCH`。
- Backend 草稿错误解析兼容新对象与旧字符串响应。
- Web 对契约问题显示管理员恢复动作，不再提供无效模型重试。
- 重建当前 Orchestrator，恢复本地结构化草稿。

### Phase 1：运行就绪与启动门禁

- 新增 Orchestrator `/livez`、`/readyz` 和 `protocol_version`。
- Backend 提供场景级 Runtime readiness 聚合。
- development、staging、production 启动后校验实际运行容器契约。
- 增加跨仓契约测试。

### Phase 2：协议与 Prompt 解耦（已完成）

- 请求改为携带协议/Schema 能力，不再精确钉死 Prompt revision。
- Orchestrator 返回实际 Prompt revision 并由 Run 持久化。
- 建立完整 Release Manifest 和兼容矩阵。

### Phase 3：模型状态与发布治理（进行中）

- 模型健康引入 TTL、`stale/unknown/half_open`。（已完成首轮）
- 按场景计算模型资格和 fallback 链。（已完成：Agent 生命周期/能力/工具/健康资格与有序提升；意图和四类草稿结构化输出资格与有序提升）
- 分离 Provider 原生 `supports_json_schema` 与实际 `supports_structured_output`，并通过真实最小 Schema 探测持久化资格。（已完成）
- 完成有界 staging canary、确定性失败自动停止和不可变 Backend/AI 成对回滚门禁。（已完成）
- 完成多副本、`/readyz` 主动摘流、副本运行身份一致性门禁。（已完成）
- 完成 SLO 机器判定、告警状态持久化和可选 Webhook。（已完成首轮）
- 完成 stable/candidate 渐进流量切换、持久双 map、Agent release affinity、双向 drain 和阶段自动回退。（已完成）

## 14. 当前实现边界

本轮已交付 Phase 0 ～ 2，并完成 Phase 3 的健康租约、场景资格、结构化能力画像、staging 发布闭环、多副本主动摘流、SLO 首轮和 stable/candidate 渐进发布：结构化契约错误、三层健康接口、场景 readiness、实际运行容器门禁、协议/Schema 协商、响应运行元数据、Run 审计字段、Release Manifest 与兼容矩阵；Backend 持久化健康过期时间、连续失败次数和探测来源，统一派生 `effective_health_status`，Web 和 Orchestrator 不再把过期 `unavailable` 永久沿用；Agent 就绪预检按当前生命周期、策略能力、工具能力和健康状态输出有序合格链；意图和四类草稿按 `supports_structured_output` 过滤模型，自动链均可提升第一个合格 fallback。staging canary 对瞬时错误执行一次同制品重试，对确定性失败自动停止，并仅用 `passed` 报告登记精确 Backend/AI revision 与镜像身份的成对回滚目标。staging 可配置 1 ～ 10 个 Orchestrator 副本，由内部 HAProxy 按 `/readyz` 摘流；stable/candidate 双池通过持久 rollout/affinity map 分配 fresh request，并使 Agent resume 回到原 release。双向 drain 保证晋级和回滚都不会立即删除仍可能拥有 checkpoint 的 release。SLO 门禁不会把小样本结果误报为 PASS。

同一 stable 或 candidate 副本池内部仍只允许同一镜像和同一运行身份；只有两个池之间允许受治理地混跑 revision。通用 canary 不自动持有 Agent 业务权限，Agent 工具链的真实验收由专用最小权限 staging 用户和认证场景测试承担。drain 截止后的旧 release resume 会按显式退休策略失败关闭，因此生产环境必须按实际审批和恢复窗口设置足够长的 `AI_ROLLOUT_DRAIN_SECONDS`。
