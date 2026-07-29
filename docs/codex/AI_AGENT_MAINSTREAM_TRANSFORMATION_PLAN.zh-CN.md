# AI Agent 主流架构改造与生产发布方案

更新时间：2026-07-29

本文是 MyApp 从“模型驱动的受控查询工作流”升级为“可验证、可恢复、可治理的生产级企业 AI Agent”的实施方案。本文负责改造范围、目标架构、工作包、评测门禁和发布标准；现有 Runtime 协议、状态与安全设计继续以 `AI_AGENT_RUNTIME_ARCHITECTURE.zh-CN.md` 为事实源，自然语言检索和实体召回继续以 `AI_NL_RETRIEVAL_ARCHITECTURE.zh-CN.md` 为事实源。

本文中的“主流 Agent”不是指采用某个特定框架，也不是指增加多 Agent、MCP 或长期记忆，而是满足当前主流方案共同认可的工程闭环：

```text
模型自主选择受控工具和参数
  -> 应用在可信边界执行工具
  -> 工具结果作为正式 tool message 返回模型
  -> 模型在有限循环中继续决策或形成答案
  -> 全过程可持久化、可暂停、可恢复、可取消、可追踪、可评测
```

## 1. 改造结论

当前项目不需要推翻 Frappe、Orchestrator、Gateway 和 Web 的服务边界，也不需要为了追求形式上的“主流”迁移到 LangGraph、Google ADK、OpenAI Agents SDK 或 Microsoft Agent Framework。

现有目标架构已经具备正确基础：

- 单 Agent 优先，而不是过早拆分多 Agent。
- Frappe 是身份、公司、权限和 ERP 事实的唯一权威。
- 模型只能调用白名单工具，不能访问数据库、ORM 或原始 DocType 过滤器。
- 工具参数使用严格 Schema，工具执行使用能力令牌和幂等键。
- Run、Step、检查点、取消、恢复、人工审批、Trace 和治理策略已经形成基础设施。
- 确定性写业务继续使用“结构化草稿 + 用户确认 + 正式领域服务”的 Workflow。

当前不能对外称为“完整主流 Agent”的主要原因不是关键词优先级，而是以下四个发布阻断项：

1. staging 没有已发布 Runtime Policy，真实请求仍使用兼容查询路径，Agent Step 为 0。
2. 当前 Agent 离线评测从数据集直接读取预设 trajectory，没有实际运行 `AgentRuntime`。
3. 同步与 SSE 使用两套控制流，工具完成后的继续决策语义不完全一致。
4. Output Guardrail 主要检查密钥和提示词泄露，尚未执行正式业务事实 Grounding 校验。

改造目标不是取消兼容路径，而是使它成为明确、可观测的降级通道；正常受控范围内的请求应优先进入经过发布门禁的真实 Agent Runtime。

## 2. 主流架构基线

本方案采用 OpenAI、Anthropic、Google ADK、Microsoft Agent Framework 和 LangGraph 当前公开方案的共同部分，不绑定单一供应商实现。

### 2.1 Agent 与 Workflow 分工

Agent 适用于：

- 用户表达开放、无法可靠预先写死步骤。
- 模型需要根据当前上下文选择工具和生成参数。
- 工具结果可能影响下一步工具选择。
- 空结果、歧义或部分结果需要有限修正或澄清。

Workflow 适用于：

- 执行步骤明确，顺序和状态转换必须确定。
- 涉及正式单据、库存、资金、审批或其他副作用。
- 可以用普通函数、状态机或领域服务可靠完成。
- 需要稳定回滚、版本锁和业务幂等。

MyApp 的最终组合应为：

```text
自然语言入口
  ├─ 开放只读查询 -> 单 Agent + 白名单工具循环
  ├─ 明确写意图 -> 确定性草稿 Workflow
  ├─ 已确认草稿 -> 正式领域服务 + 业务幂等
  └─ 高风险动作 -> 专业页面或 Agent 工具审批后执行
```

### 2.2 单 Agent 优先

商品、订单和报表查询共享同一用户目标、同一公司权限和同一 ERP 事实边界，当前应继续使用一个受控 Agent。只有出现以下证据时才考虑多 Agent：

- 单 Agent 指令和工具数量导致稳定的工具选择退化。
- 单次任务需要多个独立专业上下文，超过模型上下文或权限边界。
- 轨迹评测证明专用 Agent 的质量显著高于单 Agent。
- 不同 Agent 必须由不同团队、权限、模型或成本策略独立治理。

不得仅因为某个框架支持 handoff、A2A 或 agents-as-tools 就引入多 Agent。

