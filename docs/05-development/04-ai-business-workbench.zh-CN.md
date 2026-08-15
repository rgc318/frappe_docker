# AI 业务操作台闭环设计

只读自然语言请求升级为真实单 Agent 工具循环的改造范围、评测门禁和 staging 发布顺序，见 `docs/codex/AI_AGENT_MAINSTREAM_TRANSFORMATION_PLAN.zh-CN.md`。本文继续负责业务工作台查询、草稿、确认和正式领域服务闭环，不把确定性写业务强行改造成开放 Agent。

## 1. 目标

AI 工作台不是“生成文本和跳转链接的聊天页”，而是当前账号权限范围内的业务操作入口。高频查询和低至中风险草稿应在当前上下文完成；完整业务模块用于复杂例外、后续处理和专业操作，不再是必经步骤。

本设计覆盖：

- 商品、销售订单、销售发票、采购订单和采购发票的当前页详情预览。
- 商品建档、销售订单、采购订单和库存调整草稿的当前页编辑、重新校验、确认执行和成功回执。
- 草稿中心与来源会话使用同一套编辑和执行组件。
- LiteLLM 可见模型的受控同步、自动策略选择和用户显式固定模型。
- 可选业务深链、权限、幂等、版本、审计和失败恢复。

## 2. 设计原则

1. **AI 建议与用户执行分离**：模型只生成结构化候选，正式操作必须由用户点击确认。
2. **确认不等于跳转**：用户确认可以在 AI 页面完成，安全边界由后端权限和领域服务保证。
3. **复用正式业务服务**：AI 执行层不得复制商品、订单、库存、UOM、价格或事务逻辑。
4. **渐进式披露**：摘要在消息中，完整关键字段在 Drawer，专业页面作为次级入口。
5. **版本锁定**：确认时必须提交用户看到的草稿版本；版本已变化则拒绝执行。
6. **一次草稿一次正式结果**：草稿执行后进入 `executed`，保存正式对象回执，不允许重复创建。
7. **可恢复**：网络超时后使用同一草稿 ID 和版本幂等键重试；成功回执可从草稿重新加载。
8. **可审计**：保存执行人、执行时间、目标 DocType、目标名称、请求哈希和结果哈希。
9. **业务事实可刷新**：草稿保存权威 baseline、用户 patch 和字段来源；执行前重新读取价格、UOM 换算和实时库存，漂移时生成新版本并要求重新确认。

## 3. 用户流程

### 3.1 查询

```text
自然语言查询
  → 对话内结构化表格
  → 显示回答时查询时间、公司、权限范围和截断状态
  → 可选“刷新当前数据”（不调用模型）
  → 点击单据编号
  → 当前页详情 Drawer（回答时快照 / 当前数据）
  → 可选“在业务模块打开”
```

结果面板展示查询时间、公司和当前账号权限范围；分组展示返回数量、可安全确定时的可见总量、截断状态和业务模块完整列表入口。无法权限安全确定总量时显示“未知”，不能推断为没有更多记录。刷新复用 Frappe 正式只读查询并重新检查权限，不创建 Run、不调用模型或产生模型费用。

Drawer 展示单据状态、公司、往来单位、日期、金额、已结/未结、商品行、仓库、关联单据和备注，并明确区分回答时结构化快照与当前读取数据。商品 Drawer 同样区分 citation 中的回答时价格/库存与当前商品、价格和分仓库存。业务模块深链只用于编辑、打印、付款、收发货、退货、冲销等复杂后续操作。

### 3.2 草稿

```text
自然语言
  → AI 结构化候选
  → Frappe 权限与业务校验
  → 当前页完善草稿
  → 保存草稿，系统自动校验（版本 +1）
  → 用户确认当前版本
  → execute_ai_draft_v1
  → 正式领域服务
  → executed + 正式对象回执
```

校验未通过时禁用执行，但允许继续编辑。复杂场景保留“在业务编辑器继续”，该操作不再是默认主按钮。

## 4. 风险分层

