# AI Agent Runtime 架构设计

更新时间：2026-07-28

本文是 MyApp 生产级单 Agent Runtime 的设计事实源。自然语言检索、实体解析和向量召回的细节继续以 `AI_NL_RETRIEVAL_ARCHITECTURE.zh-CN.md` 为准；本文负责 Agent 循环、工具协议、身份委托、运行状态、审批恢复、观测和评测边界。

## 当前实现状态

截至 2026-07-28，生产级只读单 Agent Runtime 的代码和本地数据库迁移已经完成：

- 模型使用正式 Function Calling 自主选择三个白名单只读工具，工具结果通过 `role=tool` 回传。
- Frappe 已落地 Run/Step、短期能力令牌、用户/公司/工具绑定、`run_id + call_id` 幂等和取消状态。
- 工具调用会在 Run 行锁内再次检查相同 `call_id`；并发重放在首个调用完成后复用持久结果，不再竞争唯一键或重复执行。
- 最终 grounded answer 使用真实上游 SSE；模型决策、工具开始/完成、首 Token 和完成事件均来自真实执行。
- 模型治理已增加强制 Function Calling 探测和 `supports_tools`，生产 Agent 对未验证模型失败关闭。
- 上下文按估算 Token 预算保留最近完整会话/工具单元，不再只依赖 20 条消息上限。
- Agent Runtime 已增加统一 Run deadline、累计 Token 上限和模型等待期间的主动取消轮询；用户取消不再只修改数据库状态，也会取消 Orchestrator 中正在等待的异步上游请求。
- 输入、工具结果和输出 Guardrail 已成为独立可阻断运行步骤；工具参数按与模型定义一致的严格 Schema 二次校验，工具结果进入模型前清除敏感键并移除指令式内容。
- Langfuse 已记录 Agent Run、Model Decision、Tool Call 和 Guardrail 父子 Span；固定评测已覆盖工具选择、参数、空结果有限重试、调用预算和禁止越权工具。
- Frappe 已持久化 `agent-state-v1` 安全检查点：输入 Guardrail、模型工具决策、每个正式 `role=tool` 结果和输出 Guardrail 都是可恢复边界；模型决策中的待执行工具调用也会随检查点保存。
- Orchestrator 与 Frappe Gateway 已提供同步和 SSE 恢复入口。失败/过期 Run 只能由原所有者恢复；Frappe 会校验会话、检查点、原 Prompt 版本和模型别名，原子重新激活 Run 并重新签发能力令牌。恢复时再次校验工具白名单和参数 Schema；已完成工具不重跑，模型已作出的工具决策不重新解释，已完成输出可直接回放。
- 检查点与运行事件写入同时要求长期服务身份和当前 Run 能力令牌；Backend 限制检查点为 200KB、事件为 30KB，并拒绝能力令牌、Authorization、Cookie、密码等敏感字段落盘。
- `waiting_approval` 持久审批状态机已落地：Orchestrator 在敏感工具执行前提交包含原工具决策的安全检查点，Frappe 在同一事务中创建 `MyApp AI Agent Approval`、绑定 `run_id + call_id + tool + arguments_hash`、把 Run 切为 `waiting_approval` 并吊销能力令牌。批准或拒绝后重新签发令牌并恢复同一 Run；拒绝会形成结构化 `denied` 工具结果，批准后仍由工具幂等层保证只执行一次。
- 审批记录只保存裁剪参数摘要和 SHA-256，不保存能力令牌或完整敏感负载；支持 `pending / approved / rejected / expired`、乐观版本、审批原因、审批人与执行结果哈希。取消待审批 Run 会同时使未决审批失效。
- Web 已完成 `waiting_approval` 接入：SSE 暂停不会被当作流式不完整，来源会话展示审批工具、风险等级和裁剪参数摘要，Sender 在待审批期间锁定；批准或带原因拒绝后通过 Frappe 恢复同一 Run，并重新读取持久会话。审批列表对乱序响应做保护，旧请求不能覆盖新暂停状态。
- 只读 Agent 与原有销售/采购/库存/商品草稿场景保持隔离，自动场景中的明确写意图继续进入既有草稿加人工复核链路，不会被只读工具集截获。
- Frappe 在创建新只读 Agent Run 前会镜像 Orchestrator 的发布策略选择规则，检查场景、环境、生效期、灰度、公司/角色优先级、唯一胜出策略，以及主模型、fallback 和显式固定模型的工具能力。只有预检通过才签发 Agent 能力令牌。
- 新 Agent Run 同时携带 Frappe 预检命中的策略编码和版本。Orchestrator 先复用匹配的短缓存；若策略版本或主模型、fallback、显式固定模型的状态/工具能力元数据不一致，则在执行模型前强制刷新一次。刷新后仍不一致时失败关闭，避免策略刚发布、回滚或模型探测刚更新后的 30 秒缓存窗口使用旧治理快照。
- Agent Runtime 开关已开启但策略尚未发布、不匹配、存在同优先级歧义或模型工具能力未验证时，新请求不会进入一个必然失败的 Agent Run，而是使用“结构化意图模型 → Frappe 只读预查询 → 模型总结”兼容路径，并返回用户可见 warning。除四类写草稿的确定性安全分流外，兼容路径不要求本地关键词先命中业务场景；关键词/DSL 仅在意图模型不可用、低置信度或输出非法时降级。已经进入 Agent 循环后的真实治理、模型或工具错误仍失败关闭，不自动重放或产生第二次模型费用。
- `bench --site localhost migrate` 已成功执行 `create_ai_agent_runtime_tables`、`create_ai_agent_approval_table` 与 `add_ai_model_supports_tools`。

