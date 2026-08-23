# AI Chat Core V2 改进设计

## 1. 背景与结论

当前 AI 工作台已经具备 ERP 权限隔离、公司范围、模型治理、草稿版本、人工确认、Run 审计、Agent 工具与审批等企业能力，但聊天内核仍以“文本消息 + 当前请求附件”为中心。图片上传成功不等于图片已经成为会话上下文：历史消息只向模型恢复文字，Orchestrator 又只把请求级附件附加到最后一条用户消息，因此用户在下一轮追问时，模型无法看到上一轮图片。

这不是单个页面参数遗漏，也不代表整个 AI 模块需要推倒重做。问题集中在 Chat Core 的消息表达、上下文构建、附件生命周期、运行恢复和前端会话状态边界。V2 在保留既有业务编排与审计基础的前提下，分阶段替换这些薄弱边界。

## 2. 现状问题

### 2.1 消息与上下文

- 持久消息保存 `content` 和 `attachments_json`，但模型上下文只读取 `role + content`。
- Orchestrator 的 `ChatMessage.content` 只能是字符串，图片依赖 `ChatRequest.attachments`，并被附加到最后一条用户消息。
- 最近消息窗口固定为 20 条，没有会话摘要、长期记忆或基于 Token 的 Backend 级上下文策略。
- 图片追问、失败重试和恢复 Run 没有共享一个统一 Context Builder。

### 2.2 附件生命周期

- 未发送图片和已绑定到历史消息的图片都使用 24 小时保留期。
- 会话默认保留 30 天，导致消息审计记录仍存在时，原始视觉证据可能已经被清理。
- 待发送附件没有严格按会话隔离，切换会话可能把附件带入另一段对话。

### 2.3 运行与传输

- 普通 Chat 缺少客户端请求幂等 ID，网络重试可能创建重复消息或重复 Run。
- SSE 没有持久事件序号、断点续传和已通过安全检查的部分内容恢复；连接中断后只能将 Run 视为失败或重新生成。
- 失败重试依赖最后一个失败 Run，前端缺少原请求模态事实，可能允许用纯文本模型重试带图请求。

### 2.4 模型就绪与发布

- 自动模型依赖 Runtime Policy，但部署健康检查只报告已发布策略和 tool-ready 数量。
- 门禁没有验证策略是否处于有效时间、灰度是否大于 0，以及策略链中是否存在 `supports_vision=true` 的健康模型。
- 因此页面可以允许自动图片请求，而运行时在 Provider 调用前以 `AI_VISION_MODEL_REQUIRED` 失败。

## 3. 目标架构

```text
Web Composer State（按会话隔离）
  → Backend Command（幂等请求边界）
  → Durable Message / Run / Attachment
  → Context Builder
      ├─ 消息窗口与摘要
      ├─ 消息级 ContentPart / Attachment
      ├─ 会话工作状态
      └─ 权限过滤后的业务上下文
  → Runtime Policy + Modality Gate
  → Orchestrator Provider Adapter
  → Durable Run Events
  → SSE 投影 / 断点恢复
```

核心原则：

1. 消息是上下文事实，附件必须属于具体消息，不能只属于一次 HTTP 请求。
2. Backend 是上下文和生命周期的事实来源；Web 不重新拼装历史证据。
3. 模态是模型选择的强约束；没有视觉候选时失败关闭，不能静默丢图。
4. Run、消息和事件需要可幂等、可审计、可恢复。
5. 业务工具、权限、草稿和正式写入继续沿用现有领域边界。

## 4. 目标消息模型

最终消息内容使用有序 ContentPart：

```json
{
  "role": "user",
  "content_parts": [
    { "type": "text", "text": "这张图片里的商品是什么？" },
    { "type": "image", "attachment_id": "AI-ATT-..." }
  ]
}
```

建议支持的基础类型：

- `text`
- `image`
- `tool_call`
- `tool_result`
- `citation`
- 后续扩展 `file`、`audio` 和受控结构化 UI 数据