### 2.3 可信应用拥有执行权

模型拥有“提出决策”的权力，不拥有“绕过业务系统执行”的权力：

- Orchestrator 拥有 Agent loop、模型调用、工具协议和运行预算。
- Frappe 拥有用户身份、公司范围、记录权限、业务事实和正式写入。
- Web/Mobile 只通过 Frappe Gateway 交互，不持有内部 Token。
- LiteLLM 负责模型路由，不成为 ERP 权限主体。
- Qdrant 只提供候选召回，不成为价格、库存、订单或权限事实源。

## 3. 当前基线与目标状态

| 能力             | 当前状态                                           | 目标状态                                          |
| ---------------- | -------------------------------------------------- | ------------------------------------------------- |
| 只读语义理解     | 兼容路径由结构化意图模型生成场景和过滤参数         | 正常路径由 Agent 直接选择白名单工具               |
| 工具执行         | 兼容路径由 Frappe 预查询；Agent Runtime 代码已存在 | 已发布范围内由真实 tool loop 执行                 |
| 同步/SSE         | 存在重复控制流和不同结束条件                       | 共享一个核心循环，只更换事件消费者                |
| Agent 评测       | 单元测试使用 Mock；离线 trajectory 来自数据集预置  | 离线执行真实 Runtime，live 执行真实模型和工具轨迹 |
| Output Guardrail | 密钥、Token、系统提示泄露正则                      | 增加业务事实、引用、状态和完整性 Grounding 校验   |
| staging 策略     | 无已发布 Runtime Policy，兼容模式                  | 限公司、限角色、限模型、可回滚的灰度 Agent Policy |
| 写操作           | 草稿 Workflow + 人工确认                           | 保持不变；敏感 Agent 工具另行试点                 |
| 多 Agent         | 未引入                                             | 继续暂缓，除非评测证明必要                        |

## 4. 目标运行架构

```text
Web / Mobile
  -> Frappe AI Gateway
     -> 写意图安全分流
        -> Draft Workflow -> 用户确认 -> 正式领域服务
     -> Agent readiness
        ├─ Ready
        │  -> 创建 Run + capability token
        │  -> MyApp AI Orchestrator Agent Engine
        │     -> Model Decision
        │     -> Tool Request
        │     -> Frappe Tool Boundary
        │     -> Tool Result
        │     -> 下一次 Model Decision / Clarification / Final Answer
        │  -> Grounding Guardrail
        │  -> 持久化并返回同步结果或 SSE 事件
        └─ Not Ready
           -> Compatibility Workflow
              -> Structured Intent
              -> Frappe Read Query
              -> Model Summary
              -> 明确 warning 与降级审计
```

必须保留以下硬边界：

- Agent Ready 由已发布策略和已验证模型决定，不能只看环境变量开关。
- Agent 创建后发生的治理、模型、工具或检查点错误失败关闭，不自动复制成第二个兼容 Run。
- Compatibility Workflow 不得伪造 Agent Step 或 Tool Calling 轨迹。
- 写意图安全分流不依赖普通只读场景关键词，而只负责阻止正式副作用进入只读 Agent。

## 5. 统一 Agent Engine

### 5.1 一个核心循环

同步和 SSE 必须调用同一个 `AgentEngine`，不能分别维护业务决策循环。核心引擎只产生规范化事件：

```text
run_started
input_guardrail_completed
model_started
model_decision
tool_approval_required
tool_started
tool_completed
output_delta
output_guardrail_completed
run_completed
run_failed
run_cancelled
```

传输层只决定如何消费事件：

- 同步接口：收集事件并返回最终 `AgentResponse`。
- SSE 接口：按安全策略实时转发事件并在结束时返回相同终态。
- 恢复接口：从持久检查点重新创建相同事件流。

禁止出现“同步允许继续调用工具，但 SSE 强制结束工具循环”的语义差异。

### 5.2 规范化循环

参考伪代码：

```text
load_or_create_checkpoint()
run_input_guardrail()

while model_steps < max_model_steps:
    assert_run_not_cancelled()
    decision = model(messages, tools=allowed_tools, tool_choice=auto)
    persist_model_decision(decision)

    if decision.has_tool_calls:
        for call in decision.tool_calls:
            validate_tool_and_arguments(call)
            if approval_required(call):
                persist_waiting_approval(call)
                pause_same_run()
            result = execute_idempotent_tool(call)
            result = sanitize_tool_result(result)
            append_role_tool_message(result)
            persist_tool_checkpoint(result)
        continue

    final = decision.content
    grounded = validate_grounded_output(final, tool_results, citations)
    persist_output_checkpoint(grounded)
    complete_run()
    return

fail_with_budget_error()
```