尚未对外宣称“全部生产验收完成”的主要条件为：Mobile 尚未接入待审批展示和批准/拒绝交互；Web 仍需在 staging 使用真实模型、真实权限角色、进程中断、审批并发与网络故障注入跑完整发布门禁；首个敏感工具接入时补充该工具的权限、业务幂等和审批角色策略。当前三个 Agent 工具仍全部只读，正式写操作继续使用既有草稿加人工确认，因此审批基础设施不会改变原有对话和草稿体验。

## 1. 目标与定位

目标不是让模型直接访问 ERP，也不是引入无边界自主执行，而是形成以下受控闭环：

```text
用户目标
  -> 模型选择白名单工具并生成严格参数
  -> Frappe 校验短期能力令牌、用户、公司、权限和参数
  -> Frappe 幂等执行工具并返回结构化结果
  -> 结果以 tool result 回传模型
  -> 模型在有限步数内继续调用、请求澄清或生成最终回答
  -> 全过程持久化、可取消、可恢复、可追踪、可评测
```

完成后的系统定位是“生产级现代企业 AI Agent”。多 Agent、MCP、长期语义记忆和自动提交正式单据不是本阶段验收条件。

## 2. 责任边界

### 2.1 Orchestrator

- 持有单次 Agent Run 的有限工具循环。
- 向模型提供工具名称、描述和 JSON Schema。
- 解析 `tool_calls`，使用 Frappe 签发的短期能力令牌调用工具执行端点。
- 将工具结果作为正式 `tool` 消息回传模型，不拼入 system prompt。
- 强制最大步数、总超时、Token/费用预算和单工具超时。
- 流式输出真实的 model/tool/run 事件。
- 记录模型、工具、Guardrail 和状态迁移 Span。

### 2.2 Frappe

- 是用户身份、公司范围、记录权限和 ERP 事实的唯一权威。
- 为每个 Run 签发短期、绑定用户/公司/Run/工具白名单的能力令牌。
- 校验工具参数，调用正式领域服务，不允许模型生成 SQL、DocType 原始过滤器或直接访问 ORM。
- 以 `call_id` 幂等执行工具，重复调用返回原结果。
- 持久化 Run、Step、工具参数摘要、结果摘要、状态、耗时和错误码。
- 写操作继续先生成草稿；正式执行仍由业务页面确认和既有幂等接口完成。

### 2.3 Web / Mobile

- 只调用 Frappe Gateway，不持有 Orchestrator Token 或 Agent 能力令牌。
- 展示真实工具生命周期事件，不伪造已经完成的工具步骤。
- 对 `waiting_approval`、`cancelled`、`failed` 和可恢复状态提供明确反馈。

## 3. 工具协议

所有工具使用统一信封：