| 操作                                      | 默认呈现           | 确认要求                   | 是否建议深链 |
| ----------------------------------------- | ------------------ | -------------------------- | ------------ |
| 查询单据详情                              | Drawer             | 无额外确认                 | 可选         |
| 创建商品                                  | 当前页执行         | 明确二次确认               | 创建后可选   |
| 创建销售/采购订单                         | 当前页执行         | 明确二次确认               | 创建后可选   |
| 库存调整                                  | 当前页执行         | 展示实时前后数量并二次确认 | 创建后可选   |
| 付款、退款、取消、退货、批次/序列号、审批 | 专业页面或专用流程 | 专项确认/审批              | 默认         |

首期原地执行只覆盖现有四类草稿，不把付款、退款、取消、退货或审批权限扩张到 AI。

## 5. 后端契约

### 5.1 `execute_ai_draft_v1`

请求：

```json
{
  "draft_id": "AI-DRAFT-...",
  "expected_version": 3,
  "confirmed": 1
}
```

请求必须使用 POST 和 `Idempotency-Key`。Web 使用 `web-execute-ai-draft-{draft_id}-v{version}`，保证网络重试不会重复创建。

响应：

```json
{
  "draft": {
    "status": "executed",
    "version": 3,
    "execution": {
      "executed_by": "user@example.com",
      "executed_at": "2026-07-18 12:00:00",
      "target_doctype": "Sales Order",
      "target_name": "SO-0001",
      "result": {}
    }
  },
  "execution": {},
  "replayed": false
}
```

服务端执行顺序：

1. owner 隔离并读取草稿。
2. 检查 `confirmed=1`、`status=draft`、`expected_version` 和 `ready_for_handoff`。
3. 按草稿 ID 获取执行锁。
4. 调用既有领域服务：
   - `product_setup/create` → `create_product_v2`
   - `product_setup/update` → `update_product_v2`，仅提交用户补丁，不携带库存目标
   - `sales_order` → `create_order_v2`
   - `purchase_order` → `create_purchase_order`
   - `inventory_adjustment` → `reconcile_inventory_stock_v1`
5. 保存 `executed` 状态和正式对象回执。
6. 写入 `MyApp AI Audit Event`。

### 5.2 草稿状态

```text
draft ──编辑/恢复──> draft（新版本）
  ├─确认执行成功──> executed
  ├─复杂编辑交接──> handed_off
  └─用户放弃──────> discarded
```

`executed`、`handed_off` 和 `discarded` 均为终态。正式执行失败不会修改草稿版本或状态，用户可修正后生成新版本，或使用同一版本幂等重试可恢复异常。

### 5.3 持久回执

`MyApp AI Draft` 增加：

- `execution_request_id`
- `executed_by`
- `executed_at`
- `target_doctype`
- `target_name`
- `execution_result_json`

回执用于刷新恢复、来源追踪和幂等结果展示，不取代正式 DocType 审计。

### 5.4 模型注册与选择

- Orchestrator 从 LiteLLM `/v1/models` 返回当前 Service Key 可见的完整模型库存，不再只暴露默认 Chat 和 Embedding 别名。
- Frappe `sync_ai_model_registry_v1` 负责同步模型能力和健康状态；已消失模型标记为 `degraded / missing`，人工 `disabled / retired` 状态不会被覆盖。
- `list_ai_selectable_models_v1` 只返回 `active / validated` 且属于 `fast_chat / reasoning / structured` 的模型；Embedding、缺失、停用和退役模型不进入清单。最近健康失败不会自动改变人工生命周期，但接口会返回健康时间、状态和错误码；Web 将 `unavailable` 项标记并禁用，Backend 也拒绝新的固定模型请求。
- Chat、SSE 和四类草稿统一接受可选 `model_alias`。省略时使用已发布策略；显式选择时由 Frappe 再次校验，并禁用本次请求的静默模型 fallback。
- 自动模式按策略主模型和有序 fallback 选择，跳过最近健康状态为 `unavailable` 的候选；Chat 只允许在首个可见正文 Token 前因 Provider 故障切换，避免拼接多个模型的正文。没有匹配已发布策略时，Orchestrator 可使用 `MYAPP_AI_MODEL + MYAPP_AI_FALLBACK_MODELS` 组成系统默认链。
- 最终 Run 返回的 `model_alias` 是实际执行事实，`requested_model_alias` 是显式请求事实；Web 不能只依据发送前的本地选择宣称模型已经切换。
- 只读 Agent 在创建 Run 前执行 Runtime Policy 就绪预检。没有唯一有效的已发布策略，或主模型、fallback、显式固定模型任一未达到 `active / validated + supports_tools=true` 时，本次请求使用兼容查询模式。同步响应和 SSE 都返回 warning，Web 按普通运行警告展示，不应把 `AI_AGENT_MODEL_TOOLS_UNVERIFIED` 等内部治理错误直接呈现给业务用户。
- 兼容查询只发生在新 Run 路由阶段。它仍先通过 `erp-intent-v3` 结构化意图模型提取只读场景和工具参数，再由 Frappe 执行权限安全的商品、单据或报表查询；本地关键词/DSL 只在意图模型不可用、低置信度或输出非法时降级。完整 Agent 已开始后的失败不自动改走兼容路径，避免重复 Run、重复工具副作用或额外模型调用。