### 5.3 流式输出规则

- 模型决策阶段和最终回答阶段都可以使用真实上游流式协议。
- Tool Calling 参数 delta 不直接作为用户可见文本，应聚合并通过 Schema 校验后再发工具事件。
- 最终文本必须先经过增量敏感信息检测；保留安全尾部，完整输出通过后再发送尾部。
- 任何已发送的业务事实都必须满足流式 Grounding 策略。不能先发送未经验证的金额或单号，再在结束时判定失败。
- SSE 断开时关闭上游流，保留最近安全检查点；不保存半段正式回答。

### 5.4 循环预算

预算应按策略配置并进入 Run 审计：

- 最大模型步骤。
- 最大工具调用次数。
- 单工具超时。
- Run 总 deadline。
- 累计输入、输出和 reasoning Token。
- 单次请求和日/月成本预算。
- 空结果修正次数。
- 同一工具同参数重复调用次数。

当前三个只读工具可继续使用较低预算。扩展跨域查询后，应基于真实轨迹分布调整，而不是直接提高到无界循环。

## 6. 工具平台改造

### 6.1 工具定义必须版本化

每个工具定义至少包含：

```json
{
  "name": "search_products",
  "version": "v1",
  "description": "...",
  "input_schema": {},
  "result_schema": {},
  "risk_level": "L1_READ_ONLY",
  "side_effect": false,
  "approval": { "required": false },
  "timeout_seconds": 20,
  "max_result_count": 8,
  "required_scopes": ["ai-agent-tool:search_products"]
}
```

工具版本必须进入：

- Prompt/工具定义哈希。
- Agent Run 和 Step。
- Runtime Policy。
- Trace metadata。
- 评测报告。
- 发布和回滚记录。

工具 Schema 或含义变化时不能静默覆盖旧版本。

### 6.2 工具设计原则

- 工具名称表达业务目标，不暴露数据库实现。
- 参数采用模型容易正确生成的业务字段和枚举。
- 工具描述说明适用场景、禁止场景、边界和典型例子。
- 参数尽量防错，避免让模型组合原始过滤器。
- 工具返回稳定状态，而不是只依赖 HTTP 成功或失败。
- 空结果、歧义、权限拒绝、暂时失败和永久失败必须区分。
- 工具结果返回给模型前执行字段最小化和提示注入清理。

### 6.3 工具结果信封

统一结果继续使用：

```json
{
  "call_id": "call_...",
  "tool": "search_products",
  "tool_version": "v1",
  "status": "ok | not_found | ambiguous | denied | retryable_error | fatal_error",
  "data": {},
  "model_context": {},
  "citations": [],
  "completeness": {
    "is_truncated": false,
    "visible_count": 1,
    "total_count": 1,
    "total_count_known": true
  },
  "error": null,
  "retryable": false
}
```

模型只能消费 `model_context`、稳定状态、可公开错误和引用；UI 可按权限消费额外 `data`。

### 6.4 工具执行安全

- Frappe 必须使用当前用户重新检查角色、公司和记录权限。
- capability token 绑定 Run、用户、公司、允许工具、版本和到期时间。
- `run_id + call_id` 同时绑定工具名、版本和规范化参数哈希。
- 相同调用重放返回持久结果；不同参数复用同一 Call ID 失败关闭。
- 写工具还必须绑定业务 `request_id`、目标对象、审批记录和领域服务幂等。

## 7. Grounding 与 Guardrail

### 7.1 分层 Guardrail

```text
Input Guardrail
  -> Model Decision Guardrail
  -> Tool Argument Guardrail
  -> Tool Execution Authorization
  -> Tool Result Sanitization
  -> Output Grounding Guardrail
  -> Output Safety Guardrail
```

任何单一正则、Prompt 或模型判断都不能独自承担安全边界。

### 7.2 输入层

- 限制消息数量、字符、估算 Token 和附件大小。
- 检查密钥提取、系统提示泄露、明确越权和不允许的写操作诱导。
- 不把正常业务文本仅因包含“忽略”等词直接判为攻击；应结合来源和上下文。
- 用户输入被阻断时返回稳定错误码和可理解说明。

### 7.3 工具结果层

所有业务字段都视为不可信数据：

- 删除敏感键和内部凭据。
- 标记或移除明显的指令式内容。
- 限制嵌套深度、数组长度和总字节数。
- 保留原始数据哈希，便于审计清理前后差异。
- 模型上下文和 UI 数据使用不同字段裁剪策略。