```json
{
  "run_id": "AI-RUN-...",
  "call_id": "call_...",
  "tool": "search_products",
  "arguments": {},
  "capability_token": "opaque-short-lived-token"
}
```

执行结果：

```json
{
  "call_id": "call_...",
  "tool": "search_products",
  "status": "ok | not_found | ambiguous | denied | retryable_error | fatal_error",
  "data": {},
  "model_context": {},
  "citations": [],
  "error": null,
  "retryable": false
}
```

约束：

- `call_id` 在一个 Run 内唯一，是工具幂等键和 Trace 关联键。
- `model_context` 是字段裁剪后的模型输入；`data` 可包含仅供 Frappe/UI 使用的额外结构。
- 业务字段始终是不可信数据，不能进入 system 指令层。
- 工具错误必须使用稳定错误码，模型不得接收 Provider、SQL 或内部堆栈原文。
- 每个工具定义风险等级、允许场景、参数 Schema、最大结果数、超时和是否需要审批。

首批只读工具：

1. `search_products(query, match_mode, search_fields, limit)`
2. `query_business_documents(entities, date_from, date_to, status, sort, min_amount, limit)`
3. `get_business_report(report_type, date_from, date_to)`

## 4. Agent 循环

默认最大 3 个模型步骤、最多 2 次工具执行；单次工具失败只允许在 `retryable=true` 时重试一次。

```text
RUNNING
  -> MODEL_DECISION
     -> FINAL_ANSWER -> COMPLETED
     -> TOOL_REQUESTED
        -> TOOL_RUNNING
           -> TOOL_COMPLETED -> MODEL_DECISION
           -> TOOL_FAILED -> MODEL_DECISION 或 FAILED
           -> APPROVAL_REQUIRED -> WAITING_APPROVAL
```

停止条件：

- 模型返回最终回答且没有工具调用。
- 达到最大模型步骤、工具调用次数、总超时或预算。
- 工具返回权限拒绝或不可恢复错误。
- 用户取消。
- 需要人工审批时持久化状态并暂停；审批后恢复同一 Run，不创建伪造的新轮次。

模型第一次搜索为空时，可以修改一次受控参数；仍为空必须说明未找到或请求澄清，禁止无限扩大搜索范围。

## 5. 身份、权限和控制面

- 现有长期 Service Token 仅作为服务身份，不再单独代表最终用户授权。
- Frappe 签发随机能力令牌，数据库只保存 SHA-256；令牌绑定 `run_id`、用户、公司、允许工具和到期时间。
- Orchestrator 调用工具时同时提交服务身份和能力令牌。
- 运行事件写入和检查点读取也同时提交服务身份与能力令牌，长期 Service Token 不能单独修改任意用户 Run。
- 能力令牌默认 5 分钟到期，Run 完成、失败或取消后立即吊销。
- Chat 工具执行、向量写入、向量 alias、模型策略和反馈同步使用不同 scope；控制面不得依赖普通 Chat scope。
- 生产环境没有已验证策略快照时失败关闭；只允许使用 last-known-good 策略。无治理默认模型仅允许显式 development/test 配置。
- 上一条失败关闭规则作用于已经进入 Orchestrator Agent Runtime 的请求。Frappe 的新 Run 路由预检允许在未满足 Agent 发布门禁时选择非 Agent 兼容查询路径；它不发布策略、不伪造验证结果，也不绕过 live/full evaluation、审批和发布门禁。

## 6. Guardrail

### 输入

- 限制消息、上下文 Token 和无关请求成本。
- 检查明确的越权、密钥提取和写操作诱导。

### 工具

- JSON Schema 严格校验。
- Frappe 重新校验权限、公司、字段白名单和数量上限。
- 工具结果执行字段裁剪、指令式内容标记和敏感字段清除。

### 输出

- 正式业务事实必须能映射到本 Run 的工具结果或引用。
- 禁止把草稿描述成已执行单据。
- 禁止泄露系统 Prompt、Token、内部错误和未授权记录。

## 7. 状态、取消、恢复与幂等

Run 状态至少支持：

```text
running | waiting_approval | completed | failed | cancelled | expired
```

Step 保存：序号、类型、状态、`call_id`、工具名、参数摘要、结果摘要、开始/结束时间、耗时、错误码和 Trace Span ID。

