# 当前交接状态

更新时间：2026-08-04 CST

本文件只记录当前短期状态、仓库边界、验证结果、风险和下一步。历史过程以 Git 历史、GitHub Actions Run 和长期设计文档为准，不再持续追加到本文件。

## 当前目标与结果

- 本轮目标：让商品图片能力在所有高价值 Web 场景中保持可发现，统一无图 / 加载失败占位，并允许用户在 AI 当前商品详情中直接上传、替换和删除正式商品图片。
- 当前结果：Web 代码、测试和文档已完成并提交推送；staging Web 已切换到 `staging-20260804-01544c4`，容器健康、登录页和 Frappe Ping 通过，静态资源已确认包含 AI 直接图片维护代码。Backend、AI Orchestrator 和 production 均未变更。
- 涉及仓库：`frontend/myapp-web` 和父仓库交接文档。Backend、AI Orchestrator、Mobile 未修改。

## 本轮已完成

- `ItemImageUpload` 默认使用 `staged`：选择、替换和删除图片只更新表单值，正式 `Item.image` 随商品保存接口变更；保留 `commitMode="immediate"` 供明确的独立图片动作。
- `update_product_v2` 在回滚时清理新暂存图片、提交后清理旧受管图片；显式 `image=""` 删除图片，省略字段保持不变。
- AI `product_setup` 草稿支持图片 baseline、patch、版本差异、复核、交接和原地执行；图片由用户上传，不进入模型消息或 Prompt。
- 暂存图片清理会保护 `draft` / `handed_off` AI 草稿仍引用的文件。
- Web 已在 AI 商品 citation、商品当前详情、AI 草稿编辑/复核、AI 业务单据详情、销售发货、采购收货、销售/采购退货、库存盘点、库存调整和转仓确认区展示商品图片；销售/采购发票通过共享单据列同步获得图片与规格展示。
- 商品列表编辑与 AI 交接已保留空字符串删除语义和图片预览，不再因把空值转成 `undefined` 而丢失删除操作。
- Backend API 与 AI Web 设计文档已补充图片上传、事务、草稿和展示契约。
- 新增统一 `ProductImage` 展示组件：真实图片、无图和加载失败使用同一尺寸边界；商品主数据、库存列表 / 详情 / 调整 / 盘点 / 转仓、销售 / 采购订单明细、销售 / 采购退货、AI 商品 citation、AI 草稿摘要 / 复核和 AI 当前单据明细不再隐藏空图片位置或只显示横杠。
- AI `ProductDetailDrawer` 同时展示回答时图片快照和当前商品图片；当前图片区始终可见，并通过 `ItemImageUpload commitMode="immediate"` 直接上传、替换或删除正式 `Item.image`，成功后自动重新读取服务器数据。实际写权限继续由 Frappe Item 保存裁决。
- 已确认 staging 商品“迪莫”的 `Item.image` 为 `null`；旧商品不会因部署自动生成图片。新 UI 会明确显示占位和上传入口，仍需业务用户选择实际商品图片。

## 本轮验证

- Backend：容器内 4 个相关 suite，`137 tests` 通过。模拟 Orchestrator 502/503 日志和 ResourceWarning 为测试预期输出。
- Web：`npm run tsc` 通过；`npm run biome:lint` 通过，检查 `234 files`。
- Web 全量 Jest：`39 suites / 277 tests` 通过；`npm run build` 通过。Jest 仍输出仓库既有的 open handle 提示，但退出码为 `0`。
- Parent、Backend、AI、Web 的 `git diff --check` 均通过。
- 本地站点已执行 `bench --site localhost migrate`，`myapp.patches.extend_ai_run_retry_fields` 成功应用。
- 真实商品图片 HTTP 回路通过：暂存上传、创建商品绑定、替换、显式删除、File 附件清理和测试商品删除均成功，无 Item/File 残留。
- 本地 AI Orchestrator 旧镜像仍使用 `product-setup-draft-v2`，已按当前源码重建为 `product-setup-draft-v4`；容器当前 `healthy`。
- 真实 AI 商品草稿图片链路通过：使用已注册且健康的 `gpt-5.5` 生成 `product_setup` 草稿，暂存上传图片，更新草稿 `version 1 -> 2`，重新读取确认，确认 2 个版本中的图片快照与 `image` diff，随后丢弃草稿、删除测试图片并归档测试会话。
- 本地残留检查：`ai-image-smoke-*` File 数量为 `0`；2 个测试草稿均为 `discarded`；3 个测试会话均已归档。
- 本地运行态 smoke：Backend Ping、Web `/ai`、Web `/master-data/products` 均返回 `200`。Backend 与 Web 当前由手动开发进程提供服务，避免重启相关容器后忘记重新启动。