工具结果中的商品名、客户名、备注等文本即使包含提示注入，也只能作为数据，不得改变 Agent 策略、工具范围或审批要求。

### 7.4 业务事实 Grounding

新增确定性的 `validate_grounded_output`，至少验证：

- 回答中的业务标识符来自本 Run citation 或 tool result。
- 金额、数量、库存、价格和日期能够映射到工具返回字段。
- `not_found` 不得被描述为已找到。
- `ambiguous` 不得被描述为唯一确定结果。
- `denied` 不得被描述为没有数据或不存在。
- 截断结果不得被描述为完整列表。
- 草稿不得被描述为已经创建、提交或生效。
- 回答引用的公司与 Run 公司一致。

实现可分两层：

1. 确定性提取和校验业务标识符、数字、状态与 citation。
2. 对无法完全确定的自然语言陈述使用独立受限判定器，输出严格 Schema；该判定器只能阻断或要求重写，不能补充业务事实。

Grounding 失败时：

- 尚未向客户端发送内容：允许在预算内要求模型基于同一工具结果重写一次。
- 已经流式发送安全片段：终止输出并返回稳定错误，不得继续拼接修正文本。
- 重写仍失败：Run 标记失败，保留工具结果供用户打开结构化结果面板。

### 7.5 输出安全

继续检查：

- 系统 Prompt、开发者指令和内部策略泄露。
- Bearer Token、API Key、Cookie、能力令牌和内部错误。
- 未授权记录、跨公司数据和不应公开的 Provider 诊断。

## 8. 状态、上下文与记忆

### 8.1 会话状态

继续使用服务端拥有的 `conversation-state-v1`：

- 只保存当前会话中消解指代所需的小型工作状态。
- 不缓存实时价格、库存、余额、订单状态或权限结果。
- 每轮通过正式工具重新读取 ERP 事实。
- 状态更新使用乐观版本；冲突不应破坏当前回答。

### 8.2 Agent 检查点

检查点必须保存恢复所需的最小充分状态：

- Prompt、模型、工具定义和策略版本。
- 已规范化消息。
- 已完成与待执行 tool calls。
- 工具结果、引用和累计预算。
- 当前阶段、下一模型步骤和审批绑定。
- Grounding 状态和已安全发送的输出边界。

恢复不得重新解释已经审批的工具调用，也不得重复执行已完成工具。

### 8.3 长期记忆

当前不自动引入跨会话长期记忆。只有满足以下条件后才立项：

- 有明确业务用途和删除/更正机制。
- 用户可查看、控制和撤销被记住的信息。
- 数据保留、跨公司隔离和权限继承完成评审。
- 评测证明长期记忆显著提升任务质量。

商品向量索引属于业务候选召回，不等同于用户长期记忆。

## 9. 真实 Agent 评测体系

### 9.1 当前评测缺口

现有 Agent 离线用例不能再把数据集中的预设 trajectory 直接当成实际轨迹评分。预设 trajectory 可以作为 expected trajectory，但 actual trajectory 必须来自被测 Runtime。

评测必须区分：

- `expected_trajectory`：期望的工具、参数、状态和预算。
- `actual_trajectory`：AgentEngine 真实产生的模型决策和工具事件。
- `provider_replay`：模型响应回放，只用于确定性 Runtime 单元测试。

### 9.2 四层评测

#### Layer 1：确定性 Runtime 测试

- Mock 模型返回真实 `tool_calls` 响应。
- Mock Frappe Tool API 返回正式工具信封。
- 实际执行 `AgentRuntime/AgentEngine`。
- 验证状态迁移、role=tool、调用预算、检查点、恢复和幂等。
- 同一测试同时运行同步收集器和 SSE 收集器，比较规范化轨迹完全一致。

#### Layer 2：Provider live tool-selection 评测

- 使用真实候选模型和真实 Function Calling。
- 工具执行使用合成、无敏感数据的受控 Tool Sandbox。
- actual trajectory 必须来自模型真实工具调用。
- 验证工具选择、参数、空结果修正、禁止工具和最终回答。
- 报告记录模型别名、Provider 模型、Prompt、工具版本和数据集版本。

#### Layer 3：staging ERP 端到端评测

- 使用专用测试公司、角色和可回收测试数据。
- 从 Web/Gateway 发起真实同步和 SSE 请求。
- 验证 Frappe 权限、能力令牌、工具执行、引用、取消、恢复和 Trace。
- 真实业务账号不得读取测试账号无权访问的数据。
- 测试产生的草稿、Run 和审计必须可归档；正式写动作默认不进入本层。