### 5.5 模型执行事实、故障诊断与健康检查

模型选择和模型执行必须分开建模：

- `requested model`：用户显式选择的 alias；自动策略模式下可以为空。
- `actual model`：本次最终执行或最终失败尝试的 `model_alias`，只能由 Backend/Orchestrator Run 事实确认。
- `model_display`：面向普通业务用户的友好名称。
- `provider model`：底层路由或供应商模型名，只属于高级诊断，不是业务选择事实。

自动策略模式也必须在助手消息、失败卡、历史 Run 和 Run Inspector 中显示实际模型的友好名称。页面不能因为请求时选择了“自动”就隐藏模型，也不能仅依据发送前的固定选择宣称某模型已经执行。

Provider 最终拒绝 Chat、意图解析或四类结构化草稿时，Orchestrator 统一返回 `MODEL_PROVIDER_REJECTED`、实际 `model_alias` 和可选稳定 `provider_error_code`。Frappe 负责生成权限安全的 `model_display`，高级诊断角色才可看到技术 alias 和 Provider 错误码。任何层都不得透传 Provider 原始正文、凭据、Authorization Header 或系统 Prompt。

模型健康治理有三种人工范围：

- 单项：只检测一个 alias。
- 多选：检测明确选择的 1～100 个 alias。
- 全量：检测全部未停用、未退役模型，必须作为独立明确动作确认。

显式空选择不是全量；未知、停用或退役 alias 整体拒绝。Chat 探测包含最小回答和强制 Function Calling，Embedding 探测使用固定合成文本。检查会产生少量真实 Provider 调用和费用，只更新健康、能力和审计事实，不自动修改模型生命周期或发布策略。

Frappe Scheduler 默认每天站点时间 `03:15` 执行健康检查，Redis 锁防止同站点并发重复探测。站点可关闭任务或把范围限制到指定 alias；未配置范围时检查全部未停用模型。治理页面展示启停、范围和最近检测时间，但 Scheduler 配置仍属于服务端运维边界。

健康状态必须带时间解释：一次成功不代表长期可用，一次超时也不等于模型永久退役。运行路由、策略发布、人工排障和告警应共同参考最近检测时间、稳定错误码、工具能力、真实 Run 错误和 Provider SLA。

### 5.6 消息级重试与 Run 审计

“恢复输入供修改”和“重试失败消息”是两个不同动作：

- 恢复输入只把原问题放回输入框，由用户修改后作为新消息发送。
- 消息级重试绑定失败 `run_id`，恢复原问题、场景、会话和公司，但使用用户点击重试时页头当前选择的模型。

普通 Chat 重试不重复插入用户消息。Backend 创建新 Run，把原失败助手占位原位绑定到新 Run；成功后在原位置更新正文和 citation。旧 Run 保留失败事实，新 Run 通过 `retry_of_run_id` 记录来源。`requested_model_alias` 记录本次固定请求，`model_alias` 记录实际执行模型；自动模式前者为空。

草稿生成失败不复用普通 Chat 的消息级重试接口，而是继续调用对应四类草稿生成接口，因为草稿还需要版本、字段校验、幂等和人工确认生命周期。任何重试都必须由用户显式触发，不能由浏览器自动重复模型调用。

