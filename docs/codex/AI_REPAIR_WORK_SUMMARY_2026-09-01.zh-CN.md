# AI、单位与库存修复阶段工作总结

更新时间：2026-09-01 CST

本文总结 2026-08-29 至 2026-09-01 的连续修复工作，供后续开发、测试、提交和 staging 验收接手使用。短期运行状态仍以 `docs/codex/CURRENT_HANDOFF.zh-CN.md` 为准；长期规则以 `AGENTS.md`、`docs/codex/DEVELOPMENT_GUIDE.zh-CN.md` 和 `docs/codex/KNOWN_ISSUES.zh-CN.md` 为准。

## 1. 阶段目标与最终结论

本阶段解决的不是单一页面缺陷，而是以下相互关联的问题：

1. 点击发送后消息迟迟不进入列表，复杂 `auto` 请求存在重复 intent 串行。
2. 图片已经上传，但本地私有图片预览失败。
3. AI 配置、Prompt/模型健康状态和运行容器环境可能不一致。
4. 单位和库存编辑不自然，科学单位、重复“箱”、商品多单位、价格和条码单位缺少统一治理。
5. 商品搜索后的“完善商品”和“调整库存”没有直接续接原业务上下文。
6. 页面刷新后 AI Run 状态没有从持久层实时恢复，审批或进程中断后可能长期卡住。
7. 选择性 recreate Backend 后，本地 Frontend Nginx 可能继续连接旧容器 IP 并返回 502。

当前结论：

- 代码层面的主要修复已经完成并按 Backend、AI Orchestrator、Web、Parent 仓库边界本地提交。
- Backend、Web、AI 定向测试、静态检查、数据库回滚式 smoke、真实 HTTP 和本地容器配置检查均已通过。
- 2026-09-01 的单位库存、商品续接、模型健康和 Run 状态提交尚未推送、尚未部署新的 staging 候选。
- production 未操作。
- 真实错误商品 `可口可乐-5000ML` 尚未执行替代迁移；该动作需要用户明确业务决定。
- 模型/Provider 自身首 Token 慢不通过关键词模板、机械问候或前端伪回复处理。

## 2. 当前仓库功能基线

| 仓库 | 分支 | 当前提交 | 状态 |
| --- | --- | --- | --- |
| Parent | `develop` | `baeb2d82 fix(ai): enforce runtime state consistency`；本文档提交可能位于其后 | 保留用户已有文档和未跟踪本地状态 |
| Backend `apps/myapp` | `develop` | `46f5d48 fix(ai): converge durable run state` | clean |
| AI Orchestrator `services/myapp-ai` | `develop` | `25e55e7 fix: refresh stale model health policy cache` | clean |
| Web `frontend/myapp-web` | `main` | `b4112fe fix(ai): restore durable run state` | clean |
| Mobile | 未核对 | 本阶段未修改 | 不在本阶段提交范围 |

Parent 不得顺带提交或清理的状态：

- `AGENTS.md`
- `STAGING_DEPLOYMENT.zh-CN.md`
- `docs/codex/DEVELOPMENT_GUIDE.zh-CN.md`
- `docs/codex/HANDOFF_TEMPLATE.zh-CN.md`
- `docs/codex/KNOWN_ISSUES.zh-CN.md` 中用户已有修改
- `.codex`
- `docs/codex/AI_MULTIMODAL_WORK_SUMMARY_2026-08-16.zh-CN.md`

## 3. 已完成工作

### 3.1 发送即时回显与重复 intent 消除

- Web 在任何网络请求前锁定提交、立即插入用户消息和助手占位、清空输入框与待发送附件。
- 路由阶段和正式 SSE 共用同一取消控制；场景解析尚未完成时也能停止。
- Backend 为受控场景解析结果签发一次性 `resolution_id`，正式 Chat/SSE 只在用户、内容、公司、会话、附件、模型和上下文版本一致时复用。
- 复杂 `auto` 请求从“前置 intent + Chat 内重复 intent + 正式模型”减少为“前置 intent + 正式模型”。
- 精确问候和确定性草稿操作使用受控本地路由，但没有加入前端关键词回答或伪造 AI 回复。
- 该阶段已于 2026-08-31 部署 staging；后续模型生成等待主要取决于实际模型和 Provider 首 Token。

### 3.2 图片上传与私有预览

- 已确认截图中的主要问题是“上传成功、预览失败”，不是附件未落盘。
- Web 开发代理补齐 `/private/files/`，私有图片继续通过 JWT 获取，不把私有路径直接作为公开 `<img src>`。
- 图片输入器支持选择、粘贴、拖拽、图片-only 发送和会话隔离。
- 该阶段已部署 staging，并完成真实图片上传、私有预览和测试附件删除验证。

### 3.3 单位与库存 P0～P4