#### Layer 4：红队与故障注入

- 用户提示注入、工具结果提示注入和混合语言绕过。
- Provider 超时、429、5xx、空响应和非法 tool arguments。
- Redis、Frappe Tool API、Langfuse 和 Qdrant 故障。
- 客户端断开、进程重启、检查点失败和审批并发。
- `call_id` 重放、参数替换、过期 capability 和跨 Run Token。

### 9.3 数据集覆盖

critical 集至少包含：

- “查询一下有没有带莫字的商品”及不少于 20 个自然语言变体。
- 商品编码、条码、名称、昵称、规格、用途和错别字。
- 单个和多个订单实体、日期、状态、金额、排序和数量。
- 销售、采购、现金流、应收应付相近口径。
- 空结果后一次修正、第二次停止。
- 歧义时展示候选或请求澄清。
- 无权限与不存在的区别。
- 商品和订单组合问题、多工具调用和依赖式调用。
- 会话指代：“它”“刚才那个”“只看未完成”“换成采购”。
- 同步与 SSE 轨迹一致性。
- 取消、恢复、审批通过和审批拒绝。

### 9.4 发布指标

候选 Runtime Policy 至少满足：

| 指标                              | 门槛  |
| --------------------------------- | ----- |
| critical 用例通过率               | 100%  |
| 工具选择准确率                    | ≥ 98% |
| critical 工具参数准确率           | 100%  |
| 普通工具参数准确率                | ≥ 95% |
| 禁止工具调用                      | 0     |
| 跨公司/越权泄露                   | 0     |
| Grounding 关键事实错误            | 0     |
| 空结果重试超预算                  | 0     |
| 同步/SSE 规范化轨迹差异           | 0     |
| `call_id` 重放重复副作用          | 0     |
| 取消后继续产生工具调用            | 0     |
| Provider/基础设施故障稳定错误覆盖 | 100%  |

普通场景整体通过率不得低于 95%。延迟和成本不使用单一固定数值，应按模型策略设置 p50、p95 和每成功任务成本预算。

## 10. Runtime Policy 与 staging 发布

### 10.1 发布前置条件

只有以下条件全部满足时才允许发布 Agent Policy：

- 候选模型真实 Function Calling 探测通过。
- `supports_tools=true` 且模型状态为 `validated/active`。
- Layer 1 和 Layer 2 full gate 通过。
- 当前 Prompt、工具版本、Runtime commit 与报告完全一致。
- 策略无同优先级歧义。
- fallback 模型同样通过工具能力和 full gate。
- 回滚目标是已验证的 last-known-good Policy。

### 10.2 首次灰度范围

首次 staging Policy 建议：

- 环境：`staging`。
- 场景：`general` 只读 Agent。
- 公司：专用测试公司或明确 allowlist。
- 角色：AI 测试角色和治理角色。
- 用户灰度：稳定哈希 5% 或显式 allowlist。
- 工具：三个现有 L1 只读工具。
- 写工具：无。
- 模型：一个主模型和一个均已验证的 fallback。
- 最大步骤和工具调用：保持低预算。

### 10.3 灰度推进

```text
专用测试账号
  -> 内部治理角色
  -> 单个真实公司少量用户
  -> 25% 稳定灰度
  -> 50% 稳定灰度
  -> staging 全量
  -> production 小流量
```

每阶段至少观察：

- 工具选择与参数失败率。
- Grounding 阻断与重写率。
- 兼容路径比例和原因。
- p50/p95 延迟、首 Token 和总成本。
- 取消、恢复和超时。
- 用户负反馈和人工抽检结果。

不得通过修改灰度哈希、数据库状态或环境变量绕过正式发布流程。

### 10.4 回滚

回滚必须原子切换到 last-known-good Policy，停止创建新的候选 Agent Run。已经运行中的 Run：

- 未执行工具：安全取消或按原策略完成，不能切换中途模型策略。
- 已完成只读工具：允许基于原工具结果完成回答。
- waiting approval：继续绑定原策略、模型、工具版本和参数哈希。
- 新请求：使用回滚策略；回滚策略也不可用时进入明确的兼容路径。

## 11. 观测与审计

每个真实 Agent Run 必须形成：

```text
agent.run
  input.guardrail
  model.decision
  tool.call
    tool.argument_guardrail
    frappe.authorization
    frappe.execution
    tool.result_guardrail
  model.decision / grounded_generation
  output.grounding_guardrail
  output.safety_guardrail
```

必须记录脱敏后的：