第一阶段不立即迁移数据库。继续保存现有 `content + attachments_json`，但 Backend Context Builder 将其映射为消息级 `attachments[]`，Orchestrator 同时接受新消息级附件和旧请求级附件。完成数据回填、灰度和兼容期后，再把 ContentPart 设为正式持久化模型。

## 5. Context Builder

所有 Chat、结构化草稿、失败重试和 Run 恢复必须经过同一个 Context Builder：

1. 校验会话 owner、状态、公司和上下文边界。
2. 读取有效消息窗口，排除失败或取消 Run 的空助手占位。
3. 恢复每条用户消息绑定的附件，并校验 owner、会话、消息、文件哈希和有效保留期。
4. 合并服务端会话工作状态和权限过滤后的业务上下文。
5. 输出消息级多模态请求，不把历史图片改挂到最新用户消息。
6. 按文本、图片和工具结果的综合 Token 预算裁剪完整对话单元。

结构化业务草稿不能只让模型“看见”历史图片，还必须把实际采用的 Attachment 提升为草稿来源资产。商品草稿优先消费模型 evidence 指定且属于当前有效消息窗口的 Attachment；只有用户当前文字明确引用之前图片时，才允许回退到最近带图消息。完善现有商品默认不覆盖图片，明确的主图/封面替换意图才形成图片 patch。

短期仍保留最多 20 条的兼容窗口；后续增加滚动摘要、重要实体记忆、Token 预算和摘要版本审计。摘要只能压缩对话，不得替代 ERP 实时事实。

## 6. Attachment 生命周期

附件采用两段生命周期：

```text
uploaded（未绑定）
  └─ 24 小时内未发送 → 清理

bound（已绑定消息/会话）
  └─ 有效期跟随会话 retention_until
      ├─ 会话继续活跃 → 随会话延长
      ├─ 活动草稿仍引用 → 继续保护
      └─ 会话和草稿均到期 → 清理文件并标记 expired
```

约束：

- 附件不能跨 owner、跨会话或跨消息重新绑定。
- 历史上下文只能读取消息实际绑定的附件。
- 浏览器只持有 Attachment ID 和安全预览元数据，不接触磁盘路径或 base64。
- base64 只在 Backend 到 Orchestrator 的内部请求中短暂存在，不进入普通日志、错误正文或 Langfuse input。
- 删除会话或调整保留策略时，应有明确的附件级联与审计规则。

## 7. Durable Run、幂等与可恢复 SSE

后续阶段为每次用户发送增加 `client_request_id`：

- 唯一范围建议为 `owner + conversation + client_request_id`。
- 重复请求返回已有消息和 Run，不再次产生模型费用或工具副作用。
- Run 保存输入消息版本、策略版本、模型选择、Prompt 版本和上下文快照摘要。

SSE 事件持久化为单调递增序号：

- `run_started`
- `model_started`
- `tool_started / tool_completed`
- `output_committed`
- `warning`
- `run_completed / run_failed / run_cancelled`

客户端携带最后确认事件 ID 恢复。只有通过输出 Guardrail、允许向用户展示的内容才能写入可回放事件；未经完整校验的 Provider delta 不能成为恢复事实。

## 8. Web 状态边界

Composer 状态必须以会话键隔离：

```text
composerState[conversationKey] = {
  draftText,
  pendingAttachments,
  uploadState
}
```

`conversationKey` 对已有会话使用会话 ID，对尚未创建的会话使用稳定的新会话键。切换会话时保存并恢复对应文本和附件；上传队列完成后只能写回发起上传的会话，不能写入当前碰巧打开的会话。

失败恢复必须保存：原用户消息、场景、失败消息 ID、Run ID、是否带图。点击“使用当前模型重试”时，如果原请求带图且当前固定模型不支持视觉，应在发请求前阻止；真正的附件 ID 仍由 Backend 根据失败 Run 恢复，Web 不复制已绑定附件。