## 6. Web 组件

### 6.1 查询详情

- `BusinessResultPanel`：表格主视图，单据编号打开当前页详情；显示查询/刷新时间、权限范围、返回数、可见总量、截断状态，并通过 `refresh_ai_business_result_v1` 只刷新当前消息。
- `BusinessDocumentDrawer`：统一读取四类领域详情 Service，不解析原始后端包络；并列展示回答时快照和当前详情，支持单独刷新。
- `ProductDetailDrawer`：并列展示回答时价格/库存与当前商品主数据、单位、价格和分仓库存，商品模块深链为次级操作。
- “在业务模块打开”：Drawer 右上角次级按钮。

### 6.2 草稿闭环

- `AiDraftEditorModal`：草稿中心的四类共享业务编辑器；来源会话编辑器遵循同一字段、更新和自动校验契约。每次打开都读取最新持久草稿，校验失败时保持编辑器打开并保留输入。
- `AiDraftBusinessReview`：展示业务字段、校验和执行回执。
- 草稿卡片主操作：`完善草稿 / 编辑草稿`、`确认执行`。
- 次级操作：`版本历史`、`在业务编辑器继续`、`查看正式业务对象`。

所有 UOM、数量、仓库和金额字段继续使用共享组件与后端重校验。

### 6.3 模型选择

- AI 工作台默认展示“自动选择（策略）”。
- 可选项只从 Frappe `list_ai_selectable_models_v1` 加载，浏览器不直连 LiteLLM，也不维护本地模型白名单。
- 固定模型在 Chat、SSE、四类草稿和人工重试中保持一致；界面显示固定状态，完成后仍以服务端 Run 返回值为准。
- 模型同步、停用、缺失或权限变化后，后端拒绝旧选择并提示刷新列表，不能静默改用其他模型。

## 7. 失败与恢复

- 版本冲突：提示刷新草稿，不允许执行旧版本。
- 校验失败：保持 `draft`，展示字段错误并允许编辑。
- 权限变化：正式领域服务失败关闭，不能依赖生成草稿时的旧权限。
- 网络超时：使用相同草稿/版本幂等键重试。
- 已执行重试：返回持久回执并标记 `replayed=true`。
- 正式业务对象创建成功：草稿显示成功 Alert 和可选详情深链。

## 8. 验收标准

- 用户可在 `/ai` 和 `/ai/drafts` 编辑四类草稿并重新校验。
- `ready_for_handoff=true` 的四类草稿可以原地确认执行。
- 未确认、版本不一致、非 `draft`、校验未通过或无权限请求全部失败关闭。
- 重复点击或网络重试不会重复创建正式对象。
- 查询表格点击单据编号不离开 AI 页面即可查看关键详情。
- 完整业务页始终保留为可选入口。
- 草稿刷新后仍能恢复正式对象、执行人和执行时间。
- LiteLLM 当前可见模型能完整同步；工作台只展示合规聊天模型，Embedding 不能被选择。
- 显式选择模型后，真实 SSE 完成事件中的 `model_alias` 与选择值一致，不发生静默 fallback。
- Backend、Web 单测、类型、Lint、构建和 whitespace 检查通过。

## 9. 多模态商品与订单扩展

AI 工作台支持私有短期图片 Attachment。模型注册表把用途能力与 `supports_vision` 分开治理，图片请求只使用经过真实视觉探测的模型。Web 可上传最多 4 张完整原图并随消息或草稿提交；图片消息可在历史会话恢复。

商品照片场景会先在当前账号权限范围内搜索编码、名称、条码、品牌和规格。疑似重复时必须由用户选择新增或完善；没有候选时整理可见字段形成创建草稿。只有明确新增且未指定其他图片时，首张来源图才派生暂存商品封面，完善现有商品不会自动覆盖图片。

销售和采购订单图片按“缺失不猜”提取商品行、数量、单位、价格和订单号。识别为本系统订单并要求修改时，Backend 读取真实订单 baseline；确认执行时调用现有订单更新服务。完整设计见 `06-ai-multimodal-product-and-order.zh-CN.md`。