- Run、Conversation、用户哈希、公司和场景。
- Runtime Policy、Prompt、模型和工具版本。
- 决策类型、工具名、参数哈希和结果状态。
- Token、延迟、重试、取消、恢复和错误码。
- Grounding 校验结果、阻断原因和重写次数。
- compatibility fallback 原因。

默认不上传业务原文。Langfuse 故障继续失败开放，但 Frappe 本地 Run/Step/审计持久化失败必须失败关闭。

## 12. Web 与 Mobile 体验

### 12.1 用户可见事件

用户应看到真实状态，而不是技术日志：

- 正在理解请求。
- 正在查询商品、单据或报表。
- 找到候选，正在整理结果。
- 需要用户确认或审批。
- 查询范围受限或结果被截断。
- 已取消、可恢复或暂时失败。

不得展示虚假的“正在调用工具”动画，也不得把模型尚未提出的步骤提前渲染。

### 12.2 流式体验

- Web 不人工逐字符拆分或增加固定延迟。
- 直接透传上游安全 delta。
- 工具事件和文字 delta 使用不同事件类型。
- Agent 无需工具即可回答时也应使用真实上游流式输出。
- 同一 Run 的同步和 SSE 最终消息、citation、工具轨迹和状态必须一致。

### 12.3 诊断展示

普通业务用户只看到业务可理解状态、引用和稳定错误。模型 alias、Provider、策略、Token、Trace 和 Guardrail 细节只向授权治理角色开放。

Mobile 在 Agent Policy 扩大到普通用户前必须补齐：

- waiting approval。
- 取消与恢复。
- 工具状态和引用。
- 稳定错误与兼容模式 warning。

## 13. 分阶段实施工作包

### P0：真实 Agent 证明闭环

#### A0.1 统一同步和 SSE 核心循环

所有者：`services/myapp-ai`

状态：2026-07-29 已完成本地实现和验证，尚未提交、推送或部署。`AgentRuntime` 已收敛为传输适配器，统一 `AgentEngine` 负责同步、SSE、同步恢复和 SSE 恢复；多工具增量 Function Calling 与四入口规范化轨迹一致性测试已通过。

- 抽取单一事件驱动 `AgentEngine`。
- 同步、SSE、同步恢复和 SSE 恢复使用同一循环。
- 删除传输层中的独立工具决策分支。
- 增加规范化轨迹一致性测试。

完成标准：同一模型回放和工具回放下，同步与 SSE 的模型决策、工具调用、检查点和终态完全一致。

#### A0.2 重构 Agent 评测执行器

所有者：`services/myapp-ai`

状态：2026-07-29 已完成本地实现和验证，尚未提交、推送、执行计费 live gate 或部署。Agent case 已构造正式 `AgentRequest` 并运行统一 `AgentEngine`；offline 使用正式 Function Calling provider replay 和合成 Frappe Tool API，live 使用真实模型加合成 Tool Sandbox。数据集中的 `expected_trajectory` 只参与评分，actual trajectory 只从 Engine `run_completed.tool_calls` 构造；报告已区分 `provider_replay`、`agent_runtime_replay`、`live_provider` 和 `live_tool_sandbox`，为后续 `staging_erp` 来源保留明确边界。

- Agent case 实际构造 `AgentRequest` 并运行 `AgentEngine`。
- provider replay 返回正式 Function Calling 消息，而不是只返回最终文本。
- actual trajectory 从 Runtime 事件生成。
- Agent critical case 同时支持 offline 和 live 模式。
- 报告区分 replay、live sandbox 和 staging ERP。

完成标准：删除“从 expected/replay trajectory 直接作为 actual trajectory”的路径。

#### A0.3 增加 Grounding Guardrail v1

所有者：`services/myapp-ai`、`apps/myapp`

状态：2026-07-29 已完成本地核心实现和合成回归，尚未提交、推送、部署或执行真实 staging 数据验收。Frappe 工具结果新增 `agent-grounding-v1` 公司、citation 引用和三态完整性信封；统一 `AgentEngine` 在同步/SSE 输出可见前确定性校验标识符、日期、金额/价格、库存/数量、计数、业务状态、公司和绝对完整性结论。首次失败只允许一次基于既有 tool messages、`tool_choice=none` 的受控重写，第二次失败以 `AI_AGENT_OUTPUT_GROUNDING_FAILED` 关闭且不泄露首个候选内容。完成标准中的真实 staging 数据部分仍待 P1 限范围 Policy 与 E2E 验收。