后续将当前大页面拆分为 Conversation Store、Composer Store、Run Store 和 Inspector Store，并用显式状态机描述 `idle / uploading / submitting / streaming / waiting_approval / completed / failed / cancelled`。

## 9. 模型与部署就绪门禁

图片请求的可用条件：

1. 存在当前环境、场景和范围可命中的已发布策略。
2. 策略处于有效时间窗口且 `rollout_percentage > 0`。
3. 主模型或 fallback 中至少一个模型为 `active / validated`、健康且 `supports_vision=true`。
4. 固定模型请求必须由该固定模型独立满足视觉能力，不能自动换成其他模型。

staging 部署检查应失败关闭，而不是仅打印统计。至少校验有效策略、正灰度、tool-ready 模型和策略链中的 vision-ready 模型。生产发布还应把纯文本、单图、多轮图片追问和带图失败重试纳入登录态回归。

## 10. 分阶段实施

### Phase 1：恢复正确性（本次）

- Backend 历史消息恢复消息级附件。
- 已绑定附件跟随会话保留期；未绑定附件继续 24 小时清理。
- Orchestrator 支持消息级附件，并兼容旧 `ChatRequest.attachments`。
- 视觉能力校验、预算和可观测输入统计覆盖消息级附件。
- Web 待发送附件按会话隔离；失败重试记录原请求是否带图并预检固定模型。
- staging 门禁校验有效策略、正灰度和 vision-ready 模型。

### Phase 2：可靠运行

- 增加 `client_request_id` 和 Chat 幂等记录。
- 持久化安全 Run 事件，SSE 支持事件 ID、断线续传和完成结果重放。
- 允许从任意失败消息重试或重新生成，而不是只处理会话最后一个失败 Run。

### Phase 3：上下文与扩展

- 正式迁移 Message ContentPart。
- 引入摘要、Token 预算、长期实体记忆和上下文版本审计。
- 支持 PDF、Excel、Word 等受控文件类型及异步解析。
- 支持会话分支、任意消息重新生成和多端同步 Composer。

## 11. 兼容与迁移

- 旧调用只传顶层 `attachments[]` 时，Orchestrator 继续把它们附加到最后一条用户消息。
- 新调用在 `messages[].attachments[]` 中携带附件；若顶层和消息级出现同一 Attachment ID，只发送一次。
- 旧消息的 `attachments_json` 在读取时动态映射，不要求立即回填数据库。
- 历史已绑定但尚未物理清理的附件，按所属会话有效期恢复；已被清理的文件无法凭消息元数据重建，应在 UI 显示证据已过期而不是伪造图片。

## 12. 验收矩阵

| 场景 | 预期 |
| --- | --- |
| 首轮上传图片并提问 | 模型收到当前用户消息的文字和图片 |
| 第二轮只发“继续分析这张图” | 模型仍收到第一轮消息绑定的图片 |
| 两轮分别上传不同图片 | 每张图片保留在原消息，不全部挂到最后一轮 |
| 切换 A/B 会话后上传 | 每个会话只恢复自己的待发送附件 |
| 上传未发送超过 24 小时 | 附件清理 |
| 已发送图片超过 24 小时但会话仍有效 | 历史预览和模型上下文仍可用 |
| 带图失败后选择纯文本固定模型重试 | Web 发送前阻止，Backend/Orchestrator仍二次校验 |
| 自动图片请求无有效视觉策略 | 部署门禁失败；运行时失败关闭且不丢图 |
| 旧客户端使用顶层附件 | 保持兼容 |
| Langfuse 默认/内容采集模式 | 均不记录图片 base64 |

## 13. 非目标

本设计不改变 ERP 权限、公司隔离、业务工具白名单、草稿确认、正式领域服务、UOM、价格、库存和单据生命周期规则。模型仍不能直接写正式业务数据。