`agent-state-v1` 检查点保存：阶段、下一模型步骤、累计 Token、运行消息、Agent Step、工具审计、工具结果、引用、Trace/Span、最终内容，以及尚未执行的模型工具决策。安全阶段为：

```text
input_guardrail -> model_decision -> waiting_approval -> tool_completed -> output_guardrail
```

- 相同 `run_id + call_id` 不重复执行工具。
- 客户端断开不代表工具可以重复执行；服务端先关闭上游流，再把 Run 标记为 cancelled/failed。
- 对产生副作用的工具必须复用全局 `request_id` 幂等机制。
- 恢复必须从持久 Step 状态继续，不重新解释已经审批或执行完成的步骤。
- `waiting_approval` 检查点的首个待执行工具必须与审批记录的 `call_id`、工具名和参数哈希完全一致；任何参数替换都会失败关闭。
- 批准和拒绝都只改变审批决定，不创建新 Run。恢复后批准项执行原调用；拒绝项作为稳定 `denied / AI_AGENT_TOOL_REJECTED` 工具结果回传模型，由模型安全解释未执行原因。
- Frappe 用户恢复接口为 `resume_ai_run_v1(run_id)` 与 `stream_ai_run_resume_v1(run_id)`；它们不接受新的用户消息，避免把“恢复”伪装成新一轮对话。
- 在 `model_decision` 或部分多工具调用后崩溃时，只执行检查点中的剩余工具；在 `tool_completed` 后崩溃时从下一模型步骤继续；在 `output_guardrail` 后崩溃时直接返回或回放已通过检查的最终内容。
- SSE 在部分文本期间不保存不完整回答；若流中断，恢复到最近工具检查点并重新生成完整最终回答，避免把未经完整输出 Guardrail 的半段文本当作正式结果。

## 8. 上下文与记忆

- 会话状态继续使用小型、服务端拥有的 `conversation-state-v1`，不缓存实时价格、库存和单据状态。
- 历史消息按模型 Token 窗口预算裁剪，而不是只按条数和字符数。
- 每轮工具都重新查询实时 ERP 事实。
- 不在本阶段引入自动长期向量记忆。

## 9. 观测与评测

每个 Run 至少记录以下父子轨迹：

```text
agent.run
  agent.model_decision
  agent.tool_call
    agent.tool_guardrail
    frappe.tool_execution
  agent.output_guardrail
```

评测必须同时覆盖最终答案和执行轨迹：

- 工具选择准确率。
- 参数准确率。
- 空结果后的有限修正。
- 歧义时澄清而不是猜测。
- 权限拒绝不得绕过。
- `call_id` 重放不得重复执行。
- 工具超时、Provider 失败和取消恢复。
- 回答中的商品、金额、库存和单号必须来自工具结果。

“查询一下有没有带莫字的商品”及其变体必须进入 critical 回归集。

## 10. 分阶段实施

### Phase A：协议与安全基础

- Run/Step/能力令牌持久化。
- Agent 请求、工具执行和结果 Schema。
- `search_products` 首个真实工具循环。
- 业务数据从 system prompt 移到 tool result。
- 生产策略失败关闭开关。

### Phase B：完整只读 Agent

- 订单和报表工具。
- SSE 真实工具事件。
- 取消、幂等和有限重试。
- 工具/输出 Guardrail。
- 模型 Tool Calling 能力探测和路由门禁。

### Phase C：观测与发布门禁

- Run/模型/工具/Guardrail 父子 Span。
- 轨迹评测、故障注入和发布阈值。
- Token 感知上下文裁剪。
- staging 真实语料验收。

## 11. 完成标准

以下条件全部满足后，才对外称为完整生产验收通过的现代 AI Agent：

- 模型真实选择工具，Frappe 不再预执行后只让模型总结。
- 至少三个只读业务工具使用统一协议和权限边界。
- 工具结果使用正式 tool message，不进入 system 指令层。
- Run 可持久化、取消，敏感动作可暂停并恢复。
- 工具调用幂等，策略和身份治理失败关闭。
- 轨迹可解释每个模型、工具和 Guardrail 步骤。
- Agent 轨迹评测和自然语言 critical 集通过发布门禁。
- 无权限、歧义、空结果和外部故障均有稳定、可恢复行为。