- P0：统一商品单位解析、整数单位校验、库存调整语义和前后端换算入口；库存盘点使用正式 `Stock Reconciliation`。
- P1：通过 `UOM.myapp_business_selectable` 区分系统保留单位与日常业务可选单位，科学单位不进入普通业务下拉。
- P2：正式使用 ERPNext 原生 `Item Price.uom` 和 `Item Barcode.uom`，同一商品可以维护多个交易单位、单位价格和单位条码。
- P3：实现受控错误商品替代迁移。存在历史流水的商品不原地修改 `stock_uom`，而是创建正确新商品、迁移明确选择的价格/条码、建立 `Item Alternative` 并停用旧商品。
- P4：`Box` 作为默认“箱”；`Case / Carton` 保留历史引用但默认不进入日常业务目录，并显示为“箱装/纸箱”，解决多个相同“箱”标签。
- 商品、订单、采购、库存和 AI 草稿继续使用共享 UOM helper，不在页面临时计算换算。
- 当前本地可自由维护商品多单位和换算；真实异常商品没有自动改写。

### 3.4 商品候选续接与库存编辑

- 商品搜索结果的“编辑商品资料”和“调整库存”直接准备确定性草稿并打开共享编辑器，不再把商品名填回输入框，也不再额外调用模型。
- 下一条消息能够在原草稿候选中唯一选择商品并继续原业务意图；仍有多个候选时失败关闭，不自动选择第一条。
- 商品完善弹窗展示公司总库存、分仓库存、库存基准单位和“调整此商品库存”入口。
- 商品主数据与库存调整仍是两个受控业务流程，不在商品资料保存时直接混写库存。
- 异常库存单位会进入受控 UOM 迁移入口，不允许继续执行库存草稿。

### 3.5 模型健康与缓存实时收敛

- 单次 429、超时、5xx 或连接异常不再立即把模型永久标记为 `unavailable`；首次瞬时失败为 `degraded`，确定性认证/配置错误仍立即不可用。
- 健康状态写入和审计先提交数据库，再使 Orchestrator Policy 缓存失效；缓存通知失败不回滚数据库事实。
- 固定模型缓存不可用或自动模型链全部缓存不可用时，Chat/SSE/草稿会强制刷新一次持久策略快照。
- Web 将 `degraded` 显示为“临时波动”并保持可选，`unavailable` 继续禁用。
- 本地固定 `gpt-5.6-luna` 的最小真实 Chat 已返回 200，未再出现旧的健康误阻断。

### 3.6 持久 Run 状态恢复与 watchdog

- Backend `get_ai_conversation_v1` 返回最新持久 `latest_run` 和可空 `message_id`，不依赖助手消息是否已经生成。
- Web 精确恢复 `running / waiting_approval / completed / failed / expired / cancelled`，不再把所有非失败状态折叠为“已完成”。
- 活动 Run 每 3 秒低频读取持久快照；终态后替换占位并恢复 Sender。活动期间禁止重复发送和修改待发送附件。
- `message_id` 防止把已存在但位于当前分页之外的旧助手回答重复追加到会话末尾。
- Scheduler 每 10 分钟回收超过 900 秒没有持久更新的 `running` Run，并处理超过有效期但仍停在 `waiting_approval` 的 `pending / approved / rejected` 审批。
- 超时 Run 吊销能力令牌、设置取消标记、写入稳定错误码并补齐失败助手占位。

### 3.7 五服务 AI Gateway 配置一致性

- 新增 `verify-ai-gateway-runtime-env.sh`，比较期望 env、运行容器 `Config.Env` 和容器间实际值，只输出不一致变量名，不输出 Secret。
- 检查覆盖 Backend、Scheduler、`queue-short`、`queue-long`、`queue-ai-vector`。
- 已接入本地 dev/prod 启动、Service Token 轮换和 staging start/deploy。
- 明确约束：环境变量变化必须由 Compose recreate；`docker restart` 不会加载新环境。
- 本地曾准确发现 Backend/Scheduler 缺少新变量，以及 Backend 的向量排除前缀仍为旧值；同步并 recreate 后五服务检查通过。

## 4. 本地 502 诊断与恢复

2026-09-01 用户通过 `http://localhost:8001` 测试时出现稳定 502。

证据：

- Backend `8000`：200。
- AI Orchestrator `4010`：200、healthy。
- Frontend `8080`：502。
- Web `8001` 通过 Frontend 访问 Gateway：502。
- Frontend Nginx 日志仍请求旧 Backend `172.19.0.5:8000`；当前 Backend 已因选择性 recreate 变为 `172.19.0.9`。

处理：

```bash
docker compose restart frontend
```

恢复后 `8000 / 8080 / 8001 / 4010` 全部为 200，Frontend 重新解析 `backend` 为 `172.19.0.9`。

这是运行拓扑刷新问题，不是 AI、Provider、Prompt、Backend 业务代码或数据库错误。自动预防仍未实现：会选择性 recreate Backend 的脚本需要在 Backend 就绪后 reload/restart Frontend，并验证真实浏览器入口的 Gateway Ping。