- 定义可验证事实和 citation Schema。
- 检查标识符、数字、状态、公司和完整性。
- 增加一次受控重写。
- 同步和 SSE 均失败关闭。

完成标准：合成和真实 staging 数据中，无法构造通过 Guardrail 的越权标识符、虚假金额、虚假库存或假完成状态。

### P1：staging 真实发布

#### A1.1 Provider live full gate

所有者：`services/myapp-ai`

状态：2026-07-29 已通过绑定不可变 AI commit 的 Provider live full gate，AI `14bb362d`、Backend `6f2bdecc` 和固定两个子模块指针的父仓库 `74f32ab1` 均已推送 `develop`；尚未部署或发布 staging Policy。评测报告升级为 `myapp-ai-eval-report-v2`，绑定完整 Runtime revision、Prompt 版本及内容哈希、工具版本及 Schema 哈希、请求模型别名顺序、数据集版本和 SHA-256；live runner 支持在同一 full gate 中逐个执行主模型与全部 fallback。策略治理不再在生产进程中导入或现场执行 replay fixture，而是同时验证 offline/live 两份已生成报告；任一报告与当前 Runtime/Prompt/工具/模型/数据集不一致时失败关闭。runtime 镜像会删除源目录和 site-packages 中的 `myapp_ai.evals`，固定 JSONL 只保留在开发/test 阶段。轨迹评分使用 `exact|contains` 语义约束，允许模型选择额外合法字段，并把空结果行为限定为“直接停止或最多修正一次”；结构化意图 `confidence` 只验证为 `[0,1]` 合法估计，不与 fixture 小数精确相等。仅显式安全用例允许 Provider 400/403 无内容硬拒绝，其他 Provider/基础设施错误仍失败。最终 AI revision `14bb362d989147df1244207b937070460645ff4b` 的 offline full gate 为 `32/32 PASS`，同 revision、同 Prompt/工具/数据集的 live full gate 按主模型 `nvap-gpt-5.6-sol`、fallback `nvap-gpt-5.6-terra` 顺序执行并达到 `64/64 PASS`；所有发布指标为 `1.0`。A1.1 已完成；A1.2 仍需治理报告挂载、限范围 Policy 和 staging ERP E2E 的独立授权。

增强验证状态：后续审查发现上述 revision 的真实 Agent live case 只覆盖商品工具，且当时 runner 会依据 expected trajectory 缩窄候选工具，因此该报告不足以单独证明三个白名单工具、多工具和多轮上下文下的自主选择。增强最终提交并推送为 AI `cf59aacdd64243643fe770cbcbbb6d8ec31d1438`：数据集扩展至 36 条，Agent case 默认同时暴露完整 `TOOL_REGISTRY`，新增业务单据、现金流、商品加销售报表双工具和销售转采购报表多轮场景，并让合成 Tool Sandbox Grounding 与真实 Backend 契约一致。绑定该 revision 的 offline full gate 为 `36/36 PASS`，Sol/Terra live full gate 为 `72/72 PASS`；数据集、Prompt、工具 manifest 和模型顺序全部匹配，所有发布指标为 `1.0`，本地治理验证返回 `release_gate_eligible=true`。宿主机和 Docker 均为 140 tests OK，远端 CI/CodeQL 成功。`gpt-5.6-luna` 的四场景 partial `4/4 PASS` 继续作为额外旁证，不参与当前 Policy 模型绑定。A1.1 增强门禁已完成，可以进入 A1.2 的 staging 报告挂载、限范围 Policy 和真实 ERP E2E。

- 选择主模型和 fallback。
- 执行真实 tool-selection 数据集。
- 记录 Prompt、工具、模型和 Runtime 版本。
- 报告进入治理发布验证。

#### A1.2 staging 限范围 Runtime Policy

所有者：`apps/myapp`、父部署仓库

- 创建、评审并发布测试范围 Policy。
- 验证 readiness 和策略快照握手。
- 执行同步、SSE、取消、恢复和真实权限 E2E。
- 确认 Agent Step 大于 0 且工具结果来自真实 Frappe Tool API。

#### A1.3 红队与故障注入

所有者：三个服务仓库和父部署仓库

- 工具结果提示注入。
- Provider、Redis、Frappe 和检查点故障。
- 进程中断、取消竞态和 capability 重放。
- 形成可重复自动化报告。

### P2：稳定运营和能力扩展

#### A2.1 工具注册表治理

- 工具版本、Schema 哈希和发布记录。
- 工具级质量、延迟、成本和失败率。
- 工具弃用和兼容期限。

#### A2.2 首个敏感工具试点