## 当前提交与部署版本

- Backend：`5a23dd1 feat: add transactional product image workflows`，已推送 `origin/develop`。
- Web：`01544c4 feat: make product images discoverable across workflows`，已推送 `origin/main`。
- AI Orchestrator：`ca5448c docs: document AI model fallback behavior`，已推送 `origin/develop`；本轮只有文档提交，运行时代码未变。
- Parent release：`b1d0e8e8 feat: release product image workflows`，固定 Backend/AI gitlink 并已推送 `origin/develop`。
- Backend / AI staging 仍使用 `staging-20260804-b1d0e8e8`；Web staging 使用 `staging-20260804-01544c4`。
- `.codex` 仍为既有未跟踪目录，不提交。

## staging 构建与部署

| 范围                       | Workflow Run                                                                    | 结果 |
| -------------------------- | ------------------------------------------------------------------------------- | ---- |
| Backend + AI build         | [30881015149](https://github.com/rgc318/frappe_docker/actions/runs/30881015149) | 成功 |
| Web build                  | [30896446600](https://github.com/rgc318/myapp-web/actions/runs/30896446600)     | 成功 |
| Backend + AI deploy/health | [30884538936](https://github.com/rgc318/frappe_docker/actions/runs/30884538936) | 成功 |
| Web deploy/health          | [30896861740](https://github.com/rgc318/myapp-web/actions/runs/30896861740)     | 成功 |

部署事实：

- Parent release 的 gitlink 精确固定 Backend `5a23dd1` 和 AI `ca5448c`；远端 Backend/AI/Web 分支头分别精确指向 `5a23dd1`、`ca5448c` 和 `01544c4`。
- Backend、Frontend、Queue、Scheduler、Websocket 和 AI Orchestrator 仍使用第一阶段统一标签；独立 Web 容器已切换到 `staging-20260804-01544c4`，状态为 `running / healthy`。
- `bench --site staging.example.com migrate` 成功执行。
- AI `/healthz` 返回 `status=ok`；LiteLLM、Runtime Governance 和 Vector Search 已配置；Backend 到 Orchestrator 内部认证通过。
- Runtime Policy 已发布：`1 policies, 7 tool-ready models`。
- `check-staging.sh` 的首页和 Ping 均返回 `200`；新 Web workflow 的 `/healthz`、`/user/login` 和 `/api/method/ping` 门禁通过，服务器静态资源包含 AI 当前商品直接图片维护文案。
- 首次 Web build run [30896346835](https://github.com/rgc318/myapp-web/actions/runs/30896346835) 因 `actions/checkout` 把短 SHA `01544c4` 当作 branch/tag ref 而失败；确认远端 `main` 精确指向完整提交 `01544c4dd3d1fa89fce3256cfc0187a4b2dfa7b9` 后，以 `web_ref=main` 重跑成功，没有产生错误镜像。
- staging 未配置本轮登录态关键 HTTP 回归输入，因此部署 workflow 保持 `run_http_regression=false`；真实商品图片和 AI 草稿图片链路已在本地使用登录态完成。

## 当前风险与下一步

1. 使用有 Item 写权限的 staging 账号做浏览器人工 UI 验收：打开“迪莫”应看到无图占位和“上传图片”，上传后应自动刷新为实际图片；同时抽查商品列表、库存作业、订单 / 退货明细和 AI 草稿的占位尺寸。当前环境没有 Playwright/Puppeteer，因此自动验收覆盖组件、构建、路由资源和部署健康门禁。
2. 若要把登录态商品图片链路加入部署门禁，为 staging workflow 配置受限测试账号或专用 Bearer/API Token，并新增不会污染业务数据的图片生命周期 HTTP case。
3. 第二阶段可补 Mobile 的表单暂存边界、不可变单据行图片快照、缩略图派生、真实文件头/像素校验、上传配额和正式 Media Reference 表；当前 AI 草稿引用保护仍是对 `payload_json` 的轻量查询。
4. 本地默认模型 `opencode-deepseek-v4-flash` 当前仍被 LiteLLM 以 `PROVIDER_HTTP_403` 拒绝；本次 AI 图片验收显式使用健康的 `gpt-5.5`，没有修改默认模型或 Runtime Policy。Provider 恢复后应重新执行健康检测。

## 上一轮目标（2026-08-03，已完成）

- 本轮目标：修复 AI 草稿校验提示不具体、不可用模型仍被使用、自动模式缺少 fallback、失败消息无法按当前模型原位重试等问题，并完成 staging 发布与文档收口。
- 当前结果：代码已提交、推送并部署 staging；Backend/AI/Web 健康检查通过。当前只剩文档整理尚未提交。
- 涉及仓库：父仓库、`apps/myapp`、`services/myapp-ai`、`frontend/myapp-web`。Mobile 未修改，production 未变更。

## 已部署基线版本

staging 统一镜像标签：`staging-20260803-a221a8ad`

| 范围            | 当前提交                                               | 说明                                              |
| --------------- | ------------------------------------------------------ | ------------------------------------------------- |
| Parent          | `a221a8ad feat: deploy AI model fallback and retries`  | staging 编排、Backend/AI gitlink 与 fallback 配置 |
| Backend         | `862bbb0 feat: support audited AI message retries`     | 模型健康字段、固定模型拒绝、消息级重试与 Run 审计 |
| AI Orchestrator | `84a37b5 feat: add automatic model fallback`           | 默认 fallback 链、跳过不可用模型、首 Token 前切换 |
| Web             | `2a022c3 feat: improve AI model switching and retries` | 页头模型切换、不可用项禁用、当前模型原位重试      |

上述提交均已在对应远端分支：Parent/Backend/AI 为 `develop`，Web 为 `main`。

## 已部署基线改动

### 草稿校验与人工修正

- 四类草稿区分原始查询词与已解析主键。未唯一匹配的客户、供应商、商品、商品分类、品牌和仓库保持空主键，并保留 `*_query` 供人工搜索。
- Web 不再把 `item_query` 等文本伪装成已选 Link 值；摘要显示“待匹配”，编辑器绑定可操作字段错误并定位首个阻断字段。
- 库存调整的“商品无法唯一匹配”和“必须填写盘点差异或业务原因”等错误会完整展示，不再只给笼统提示。

### 模型选择与自动 fallback

- 可选模型接口返回 `last_health_at`、`last_health_status` 和 `last_error_code`。
- Web 页头提供快速模型 Select；`unavailable` 模型显示“不可用”并禁用，当前固定选择失效时回到自动模式。
- Backend 拒绝显式固定到最近健康状态为 `unavailable` 的模型。
- 自动模式按 Runtime Policy 的主模型/fallback 链选择；没有匹配策略时使用 `MYAPP_AI_MODEL + MYAPP_AI_FALLBACK_MODELS`。
- Orchestrator 跳过不可用候选；Provider 在首个可见正文 Token 前失败时可切换后续 fallback。已经输出正文后不切换，避免拼接多个模型的回答。
- 显式固定模型关闭本次静默 fallback。

### 模型展示与 Run 审计

- 页面自动模式在运行前显示“自动模型（由策略选择）”，运行后显示“自动模型（实际模型名）”。
- Run 同时区分 `requested_model_alias`、实际 `model_alias` 和 `retry_of_run_id`。
- Run Inspector 展示请求方式、请求模型和实际模型；高级诊断额外展示请求/实际 alias。
- 普通用户只看到安全友好名称；Provider 原始正文、Secret、Header 和系统 Prompt 不进入响应。

### 消息级重试

- `stream_ai_message_v1` 新增 `retry_run_id`。
- Backend 从失败 Run 恢复原问题、场景、会话和公司，不信任浏览器重新拼装持久事实。
- 重试不重复插入用户消息；原失败助手占位原位绑定新 Run，成功后原位更新内容。
- 旧 Run 保留失败审计，新 Run 通过 `retry_of_run_id` 关联来源。
- 重试模型只取用户点击时页头当前选择，不再使用失败时旧模型。
- 草稿失败继续使用对应草稿生成接口，不复用普通 Chat 的消息级重试，因为草稿有独立版本、校验和幂等生命周期。

## 已部署基线迁移

- 新 patch：`myapp.patches.extend_ai_run_retry_fields`。
- `MyApp AI Run` 新增 `requested_model_alias` 和 `retry_of_run_id`，并为重试来源增加索引。
- staging 部署执行 `bench migrate` 成功；部署后的 Backend、Queue、Scheduler 和 AI Orchestrator 均运行新镜像。

## 已部署基线验证

### AI Orchestrator

- `ruff check .`：通过。
- Pytest/Docker test：`157 passed`，另有 `9` 个 subtests 通过。
- `pre-commit run --all-files`：通过。
- Docker `test` 与 `runtime` target：构建通过；runtime import smoke 通过。

### Backend

- 新增链路定向测试：`5` 项通过。
- AI Service、模型治理和 Gateway 相关测试：`254` 项通过。
- 已知独立既有失败：`test_get_conversation_state_is_owner_scoped_and_recovers_default_shape` 单独运行也报 `KeyError: product`，本轮未扩大范围修改。

### Web

- `npm run tsc`：通过。
- `npm run biome:lint`：通过。
- 定向 Jest：`62` 项通过。
- 全量 Jest：`37` suites / `270` tests 通过。
- `npm run build`：生产构建通过。
- 提交钩子格式化后再次运行 `npm run tsc`：通过。

### 空白检查

- Parent、Backend、AI 和 Web 的相关 `git diff --check` 均通过。

## staging 构建与部署

| 工作流                     | Run                                                                             | 结果 |
| -------------------------- | ------------------------------------------------------------------------------- | ---- |
| Backend + AI build         | [30825008564](https://github.com/rgc318/frappe_docker/actions/runs/30825008564) | 成功 |
| Backend + AI deploy/health | [30825447419](https://github.com/rgc318/frappe_docker/actions/runs/30825447419) | 成功 |
| Web build                  | [30824680201](https://github.com/rgc318/myapp-web/actions/runs/30824680201)     | 成功 |
| Web deploy                 | [30825791796](https://github.com/rgc318/myapp-web/actions/runs/30825791796)     | 成功 |

部署健康事实：

- `staging-ai-orchestrator-1` 使用目标 tag，状态 `healthy`。
- Backend、Frontend、Queue、Scheduler 和 Web 均使用目标 tag。
- Orchestrator `/healthz` 返回 `status=ok`，LiteLLM、Runtime Governance 和 Vector Search 已配置。
- `check-staging.sh`、ERP Ping、登录页和 Web Gateway Ping 通过。
- production 未执行部署。

首次 Backend/AI build run [30824675060](https://github.com/rgc318/frappe_docker/actions/runs/30824675060) 因把完整 Backend commit SHA 传给 `myapp_ref` 失败。当前 workflow 会把该值交给 `git clone --branch`，因此只支持 branch/tag。确认远端 `develop` 精确指向 `862bbb0` 后，保持同一父提交和同一镜像 tag 重跑成功。长期处理已补充到 staging runbook 和 Known Issues。

## 上一轮结束时仓库状态

### Parent `/home/rgc318/python-project/frappe_docker`

- HEAD：`a221a8ad`。
- 当前文档改动：
  - `STAGING_DEPLOYMENT.zh-CN.md`
  - `docs/05-development/04-ai-business-workbench.zh-CN.md`
  - `docs/codex/CURRENT_HANDOFF.zh-CN.md`
  - `docs/codex/HANDOFF_TEMPLATE.zh-CN.md`
  - `docs/codex/KNOWN_ISSUES.zh-CN.md`
- `apps/myapp` 和 `services/myapp-ai` 显示小写 `m`，原因是子仓库仅有文档改动。
- `.codex` 是既有本地未跟踪状态，不提交。

### Backend `apps/myapp`

- HEAD：`862bbb0`。
- 仅 `API_GATEWAY.zh-CN.md` 有文档改动；代码工作树无未提交修改。

### AI Orchestrator `services/myapp-ai`

- HEAD：`84a37b5`。
- `docs/API_CONTRACT.zh-CN.md` 与 `docs/CONFIGURATION.zh-CN.md` 有文档改动；代码工作树无未提交修改。

### Web `frontend/myapp-web`

- HEAD：`2a022c3`。
- 仅 `AI_WEB_FRONTEND_DESIGN.zh-CN.md` 有文档改动；代码工作树无未提交修改。

### Mobile `frontend/myapp-mobile`

- 本轮未修改、未部署。

## 上一轮遗留事项

- staging workflow 没有配置登录后的 HTTP 回归凭据，因此本轮没有代替真实用户执行登录态聊天点击验收。镜像、迁移、公开健康端点和自动化测试均已通过。
- 模型健康是带时间戳的快照。DeepSeek Flash 曾返回 `PROVIDER_HTTP_403`；Provider 恢复后仍需重新执行健康检测，不能手工假定已经恢复。
- 消息级重试只允许当前账号、活跃会话中最后一条失败/取消的助手 Run，避免历史消息被任意重绑。
- 当前文档尚未提交、推送；文档提交不会改变已部署运行镜像，不需要因此重新部署。
- 服务器仓库曾显示 `services/myapp-ai` 脏 gitlink；运行事实以不可变镜像 tag/revision 为准，不要在服务器直接开发或提交子模块内容。

## 上一轮原建议

1. 审查本轮文档差异并按仓库边界提交：Backend、AI、Web 各自提交文档，最后由 Parent 更新两个子模块指针并提交父仓库文档。
2. 如需业务验收，使用有权限的 staging 账号检查：页头切换 Luna、DeepSeek 不可选、自动模式显示实际模型、失败后切换模型原位重试、Run Inspector 请求/实际模型一致。
3. 后续单独处理 `test_ai_repository` 的既有 `KeyError: product`；不要混入本轮文档提交。
4. 若要让 staging build 真正支持不可变 Backend commit SHA，改造 workflow 的 fetch/checkout 逻辑；在此之前 `myapp_ref` 只传 branch/tag。