## 5. 为什么此前测试可能成功但用户仍遇到问题

不同问题绕过了不同测试边界：

- Web、Gateway 和 Service 的 Mock 测试不会执行被 Mock 掉的 adapter，因此曾遗漏中间函数参数漂移。
- Backend 和 Web 单元测试不会检查已经运行数小时的容器是否加载了最新 env，也不会发现 Nginx worker 缓存旧容器 IP。
- 页面过去用助手消息和内存状态推测 Run，单次请求测试不会覆盖“刷新页面时尚无助手消息”的状态恢复。
- 模型健康测试覆盖单次结果写入，但旧实现没有区分确定性失败和 Provider 瞬时失败。
- Runtime/工具直调成功不能替代 `Web → Frontend → Gateway → adapter → Service → Orchestrator` 的真实用户入口。

本阶段新增或强化的门禁：

- 不跳过 adapter 的 Backend 契约测试和真实 HTTP 回归。
- 持久 `latest_run` 契约与 Web 刷新/轮询测试。
- 运行容器实际 env 一致性检查。
- Backend、Frontend、Web 代理和 AI 四层分段健康诊断。
- staging 验收必须注明验证的是 Runtime、Backend HTTP 还是 Web 浏览器端到端，三者不能互相冒充。

## 6. 最终验证证据

Backend：

- 全量 unit：857 tests PASS。
- `test_ai_repository`：45 tests PASS。
- 容器 Python compile PASS。
- `bench --site localhost migrate` PASS。
- `cleanup_stale_ai_runs` 已注册为 `*/10 * * * *`。
- 真实数据库回滚式 watchdog 和 `get_conversation` 查询 PASS。

Web：

- TypeScript PASS。
- Biome PASS。
- 全量 51 suites / 328 tests PASS。
- AI 页面与 Service 定向 58 tests PASS。
- Jest 仍有项目既有 open-handle 提示，但退出码为 0。

AI Orchestrator 模型健康阶段：

- 33 tests + 6 subtests PASS。
- Ruff PASS。
- 本地容器 healthy，缓存失效与固定模型最小真实 Chat PASS。

运行环境：

- 五个 Frappe AI Gateway 服务 env 一致性检查 PASS。
- Backend `8000`、Frontend `8080`、Web `8001`、AI `4010` 最终均为 200。
- Parent、Backend、AI、Web 相关 `git diff --check` 已通过。

## 7. 尚未完成

### 代码/运维缺口

1. Backend 选择性 recreate 后自动 reload/restart Frontend 的预防机制尚未实现。
2. 尚未为真实浏览器入口建立自动化的 `8001 → 8080 → Backend` 容器切换回归。

### 发布与验收

1. 2026-09-01 的本地提交尚未按仓库顺序推送。
2. 尚未构建新的不可变 staging 候选并部署。
3. staging 尚未验收运行中刷新、切换会话、审批恢复中断、终态 Sender 恢复、模型临时波动、商品候选续接和库存调整。
4. production 未操作。

### 业务数据

真实商品 `可口可乐-5000ML` 当前仍使用错误库存基准单位 `Wavelength In Megametres`，同时存在 `Box = 24` 和历史库存流水。最终迁移前必须确认：

- 新商品编码。
- 正确库存基准单位。
- 完整多单位换算表。
- 四条历史价格分别复制到哪个单位或跳过。
- 条码迁移决定。
- 受控作业时间窗口。

不得直接修改旧商品 `stock_uom`，不得自动猜测价格单位，也不得绕过历史流水保护。

## 8. 建议接手顺序

1. 先实现 Backend recreate 后的 Frontend reload/restart 和真实 Gateway Ping，运行 Shell 检查与本地容器切换验证。
2. 重新确认 Backend、AI、Web 工作树 clean；Parent 只暂存明确文件，不包含用户已有文档和 `.codex`。
3. 依次推送 Backend、AI Orchestrator、Web，再更新并推送 Parent 子模块指针；不要先推 Parent 的未知 gitlink。
4. 构建单一不可变 staging 候选，不因外部瞬时波动反复生成新候选。
5. 部署后执行 Backend/Frontend/Web/AI 分层健康检查和五服务 env 一致性检查。
6. 使用真实浏览器账号完成本阶段目标场景验收，记录实际入口、Run ID、错误码和最终状态。
7. 业务验收通过后，再单独安排真实错误商品迁移；production 必须另行授权。

## 9. 重要边界

- 不修改 `apps/frappe` 或 `apps/erpnext`。
- 不输出或提交 Service Token、Provider Key、LiteLLM Key、系统 Prompt 或本地 Secret env。
- 不把模型自身速度问题伪装成前端机械回复。
- 不把库存写入混入商品主数据保存。
- 不在页面手写单位换算或显示标签。
- 不使用全局 prune、删除 volume、数据库、附件或治理报告处理运行问题。
- staging 通过不等于 production 授权。