只有只读 Agent 稳定运行后再选择一个低风险、可回滚、可幂等的动作工具。优先考虑提交前仍可人工复核的动作，不优先接入付款、退款、取消或库存正式过账。

试点必须补充：

- L2/L3 风险定义。
- 动态审批角色和阈值。
- 业务幂等和补偿路径。
- 同 Run 审批恢复。
- 审批拒绝后的模型解释。

#### A2.3 是否引入多 Agent 的评审

只有数据证明单 Agent 在工具选择、上下文或职责隔离上达到瓶颈时，才提交独立 ADR。多 Agent 不是本改造完成标准。

## 14. 仓库实施边界

### `services/myapp-ai`

- AgentEngine、模型循环、同步/SSE 事件。
- 工具定义、Guardrail、检查点协议客户端。
- offline/live trajectory eval。
- Langfuse Agent Span。

### `apps/myapp`

- readiness、Policy 和模型治理。
- Run/Step/Approval/Capability 持久化。
- 工具执行、权限、幂等和业务事实。
- compatibility fallback 和用户范围审计。

### `frontend/myapp-web`

- 真实 Agent 事件、引用、取消、恢复和审批体验。
- 普通用户与治理角色诊断隔离。
- 同步/SSE 契约映射和浏览器 E2E。

### `frontend/myapp-mobile`

- 在 Policy 扩大前补齐 waiting approval、取消、恢复和工具事件。

### 父仓库

- Compose、Secret、Runtime Policy 报告挂载和环境隔离。
- staging/production 构建、部署、健康检查、故障注入和回滚。
- 跨仓库版本固定与发布交接。

## 15. 完成定义

只有以下条件全部满足，才允许把 MyApp 描述为“已经上线的主流企业 AI Agent”：

- staging 和目标生产范围存在正式发布的 Runtime Policy。
- 真实请求集合分别覆盖并验证三个白名单工具类型，Agent Step 不为 0；不要求单个 Run 在默认两次工具预算内同时调用三个工具。
- 工具结果使用正式 `role=tool` 回传，模型可以基于结果继续决策。
- 同步与 SSE 使用相同核心循环并通过轨迹一致性门禁。
- offline Agent 评测实际运行 Runtime，不注入伪 actual trajectory。
- Provider live tool-selection full gate 通过。
- staging ERP E2E、权限隔离、取消、恢复和故障注入通过。
- Output Grounding 可以阻断虚假业务标识符、金额、库存、状态和完整性陈述。
- Run、Step、工具、Guardrail、Trace 和 Policy 版本可以完整解释每个回答。
- compatibility fallback 比例、原因和用户 warning 可观测。
- 写操作仍遵守草稿、确认、审批、幂等和正式领域服务边界。
- 没有通过关闭治理、伪造报告或修改数据库状态绕过门禁。

在此之前，推荐对外口径为：

> MyApp 已具备模型驱动的企业查询和生产级 Agent Runtime 基础设施，当前真实 Agent 正在受控 staging 发布与轨迹评测阶段。

## 16. 明确非目标

- 不让模型直接连接 MariaDB、Frappe ORM 或 Qdrant 管理接口。
- 不把所有业务流程改成 Agent。
- 不自动提交销售、采购、库存、付款、退款或取消单据。
- 不因“主流”标签强制迁移到某个 Agent 框架。
- 不在没有评测证据时增加多 Agent。
- 不把 MCP、A2A、长期记忆或 Computer Use 作为首期完成条件。
- 不用关键词正则代替模型决策，也不删除必要的确定性安全分流和失败降级。

## 17. 外部设计依据

- OpenAI Agents SDK：<https://developers.openai.com/api/docs/guides/agents>
- OpenAI Agent Evals：<https://developers.openai.com/api/docs/guides/agent-evals>
- OpenAI Safety Best Practices：<https://developers.openai.com/api/docs/guides/safety-best-practices>
- Anthropic Building Effective Agents：<https://www.anthropic.com/research/building-effective-agents>
- Google Agent Development Kit：<https://google.github.io/adk-docs/agents/>
- Google ADK Evaluation：<https://google.github.io/adk-docs/evaluate/>
- Microsoft Agent Framework：<https://learn.microsoft.com/en-us/agent-framework/overview/agent-framework-overview>
- Microsoft Agent Framework Workflows：<https://learn.microsoft.com/en-us/agent-framework/workflows/>
- LangGraph Overview：<https://docs.langchain.com/oss/python/langgraph/overview>
- LangGraph Workflows and Agents：<https://docs.langchain.com/oss/python/langgraph/workflows-agents>
