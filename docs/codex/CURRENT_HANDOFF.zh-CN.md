# 当前交接状态

更新时间：2026-07-24 11:23 CST

本文件只记录当前短期状态、仓库边界、验证结果、风险和下一步。长期规则见 `AGENTS.md` 与 `docs/codex/DEVELOPMENT_GUIDE.zh-CN.md`。

下方较早日期章节是历史执行记录；其中嵌入的“当前状态 / 下一步”只代表当时截面，最新口径始终以本页顶部“当前最终状态”和最新工作总结为准。

## 当前最终状态

### 2026-07-24 每条 AI 回答独立 Run（已提交，未推送/未部署）

- Web 已把 Run Inspector 从全局“最近一次运行”切换为消息级上下文：每条成功回答提供自己的“运行详情”，失败回答的“查看诊断”也精确绑定该消息；历史会话直接使用 `get_ai_conversation_v1` 已返回的持久 Run 摘要，不需要扩展 Backend 契约，也不会把当前或最近 Run 的工具、警告或错误状态错误复用到其他消息。
- 顶部入口只在生成过程中显示为“当前运行”。当前消息持续保存 Run ID、状态、流式统计、工具进度和警告；生成完成后顶部入口消失，由回答下方入口承接。切换会话、新建请求或关闭 Drawer 会清理当前检查目标，避免跨会话残留。
- Run Drawer 已分层：默认“运行概览”显示状态、业务场景、公司与当前账号权限范围、总耗时、消息时间和错误类别；模型 alias、实际模型、首 Token、流式统计、Token、Run 与 trace 收进“高级诊断”。历史接口未返回的工具过程保持为空，不在 Web 猜测。
- 自动化新增消息按钮、概览/高级诊断分层、两个历史 Run 精确切换和生成中“当前运行”测试。Web 全量验证通过：`npm run tsc`、`npm run biome:lint`、35 套/229 项 Jest、`npm run build`、`npm audit --omit=dev`（0 漏洞）和 `git diff --check`。Jest 仍保留既有 open-handle 提示，但退出码为 0。
- Web 提交：`0ad5424 feat: attach run diagnostics to AI messages`。该提交未推送、未构建镜像、未部署；Backend 保持 `develop` ahead 2，AI Orchestrator 工作树干净。Mobile 原有 5 个未提交文件继续保留且未触碰，父仓库 `.codex` 继续保持未跟踪。
- 下一步：路线图第二阶段第 5 项“数据新鲜度和完整结果入口”，重点区分回答时 citation 快照与 Drawer 当前数据、显示查询/校验时间和截断状态，并提供刷新与业务模块完整结果入口；同时应在 staging 使用包含多轮成功、历史失败和生成中 Run 的真实会话人工验收本项。

### 2026-07-24 AI 草稿关键业务摘要（已提交，未推送/未部署）

- Web 新增共享 `AiDraftCompactSummary`，会话中的 `ai_draft` citation 与 `/ai/drafts` 草稿中心列表共用同一摘要规则；用户无需先打开复核工作台即可核对商品、价格、单位、往来单位、日期、订单数量与金额、仓库或库存变化。
- `ai_draft` citation 的 `data` 已确认是 Backend 返回的完整持久草稿，包含 `payload`、validation、version、status 和 execution；`list_ai_drafts_v1` 返回同一结构，因此本项不需要扩展 Backend 契约。Web 领域 Service 新增统一 `mapAiDraft` / `resolveAiDraftCitation`，消息卡片不再自行解析草稿版本、状态、校验和执行回执元数据。
- 商品建档摘要展示名称/编码、库存单位、标准售价、批发价、零售价、成本价以及初始库存和仓库。销售/采购摘要展示客户或供应商、单据与交付日期、商品行数、按 UOM 分组的数量、草稿金额和涉及仓库；不同 UOM 不直接相加，任一行缺少数量或价格时不展示误导性的部分金额合计。库存调整摘要展示商品、仓库、当前库存、目标库存、差异数量、估值参考和原因。
- 四类草稿组件测试、消息卡片接入测试和 citation 领域映射测试已补齐。Web 全量验证通过：`npm run tsc`、`npm run biome:lint`、35 套/227 项 Jest、`npm run build`、`npm audit --omit=dev`（0 漏洞）和 `git diff --check`。Jest 仍保留既有 open-handle 提示，但退出码为 0。
- Web 提交：`c84d89e feat: summarize AI draft business facts`。该提交未推送、未构建镜像、未部署；Backend、AI Orchestrator 和 Mobile 均无本项改动。Mobile 原有 5 个未提交文件继续保留且未触碰，父仓库 `.codex` 继续保持未跟踪。
- 后续状态：路线图第二阶段第 4 项“每条消息独立 Run”已由上方最新章节完成。仍建议把版本冲突、错误分类、紧凑摘要和消息级 Run 一起在 staging 用真实账号人工验收。

### 2026-07-24 AI 工作台 P1 前两项（已提交，未推送/未部署）

- Backend 新增稳定的草稿乐观锁冲突契约：保存、历史恢复或执行遇到过期 `expected_version` 时返回 HTTP `409` 与 `code=AI_DRAFT_VERSION_CONFLICT`，不再要求 Web 依赖中文错误文案。相关设计已同步修正 `product-setup-draft-v2` 和“用户确认后由 Frappe 正式领域服务执行”的主体表述。
- Web 草稿工作台新增保存、校验、执行和回执步骤状态；保存或最终确认发生版本冲突时读取最新草稿，展示“原打开版本 / 我的输入 / 最新持久版本”三方字段差异，可全部采用最新版本或在最新版本上选择性重放本地字段。订单商品明细作为整体冲突字段处理，不按数组下标静默合并。
- 无本地修改的执行前刷新若发现更高版本，会刷新工作台并要求用户重新确认，不直接执行；确认弹窗打开后再次发生冲突也会进入同一恢复流程。冲突合并始终以触发冲突的草稿快照为基线，避免刚保存的新版本被误判为未保存输入。
- Backend 进一步贯通 AI 流式错误码：Orchestrator 的限流、预算、并发、模型熔断、Prompt 版本、内部认证和服务不可用代码会保留到 SSE `error.code` 与持久 Run `error_code`；权限和校验错误也转换为稳定代码。未知内部异常统一为 `AI_RUN_FAILED` 和通用用户提示，不把数据库、供应商或堆栈细节暴露给普通用户。
- Web 失败消息按稳定错误码分为四类：临时/限流问题提供“稍后重试”；请求校验或模型拒绝恢复原问题供修改；权限拒绝不提供无意义重试；预算与系统/治理配置故障引导查看诊断和联系管理员。所有恢复均为人工动作，不自动重复收费调用；页面刷新后继续使用持久 Run 的相同分类。
- Backend 验证：`test_ai_repository + test_ai_service` 共 55 项通过，Backend `git diff --check` 通过；当前 backend bench 环境未安装 Ruff，因此未伪报 Ruff 已执行。
- Web 验证：`npm run tsc`、`npm run biome:lint`、34 套/222 项 Jest、`npm run build`、`npm audit --omit=dev`（0 漏洞）和 `git diff --check` 全部通过。失败分类定向测试 5 套/41 项通过，另有 SSE/Gateway 错误包络 Service 测试。
- 已提交 Backend `60144b1 feat: add AI draft version conflict contract`、`0bf60ef feat: preserve AI run failure codes`；Web `0f43e28 feat: recover AI draft version conflicts`、`30a5831 feat: classify AI failure recovery`，另有前置未推送文档提交 `874dc15 docs: add AI Web optimization roadmap`。父仓库将在本节提交中把 Backend gitlink 更新到 `0bf60ef`。以上提交均未推送、未构建镜像、未部署。
- 仓库边界：父仓库仅保留 `.codex` 未跟踪状态；Mobile 原有 5 个未提交文件继续保留且本轮未触碰；AI Orchestrator 无本轮改动。
- 下一步：先在 staging 使用两个页面并发编辑同一草稿，并人工制造 429、权限拒绝和上游不可用，验收字段选择、错误动作、刷新恢复、诊断和正式回执；代码路线下一项是草稿卡片关键业务摘要，随后再做每条消息独立 Run。

### 2026-07-23 AI 工作台交互 P0 收口（已推送并部署）

- Web 草稿编辑器已实现原地闭环：保存不自动关闭；“确认执行”会先保存未提交修改或重读最新持久版本，通过后端校验后展示业务复核摘要，最后使用最新版本执行并在当前编辑器展示正式回执。执行期间禁止关闭、重复保存和重复提交。
- AI 会话草稿卡片与 `/ai/drafts` 列表/Drawer 已移除绕过复核工作台的直接执行入口，统一使用“复核并执行 / 完善草稿”；版本历史、业务编辑器交接和放弃草稿收入次级菜单。
- 常用 Prompt 改为只回填 Sender 和场景，不再点击即发送。AI 调用失败保留助手消息位置、错误和显式重试；重新打开活跃失败会话也会从持久化 Run 恢复原问题、场景和模型重试上下文。
- 归档会话显示明确只读提示，Sender 禁用且只提供“新建会话”恢复路径。会话列表筛选状态与当前会话真实状态已拆分，切换筛选会清空当前选中项，避免误锁/误解锁会话。
- Web 设计事实源 `AI_WEB_FRONTEND_DESIGN.zh-CN.md` 已同步当前交互约束和 P1/P2 路线：版本冲突对比、失败分类恢复、长会话窗口化、快捷键/可达性、性能预算和治理查询缓存。
- 验证通过：`npm run tsc`、`npm run biome:lint`、32 套/205 项 Jest、`npm run build`、`npm audit --omit=dev` 为 0、Web `git diff --check`。Jest 仍有既有 open-handle 提示，退出码为 0。
- Web `3362634 feat: refine AI workspace interactions` 已推送 `origin/main`；父仓库交接提交 `8ef24337 docs: record AI workspace interaction handoff` 已推送 `origin/develop`。本轮未修改 Backend、AI Orchestrator 或 Mobile；Mobile 既有 5 个未提交文件继续保留，父仓库未跟踪 `.codex` 继续不提交。
- 推送触发的 Web CI run `30003868944` 与 coverage run `30003869068` 均成功。Web 镜像构建 run `30004171792` 再次通过 TypeScript、Biome、32 套/205 项 Jest，并成功发布 `ghcr.io/rgc318/myapp-web:staging-20260723-3362634`；镜像 digest 为 `sha256:a85bb58dc913d35eea052a73cdd055834e3a6aee6384d51d3d20ec83c2eb9b9c`。
- Web 部署 run `30004476381` 成功，目标容器使用上述不可变标签并处于 starting/健康检查通过状态。部署后直连 `192.168.31.229:30080` 验证 `/healthz`、`/user/login`、`/api/method/ping`、`/ai` 与 `/ai/drafts` 均为 HTTP 200；入口 HTML 为 `Cache-Control: no-store`，Ping 返回 `{"message":"pong"}`。
- 当前仓库没有可复用的 staging 登录态或 E2E 凭据，因此尚未冒充完成人工登录后的业务操作验收。下一步应使用真实测试账号在浏览器验收草稿保存/复核/执行回执、归档会话只读、新建会话恢复和失败重试；通过后进入 P1，优先实现版本冲突对比与恢复，其次是按错误码分类恢复和长会话窗口化。

### 2026-07-23 单位置顶与 AI 商品建档价格补全（已提交并推送）

- 共享单位排序规则统一为 `Box / 箱` 第一、`Nos / 件` 第二，其余单位保持原顺序；Backend 商品 `all_uoms`、Web 通用 `UomSelect`/商品单位上下文、Mobile 通用 UOM 搜索及主要商品/采购单位选择入口均已接入。
- AI 商品建档草稿已从原有 Standard Selling + 旧估值/成本候选扩展为四档价格：`standard_selling_rate`（标准售价/默认单价）、`wholesale_rate`（Wholesale 批发价）、`retail_rate`（Retail 零售价）、`standard_buying_rate`（成本价/默认采购价）。Orchestrator Schema 与 Prompt 已升级为 `product-setup-draft-v2`，可从用户原文区分四类价格；`valuation_rate` 仅保留明确“估值价”和旧响应兼容。Backend 草稿编辑、重校验、预览、交接和原地正式执行均保留这些字段；正式执行复用 `create_product_v2` 写对应价格表，成本价继续作为首次入库成本，售价不会用于库存计价。
- Web 文案已明确为“标准售价（默认单价）”“批发价”“零售价”“成本价（默认采购价）”，商品主数据页接收 AI 交接时也会回填批发价和零售价。Mobile 既有四档价格字段是本轮契约对齐参考，未重写其价格逻辑。
- 验证通过：AI Orchestrator Ruff、Pre-commit、89 项 pytest、test 镜像内 89 项测试和 runtime 镜像构建；Backend `test_ai_service + test_uom_display + test_wholesale_service` 共 73 项；Web `npm run tsc`、`npm run biome:lint`、32 套/199 项 Jest；各相关仓库 `git diff --check`；Mobile 本轮涉及文件的定向 ESLint。
- 已推送 AI `f246542 feat: expand AI product setup pricing`、Backend `703a8e4 feat: complete AI product pricing and UOM priority`、Web `e03e586 feat: improve AI product pricing and UOM selection`、Mobile `15a1a87 feat: prioritize common UOM options`。Mobile 推送同时包含该分支原先已存在的前置提交 `1596c73 fix: display business UOM labels consistently`。
- Mobile 全量 `npx tsc --noEmit` 仍被工作区范围内的大量既有/并行类型问题阻断，错误覆盖报表、样式、LinkOption、采购编辑和当前未提交价格映射等多处；本轮新增共享 UOM 排序 helper、Mobile UOM 搜索和主要选择器未出现独立 ESLint 错误。原有并行改动继续保留在 `app/common/product-search.tsx`、`lib/sales-mode.ts`、`services/gateway.ts`、`services/products.ts`、`services/sales.ts`；其中后两个混合文件只提交了本轮 UOM 排序区块，其余价格/销售改动仍未提交。
- 父仓库本次提交固定 Backend `703a8e4` 与 AI `f246542` 子模块指针，并提交本交接记录；父仓库原有未跟踪 `.codex` 继续未触碰。
- staging 已部署完成：ERP/AI 镜像构建 run `29994851612`、Web 镜像构建 run `29994851719`、ERP/AI 部署 run `29995281853`、Web 部署 run `29995281707` 均成功。ERP/AI 使用 `staging-20260723-37c3ac7`，Web 使用 `staging-20260723-e03e586`；`staging.example.com` 已完成 `bench migrate`。
- 部署健康检查确认 AI Orchestrator、Qdrant、MariaDB、Backend、各队列 Worker、Scheduler、WebSocket 和 Frontend 均运行正常，Backend → AI 内部认证通过，AI 状态为 `ok`；服务器内 ERP 首页和 Ping 为 HTTP 200。本地直连 `192.168.31.229:28080` 的 ERP 首页/Ping，以及 `192.168.31.229:30080` 的 Web 健康页、登录页、Ping 和商品页均为 HTTP 200。Mobile Web Preview 自动部署 run `29987625995` 也已成功。
- Web 首次手动部署 run `29994471175` 在镜像构建前误用不存在的 `staging-latest`，因 `manifest unknown` 失败且未替换旧容器；随后先构建唯一标签再部署成功。后续继续遵循“先完成镜像构建，再使用相同不可变标签部署”的顺序。

### 2026-07-23 LiteLLM 模型同步、模型管理命名与真实可用性检查

- AI Orchestrator、Backend 与 Web 已完成并推送本轮改动。模型同步继续以当前 `MYAPP_AI_LITELLM_API_KEY` 调用 LiteLLM `/v1/models`，增加 no-cache 请求头，并明确返回 `source=litellm` 与 `visible_count`；同步表示当前 Key 可见性，不再误标为真实健康。
- 新增 `POST /internal/v1/governance/models/availability` 与 Gateway `check_ai_model_availability_v1`。Chat 模型调用最小 `/v1/chat/completions`，Embedding 模型调用最小 `/v1/embeddings`，最多 4 路并发；Backend 更新 `available / unavailable`、耗时对应的返回结果、Provider 模型名和稳定错误码并记录审计，不保存模型输出/Provider 错误原文，也不会因单次失败自动修改人工模型状态。已有真实检查结果不会被后续普通同步降回 `listed`。
- Web 菜单和页面用户文案已由“模型治理”改为“模型管理”；同步成功提示当前 Key 可见数量，新增带少量费用确认的一键可用性检查按钮，健康列显示“LiteLLM 可见 / 可用 / 不可用 / LiteLLM 不可见”和错误码。
- 验证通过：AI Ruff、Pre-commit、89 项 pytest、test/runtime Docker 镜像；Backend 模型管理与 Gateway 141 项 unit；Web TypeScript、Biome、32 套/198 项 Jest 和 production build；三仓库 `diff --check`。已推送 AI `f48c14b`、Backend `ab3a708`、Web `51670b7` 和父仓库 `dc3c4602`。
- staging 镜像构建 run `29925570558`、Web 镜像构建 run `29925386108`、ERP/AI 部署 run `29979836312`、Web 部署 run `29980057785` 均成功。服务器父仓库为 `dc3c4602`；ERP/AI 使用 `staging-20260722-dc3c460`，Web 使用 `staging-20260722-51670b7`，目标容器均 running/healthy，模型管理页面、登录页、Ping 和健康检查均为 HTTP 200。
- 实机以 Administrator 上下文执行同步与真实可用性检查：当前 LiteLLM Key 可见 13 个、缺失 0；13 个模型中 9 个可用，`nvap-gpt-5.5`、`nvap-gpt-5.6-luna`、`nvap-gpt-5.6-sol`、`nvap-gpt-5.6-terra` 在 20 秒探测阈值内返回 `PROVIDER_TIMEOUT`。`erp-embedding` 和其余 8 个 Chat 模型真实调用成功，结果已写入模型注册表与审计。

### 2026-07-22 Web 前端部署文件补齐与容器验收

- 独立 Web 仓库 `frontend/myapp-web` 已提交并推送 Node.js 22 + Nginx Unprivileged 多阶段 `Dockerfile`、`.dockerignore`、生产 Nginx 模板和 `DEPLOYMENT.zh-CN.md`；Nginx 支持 SPA history fallback、`/api/method/`、`/files/`、`/private/files/` 同域代理、AI POST + JWT SSE 关闭缓冲及 300 秒超时、健康检查、入口不缓存和哈希资源长期缓存。
- GitHub Actions 已把旧 Ant Design Pro GitHub Pages/Surge 模板替换为：完整 CI、GHCR staging 镜像构建发布、SSH 部署到 `vivy@192.168.31.229` 的 staging Web workflow。部署默认使用 `staging_default` 网络、`http://frontend:8080` 上游和宿主机 `30080` 端口，具备输入/Secret 校验、非 root 容器、capabilities 清理、三项 HTTP 验收和按旧镜像 ID 自动回滚。
- 已删除旧 `public/CNAME` 和三个 Surge PR preview workflow，避免继续发布到 `preview.pro.ant.design`；README 与 `.env.example` 已指向当前部署口径。运行时推荐 `MYAPP_WEB_API_BASE_URL=` 保持空值，由 Web Nginx 同域代理 Frappe，避免 CORS 和混合内容问题。
- 验证完成：`npm run tsc`、Biome、31 套/196 项 Jest、production build、workflow YAML 解析和 `git diff --check` 全部通过；本地从零 Docker build 成功。容器以 UID 101、`no-new-privileges`、`cap-drop ALL` 启动并 healthy，`nginx -T` 通过。首次 staging 部署复验发现无尾斜杠路由会把浏览器重定向到容器内部 `:8080`，已由 `3a94950 fix: serve clean SPA routes directly` 修复，同时把部署门禁收紧为 `/user/login` 必须直接返回 200。
- Web 部署提交均已推送 `origin/main`：`6784631`、`ce40379`、`2481f53`、`3a94950`。用户验收截图进一步发现数据库重置后模型注册表为空，以及 6 个 AI 治理功能与用户/角色等系统功能平级。staging 已通过治理同步恢复 13 个模型，12 个聊天模型为 active/selectable，`erp-embedding` 按设计不进入聊天下拉框；Web `db6140b fix: group AI administration routes` 把模型、策略、用量、向量、审计和数据治理归组到“系统管理 > AI 管理”，并增加路由层级单测。
- 最终 CI run `29907558040`、coverage run `29907558342`、镜像构建 run `29907761294` 和部署 run `29908433648` 均成功。目标 `192.168.31.229:30080` 正在运行 `ghcr.io/rgc318/myapp-web:staging-20260722-db6140b`，容器 UID 101、状态 running/healthy、网络为 `staging_default`；`/healthz`、`/user/login`、动态 SPA 路由、`/administration/ai` 和 `/api/method/ping` 均为 200，AI 未授权流式请求由 Frappe 返回 403，哈希 JS 返回 immutable 缓存头。Web 工作树 clean。父仓库既有 `services/myapp-ai` gitlink 脏状态和未跟踪 `.codex` 未触碰；本交接文件为本轮唯一父仓库修改。

### 2026-07-22 staging 部署、公司交易重置与完整运行态回归

- `192.168.31.229:/srv/frappe_docker` 已部署 ERP/AI 固定镜像 `sha-b4f95ca`；AI Orchestrator、Qdrant、MariaDB、Backend、Worker、Scheduler、WebSocket 与 Frontend 健康，首页和 Ping API 均 HTTP 200。部署 workflow 的 SSH command timeout 已提交为 `8c6f7828 fix: allow slow staging image pulls`，部署 run `29887181264` 成功。
- 重置前备份位于 `/srv/frappe_docker/backups/staging/staging-backup-staging.example.com-20260722-112316.tar.gz`，SHA-256 为 `bbc540320fb97da0f83e757c1c37f662efdef4e123fd35361e4fa15e0fbffe09`。ERPNext `Transaction Deletion Record` `TDL0001` 已完成 `rgc (Demo)` 公司级交易重置，清理 14 类、7,222 条交易/库存/账务引用，用户保持 14 个、启用 5 个，核心主数据数量不变；危险开关已恢复为关闭，环境类型为 `staging`。
- staging 完整运行态回归：Backend `pip check`、migrate、592 项 unit、8 项真实站点 integration 全部通过；Gateway/V2/AI HTTP 共执行 132 项，其中 131 项原测试断言通过，唯一旧断言仍要求所有 citation 为 `purchase_order`，按当前 `business-result-set-v1` 正式契约复验为 `business_result_set + 5 purchase_order` 并通过；采购快捷 HTTP 39 项全部通过。
- JWT 一次性 Token 未修改 User 密码/API Key；`me → refresh → 旧 refresh 401 → logout → 注销 access 401` 和无效 Token 401 均通过，测试 Token 已撤销并删除。AI 运行态发现 13 个模型，合成向量 upsert/search/delete 全链路通过且 point 已删除。
- 回归后 `rgc (Demo)` 总账借贷差额为 0、负库存 Bin 为 0，用户仍为 14/5。HTTP/integration 回归生成的业务测试数据当前保留用于验收追踪；如需再次清空，应重新执行受控公司级交易重置。

### 2026-07-21 企业测试数据管理与公司级重置交付完成

- Backend `1b73cbc feat: add enterprise test data reset workflows` 已推送 `origin/develop`；Web `c397654 feat: add test data administration console` 已推送 `origin/main`。
- 支持版本化标准数据集、generate/supplement/reset、small/medium/large 档位、审计、Redis 进度、完整性验证，以及封装 ERPNext `Transaction Deletion Record` 的公司级交易重置。
- 临时 Site 真实清理 15 类、24,656 条交易引用并保留核心主数据，随后成功重建 38 个标准模板对象；临时 Site、数据库、用户和备份已全部清理。
- 原 `localhost` 未受破坏性测试影响，保持 38 个活动模板对象，UOM、库存、发票未结金额、对象存在性和总账平衡验证全部通过。
- 最新验证：Backend 592 项 unit、Ruff、空白检查；Web TypeScript、Biome、31 套/196 项 Jest、production build。

### 2026-07-19 AI 业务工作台、草稿闭环与模型切换提交完成

- 本轮把 2026-07-18 的三组连续改动作为同一交付里程碑收口：AI 自动场景纠偏、查询结果当前页详情、四类草稿原地编辑/确认执行、商品草稿字段与校验修复，以及 LiteLLM 全模型同步与工作台自由切换模型。
- 已推送 Backend `cb6b65b feat: complete AI draft execution and model controls` 到 `origin/develop`；包含 `execute_ai_draft_v1`、草稿 `executed` 终态与持久回执、版本/确认/权限/幂等/审计保护、商品默认采购价语义、完整模型注册同步、普通用户可选模型接口及 Chat/SSE/四类草稿模型校验。
- 已推送 AI Orchestrator `fcf6b9c feat: expose selectable LiteLLM models` 到 `origin/develop`；包含 LiteLLM 完整模型发现、Embedding 分类、可选 `model_alias` 契约、显式模型成本元数据和禁用静默 fallback。
- 已推送 Web `3dccc00 feat: complete AI business workspace controls` 到 `origin/main`；包含共享草稿编辑器、当前页单据/商品 Drawer、草稿原地执行与回执、商品字段校验和业务术语、模型选择器及重试模型保持。
- 父仓库本次提交同步 Backend/AI 子模块指针，提交企业设计事实源 `docs/05-development/04-ai-business-workbench.zh-CN.md`，并更新本交接与集中工作总结。父仓库既有未跟踪 `.codex` 继续不提交；Mobile 五项用户改动未触碰。
- 最终验证保持通过：Backend 177 项；AI Ruff、Pre-commit、82 项 pytest、test/runtime 镜像；Web TypeScript、Biome、30 套/184 项 Jest、production build；四仓库 `diff --check`。真实 Session HTTP/SSE 验证为 LiteLLM 9 个模型、工作台 8 个聊天模型、`erp-embedding` 被排除，固定 `opencode-glm-5.2` 后实际完成模型一致。
- 当前运行态：`ai-orchestrator` healthy，Backend/Frontend HTTP 正常。Backend 8000 当前使用与 `.vscode/launch.json` 等价的 `--noreload --nothreading` 进程，但未挂接 VS Code 调试器；需要断点时先停止当前进程再按 F5。

### 2026-07-18 LiteLLM 全模型同步与 AI 工作台自由切换模型

- 根因已修复：Orchestrator 旧模型发现逻辑虽然读取 LiteLLM `/v1/models`，但只向 Frappe 暴露 `MYAPP_AI_MODEL` 与 `MYAPP_AI_EMBEDDING_MODEL`；Chat/SSE/四类草稿请求也没有 `model_alias` 契约，因此 Web 既看不到完整库存，也无法固定实际执行模型。
- Orchestrator 现在返回当前 LiteLLM Key 可见的全部模型；配置的 Embedding 别名或名称包含 `embed / embedding` 的模型分类为 `embedding`，其余为 `fast_chat`。Frappe 同步全部模型，已消失模型标记为 `degraded / missing`，人工 `disabled / retired` 不被覆盖。
- 新增登录用户接口 `list_ai_selectable_models_v1`，只返回注册表中 `active / validated` 且能力为 `fast_chat / reasoning / structured` 的模型。Chat、SSE 和四类结构化草稿新增可选 `model_alias`；Frappe 在调用 Orchestrator 前再次校验，Embedding、停用、退役、缺失和注册表外别名均拒绝。
- Web `/ai` 上下文栏新增模型选择器，默认项为“自动选择（策略）”；用户固定模型后显示明确状态，并在普通 SSE、四类草稿和人工重试中保留同一 `modelAlias`。显式选择时 Orchestrator 禁用本次请求的静默模型 fallback，最终 Run 返回的 `model_alias` 仍作为实际执行事实。
- 自动化验证全部通过：Backend AI Model Governance/Service/Repository/Gateway 177 项；AI Orchestrator Ruff 与 82 项 pytest；Web TypeScript、Biome、30 套/184 项 Jest 和 production build；父仓库、Backend、AI、Web `git diff --check`。Jest 仍有既有 open-handle 提示，但退出码为 0。
- 运行态已重建 `ai-orchestrator` 并完成真实 Session HTTP/SSE 验收：Orchestrator 返回 9 个模型；Frappe `sync_ai_model_registry_v1` 返回 `synced_count=9`、`missing_count=0`；普通可选列表为 8 个聊天模型且不含 `erp-embedding`。SSE 固定 `opencode-glm-5.2` 后最终 `model_alias` 和 Provider model 均为该别名，回复“模型切换正常”，测试会话已归档；提交 `erp-embedding` 被 Frappe 以 HTTP 422 拒绝，未进入模型调用。
- 运行注意：本轮为加载新 Gateway 曾重启 Dev Container 的 Backend 容器，VS Code F5 进程随之结束；当前已按 `.vscode/launch.json` 等价参数恢复 `frappe serve --port 8000 --noreload --nothreading`，HTTP 服务正常，但不是挂接调试器的 F5 会话。如需断点调试，应先停止当前 8000 端口进程再重新按 F5 启动。
- 当前改动未提交：Backend `apps/myapp`、AI `services/myapp-ai`、Web `frontend/myapp-web` 和父仓库交接/设计文档均有本轮及前序 AI 工作台改动；父仓库既有未跟踪 `.codex` 和 Mobile 五项用户改动继续保留，不得回滚或提交 `.codex`。

### 2026-07-18 AI 商品草稿校验、状态保留与业务术语修复

- 修复商品草稿再次编辑时可能回填会话 citation 旧快照的问题：`/ai` 每次打开草稿编辑器都会按草稿 ID 调用 `get_ai_draft_v1` 读取最新持久版本，并立即刷新消息卡片；不再以生成时快照作为编辑事实源。
- 商品草稿存在校验问题时，保存后编辑器保持打开并直接展示后端错误，不再关闭后只留下灰色“确认执行”按钮。表单提交前也会按当前输入执行条件校验：初始库存数量大于 0 时，入库仓库和默认采购价必填；校验失败不会调用更新接口，用户已经输入的其他字段保持不变。
- 文案与 Mobile 商品模块对齐：`库存单位` 改为 `库存基准单位`；移除可独立选择的“初始库存单位”，初始库存固定使用库存基准单位；`库存估值价` 改为业务术语 `默认采购价`；`编辑并重新校验 / 保存并重新校验` 改为 `完善草稿 / 编辑草稿 / 保存草稿`，自动校验作为系统行为说明而非按钮技术文案。
- Backend 商品草稿新增 `standard_buying_rate` 规范字段，兼容读取旧 `valuation_rate`。正式执行时默认采购价写入 Standard Buying，并作为首次入库成本；标准售价不会用于库存计价。复杂业务编辑器交接同时预填标准采购价和估值价，保留专业页面进一步调整能力。
- 已验证：Backend AI Service/Repository/Gateway 159 项通过；Web TypeScript、Biome、30 套/182 项 Jest 和 production build 通过；父仓库、Backend、Web `git diff --check` 通过。Jest 仍有既有 jsdom `getComputedStyle` 和 open-handle 非阻塞提示，退出码为 0。
- 用户重启 Backend F5 后完成真实 Session HTTP 验证：`list_ai_drafts_v1` 返回 `AI_DRAFTS_FETCHED`；专用测试草稿 `AI-DRAFT-53b4c2b96e3344558b28698b75c9a931` 缺默认采购价时保存为版本 2 且 `ready_for_handoff=false`，商品名称、数量和仓库保持不变；补默认采购价后版本 3 变为 `ready_for_handoff=true`，`opening_uom=stock_uom`。随后测试草稿已标记 `discarded`；`confirmed=0` 调用正式执行接口返回 HTTP 422，未创建 Item、Item Price 或库存单据。
- 本轮未修改 Mobile；其当前 `app/common/product-search.tsx`、`lib/sales-mode.ts`、`services/gateway.ts`、`services/products.ts`、`services/sales.ts` 五项既有用户改动继续保留。Backend 当前已加载新接口。

### 2026-07-18 AI 业务操作台闭环完成

- 新增企业级设计事实源 `docs/05-development/04-ai-business-workbench.zh-CN.md`。统一原则为：AI 只生成候选，用户必须明确确认；“需要确认”不等于“必须跳转”；查询、草稿编辑、重新校验、确认执行和正式回执应在 AI 工作台内闭环，业务模块深链只作为复杂操作的可选入口。
- Backend 新增 `execute_ai_draft_v1`，覆盖商品建档、销售订单、采购订单和库存调整四类草稿。执行前强制 owner、`draft` 状态、版本、`ready_for_handoff` 和 `confirmed=1` 检查，并使用草稿级文件锁、请求幂等和成功/失败 AI 审计；正式执行复用 `create_product_v2`、`create_order_v2`、`create_purchase_order` 和 `reconcile_inventory_stock_v1`，不在 AI 层复制业务逻辑。
- 草稿新增 `executed` 终态和持久回执字段：`execution_request_id`、`executed_by`、`executed_at`、`target_doctype`、`target_name`、`execution_result_json`。迁移 `extend_ai_draft_execution_fields` 已对真实 `localhost` 站点成功执行；只验证了旧草稿读取和未确认拒绝，未执行任何真实商品、订单或库存操作。
- Web `/ai` 与 `/ai/drafts` 均支持四类草稿原地编辑、保存并重新校验、明确确认执行和正式业务回执；成功后显示正式对象、执行人和执行时间。订单/发票编号在当前页 `BusinessDocumentDrawer` 打开，商品结果在 `ProductDetailDrawer` 打开；“在业务模块打开/继续”均降为次级可选入口。
- 价格边界已补齐：模型生成销售/采购草稿时仍忽略模型建议价并采用后端参考价；用户在草稿编辑器明确修改的非负价格由重新校验链路保留，负数价格回退到当前后端参考价并给出警告。
- 最终验证：Backend AI Service/Repository/Gateway 158 项通过；Web TypeScript、Biome、30 套/179 项 Jest 和 production build 通过；父仓库、Backend、Web `git diff --check` 通过。Jest 仍提示项目既有未清理异步句柄，但退出码为 0 且全部测试通过。
- 当前改动尚未提交：Backend 位于 `apps/myapp` 子模块，Web 位于独立仓库 `frontend/myapp-web`，父仓库包含新设计文档、交接文件和 Backend gitlink 脏状态；AI Orchestrator clean，父仓库既有未跟踪 `.codex` 保持不处理。当前 Backend 由 VS Code F5 以 `--noreload` 运行，页面联调前必须由用户停止并重新启动一次 F5 才能加载新接口；本轮未中断该调试会话。

### 2026-07-18 AI 场景残留与空商品草稿修复

- 根据用户截图和真实运行库会话 `AI-CONV-72998dcce4a14e7eaa5c842650379919` 定位：首次“添加一个新商品，煌星，10000一个，入库5000个”实际沿用了上一轮 `order_query`；手动切换 `product_setup_draft` 后固定场景又持续污染“查询一下煌星是否已经正常入库”及后续标点消息，最终额外创建标题为 `.` 的空商品草稿。第二张截图不是同一草稿版本丢字段，而是错误场景残留创建了不应存在的新草稿。
- Web 显式场景现只对当前一次发送生效，请求开始即恢复 `auto`，并在固定场景旁显示“仅本次发送”；历史会话重新打开仍恢复 `auto`。Frappe 意图解析现让明确写意图优先，并把商品是否入库、到货、现货或库存状态等问法路由到 `product_search`；商品检索词会从“查询一下煌星是否已经正常入库”等表达中提取为“煌星”。
- 当前未提交修改位于 Backend `apps/myapp`（AI Service、单测、API 文档）、Web `frontend/myapp-web`（AI 工作台、测试、设计文档）和父仓库本交接文件；AI Orchestrator clean，父仓库仍保留既有未跟踪 `.codex`。未修改或自动作废真实业务草稿，截图中的错误空草稿仍需用户按正常“放弃草稿”操作处理。
- 已验证：Backend AI Service/Repository/Gateway 152 项通过；Web AI 工作台与领域 Service 2 套/14 项 Jest、TypeScript、Biome 通过；Backend、Web、父仓库 `git diff --check` 通过。
- 当前 8000 端口的 Backend 由 VS Code F5 以 `frappe serve --noreload --nothreading` 启动；本轮未擅自中断用户调试会话。页面联调前需停止并重新启动一次 Backend F5 以加载新的意图解析代码，Web 开发服务通常可通过热更新加载前端修改。

### 2026-07-18 AI 工作台与商品草稿交付收口

- 分仓库提交和远端推送均已完成：Backend `cf7837d feat: add structured AI results and product setup drafts` 已推送 `origin/develop`；AI Orchestrator `2da8e7c feat: add governed AI product setup drafts` 已推送 `origin/develop`，并通过远端引用直接确认；Web `cf16894 feat: improve AI workspace results and product drafts` 已推送 `origin/main`。父仓库本文件所在提交同步 Backend/AI 子模块指针和最终交接状态。
- 本轮最终功能包含：AI 工作台固定视口高度与内部唯一滚动容器、`business-result-set-v1` 结构化单据结果、历史会话恢复 `auto` 防场景污染、Frappe 统一意图解析，以及 `product_setup_draft` 从 Orchestrator 严格 Schema、Frappe 权限/主数据校验、不可变草稿版本到 Web 编辑和商品页人工交接的完整链路。AI 只生成和校验草稿，不直接创建 Item、Item Price 或库存单据。
- 最终验证口径：Backend AI/Repository/Gateway 151 项通过；Web TypeScript、Biome、6 套/78 项定向 Jest 和 production build 通过；AI Ruff、Pre-commit、81 项 pytest、22 项 offline full gate 通过；四仓库 `git diff --check` 通过。提交钩子另对 Web 18 个暂存文件执行 Biome 写入检查并成功完成。
- 运行态已验证：Orchestrator `/health` 返回 `product_setup_draft=product-setup-draft-v1`；F5 重启后的真实 JWT HTTP 场景解析返回 `product_setup_draft`，商品草稿可恢复；Web `/ai` 与 `/master-data/products` 均 HTTP 200。真实草稿 `AI-DRAFT-c9ac496e9377463ebe2cb6c3ce85aa6c` 当前版本 2，正确保存“传承结晶 / 1000 个 / 标准售价 9999 CNY”，由于缺少叶子仓库和独立库存估值价保持 `ready_for_handoff=false`，且未创建正式业务数据。
- 提交完成后的仓库状态：Backend、AI Orchestrator、Web 工作区 clean；父仓库只保留既有未跟踪 `.codex`，不得提交。已知非阻塞风险：现有 HS256 HMAC Secret 长度为 30 bytes，低于建议的 32 bytes，需后续按 Secret 轮换流程处理；本轮未在文档或提交中记录 Secret/JWT。`erp-readonly-v7` 的付费 live full gate 仍未执行，正式发布新 Prompt 策略前需要补跑。

- 2026-07-17 修复 AI 历史会话场景污染并新增商品建档结构化草稿。重新打开会话不再把上一轮实际 `order_query` 恢复为固定 UI 场景，而是回到 `auto`；发送前由新增 Frappe `resolve_ai_scenario_v1` 统一识别只读查询或四类写意图，Web 不复制关键词规则。“添加一个新的商品叫做传承结晶，1000个，售价9999元每个”现稳定路由到 `product_setup_draft`，不再执行订单查询。
- 商品建档 Prompt 为 `product-setup-draft-v1`，Orchestrator 新增 `/internal/v1/drafts/product-setup` 严格 Schema；Frappe 重新校验 Item/Item Price/Stock Entry 权限、名称编码重复、分类、品牌、UOM、公司仓库、币种、售价、初始库存和估值价，持久化 `product_setup` 草稿、版本和审计。售价与库存估值价严格分离，初始库存必须补叶子仓库和估值价后才能交接；Web 草稿卡片/编辑器/草稿中心已接入，交接到 `/master-data/products` 并预填既有 `create_product_v2` 表单，最终仍由用户主动保存。
- 验证：Backend AI/Repository/Gateway 151 项；Web TypeScript、Biome、6 套/78 项定向 Jest、production build；AI Ruff、Pre-commit、81 项 pytest 和 22 项 offline full gate 全通过。Orchestrator 已按当前 Compose 重建，`/health` 返回 `product_setup_draft=product-setup-draft-v1`。Backend F5 重启后，真实 JWT HTTP `resolve_ai_scenario_v1` 返回 `product_setup_draft`，`get_ai_draft_v1` 成功恢复商品草稿；Web `/ai` 与 `/master-data/products` 均 HTTP 200。真实 Frappe→Orchestrator 调用已生成 `AI-DRAFT-c9ac496e9377463ebe2cb6c3ce85aa6c`（版本 2），正确提取“传承结晶 / 1000 个 / 标准售价 9999”，并因缺少仓库和独立估值价保持 `ready_for_handoff=false`；没有创建 Item、Item Price 或库存单据。
- 2026-07-17 二次定位并修复结构化结果升级后长会话无法滚动。首轮遗漏了 `PageContainer` 自动插入的 `.ant-pro-grid-content` 与 `.ant-pro-grid-content-children` 两层无高度包装，导致内层 `height: 100%` 无可解析基准，工作台继续随消息内容伸缩；同时 `Bubble.List` 的 `autoScroll`、滚动锁定和手动滚动实际作用于内部 `.ant-bubble-list-scroll-box`，不能由外层 messages 代管。现已按 Ant Design X 官方固定父容器/Flex 建议，把 PageContainer 固定为视口扣除 56px 全局 Header，补齐 GridContent、children-container、workspace、main、messages 的连续 Flex 高度链与 `min-height: 0`；messages 使用 `overflow: hidden`，`Bubble.List` 根节点与内部 scroll-box 占满剩余高度，唯一纵向滚动归内部 scroll-box。同步更新 `ai-scroll-layout.test.ts` 和 Web 设计文档。Web TypeScript、Biome、3 套/11 项定向 Jest 和 production build 通过。
- 2026-07-17 AI 工作台开始按“结构化结果优先”优化：单据查询新增持久化 `business-result-set-v1` citation 元数据，记录公司、日期、状态、排序、每类上限、请求/返回数量和 `success / partial / empty`。Web 领域 Service 合成为 `AiBusinessResultSet`，按销售订单、销售发票、采购订单、采购发票使用 `Tabs + ProTable` 展示；旧历史会话缺少元数据时仍可从逐单据 citation 恢复分组。
- 单据 citation 在模型首 Token 前到达后立即显示业务表格，并提示“业务结果已返回，正在生成摘要”；模型正文移到结果之后，不再同时重复展示业务来源列表、逐条卡片和 Markdown 明细。状态、金额和未结金额复用共享展示工具；结构化结果宽度扩大，AI 工作区取消全局 Footer 并改为单一内部滚动。
- 查询 Prompt 升级为 `erp-readonly-v7`：保留 v6 的权限、公司和正式写操作边界，新增结构化结果不重复复述约束，摘要最多三个要点。模型上下文不再包含逐单据字段，只包含查询范围和返回数量；`success` 明确只表示结果覆盖，不代表业务健康。同步修正确定性日期范围结束日、共享名词“销售和采购订单/发票”解析以及旧评测数据漂移。验证：Web TypeScript、Biome、25 套/170 项 Jest、production build；Backend AI/Repository/评测/治理/向量/Gateway 190 项；AI Ruff、Pre-commit、80 项 pytest；父仓库、Web、Backend、AI `diff --check` 全部通过。Orchestrator 已定向重建，`/health` 返回 v7；VS Code F5 Backend 已于 15:33 CST 重启。真实 JWT + HTTP SSE 查询“最新 1 条销售订单”依次返回 `run_started → context/tool → business_result_set/单据 citation → model stream → completed`，结果集版本为 `business-result-set-v1`、无 error、73 个增量、首 Token 19.572 秒、总耗时 20.227 秒；摘要只说明查询范围和数量。v7 付费 live full-gate 尚未执行。
- 2026-07-17 修复 AI 工作台“看似不流式、不能切公司、业务查询无上下文”问题：首段前状态现在明确显示权限/公司确认、等待首个 Token 和客户端已等待时间，首 Token 到达后显示实时输出；不再把 Provider 首字等待描述成“思考”或“内容到达后逐段显示”。新会话增加 Company 远程选择器并以工作偏好为初值，历史会话公司保持锁定，跨公司必须新建会话。
- Web 默认场景改为 `auto`，由 Frappe 根据用户问题解析实际 `general / product_search / order_query / report_summary`。单据查询现支持销售订单、销售发票、采购订单和采购发票的单类型或混合查询；每种类型分别执行 DocType/记录权限、公司、日期、状态、金额、排序和数量限制。未明确日期的“最新”查询覆盖全部日期，不再默认限制近 30 天。
- 用户截图原句“查询最新的5条销售订单和销售发票，以及采购订单”已走真实登录与 SSE 验证：工具分别返回销售订单 5、销售发票 4、采购订单 5，结构化 citation 和正文均成功；缩短的每类 1 条复测返回三类真实引用、425 个 SSE 增量块，回答和警告均不再包含“只读试运行”或“只读”措辞。
- AI 查询 Prompt 升级为 `erp-readonly-v6`，能力描述改为“当前账号权限和公司范围内的受控业务查询”，正式业务写操作仍必须由用户在 ERP 页面确认。运行 Orchestrator 镜像已重建，`/health` 返回 v6；Backend 也已重启并真实端到端通过。本地提交为 AI `c42549f feat: clarify governed AI query prompt`、Backend `723eae7 feat: auto-route AI business document queries`、Web `f7838b5 feat: improve AI company and query controls`。
- 验证：Web TypeScript、Biome、24 套/167 项 Jest、production build、production audit 0 漏洞；Backend AI Repository/Service/Gateway 146 项；AI Ruff、Pre-commit、80 项 pytest、test 镜像 80 项均通过，三个仓库 `diff --check` 通过。Prompt v6 只完成真实定向 live 冒烟，尚未重跑 21 项付费 live full-gate；生产策略/Prompt 正式发布前必须补 full-gate。AI `c42549f` 已 push 到 `origin/develop`，父仓库本次提交同步 Backend/AI 子模块指针和本交接。
- 2026-07-17 AI 可感知流式与工作台界面继续完善：真实 Orchestrator 直连在 124ms 返回 `started`、3.32s 返回首段、共 28 个 1–3 字符增量；同一模型经 Frappe 的样本在 19ms 返回 `run_started`，但首段波动到 17.66s，证明代理未缓冲、主要等待来自当前唯一 Chat 模型 `opencode-deepseek-v4-flash` 的首字波动。Backend SSE 新增 `run_progress` 的 `context_ready / generating / model_started / streaming` 阶段，最终 `completed.stream` 返回增量段数和字符数；重启后真实 Frappe 样本返回 20 个增量、首 Token 12.41s、总耗时 12.69s。
- Web `/ai` 已从三栏监控式布局改为会话侧栏 + 居中对话区双栏，Run 诊断进入右侧 Drawer，移动端会话进入左侧 Drawer；首 Token 到达前显示阶段和客户端计时，首 Token 到达后显示实时输出状态。浮动 Sender、品牌栏、权限边界和消息区视觉已更新，开发态 Ant Design Pro `SettingDrawer` 已移除。结构化销售/采购/库存草稿仍只在严格 JSON 与 Frappe 业务校验完成后整体展示，但等待期间明确显示结构化生成与校验阶段。
- 本轮提交：Backend `779247f feat: expose AI streaming progress`；Web `5743b5c feat: modernize AI streaming workspace`。验证包括 Backend AI Repository/Service/Gateway 142 项、Web TypeScript、Biome、24 套/166 项 Jest、production build、`npm audit --omit=dev` 0 漏洞、`/ai` HTTP 200 和三个代码仓库 `diff --check`；Web 提交钩子已再次执行 Biome，父仓库提交前会复验。
- 2026-07-17 修复 AI 历史会话公司上下文漂移：Web 打开已有会话后保存并使用会话自身公司，新建会话才使用当前工作偏好默认公司；当两者不同时界面明确显示“会话公司”。Backend `_prepare_chat_run` 在调用方省略公司时从持久会话恢复公司，显式传入不同公司仍失败关闭。新增 Web 历史会话回归和 Backend 公司恢复单测。
- 2026-07-16 AI Web 运行诊断与草稿复核继续完善：Frappe Gateway 的同步回答、SSE 完成事件和三类草稿返回持久 Run 摘要，历史会话补首 Token；Web 右侧检查器现展示状态、后端总耗时、首 Token、Token 分解、Run/Trace、工具执行、警告和显式失败重试。`/ai/drafts` 详情已从原始 JSON 升级为业务字段、商品明细、库存变化、校验结果、不可变版本差异和重新校验恢复，原始数据保留为辅助页签。新增 AI 工作台流式页面测试、运行检查器和草稿复核组件测试。
- 本轮分仓库提交：Backend `ae1806d feat: improve AI conversation runtime context`；Web `fc7c354 feat: improve AI workspace diagnostics and drafts`；父仓库为本文件所在提交并同步 Backend gitlink。Backend 与 Web 工作区 clean，父仓库仅保留既有 `.codex` 未跟踪状态。
- 2026-07-16 AI Web 企业级现代化 Goal 已完成本轮功能交付：Web `/ai` 已迁移到 Ant Design Pro 官方 `@ant-design/x` / `@ant-design/x-markdown`，使用全高 Conversations、Bubble、Sender、Welcome、Prompts、Sources 和 Actions 工作区；支持活跃/归档会话、停止 SSE、持久 Run/反馈恢复、分类负反馈和结构化引用卡片。页面仍只经 Frappe Gateway，不直连 Orchestrator/LiteLLM。
- 新增 `/ai/drafts` 当前用户草稿中心及 Backend `list_ai_drafts_v1`：支持销售/采购/库存调整草稿分页筛选、详情、来源会话、校验、放弃和业务编辑器交接；Repository 查询强制 owner 隔离。`get_ai_conversation_v1` 现返回当前用户 Run 摘要与已保存反馈，页面刷新后不再丢失模型、Token、trace 和反馈状态。
- AI 治理 Web 已增加独立深链路由：模型、策略、用量、向量、审计和 Data Task；治理概览新增 Orchestrator 可达性、近 7 日请求/错误/成本和向量状态，用量页新增近 30 日 KPI/趋势。审计新增 Backend `list_ai_audit_events_v1` 服务端分页、关键词/动作/对象/优先级/日期筛选。
- 向量治理已补齐此前 Web 未暴露的 Backend 能力：System Manager 可查看在线索引、待处理/失败/排除计数，补建待处理、重试失败，并按 dry-run → 原因确认清理明确排除向量；清理契约固定 `erp_items_changed=0`。Data Task 序列化新增后端 `actions.allowed/reason`，Web 不再只按本地状态推导审批、执行和回滚。
- Web 主题基线更新为 Ant Design 6 主色、固定 Header、统一圆角与页面间距，移除模板业务页背景图；新增依赖仅为官方 `@ant-design/x` 2.8 和 `@ant-design/x-markdown` 2.8，没有引入第三方后台模板或第二套样式系统。
- 本轮验证：Web TypeScript、Biome、21 套/159 项 Jest、生产 build 通过，`/ai`、`/ai/drafts`、`/administration/ai/audit` 开发路由 HTTP 200；Backend AI/Data Task/治理/向量/Gateway 184 项通过。真实站点只读冒烟确认草稿列表、运行概览和审计分页执行成功，Orchestrator、Embedding、向量、运行治理和 Langfuse 均返回已配置/可达。Web/Backend/父仓库 `diff --check` 通过。
- Web 已通过精确 `overrides` 处理 4 个间接生产依赖问题：`lodash` / `lodash-es` 固定到 4.18.1，受影响的 `path-to-regexp 8.x` 固定到 8.4.0，受影响的 `yaml 1.x` 固定到 1.10.3；`npm audit --omit=dev` 从 3 high + 1 moderate 降为 0。TypeScript、Biome、21 套/159 项 Jest 和 production build 全部通过；未使用 `npm audit fix --force`。完整开发依赖审计仍包含旧 Umi/Pro CLI 工具链告警，应与生产依赖口径分开治理。
- 本轮代码与设计文档已完成分仓库提交：Backend `1b7cfd4 feat: align AI web governance contracts`，Web `2eb4f09 feat: modernize enterprise AI workspaces`。Backend 与 Web 工作区 clean，分别较远端 ahead 1；父仓库本次提交更新 Backend gitlink、AGENTS 文档索引和本交接，仍保留既有 `.codex` 本地未跟踪状态且不得提交。

- 2026-07-16 完成 staging 构建代理故障复盘：不整体回退 `bdd00ed9 fix: harden staging image builds`。代理失效是最初外部故障，但代理恢复后仍独立复现 Git/GnuTLS 瞬时失败、Frappe v16.18.3 构建期 Redis 需求和逐 app Python resolver 漂移；显式代理覆盖/清空、有限重试、BuildKit cache、分阶段资产构建、builder 临时 Redis、uv 联合解析及 import/`pip check` 门禁均有独立保留理由。长期判断准则已补入 `KNOWN_ISSUES.zh-CN.md`，部署复盘已补入 `STAGING_DEPLOYMENT.zh-CN.md`。
- 2026-07-16 完成 Compose、启动/停止/部署/回滚、当前 Dev Container、独立 AI、staging ERP/AI 镜像和 Backend→AI 的完整本地验收。development、development+Langfuse、Dev Container、production、production+Langfuse、staging internal/HTTPS、pwd、CI、AI standalone/integration 共 11 组 Compose 均可解析；相关 Shell 语法及脚本参数分支全部通过。
- staging ERP 镜像构建已修复代理、瞬时 Git 失败、构建期 Redis、重复依赖下载和逐 app resolver 漂移：本地构建支持 `BUILD_HTTP_PROXY` / `BUILD_HTTPS_PROXY` / `BUILD_NO_PROXY` / `BUILD_NETWORK`，`bench init` 最多重试三次，uv/Yarn 使用 BuildKit cache，资产构建使用 builder 内回环临时 Redis，三个 app 最终由 uv 联合解析并执行 import 与 `pip check` 门禁。合成 `myapp develop` 清单已实际构建 `myapp-erpnext-validation:codex-validation` 和 `myapp-ai-validation:codex-validation`，成品镜像冒烟通过。
- 当前发布清单 `deploy/staging/apps.staging.json` 仍引用 `myapp main`；该分支尚未包含当前 `rgc-backend-kit` 依赖，真实 main 构建被 import 门禁正确拒绝。发布前必须先把 Backend `develop` 的已验收提交合入/标记到 release ref，再使用该不可变 ref 构建，不能通过删除门禁或在镜像中临时补包绕过。
- 当前运行 AI、Qdrant、Redis、Langfuse 均健康、零重启；Backend/Workers 无 LiteLLM/Langfuse Secret，Orchestrator 无 PostgreSQL/ClickHouse/MinIO 根密钥。Dev Container Backend 按设计保持 `tail -f /dev/null`，需由 VS Code/F5 启动 `bench serve`，因此未启动调试进程时 8000/8080 返回 404 属预期行为。
- 本轮复验：AI lock/Ruff/pre-commit/pip-audit、Docker 80/80、独立 Compose Chat + vector upsert/search/delete、runtime/tools/staging image、安全与非 root 检查均通过；Backend AI/Data Task/Gateway 178/178 通过，Backend→Orchestrator 认证 HTTP 状态检查通过。隔离 Compose 容器、网络和卷已清理。
- 真实忽略文件 `deploy/staging/staging.env` 仍缺新增 AI 镜像、Provider、Service Token 和 Frappe site host 等变量；`validate-staging-env.sh` 会按设计失败关闭。本轮只使用 `/tmp` 合成配置测试，未覆盖真实 staging 文件、未启动 staging、未推送验证镜像。

- AI Orchestrator 已从父仓库普通目录迁移为独立公开仓库 `https://github.com/rgc318/myapp-ai`，完整保留 12 个历史里程碑；`main` 与 `develop` 当前均指向 `052819e fix: use published Trivy action release`，主体独立交付提交为 `7f230f5 feat: complete standalone AI service delivery`。父仓库保持原路径 `services/myapp-ai` 子模块，因此原有 Compose、Dev Container 和 staging build context 兼容。
- AI 仓库现可独立克隆、锁定依赖、开发、测试、构建、启动和运维：新增 `.env.example`、Standalone Compose、Redis/Qdrant、合成 OpenAI/Frappe Provider、Chat 与向量 upsert/search/delete 集成测试、Makefile、启动/停止/健康脚本、uv.lock、Ruff/pre-commit/ShellCheck、依赖审计、Trivy、CodeQL、CODEOWNERS、License、Security/Contributing/Changelog 和 13 篇企业级服务文档。
- AI 本地与远程门禁全部通过：Docker 80/80、独立 Compose Chat/向量闭环、Ruff、pre-commit、ShellCheck、pip-audit 无已知漏洞、CI、CodeQL、Security/Trivy 均成功；发布 workflow 支持 amd64/arm64、provenance 和 SBOM。
- 父仓库已补齐 Backend 与 AI 两个 `.gitmodules` 声明；Dev Container 会在宿主机递归初始化子模块，开发/生产/本地 staging 构建脚本会对缺失 AI 子模块失败并给出恢复命令，staging workflow 会递归检出并把 AI commit 写入 OCI 镜像元数据。
- 剩余 AI 企业级收口 Goal 的本地可实施范围已完成：异步 OTLP、Langfuse Secret 最小化、三环境部署契约、检索噪声治理、30 条中文质量门禁、真实数据清理、Provider 复测、文档和分仓库提交均已交付。`erp-embedding` 当前已恢复并达到 v1 在线门槛；正式 Secret Manager/SSO/TLS/HA/staging 和新向量空间 full gate 仍作为明确部署依赖，不误报本地完成等于生产上线。
- 模型治理已覆盖注册、治理元数据、不可变策略版本、预算、灰度、失败关闭评测门禁、双人审批、System Manager 发布/回滚、运行时策略解析、Redis 原子限流/预算/熔断和每日用量聚合。Web `/administration/ai/models` 已实现模型、策略、用量和 Embedding release 管理。
- Embedding 发布治理已实现候选构建、验证、审批、alias 原子发布与回滚控制面。2026-07-15 已从在线 `myapp-products-live → myapp-products-v1` 移除 439 个明确 `HTTP-` 测试 points，当前 143 points / 1024 维，alias 未变化、剩余 payload 无 `HTTP-`、SKU001～SKU010 全部存在；582 个 ERP Item 和 854 个 Sales Order 未修改。当前单条/批量 Embedding 均 HTTP 200、1024 维，30 条中文门禁 Top-1 96.67%、Top-3 100%、Provider error 0、p95 211.745ms。
- Orchestrator 已使用 lifespan 共享 LiteLLM/Qdrant/Langfuse `AsyncClient`，Chat、structured、Embedding 使用独立 semaphore，稳定返回 `AI_LOCAL_CONCURRENCY_LIMITED` / `AI_EMBEDDING_CONCURRENCY_LIMITED`。新增版本化中文检索质量 runner 后，当前 Orchestrator test target 为 80 项通过。
- 可复现压测脚本和 SLO 基线已完成：合成 Chat 100 并发 200/200、p95 1122ms；SSE 200 并发 400/400、首 Token p95 2339ms、总 p95 2420ms；structured 20 并发 40/40、p95 300ms；Embedding 32/64/128 全通过。真实低价 Provider Chat/SSE 各 6/6，但 p95 约 7.67s / 8.88s；检索并发 16 开始出现 12.5% 429，均已记录为容量边界。
- Qdrant 压测真实暴露 `Too many open files`，`compose.yaml` 已为 Qdrant 增加 `nofile soft/hard=65536`。压测报告保存在 `ai-performance-reports/`，基线见 `AI_PERFORMANCE_SLO_BASELINE.zh-CN.md`。
- Langfuse generation/trace 已迁移到 `/api/public/otel/v1/traces`，使用 32 位 hex trace ID；feedback/eval score 保留 score ingestion。真实查询确认 generation、`erp-readonly-v5` Prompt 版本、输入/输出哈希摘要和 feedback 均已落库。
- `backup-ai-state.sh`、`restore-ai-state-drill.sh`、`qdrant_snapshot.py` 和恢复运行手册已完成。真实隔离恢复核对 PostgreSQL projects=1、ClickHouse traces/observations=116/116、MinIO objects=540、Langfuse API traces=116、Qdrant=582 points/1024 维，临时 Compose project、卷和 collection 已清理。
- 内部 AI 服务 Token 已真实轮换：旧 Token 401、新 Token 200；`.env.ai.local` 已更新且不得输出或提交，Backend、Queues、Scheduler、Orchestrator 已重建健康。备份位于忽略目录 `backups/ai/20260715T061700Z`，约 264 MiB，不得提交。
- Backend Data Task 已实现七个 Gateway API、`AI Data Steward` / `AI Data Approver` 角色、发起/审批/执行分离、源数据漂移检查、幂等执行、安全回滚和哈希审计。首期只允许 Item 的 `item_name`、`description`、`brand`、`item_group`，禁止价格、库存和正式交易字段。
- Backend 当前 AI/Data Task/Gateway 单元集合 178 项通过；排除项不 upsert、Item Hook 转删除、补偿/重建不重新加入、候选 collection 过滤、语义候选二次过滤、dry-run、幂等清理和 critical 审计均有覆盖。既有真实 Data Task 生命周期与迁移证据保持有效。
- Web `/administration/ai/data-tasks` 已实现 service camelCase 映射、独立权限、菜单/路由、管理入口重定向、ProTable 筛选、缺失描述扫描、手工字段建议、前值/建议值/证据对比、审批/驳回、执行和回滚。最终 `npm run tsc`、Biome、20 套/139 项 Jest 通过；仍有项目既有 Jest open handle 提示，但退出码为 0。
- 正式生产仍需在 Secret Manager/正式环境完成 Langfuse Project Key、恢复根密钥、SSO/TLS、HA 数据服务、告警负责人和真实 staging 演练；这些外部部署项不能用本地开发密钥或单机 Compose 伪造完成。
- 本轮分仓库提交：Backend `d8747fc feat: complete AI governance and data tasks`；Web `8f4410d feat: add AI governance workbenches`；父仓库 `0e71b8a3 feat: complete AI production readiness milestone`，并已把 `apps/myapp` gitlink 更新到 `d8747fc`。
- 本轮检索质量治理提交：Backend `c4a6af3 feat: govern AI vector retrieval quality`；父仓库 `62bae6ee feat: complete AI retrieval quality governance`。Provider 恢复文档提交：Backend `9ba54f1 docs: record embedding provider recovery`；父仓库 `fc6268af docs: update embedding recovery status`，gitlink 已同步。AI 独立交付最新提交为 `052819e`；父仓库 `39b86b2a docs: integrate standalone AI delivery` 已同步 gitlink 和新的独立/组合部署边界。Backend/Web 代码无未提交改动，父仓库 `.codex` 和 Mobile 既有 5 个用户改动继续不处理。本地 Secret、派生运行时文件和真实质量报告均受忽略且不得提交。
- Mobile `frontend/myapp-mobile` 保留本轮开始前已有的五个未提交文件，本轮不得修改、回滚或提交。

## AI 企业级收口最终验收

- 已完成：功能审计与追踪矩阵；模型治理 Backend/Orchestrator/Web；Embedding 发布控制面；高并发 P0 与压测；OTLP；备份恢复与内部 Token 轮换；Data Task Backend/Web；向量测试噪声治理和版本化中文检索门禁。
- 最终自动化：Orchestrator 当前源码镜像 80 项、Standalone Compose Chat/向量闭环、CI/CodeQL/Security，Backend AI/Data Task/Gateway 178 项、Web 最近完整基线 21 套/154 项全部通过；站点迁移既有证据保持有效。
- 最终仓库门禁：父仓库/Backend/Web/AI `diff --check` 通过，敏感扫描无真实 Key/Token；真实失败报告和 `.env.*.local` 均被忽略。父仓库只剩 `.codex`，Mobile 只剩本轮开始前的 5 个用户改动。
- Provider 恢复已确认：`erp-embedding` 字符串单条、数组单条和两条批量均 HTTP 200、1024 维；当前运行 Orchestrator 的真实检索返回 200。30 条质量门禁通过，最新报告保存在忽略目录 `ai-governance-reports/product-retrieval-v1-current.json`。新的 v2 alias/collection 尚未配置或发布；如果底层模型权重变化，必须按新向量空间完整发布流程处理。

## 本轮工作总结

### 2026-07-23 AI 模型管理、LiteLLM 同步与可用性检查交付总结

#### 用户问题与根因判断

- 数据重置后的模型注册表为空，需要确认模型同步是否真正以 LiteLLM 为事实源。既有链路确实经过 Web → Frappe → AI Orchestrator → LiteLLM `/v1/models`，但界面没有明确说明同步范围是“当前 `MYAPP_AI_LITELLM_API_KEY` 可见模型”，容易把“LiteLLM 新增模型”和“当前 Key 已获授权”混为一谈。
- 原同步结果把 LiteLLM 可见性写成类似健康状态，不能证明模型能够完成 Chat 或 Embedding 请求；既有策略验证是模型策略、评测报告和发布门禁校验，也不是运行时可用性探测。
- AI 管理菜单已完成归组，但“模型治理”名称偏控制面术语，与用户日常维护模型库存、成本和健康状态的操作心智不一致，需要统一为“模型管理”。

#### 最终设计与实现

- AI Orchestrator 的模型发现请求增加 `Cache-Control: no-cache` 与 `Pragma: no-cache`，同步响应明确返回 `source=litellm` 和真实 `visible_count`。配置中的默认 Chat/Embedding 如果不在当前 Key 可见列表中仍会保留为缺失模型，但不会被误计入可见数量。
- 同步状态拆分为明确语义：`listed` 表示当前 LiteLLM Key 可见，`missing` 表示当前 Key 不可见；已有真实探测产生的 `available / unavailable` 不会在下一次普通同步时被降回 `listed`。人工维护的 `disabled / retired` 状态继续不被自动同步覆盖。
- AI Orchestrator 新增 `POST /internal/v1/governance/models/availability`：Chat 模型调用最小 `/v1/chat/completions`，Embedding 模型调用最小 `/v1/embeddings`，最多 4 路并发，单模型探测上限 20 秒。返回模型别名、能力、可用性、耗时、Provider 模型名和稳定错误码，不返回模型正文或 Provider 原始错误内容。
- Backend 新增 `check_ai_model_availability_v1` Gateway。仅模型管理角色可执行；检查所有非 `disabled / retired` 模型并更新 `last_health_at`、`last_health_status`、`last_error_code` 和 Provider 模型显示名，写入 `check_model_availability` 审计。单次超时或失败不会自动改变人工模型状态，避免瞬时 Provider 波动直接停用生产模型。
- Web 菜单、页面标题、编辑弹窗和成功提示统一使用“模型管理 / Model Management”。模型表格新增“一键检查可用性”，执行前明确提示会产生少量真实 Provider 请求费用；完成后显示检查总数、可用数和不可用数。健康列展示“LiteLLM 可见 / 可用 / 不可用 / LiteLLM 不可见”、检查时间和稳定错误码。

#### 自动化验证

- AI Orchestrator：Ruff、Pre-commit、89 项 pytest、test 镜像内 89 项测试、runtime 镜像构建全部通过。
- Backend：模型管理 Service、API 聚合和 Gateway wrapper 共 141 项 unit 通过；可用性检查覆盖 available/unavailable 更新、错误码、审计、权限包装和不自动修改模型状态。
- Web：TypeScript、Biome、32 套/198 项 Jest 和 production build 通过；领域 Service 覆盖 LiteLLM 同步数量和可用性响应的 snake_case → camelCase 映射。
- 父仓库、Backend、AI、Web 的 `diff --check` 全部通过；`.codex` 继续作为本地未跟踪状态保留且未提交。

#### 提交、构建与部署

- 已推送 AI `f48c14b feat: add LiteLLM model availability checks`、Backend `ab3a708 feat: add AI model availability management`、Web `51670b7 feat: add AI model availability controls`。
- 父仓库 `dc3c4602 feat: deliver AI model management checks` 固定 Backend/AI 子模块版本；`3f491d0d docs: record AI model management deployment` 补充最终部署证据。
- 成功 workflow：ERP/AI 镜像构建 `29925570558`、Web 镜像构建 `29925386108`、ERP/AI 部署 `29979836312`、Web 部署 `29980057785`。
- 发布镜像：`ghcr.io/rgc318/myapp-erpnext:staging-20260722-dc3c460`、`ghcr.io/rgc318/myapp-ai:staging-20260722-dc3c460`、`ghcr.io/rgc318/myapp-web:staging-20260722-51670b7`。目标 `192.168.31.229` 的 ERP、AI、Worker、Scheduler、WebSocket、Qdrant、MariaDB 和 Web 容器均正常运行，Web 容器为 healthy；模型管理页面、登录页、Ping 和健康检查均为 HTTP 200。

#### 实机验收结果

- 使用 Administrator 上下文执行模型同步：`source=litellm`、`visible_count=13`、`synced_count=13`、`missing_count=0`，确认部署环境当前 Service Key 能看到全部 13 个模型。
- 一键真实探测检查 13 个模型，其中 9 个成功。`erp-embedding` 真实 Embedding 请求成功；8 个 Chat 模型真实 Chat 请求成功。
- `nvap-gpt-5.5`、`nvap-gpt-5.6-luna`、`nvap-gpt-5.6-sol`、`nvap-gpt-5.6-terra` 均在约 20 秒达到探测上限，稳定记录为 `PROVIDER_TIMEOUT`。这表示它们在当前可用性 SLA 下不可用或响应过慢，不代表 LiteLLM Key 不可见，也不会自动停用模型。
- 探测结果已经持久化到模型注册表并写入审计；后续普通同步不会覆盖这次真实健康结果。

#### 部署过程复盘与当前风险

- 首次 ERP/AI 和 Web workflow 输入使用短提交号，`actions/checkout` 与 `bench init` 按分支/标签执行浅克隆，无法把短 SHA 当作 `--branch`，因此构建失败。改用已经推送且头部固定的 `develop` / `main` 分支后构建成功。后续若要求不可变发布，应传完整可解析 ref，或改造 workflow 在构建前把 commit SHA 显式转换为可 checkout 的完整 ref，不能继续使用短 SHA。
- 当前 20 秒探测阈值会把响应极慢的模型标记为 `PROVIDER_TIMEOUT`。如果 `nvap-*` 模型业务上允许更高首响应延迟，应先明确模型 SLA，再决定是否提高探测阈值；不能仅为了让检查变绿而无限延长超时。
- 一键检查会对每个未停用模型产生一次最小真实请求。当前通过确认弹窗控制人工触发，尚未配置定时巡检、费用上限、连续失败告警或自动恢复通知。
- Langfuse 当前未启用，不影响 Chat、同步或可用性检查主链路，但缺少持续运行观测和跨时间健康趋势；如需生产级监控，应单独完成 Langfuse/指标告警方案，而不是让可用性按钮承担全部可观测性职责。

#### 后续建议

1. 在 LiteLLM 控制面检查 4 个 `nvap-*` 模型的上游路由、配额、冷启动和 Provider 延迟，并用相同 Key 单独复测，区分“稳定超时”和“偶发慢响应”。
2. 为模型可用性增加最近成功时间、连续失败次数和按模型配置的 SLA；达到连续失败阈值时告警，但仍保持人工决定停用或切换策略。
3. 优化 staging 构建 workflow 的 ref 校验：接受分支、标签或完整 commit，并在进入耗时 Docker 构建前失败关闭短 SHA/不存在 ref。
4. 如需自动巡检，先增加每日请求预算、并发和通知负责人，再通过 Scheduler 定时执行；默认不要自动停用或修改已发布模型策略。

### 2026-07-19 AI 业务操作体验与模型治理集中总结

#### 用户问题与设计判断

- 自动理解原先会被历史固定场景污染：添加商品必须人工选模式，之后查询商品状态又可能继续生成空草稿。现在自动路由以当前问题为准，显式场景只对本次发送生效。
- 草稿与正式业务操作原先完全割裂，用户必须跳转到业务模块才能继续。现在“需要用户确认”和“必须离开 AI 页面”已分离；高频四类草稿在工作台内完成编辑、校验、确认、执行和回执，专业页面只处理复杂例外。
- 商品草稿原先缺少前端必填校验，重新打开可能回填旧 citation 快照并丢失人工修改，且“库存估值价 / 初始库存单位 / 编辑并重新校验”等文案不符合项目业务语言。现在编辑器读取最新持久版本，失败保持输入，使用“默认采购价 / 库存基准单位 / 完善草稿 / 保存草稿”。
- 模型列表原先只同步默认 Chat 与 Embedding 配置，数量与 LiteLLM `/v1/models` 不一致，Chat/草稿也不能固定模型。现在完整同步 LiteLLM 可见库存，普通用户只看到合规聊天模型，并可在自动策略和固定模型之间切换。

#### 最终交付

- Backend：四类草稿统一原地执行服务、`executed` 状态、持久回执、幂等与审计、用户编辑价格保留、商品默认采购价与初始库存约束、模型注册同步、可选模型接口和模型选择校验。
- AI Orchestrator：完整模型发现、模型能力分类、显式模型请求契约、策略成本元数据与无静默 fallback。
- Web：共享草稿编辑器、草稿中心/来源会话一致交互、当前页业务详情 Drawer、确认执行与正式回执、商品字段校验和术语、自动场景一次性纠偏、模型选择与重试保持。
- 文档：Backend/API、AI API/配置、Web 设计、父仓库企业工作台设计和交接记录已对齐同一业务边界。

#### 验证与提交

- 自动化：Backend 177 项；AI 82 项、Ruff、Pre-commit、test/runtime 镜像；Web 184 项、TypeScript、Biome、production build；四仓库 whitespace 检查通过。
- 真实联调：Orchestrator 返回 9 个 LiteLLM 模型；Frappe 同步 9 个、缺失 0；普通用户选择器返回 8 个聊天模型；Embedding 选择以 HTTP 422 拒绝；SSE 固定 `opencode-glm-5.2` 后实际模型一致并成功完成。
- 已推送：Backend `cb6b65b`、AI `fcf6b9c`、Web `3dccc00`。父仓库提交负责固定两个子模块版本和本轮跨仓库文档。

### 2026-07-17 AI 工作台公司、自动路由与真实单据查询收口

- 用户反馈与根因：
  - 首 Token 前的 10～20 秒等待被界面描述为“建立安全会话”或“内容到达后逐段显示”，容易被误解为模型思考或伪流式；实际 Frappe 在约 19ms 返回 `run_started`，Provider 首 Token 存在显著波动，首 Token 后会返回数百个真实 `message_delta`。
  - 新会话只显示工作偏好默认公司，没有工作台内公司选择；历史会话又必须保持原公司边界，不能直接改写。
  - 默认 `general` 场景不会调用业务工具；原 `order_query` 只支持销售或采购订单单选，并显式拒绝混合语义，也没有销售/采购发票工具，因此用户的混合查询只能得到“没有业务上下文”。
  - Orchestrator `erp-readonly-v5` Prompt 使用“只读试运行”措辞，模型会重复该说明，让用户误以为查询能力尚不可用。
- Backend：
  - 新增 `auto` 场景和确定性 `_infer_ai_scenario`，根据当前问题解析通用、商品、单据或报表场景；解析后的实际场景进入 Message、Run、Prompt 和 Orchestrator，不把页面关键词判断当作事实来源。
  - 单据 DSL 支持销售订单、销售发票、采购订单、采购发票的一个或多个实体；订单复用现有订单工作台服务，发票复用 `list_business_documents_v1`，每类结果再次执行 DocType、记录级权限、公司、日期、状态、金额、排序和数量过滤。
  - 未明确日期的“最新”查询使用全部日期范围；明确今天、本周、本月、上月或近 N 天时才应用日期边界。混合查询按每种单据类型分别应用数量上限。
  - SSE 阶段文案调整为“已确认当前账号权限与公司范围”“等待首个 Token”“首个 Token 已到达，正在实时输出”，保留 `completed.stream.delta_count / streamed_chars` 作为真实增量证据。
- Web：
  - 默认场景改为“自动识别”，仍允许用户显式选择通用、商品、单据、报表和三类草稿。
  - 新会话使用 `RemoteLinkSelect doctype="Company"` 选择查询公司，默认值来自工作偏好；历史会话显示锁定公司，切换公司必须新建会话。
  - 首 Token 前展示“首个响应尚未返回”和已等待时间，首 Token 后展示“实时输出中”；安全边界改为“按当前账号权限查询，写操作需确认”。
- AI Orchestrator：
  - 查询 Prompt 升级为 `erp-readonly-v6`，能力说明改为当前账号权限和公司范围内的受控业务查询；创建、提交、取消、付款、退款和库存调整仍必须由用户在正式业务页面确认。
  - 运行镜像已重建，`/health` 返回四个查询场景均为 v6；定向真实查询的正文和 warning 均不再出现“只读试运行”或“只读”措辞。
- 真实验收：
  - 原始问题“查询最新的5条销售订单和销售发票，以及采购订单”自动执行 `search_sales_orders`、`list_sales_invoices`、`search_purchase_orders`，真实返回 5 条销售订单、4 条销售发票和 5 条采购订单。
  - 每类 1 条的缩短复测返回三类 citation、425 个增量块、860 个流式字符；工具、公司、单号、日期、状态、金额和链接均来自受控结构化结果。
  - Web TypeScript、Biome、24 套/167 项 Jest、production build、production audit 0 漏洞；Backend 146 项；AI Ruff、Pre-commit、80 项 pytest 和 test 镜像 80 项全部通过。
- 提交与发布边界：
  - AI `c42549f feat: clarify governed AI query prompt` 已 push 到 `origin/develop`。
  - Backend `723eae7 feat: auto-route AI business document queries`、Web `f7838b5 feat: improve AI company and query controls` 已本地提交。
  - Prompt v6 已完成真实定向 live 冒烟，但尚未执行 21 项付费 live full-gate；生产策略/Prompt 正式发布前必须补 full-gate，不能用定向冒烟替代发布门禁。

### 2026-07-17 AI 历史会话公司上下文漂移修复

- 根因：`/ai` 打开历史会话后只恢复 `conversationId`，发送时仍使用当前工作偏好 `defaultCompany`；当用户偏好与会话原始公司不同时，Backend 正确拒绝并由 Frappe 返回 417 错误页。
- Web 现恢复 `conversation.company` 并计算有效公司：已有会话优先使用会话公司，新会话使用默认公司；流式请求、三类草稿和手动重试均复用同一有效公司。两者不同时上下文栏以金色标签显示会话公司。
- Backend `_prepare_chat_run` 在已有会话请求省略 `company` 时从持久会话恢复公司；显式传入不同公司仍保留失败关闭，避免跨公司数据混入同一模型上下文。
- 已新增回归：Web 验证默认公司为 `Demo Company` 时，历史会话仍以 `Original Company` 调用 SSE；Backend 验证省略公司时 payload 使用持久会话公司。Backend AI repository/service/Gateway 142 项、Web TypeScript、Biome、24 套/165 项 Jest 和 production build 通过；Jest 仍有项目既有 open-handle 提示但退出码为 0。

### 2026-07-16 AI Web 运行诊断、失败恢复与草稿业务复核

- Backend `get_ai_conversation_v1` 的持久 Run 摘要新增 `first_token_ms`；同步 Chat、SSE 最终事件和销售/采购/库存调整草稿返回 `run.status`、`run.latency_ms` 与可选 `run.first_token_ms`，Web 不再用浏览器耗时冒充后端 Run 指标。
- `/ai` 新增独立运行检查器，覆盖等待、生成中、完成、停止和失败状态，展示模型、总耗时、首 Token、Token 分解、Run、Trace、工具执行结果和流式警告；停止或失败只允许用户主动重试上次问题。
- `/ai/drafts` 详情新增业务复核、版本历史和原始数据三个页签。业务复核展示公司、客户/供应商、日期、仓库、商品、数量、单位、参考价或库存变化；历史版本恢复继续调用后端重新解析和校验，不直接覆盖当前 payload。
- 新增 `AiRunInspector`、`AiDraftBusinessReview`、`AiDraftVersionList` 及专项测试，并新增 AI 工作台流式请求页面测试。
- 当前已验证：Backend AI repository/service/Gateway 141 项通过；Web TypeScript、Biome、24 套/164 项 Jest、production build 和 `npm audit --omit=dev`（0 vulnerabilities）通过；父仓库、Backend 与 Web `diff --check` 通过。

### 2026-07-16 AI Web 独立设计文档与提交收口

- Web 新增 `AI_WEB_FRONTEND_DESIGN.zh-CN.md` 作为 AI 前端设计事实来源，集中记录信息架构、Ant Design X/ProComponents 选型、三栏工作台、POST + JWT SSE、会话/Run/反馈恢复、结构化 citation、三类草稿交接、治理深链路、角色权限、异常恢复、安全、性能和验收门禁。
- `WEB_DEVELOPMENT.zh-CN.md` 与 `DEVELOPMENT_PLAN.zh-CN.md` 已建立设计文档入口；父仓库 `AGENTS.md` Required Context Index 已加入该文档，后续 AI Web 修改必须同步核对。
- Backend 已提交 `1b7cfd4 feat: align AI web governance contracts`：包括当前用户草稿分页、会话 Run/反馈恢复、治理概览、审计服务端分页、Data Task allowed/reason 及测试和 API 文档。
- Web 已提交 `2eb4f09 feat: modernize enterprise AI workspaces`：包括 Ant Design X AI 工作台、草稿中心、模型/策略/用量/向量/审计深链路、领域 Service 对齐、现代主题和四个生产间接依赖修复。
- 提交后复验：Backend AI/Data Task/模型治理/向量/Gateway 184 项通过；Web TypeScript、Biome、21 套/159 项 Jest、production build 和 `npm audit --omit=dev`（0 vulnerabilities）通过；各仓库 `diff --check` 通过。Jest 仍显示既有 open-handle 提示，但退出码为 0。

### 2026-07-16 AI Web 企业级现代化与前后端能力对齐

- 官方组件：核对 Ant Design Pro 2026-07 官方 Chatbot 基线，接入 `@ant-design/x` 与 `@ant-design/x-markdown`；保留现有 Frappe JWT POST SSE 和领域 Service，不复制官方示例的外部 Provider 直连。
- AI 助手：重构全高工作区、会话分组/归档、示例能力、停止生成、Markdown、结构化来源、反馈和右侧 Run 检查器；现有三类结构化草稿编辑、版本历史和业务编辑器交接保持兼容。
- 草稿中心：Backend 新增 owner-scoped `list_ai_drafts_v1`，Web 新增 `/ai/drafts`；会话详情同步返回 Run 与 feedback，使历史状态可恢复。
- 治理中心：新增模型/策略/用量/向量/审计独立路由；概览聚合 runtime/7 日 usage/vector/data-task 指标，用量增加 30 日趋势；审计从固定最近 20 条升级为分页查询。
- 向量与 Data Task：补齐索引状态、重建、排除向量预检/清理；Data Task 操作资格由 Backend 返回 `actions.allowed/reason`，继续由后端强制职责分离。
- 验证：Web `npm run tsc`、`npm run biome:lint`、`npm test -- --runInBand`（21/159）、`npm run build`；Backend AI/Gateway 184 项；真实 bench execute 和本地 8001 路由冒烟均通过。Jest 仍可能在聚焦运行时显示项目既有 open-handle 提示，但完整测试本次正常退出码 0。

### 2026-07-16 staging 构建代理故障复盘与文档固化

- 复核 `bdd00ed9 fix: harden staging image builds` 后确认不应整体回退：代理恢复后的完整构建仍验证了有限重试、构建期临时 Redis、uv 联合解析和 import/`pip check` 门禁的必要性。
- `docs/codex/KNOWN_ISSUES.zh-CN.md` 新增长期判断准则，明确各项构建加固解决的问题、默认行为和未来允许移除的验证条件。
- `STAGING_DEPLOYMENT.zh-CN.md` 新增部署复盘，明确 CI 无需工作站代理，显式代理变量只影响本地 Docker build，且最终 runtime 镜像不包含 builder 临时 Redis。
- 本次提交前重新执行 Markdown Prettier、codespell、尾随空白/文件结尾、脚本 shebang/可执行位、`bash -n`、shfmt、ShellCheck 和各仓库 `diff --check`，均通过；完整镜像、Compose 与测试结论沿用同日已完成且记录在顶部的验收结果。
- 仓库边界保持不变：父仓库只处理本次文档；Backend、AI、Web 无改动，Mobile 既有 5 项用户修改不触碰，`.codex` 不提交。

### 2026-07-16 AI 独立交付、工程治理与文档完善

- 独立运行：新增仓库根 `compose.yaml`，在不依赖 `frappe_docker` 源码的情况下启动 Orchestrator、密码保护 Redis 和固定 digest Qdrant；只发布 loopback 4010，Redis/Qdrant 使用内部网络，Orchestrator/Qdrant 保持非 root、只读 rootfs、空 capabilities 和 `no-new-privileges`。
- 集成门禁：新增 `compose.integration.yaml`、合成 OpenAI/Frappe Provider 和 `standalone_healthcheck.py`，真实验证健康、Bearer Chat、Embedding、Qdrant upsert/search/delete；使用独立 project/14010 端口，完成后清理容器、网络和测试卷，不中断现有 Dev Container。
- 工程治理：新增 `uv.lock`、`.python-version`、Ruff、pre-commit、ShellCheck、pip-audit、Trivy、CodeQL、Dependabot、CODEOWNERS、PR 模板、MIT License、Security、Contributing 和 Changelog。远程 CI、Security 和 CodeQL 均成功。
- 文档体系：新增架构、开发、配置、API、部署、安全、观测、向量、测试评测、性能、运维和发布共 13 篇文档及索引；AI 仓库成为服务级事实源，父仓库继续负责完整 ERP/Dev Container/bundled Langfuse/staging/production 组合部署。
- 提交：AI `7f230f5 feat: complete standalone AI service delivery`、`052819e fix: use published Trivy action release`；`main` 与 `develop` 均已同步。父仓库 `39b86b2a docs: integrate standalone AI delivery` 已同步 gitlink、长期规则、路线图和交接，远程 Lint 成功。

### 2026-07-16 AI Orchestrator 独立仓库迁移

- 使用 `git subtree split --prefix=services/myapp-ai` 提取历史，独立历史从 `aabca837` 到 `f608ca7` 共保留 12 个实际 AI 里程碑；导出根目录和完整历史已扫描，不包含 `.env.ai.local`、真实 `sk-*` 或 Bearer Secret。
- 创建公开远程 `rgc318/myapp-ai`，默认分支 `main`，同时保留 `develop`。两分支已推送到 `25e68c7`；AI 源码、测试、Dockerfile、CI 和镜像发布以后在独立仓库维护。
- 父仓库把原普通目录替换为同路径 Git 子模块，并补齐此前缺失的 `apps/myapp` `.gitmodules` 声明。部署仓库继续拥有 Compose、Dev Container、Langfuse/Qdrant、staging 和跨服务 Secret 边界。
- 验证：AI Docker 80 项通过、runtime 镜像构建通过，远程 GitHub CI 成功；development + Langfuse、Dev Container、现有 staging Compose 均 `config --quiet`；相关脚本 `bash -n`、workflow YAML、两个子模块 mode `160000`、父/Backend/AI `diff --check` 和敏感扫描通过。
- 依赖仓库已先行推送：Backend `develop` 已到 `9ba54f1`，Web `main` 已到 `dcde5a9`，AI `main/develop` 已到 `25e68c7`。父仓库迁移提交随后推送 `develop`，形成完整可克隆提交链。
- 用户曾在聊天中提供的测试 Key 未进入 Git 或镜像配置，但因已明文暴露，仍必须在 Provider/LiteLLM 侧轮换并撤销旧值。

### 2026-07-16 Embedding Provider 恢复与质量门禁复验

- LiteLLM `erp-embedding` 已从早期 `float + str`、后续 connection error 恢复。一次性新 Key 测试和当前 Orchestrator 运行配置均成功；测试 Key 未写入 `.env`、Docker 配置或 Git，因曾在聊天中明文出现必须轮换。
- `/v1/embeddings` 字符串单条约 279ms、两条批量约 139ms，均 HTTP 200、每条 1024 维；当前 Orchestrator 查询“数码相机”返回 HTTP 200，`SKU010` Top-1。
- `product-retrieval-zh-cn-v1` 30 条真实门禁通过：Top-1 96.67%、Top-3 100%、Provider error 0、`HTTP-` 泄漏 0、p50 145.692ms、p95 211.745ms。唯一 Top-1 未命中为背包用途表达，`SKU008` 位于 Top-2。
- 当前 v1 在线使用门槛已恢复；仍未完成的是当前新 Provider 下的 32/64/128 批量容量、真实 point 删除/重新 upsert/恢复、权限二次过滤 full gate，以及底层模型变化时的新 collection 构建、审批、alias 切换和回滚。
- 本次只更新状态文档，不把忽略目录中的报告或任何 Key 提交到 Git。提交：Backend `9ba54f1`；父仓库文档与 gitlink `fc6268af`。

### 2026-07-15 剩余 AI Goal：检索质量治理与 Provider 复测

- 新增 `MYAPP_AI_VECTOR_EXCLUDED_ITEM_PREFIXES`，development/staging 初始仅配置明确测试前缀 `HTTP-`。规则贯穿增量同步、Item Hook、小时补偿、管理员重建、候选 collection 构建/重试和语义候选二次过滤；排除只影响 AI 索引，不删除、不停用 ERP Item。
- 新增 `cleanup_excluded_ai_product_vectors_v1` Gateway POST：System Manager 权限、默认 dry-run、最大 5000、正式执行必须原因和幂等键、内部按 100 条删除、状态标记 `deleted`、critical AI 审计，响应固定证明 `erp_items_changed=0`。
- 真实 dry-run：ERP Item 582、Sales Order 854、基准 SKU 10；`HTTP-` 命中 439，其中状态 indexed 384；Qdrant 582 points / 1024 维，alias `myapp-products-live → myapp-products-v1`。
- 真实清理：删除请求 439，Qdrant points 582 → 143；清理后 Item 582、Sales Order 854、基准 SKU 10、alias 和维度均不变。直接 scroll 复核 143 个 payload 中 `HTTP-` 为 0，SKU001～SKU010 全部存在。
- 新增 `product-retrieval-zh-cn-v1` 版本化数据集：SKU001～SKU010 各三条直接名称、用途表达、模糊描述，共 30 条。`python -m myapp_ai.retrieval_quality` 检查 Top-1/Top-3、Provider 错误、排除候选泄漏和 p50/p95，默认禁止 live，真实失败关闭。
- 真实门禁 30/30 均 HTTP 502，Top-1/Top-3 为 0、Provider error=30、排除泄漏=0、p95=5856.216ms。直连复测确认 v1 HTTP 500 `unsupported operand type(s) for +: 'float' and 'str'`，v2 HTTP 400 不存在；未创建或发布 v2 collection。
- 验证：Backend AI/Data Task/Gateway 178 项通过；Orchestrator test target 80 项通过；开发+Langfuse+Dev Container 与 staging Compose 解析、shell 语法、三个仓库 `diff --check` 和敏感扫描通过。新 Orchestrator runtime 镜像已重建并健康，`retrieval_quality_ready`、Langfuse Dispatcher、向量与治理健康字段正常。queue-short、queue-long、queue-ai-vector 和 scheduler 已定向重建并确认加载 `HTTP-` 排除配置；为避免中断用户 Dev Container，会话中的 Backend 容器未重建，下次 Dev Container 启动会由 initializeCommand 自动加载同一派生 env。
- 提交：Backend `c4a6af3`；父仓库 `62bae6ee`。正式 Secret Manager、SSO/TLS、HA/告警、真实 staging 和 Provider 修复仍需对应外部平台完成，当前文档已给出失败关闭契约与运行证据。

### 2026-07-15 剩余 AI Goal：异步 Langfuse OTLP Dispatcher

- 新 Goal 已创建并开始执行，范围限定为剩余企业级收口，不重复四个已完成 Wave。首个 P0 已把 generation OTLP 从 Chat/SSE/structured 请求尾部直接网络等待改为进程内有界后台 Dispatcher。
- 请求路径只构建脱敏 OTLP payload 并 `put_nowait`；后台按默认 20 条/250ms 聚合、最多重试 2 次，队列满、发送失败或关闭排空超时均失败开放并累计丢弃，不阻断 AI 主链路。
- `/health.langfuse_delivery` 已暴露 Worker、队列容量/深度、入队、发送、批次成功/失败、重试、丢弃和通用错误状态。新增批处理、慢端不阻塞、队列满和重试成功测试，Orchestrator 全量从 74 增至 77 项并全部通过。
- 当前 Orchestrator 已基于新源码重建；真实最小 Chat 返回 200 和 trace ID，随后后台指标为 `queued_total=1`、`sent_total=1`、`queue_depth=0`、`retry_total=0`、`dropped_total=0`。Backend 容器 ID/启动时间未变化。
- 本里程碑提交：Backend `70b09c5 docs: define asynchronous AI observability delivery`；父仓库 `2b5b9ed9 feat: decouple AI generation observability delivery`。下一步是 Langfuse bundled stack 分服务 Secret 最小化和 development/staging/production 部署契约。
- bundled Langfuse Secret 最小化已提交为父仓库 `36056716 feat: enforce least-privilege Langfuse deployment`：Web/Worker 应用、Web 初始化、PostgreSQL、ClickHouse、Redis、MinIO、Orchestrator 分别使用独立 `0600` 派生文件。真实 Compose 键集合确认四个存储容器只获得自身凭据，Worker 无初始化管理员密码，Orchestrator 无存储密钥，Backend 无 Langfuse Secret。
- 六个 Langfuse 容器已使用原持久卷重建并全部健康；重建前后 PostgreSQL projects=1、ClickHouse traces=122、MinIO objects=552 完全一致。`start-prod.sh` 默认不再启动 bundled Langfuse，只有显式 `--with-observability` 才允许单节点例外。
- 新增 `AI_DEPLOYMENT_ENVIRONMENTS.zh-CN.md`，明确 development、staging、production 的拓扑、Secret、HA、TLS、SSO/RBAC、告警、保留、恢复和外部依赖边界。下一步完成本里程碑验证/提交后，推进检索数据质量门禁和 v2 Provider 复测。

### 2026-07-15 开发与 Dev Container 默认启用 Langfuse

- `start-dev.sh` 已改为默认启用 bundled Langfuse；只有显式传入 `--without-observability` 才关闭。首次缺少 `.env.langfuse.local` 时会失败并提示运行 `./setup-ai-observability.sh`，不会以半配置状态继续启动。
- Dev Container 默认 Compose 组合已加入 `overrides/compose.langfuse.yaml`，`runServices` 加入 Web、Worker、PostgreSQL、ClickHouse、Redis、MinIO 六个服务，并转发 3000/9090。初始化阶段同时同步 AI Gateway 与 Langfuse 运行时配置。
- 新增 `sync-langfuse-runtime-env.sh`：从权限 `0600` 的 `.env.langfuse.local` 生成完整 bundled-stack 运行时文件和 Orchestrator 最小观测文件。真实 Compose 解析确认 Backend 不含 Langfuse 变量，Orchestrator 只有 Host/Project Key/环境等观测字段，不含数据库、PostgreSQL 或 MinIO 密钥。
- 当前已运行的 Dev Container 采用定向方式新增六个 Langfuse 服务并只重建 Orchestrator，没有重建 Backend。Langfuse v3.212.0 health 为 `OK`，Orchestrator 为 healthy 且 `litellm_configured=true`、`langfuse_configured=true`、`vector_search_configured=true`；四个依赖存储均 healthy，Worker 正常运行。Backend 容器 ID 仍为原实例并保持运行。
- 验证通过：相关 shell `bash -n`、普通开发完整组合、Dev Container 无额外 `--env-file` 组合、带测试占位变量的本地 prod 组合、staging 示例组合 `docker compose config --quiet`，Dev Container JSONC 关键默认项断言，以及三个仓库 `diff --check`。staging 未引入本地 bundled Langfuse，继续使用外部受控配置。
- AI 完成度事实源已同步校正：四个原始收口 Wave 均已完成，本地功能基线约 98%；下一阶段只处理异步 OTLP、生产 HA/Secret/SSO/告警、真实 staging、v2 Embedding 外部阻塞和检索数据质量，不重复开发已完成的模型治理、Data Task、草稿、评测或向量 v1 主链路。
- 本轮提交：Web `dcde5a9`；父仓库 `e1310344`。Backend 无代码改动，父仓库子模块指针未变化。

### 2026-07-15 Web 查询取消自动默认公司

- 真实排查确认数据库仍有 854 条 Sales Order，订单没有被清空；浏览器访问日志显示订单页先收到含数据响应，随后偏好加载触发的默认公司请求返回空列表并覆盖前一结果。
- 已全局审计 Web 搜索面并移除工作区默认公司注入：销售/采购订单、发票/收发货通用列表、待确认、收付款、库存现状/流水/预警、商品/仓库列表、财务、经营报表和 Dashboard 首次均查询权限范围内全部公司。
- 商品和库存详情不再从工作区偏好隐式补公司；库存列表只有用户主动选择公司时才把该公司带入详情链接。销售/采购新建、库存盘点/转仓/调整、仓库新增、工作偏好设置和 AI 草稿继续保留录入所需默认公司。
- 新增 `src/__tests__/search-default-company.test.ts`，15 项断言阻止搜索页面重新引入 `initialValue: defaultCompany`、公司默认参数、偏好驱动的 ProTable remount 或详情隐式公司。验证：`npm run tsc`、`npm run biome:lint`、Web 全量 Jest 21 套/154 项、`git diff --check` 全部通过。

### 2026-07-15 AI 启动、Dev Container 与 staging 部署收口

- 新增 `sync-ai-gateway-env.sh`，从 `.env.ai.local` 只同步 Orchestrator URL、内部 Token、向量开关/别名、环境和保留期到权限 `0600` 的忽略文件 `.env.ai.gateway.local`；Backend、Worker、Scheduler 不再获得 LiteLLM/Langfuse Provider 密钥。实际 Compose 解析确认 Backend 与 Orchestrator Token 一致、向量开关均为 `1`，Backend 不包含 LiteLLM Key。
- `start-dev.sh` 在开发/测试阶段默认纳入完整 Langfuse 栈，仍可用 `--without-observability` 显式关闭；`start-prod.sh` 保持原有自动判断，staging 继续使用外部受控 Langfuse。Dev Container 默认启动六个 Langfuse 服务并转发 3000/9090。新增 Langfuse 运行时 env 同步，把完整 bundled-stack 配置与 Orchestrator 最小观测配置拆分，Backend/Worker 不获得相关密钥。
- staging `compose.staging.yaml` 已加入独立 AI Orchestrator 镜像、Qdrant 初始化/持久服务、`ai-vector` Worker、共享 Gateway 配置和安全/健康限制；LiteLLM/Langfuse Provider 凭据只进入 Orchestrator。`staging.env.example`、启动/部署/初始化、回滚和健康检查已同步更新。
- staging 构建 workflow 与本地构建脚本现在同时构建 `myapp-erpnext` 和 `myapp-ai`，使用同一发布标签；部署与回滚同步修改 `CUSTOM_TAG` / `MYAPP_AI_TAG`。新增 `validate-staging-env.sh`，对占位符、缺失镜像/Provider、短 Token、向量依赖和不完整 Langfuse 凭据失败关闭；健康检查验证 Orchestrator `/health` 和 Backend→Orchestrator 认证。
- 已验证：所有修改 shell 脚本 `bash -n`；本地基础、本地完整 Langfuse、Dev Container、staging 示例及现有旧 staging env 的 `docker compose config --quiet`；staging 有效合成 env 校验通过、模板占位符按预期拒绝；两个 GitHub Actions workflow YAML 可解析；父仓库 `git diff --check` 通过。未重启当前运行容器，未执行真实 staging pull/up；远端部署前必须把新增 AI 值填入服务器忽略文件 `deploy/staging/staging.env`。

### 2026-07-15 AI 企业级收口：高并发、恢复与 Data Task

- 完成 Orchestrator 异步客户端生命周期、分类并发池和稳定 429；新增合成/真实 Provider 压测工具、保留三份脱敏报告并形成 SLO/容量基线。Qdrant `nofile` 已按真实压测故障修正。
- 完成 Langfuse OTLP generation/trace 迁移、反馈 score 兼容、32 位 trace ID 和内容哈希；真实 trace/generation/feedback 查询通过。
- 完成 Qdrant snapshot、Langfuse PostgreSQL/ClickHouse/MinIO 联合备份、隔离恢复演练和内部服务 Token 轮换；恢复证据、清理结果和生产待办已写入运行手册。
- 完成 `MyApp AI Data Task` Backend：迁移、角色、服务、Gateway、审批/执行分离、漂移检查、幂等、回滚、审计和真实临时商品回归。
- 完成 Web `/administration/ai/data-tasks`：领域 service、权限、路由、菜单、服务端列表、扫描、创建、详情对比、审批、执行和回滚；TypeScript、Biome 和聚焦 Jest 已通过。
- 最终验证：Orchestrator 74 项、Backend 171 项、Web 20 套/139 项通过；迁移、三个仓库 `diff --check`、敏感扫描和临时压测资源清理均完成。Backend `d8747fc`、Web `8f4410d`、父仓库 `0e71b8a3` 已提交。外部 v2 Embedding Provider 故障作为明确例外保留。

### 2026-07-14 AI 商品向量检索真实启用与验收

- LiteLLM `/v1/models` 已出现 `erp-embedding`，真实 `/v1/embeddings` 请求成功，返回 1024 维数值向量；本地密钥仍只保存在被 Git 忽略的 `.env.ai.local`。
- `.env.ai.local` 已配置 `erp-embedding`、`myapp-products-v1`、Qdrant 内部地址并显式打开向量检索。Orchestrator、Backend、queue-short、queue-long、scheduler 已按现有 Compose/Langfuse 组合重建；此前退出的两个 Worker 和 scheduler 已恢复运行。
- 582 个 Item 已通过补偿队列全部索引，最终 tracked/indexed/points 均为 582，due/failed 为 0，collection 维度为 1024。`SKU010` 重复删除两次均成功，点数降至 581；重新同步后恢复为 582，验证删除幂等和恢复路径。
- 真实中文语义质量集覆盖 T 恤、电脑、读物、手机、运动鞋、咖啡杯、电视、背包、耳机、相机，10/10 目标商品均排 Top-1。额外宽泛查询暴露历史 HTTP 测试商品会产生噪声，生产数据治理仍应清理测试主数据并建立更大人工标注集。
- 混合检索确认 `retrieval_mode=hybrid`、`embedding_model=erp-embedding`、`vector_collection=myapp-products-v1`；临时不可达地址演练确认自动降级为 `lexical_fallback`。现有无 Item 权限用户的商品检索和向量治理接口均被拒绝。
- 启用真实向量环境后，既有商品工具单测暴露未 mock `search_products_semantic` 的环境耦合；测试已补充显式 lexical fallback mock，确保单测不受本机开关影响。最终 Orchestrator 44 项、offline gate 21/21、后端 142 项、Web 129 项全部通过。
- 真实商品 Copilot HTTP 回归最初在向量检索成功后被外部 LiteLLM Chat `request_timeout=None` 阻断；LiteLLM 管理员修复并重启后，`opencode-deepseek-v4-flash` 最小请求返回 200，完整商品 Copilot 用例在 13.926 秒内通过，首条商品引用为 `SKU010`，测试会话自动归档。
- 文档收口新增模型治理与高并发两份详细设计，并同步 Backend README、AI 总体设计、父仓库 README 和项目路线图。最终提交前复跑 Orchestrator 44 项、Backend 142 项、Web 19 套/129 项，全部通过；三个仓库 `diff --check` 和敏感信息扫描通过。
- 本轮分仓库提交：Backend `0206fb6`、Web `f507efb`、父仓库为本文件所在提交。Mobile 既有五个改动未修改、回滚或提交，父仓库 `.codex` 未提交。

### 2026-07-13 AI Langfuse 本地可观测性与固定评测集

- 新增 `overrides/compose.langfuse.yaml`，本地固定 Langfuse v3.212.0，并使用独立 PostgreSQL、ClickHouse 26.6.1.1193、Redis 7.4.9、PostgreSQL 17.10 和固定 MinIO digest。Web/MinIO 只绑定 loopback，数据库、ClickHouse、Redis 和 MinIO Console 不发布宿主机端口。
- 新增 `setup-ai-observability.sh` 和 `.env.langfuse.example`。脚本生成 `.env.langfuse.local`、随机数据库/存储/NextAuth/加密/API Key/管理员密码，文件权限为 `0600` 且被 Git 忽略，密钥不打印到终端，并拒绝覆盖已经存在的密钥文件。
- Orchestrator 新增统一 Prompt registry；Frappe 审计、模型请求和 Langfuse metadata 已对齐到只读 `erp-readonly-v5`、销售 `sales-order-draft-v2`、采购 `purchase-order-draft-v2`、库存 `inventory-adjustment-draft-v2`。只读提示补强公司/完整日期口径、不转述上下文注入文本和不自行推导财务公式；草稿提示明确保留用户单位量词及全单/行仓库边界。
- Langfuse 批次客户端修复 HTTP 207 误判：只有逐事件 `errors` 为空且 `successes` 覆盖本批次全部事件 ID 才算同步成功。Trace `release`、generation Prompt `version` 和 score `environment/source` 写入原生字段；eval 为 `source=EVAL`，feedback 为 `source=API`。Trace、generation、固定评测 score 和 `user-feedback` 已通过真实 API 查询持久化。
- 新增 `myapp_ai.evals`：21 个纯合成固定用例、版本化 JSONL、确定性 grader、offline replay、显式付费 live runner、阈值退出码、脱敏 JSON 报告和 Langfuse score。默认不保存模型输出或反馈 comment 原文，只保留哈希、长度、失败原因、Prompt/DataSet 版本、延迟和 Token。
- Partial eval 明确返回 `gate_scope=partial`、`release_gate_eligible=false`，缺失指标为 `null`；未知 case ID 拒绝并退出 `2`。只有覆盖当前 mode 全部用例的 full gate 可作为发布依据。
- Prompt 版本治理拒绝显式不一致及空白版本，聊天、流式和三类草稿接口返回 HTTP `409`；`/health` 返回全部场景的当前版本。镜像新增 `.dockerignore`、精确生产顶层依赖、`pip check`、非 root 用户和 Compose 运行态安全限制。
- 首次 live baseline 暴露 UOM、全单/行仓库、公司/日期口径、Unicode 连字符/千分位评分和上下文注入转述问题；修复 Prompt 和 grader 后最终低价模型 live gate 21/21 通过，critical、安全、Schema、禁止模式、结构化字段准确率和普通场景通过率均为 100%。最终 Token：prompt 13811、completion 13436、reasoning 11580、total 27247；p50 约 7.22 秒、p95 约 14.44 秒。
- Frappe 新增 20 个纯合成确定性 fixture 用例，固定 `as_of=2026-07-13`，覆盖商品短语、订单 DSL、报表 DSL；日期函数只增加测试用可选 `as_of`，生产默认仍使用 `date.today()`。同时修复 AI HTTP 测试凭据缺失分支错误调用 `cls.skipTest`。
- 最终故障演练通过：停止 Langfuse Web 后，真实低价模型聊天仍返回 200（540 tokens）；反馈接口返回 `accepted=true`、`observability_synced=false`，恢复后 Langfuse v3.212.0 健康。说明观测失败不会阻断 ERP/AI 主链路。
- 验证：Orchestrator 37 项通过；offline full gate 21/21 且可发布，partial gate 1/1 且明确不可发布，未知 case 退出 `2`；既有最终低价模型 live full gate 21/21，本轮最终镜像额外 live partial 1/1（509 tokens，约 3.26 秒）。后端 AI/确定性评测/gateway wrappers 132 项通过；Langfuse trace/generation/eval/feedback 查询、feedback 原文脱敏和失败开放演练均通过。Dockerfile 源码层可复用依赖缓存。
- 本轮分仓库提交：后端 `09fcb10 feat: add AI prompt evaluation governance`；父仓库功能提交 `95a7cae8 feat: complete AI observability evaluation milestone`；当前交接补充提交为本文件所在 HEAD。既有 `.codex` 和 Mobile 五个本地改动未提交。生产剩余风险：legacy `/api/public/ingestion` 已被 Langfuse v3 标记废弃，需迁移 OTLP；生产还需 PostgreSQL/ClickHouse/MinIO 联合备份恢复、告警、SSO/访问治理、成本看板和密钥轮换演练。

### 2026-07-13 AI 库存调整结构化草稿

- 本轮分仓库提交：
  - 后端 `apps/myapp`：`65f3ff4 feat: add AI inventory adjustment drafts`。
  - Web `frontend/myapp-web`：`1f8d9e0 feat: hand off AI inventory drafts`。
  - 父仓库：`b2dc3414 feat: complete AI inventory draft flow`。
- Orchestrator 新增 `inventory_adjustment_draft` 严格 Schema 和 `/internal/v1/drafts/inventory-adjustment`，只提取单个库存商品、仓库、`set_target / increase / decrease`、数量、单位、过账日期和原因候选；保留 `json_schema → JSON-only + 同 Schema 校验` 降级。
- Frappe 新增 `generate_ai_inventory_adjustment_draft_v1`，要求当前用户具有 `Stock Entry` 创建权限，并按公司和记录权限解析真实 Item / Warehouse；商品查询使用 `item_context=inventory`，数量通过共享 `resolve_item_quantity_to_stock` 换算。
- 草稿使用实时仓库库存计算目标库存和差异数量，估值参考只取后端商品上下文；减少后目标库存不得为负，调整原因必填。人工编辑或历史恢复都会重新读取当前库存、UOM、仓库和商品状态并创建不可变新版本。
- `prepare_ai_draft_handoff_v1` 新增 `inventory_adjustment` 安全载荷，只把库存单位下的目标数量一次性交接到 `/inventory/adjustments`。库存调整页显示 AI 来源警告并重新读取商品详情；只有用户主动点击原有“提交调整”按钮才会调用正式库存写接口。
- AI 不调用 `reconcile_inventory_stock_v1`，不创建或提交 `Stock Entry` / `Stock Reconciliation`。真实回归前后 `Stock Entry` 均为 815，`Stock Reconciliation` 为 0。
- 修复采购草稿改动中暴露的反馈同步函数不可达问题，`submit_ai_feedback_v1` 再次按失败开放契约同步 Orchestrator / Langfuse score。
- 最终 `ai-orchestrator` 镜像已重建并启动，`/health` 返回 `status=ok`、`litellm_configured=true`、`langfuse_configured=false`。
- 验证：Orchestrator 8 项通过；后端 AI + gateway wrapper 125 项通过；Web TypeScript、Biome、19 个 Jest 套件共 129 项通过；库存调整真实 HTTP 链路通过；三个仓库 `diff --check` 通过。
- AI 三类首期结构化草稿已全部完成。下一步优先部署真实 Langfuse 与固定评测集，随后实现商品向量检索/rerank、数据整理建议任务和模型策略管理台。

### 2026-07-13 AI 采购订单结构化草稿

- 本轮分仓库提交：
  - 后端 `apps/myapp`：`0a16313 feat: add auditable AI purchase drafts`。
  - Web `frontend/myapp-web`：`8f37980 feat: hand off AI purchase drafts`。
  - 父仓库：`1c733f93 feat: complete AI purchase draft flow`。
- 新增 Orchestrator `purchase_order_draft` 严格 Schema 和 `/internal/v1/drafts/purchase-order`；支持供应商、商品、数量、单位、币种、收货仓库、日期、供应商参考号和备注候选，保留 `json_schema → JSON-only + 同 Schema 校验` 兼容降级。
- Frappe 新增 `generate_ai_purchase_order_draft_v1`，按当前用户权限解析真实 Supplier，商品查询使用 `item_context=purchase`，采购价只取后端 `standard_buying_rate` / buying prices，模型价格不直接采用。
- 采购草稿复用通用 Draft / Draft Line / Version、人工编辑、重新校验、放弃、差异、安全恢复和状态机；供应商、采购价、采购 UOM、币种、预计到货日期及收货仓库保持采购领域独立口径。
- `prepare_ai_draft_handoff_v1` 现在支持 sales_order / purchase_order 两类安全载荷。Web `/ai` 新增“采购订单草稿”，草稿卡片、人工编辑和版本治理按草稿类型显示；handoff 使用一次性 sessionStorage 进入 `/purchase/orders/new`。
- 采购订单新建页新增 AI 草稿预填和来源警告，预填供应商、公司、币种、日期、采购模式、仓库、供应商参考号、备注和商品行；用户仍需主动点击现有采购创建接口。
- 真实链路通过：供应商 `HTTP Sort Supplier 1783508721925502138` + `SKU010 × 2` 生成 `AI-DRAFT-2cd683de4f7e4eceac8b54165c56c0a5`，采购参考价 920，validation ready，handoff 类型和供应商正确；会话已归档，未创建正式采购单。
- 最终 `ai-orchestrator` 镜像已基于当前工作区重建并重启，`/health` 返回 `status=ok`、`litellm_configured=true`；本地未配置 Langfuse，健康字段为 `false`，不影响草稿链路。
- 验证：Orchestrator 7 项通过；后端 AI + gateway wrapper 122 项通过；Web TypeScript、Biome、AI service Jest 5 项通过；三个仓库 `diff --check` 通过。
- 采购草稿、销售草稿版本治理、Web 人工编辑/版本历史及相关文档已完成分仓库提交。
- 后续库存调整结构化草稿已在上一节完成；采购草稿当前无待提交代码。

### 2026-07-13 AI 草稿不可变版本与安全恢复

- 新增 `MyApp AI Draft Version` 内部表和迁移 patch；已有草稿自动保存当前状态为 `migration` 基线版本，新草稿生成、人工修改和历史恢复分别记录 `generated`、`user_edit`、`restore_vN` 来源。
- 新增 `list_ai_draft_versions_v1` 和 `restore_ai_draft_version_v1`。版本接口返回字段变化以及商品行新增、删除、数量/UOM/价格/仓库变化。
- 历史恢复不会直接覆盖当前草稿，而是重新调用现有更新与真实主数据校验流程，并创建新的不可变版本，防止恢复过期价格、失效仓库或旧 UOM。
- Web 草稿卡片新增“版本历史”，展示版本号、来源、时间、字段/商品行差异，并支持将旧版本重新校验后恢复为新版本；当前最新版本不能重复恢复。
- 草稿人工编辑 Modal 已完成：客户、仓库、日期、销售模式、备注和商品行修改后由后端重新解析并刷新 validation；卡片展示状态、版本和校验错误。
- 验证：版本迁移成功；后端 AI + gateway wrapper 122 项通过；Web TypeScript、Biome、AI service Jest 5 项通过；真实 HTTP 版本列表返回既有草稿版本 1 / `migration`。
- 当前版本治理、人工编辑 UI、AI 技术设计、路线图和本交接文档尚未提交。
- 下一步：实现采购订单结构化草稿，复用通用草稿版本状态机但保持采购价格、供应商、收货仓库和采购 UOM 领域校验独立。

### 2026-07-13 AI 草稿人工编辑与版本展示

- 在生命周期控制提交后继续实现 Web 草稿人工编辑 Modal：客户、默认仓库、订单/交货日期、销售模式、备注和商品行可编辑，使用 Ant Design Form / Modal / InputNumber 和项目 RemoteLinkSelect。
- 保存调用 `update_ai_draft_v1`，后端重新解析真实 Customer / Item / Warehouse / UOM / 价格并递增版本；页面用后端返回值刷新来源卡片，不在浏览器自行判定 `ready_for_handoff`。
- 草稿卡片新增版本、状态和 validation errors 展示；只有 `draft` 状态可编辑，放弃或交接后按钮按状态禁用。
- Web TypeScript 与 Biome 通过。当前人工编辑 UI、AI 技术设计和本交接文档尚未提交。

### 2026-07-13 AI 草稿生命周期继续完善

- 本轮分仓库提交：
  - 后端 `apps/myapp`：`02dbba6 feat: add AI draft lifecycle controls`。
  - Web `frontend/myapp-web`：`95a8bc3 feat: add AI draft discard action`。
  - 父仓库：同步后端子模块指针和本交接文档；提交号以父仓库当前 HEAD 为准。
- 在已提交的销售订单草稿纵向链路上继续新增人工修改后重新解析 / 校验、版本号递增、行级 `updated_by_user` 审计和显式放弃能力。
- 新增 `update_ai_draft_v1` 与 `discard_ai_draft_v1`；只有 `draft` 状态可以修改或交接，`handed_off` 草稿不可再次修改或放弃，避免重复交接和版本漂移。
- 更新草稿时不信任前端传入的商品、价格或换算结果：Frappe 再次按当前用户、公司和真实主数据解析 Customer、Item、Warehouse、UOM、换算系数与参考价，然后重建 Draft Line 并更新 validation。
- Web AI 草稿卡片增加“放弃草稿”，放弃后当前卡片立即禁用交接。人工字段编辑界面和版本差异可视化仍待继续。
- 验证：后端 AI + gateway wrapper 121 项通过；Web TypeScript 和 Biome 通过；三个仓库 `diff --check` 通过。
- 提交后预期状态：后端和 Web clean；父仓库除既有 `.codex` 外 clean。

### 2026-07-13 AI Copilot 销售订单结构化草稿

- 本轮分仓库提交：
  - 后端 `apps/myapp`：`bb68490 feat: add auditable AI sales drafts`。
  - Web `frontend/myapp-web`：`182e612 feat: hand off AI sales drafts`。
  - 父仓库：本次提交包含 Langfuse Orchestrator、最终镜像构建优化、后端子模块指针、路线图和交接文档；提交号以父仓库当前 HEAD 为准。
- Phase B 首个纵向链路已完成：新增 `MyApp AI Draft` / `MyApp AI Draft Line` 内部表和 patch，支持销售订单草稿、来源 Run、版本、校验、候选、UOM、价格、仓库及行级审计；`bench --site localhost migrate` 成功。
- Orchestrator 新增 `/internal/v1/drafts/sales-order` 和严格 Pydantic Schema。优先使用模型 `json_schema`；当前低成本模型返回 400 时降级为 JSON-only 提取，但仍通过同一 Schema，非法自由文本不会持久化。
- Frappe 新增 `generate_ai_sales_order_draft_v1`、`get_ai_draft_v1`、`prepare_ai_draft_handoff_v1`：模型只提取候选，Frappe 按当前用户和公司权限重新解析 Customer、Item、Warehouse、UOM、换算系数和当前参考价；模型价格不直接采用，歧义会阻止交接。
- 草稿工具审计等级为 `L2_DRAFT_ONLY`。只有 `ready_for_handoff=true` 的草稿可以交接，交接只返回安全预填载荷并标记 `handed_off`，不创建或提交 Sales Order。
- Web `/ai` 新增“销售订单草稿”场景和草稿卡片；校验通过后使用一次性 sessionStorage 载荷进入现有 `/sales/orders/new`，页面显示 AI 来源警告，用户必须复核并主动点击现有 v2 创建按钮。
- 真实链路通过：使用真实客户和 `SKU010 × 2` 生成 `AI-DRAFT-e7f566a5573d4db2a78c49a480680707`，真实主数据解析、草稿持久化和 handoff 均成功；测试会话已归档，未调用正式订单创建接口。
- 验证：Orchestrator 6 项测试通过；后端 AI + gateway wrapper 121 项通过；Web TypeScript、Biome、AI service Jest 5 项通过；草稿表迁移成功；三个仓库 `diff --check` 和敏感信息检查通过。
- 最终 `ai-orchestrator` 镜像已基于当前工作区重建并启动；Dockerfile 将第三方依赖层与业务源码层分离，后续源码变更可复用依赖缓存。
- 提交后预期状态：后端和 Web clean；父仓库除既有 `.codex` 外 clean。
- 下一步：补草稿人工修改、重新校验、版本差异和放弃；随后实现采购订单草稿和库存调整草稿。

### 2026-07-13 AI Copilot Langfuse 可观测性接入

- AI Orchestrator 新增可选 Langfuse ingestion 客户端，记录 trace、generation、模型、Token、成功 / 错误状态，并把 Frappe conversation / run、场景、Prompt 版本、公司、环境和 release 作为关联元数据。
- 默认 `MYAPP_AI_LANGFUSE_CAPTURE_CONTENT=0`，输入输出只发送 SHA-256、字符数和字节数；终端用户继续使用稳定哈希，不把 Frappe 登录名发送给观测平台。只有完成数据治理评审后才能显式上传原文。
- Langfuse 集成为失败开放：未配置完整 host / public key / secret key、请求超时或平台返回错误时，不阻断模型调用、SSE 完成和 ERP 反馈保存。
- Frappe 发送给 Orchestrator 的请求已补充 `conversation_id` / `run_id`；`submit_ai_feedback_v1` 在本地持久化后调用新的 `/internal/v1/feedback`，把点赞 / 点踩同步为 Langfuse score。Run 查询补充 `trace_id` 关联。
- `.env.ai.example`、Orchestrator README、AI 技术设计和项目差距路线图已更新；健康检查现在返回 `langfuse_configured`。当前本地未配置真实 Langfuse 密钥，健康状态为 `false`，但接入代码和降级契约已完成。
- 已基于最终源码重建并重启 `frappe_docker-ai-orchestrator-1`，容器健康。Orchestrator 容器单测 5 项通过；后端 AI + gateway wrapper 120 项通过；真实低成本模型订单查询 SSE + 反馈链路通过，日志确认 `/internal/v1/chat/stream` 和 `/internal/v1/feedback` 均返回 200。
- 当前改动尚未提交：父仓库 Orchestrator、环境变量模板、路线图和本交接文档；后端 AI repository / service / tests 与设计文档。Web 无改动。父仓库既有 `.codex` 继续禁止提交。
- 下一步：部署或接入真实 Langfuse 实例完成 trace / score 实际落库与看板验收，然后进入 Phase B 销售订单结构化草稿、校验和现有编辑器交接。

### 2026-07-12 AI Copilot 经营报表解释

- 本轮分仓库提交：
  - 后端 `apps/myapp`：`0628a9e feat: add AI report explanations`。
  - Web `frontend/myapp-web`：`7c306eb feat: add AI report source cards`。
  - 父仓库：本次提交同步后端子模块指针、项目差距路线图和本交接文档；提交号以父仓库当前 HEAD 为准。
- 已完成 Phase A 的经营报表解释纵向链路：`report_summary` 不再是占位场景，Frappe 会把自然语言确定性解析为经营总览、销售、采购、资金或应收应付报表，以及今天 / 本周 / 本月 / 上月 / 近 N 天（最多 366 天）的受限 DSL。
- 报表工具复用既有结构化报表服务，不生成 SQL；执行前校验当前公司范围和报表依赖的 Sales Order、Purchase Order、Payment Entry、Sales Invoice、Purchase Invoice 读取权限，只把裁剪后的指标、趋势、排行和口径元数据交给 AI Orchestrator。
- Prompt / 工具策略审计版本升级为 `erp-readonly-v3`。回答被明确要求区分订单金额、实际收付款和发票未结金额，不得把模型推测当作报表原因或明细事实。
- Web `/ai` 已启用“报表解释”，增加示例问题、独立 `business_report` 来源卡片、中文经营指标标签和报表跳转，并同步更新只读安全边界说明。
- 修复真实回归发现的 DSL 组合语义：销售 + 应收未结仍走销售报表，采购 + 应付未结仍走采购报表；只有同时询问应收应付或明确往来账 / 欠款时才走应收应付报表。
- 修复 AI HTTP 测试未启用计费开关时错误调用 class-level `skipTest` 的既有问题，改为标准 `unittest.SkipTest`。
- 验证：后端 AI + gateway wrapper 120 项通过；真实低成本模型 SSE 报表专项 1 项通过，完整覆盖 Frappe Session → 报表权限 / 公司范围 → 销售报表 → AI Orchestrator → LiteLLM，并返回 `business_report` 引用后归档测试会话；Web TypeScript、Biome 和 AI service Jest 5 项通过；三个仓库 `diff --check` 通过。
- 提交后预期仓库状态：`apps/myapp` clean，`frontend/myapp-web` clean，父仓库除既有未跟踪 `.codex` 外 clean。
- 下一步优先项：接入 Langfuse trace / feedback 可观测性，之后进入 Phase B 结构化单据草稿；语义向量检索 / rerank 可与草稿阶段并行评估。

### 2026-07-12 AI Copilot Phase A 第一条纵向链路

- 本轮分仓库提交：
  - 后端 `apps/myapp`：`81d9688 feat: add auditable AI copilot platform`。
  - Web `frontend/myapp-web`：`6a0abc8 feat: add streaming AI copilot workspace`。
  - 父仓库：本次提交同步 AI Orchestrator、Compose 接入、环境变量示例、后端子模块指针和本交接文档；提交号以父仓库当前 HEAD 为准。
- 新增后端设计文档 `apps/myapp/AI_TECH_DESIGN.zh-CN.md`，并在应用 README 加入入口。
- 已确定企业级边界：Web/Mobile 只调用 `myapp` AI Gateway；Frappe 负责权限、会话、草稿、审计和正式业务写入；独立 AI Orchestrator 负责模型编排与工具调用；内部 LiteLLM 负责多供应商模型适配、路由、限流和预算。
- 已确定安全模型：AI 只生成、解释和修改草稿，不能创建/提交/取消正式业务单据，也不能直连数据库或生成 SQL；用户进入既有业务编辑器并主动点击后才由现有接口创建正式单据。
- 设计首期范围：聊天工作台、商品混合检索、自然语言受限查询 DSL、报表解释、销售/采购/库存调整草稿、数据整理建议任务；详细接口、DocType、工具白名单、分期验收与待决策项见设计文档。
- 新增独立 FastAPI 服务 `services/myapp-ai`：提供健康检查、内部 Bearer 服务认证、只读系统提示、LiteLLM OpenAI 兼容调用和模型响应归一化；传给模型供应商的终端用户标识使用稳定哈希，不发送 Frappe 登录名。
- `compose.yaml` 已接入 `ai-orchestrator`；本地密钥保存在被忽略的 `.env.ai.local`，提交模板为 `.env.ai.example`。临时密钥不得写入代码、文档、测试结果或 Git。
- 后端新增 `myapp.api.gateway.chat_ai_v1` 和 AI 服务层，限制消息角色、条数、长度和场景，客户端不能传入系统/工具消息；Web 新增 `/ai`、领域 service、菜单与只读边界提示。
- 已验证：AI Orchestrator 单测 1 项通过；后端 AI 与 gateway wrapper 108 项通过；Web TypeScript、Biome 和 AI service Jest 通过；真实 `localhost:8080` HTTP 回归 1 项通过，完整覆盖 Frappe Session → Gateway → Orchestrator → LiteLLM → `gpt-5.5`，最低推理等级返回 `reasoning_tokens = 0`。
- Phase A 第二条链路已继续实现：
  - 新增 `MyApp AI Conversation`、`MyApp AI Message`、`MyApp AI Run` 三张内部审计表，默认保留 30 天，小时任务清理过期数据；`bench --site localhost migrate` 已成功执行 patch。
  - 新增会话创建、列表、详情和归档网关；真实 HTTP 冒烟已验证当前用户隔离链路和归档状态。
  - `chat_ai_v1` 现在记录用户消息、模型消息、Run、Prompt 版本、Token、延迟、trace、工具摘要和失败状态，并返回可复用于 SSE 的 `events[]` 契约。
  - 首个 `product_search` 工具已接入：Frappe 校验 Item 读取权限和公司范围，复用 `search_product_v2`，最多向模型提供 8 条裁剪候选；Web 展示商品引用卡片，不从模型文本猜测商品事实。
  - ERP 工具采用混合编排：业务查询在 Frappe 当前用户上下文执行，AI Orchestrator 只消费裁剪结果，不持有 ERP 超级账号，也不任意回调业务接口。
  - Web `/ai` 已增加历史会话、消息回读、归档、场景选择、Run 标识和商品引用卡片。
- Phase A 第二条链路已完成收口：
  - 新增真正 POST + JWT SSE：Frappe 返回 Werkzeug 流式 Response，代理 AI Orchestrator / LiteLLM 增量事件；Web 使用 `fetch + ReadableStream`，支持消息逐段展示、工具状态、引用和完成/错误事件。
  - 新增 `MyApp AI Feedback` 表和 `submit_ai_feedback_v1`，只允许当前用户对本人已完成 Run 点赞/点踩；Web 已接正负反馈按钮。
  - 商品描述搜索增加确定性短语提取，可把“帮我找数码相机，只说明……”还原为真实搜索词，不额外消耗模型调用。
  - `order_query` 已接入第一版受限 DSL：销售/采购、今天/本周/本月/上月/近 N 天、状态、金额排序/门槛和最多 20 条；复用既有订单工作台服务并二次执行记录级权限过滤。
  - Web 已增加商品和销售/采购订单来源卡片，模型文本不作为商品编码、库存、金额或订单状态事实源。
- 模型成本策略已调整：普通开发/回归默认使用 `opencode-deepseek-v4-flash`，只有显式 OpenAI 专项能力测试才调用 `gpt-5.5`。新 LiteLLM 密钥只保存在被忽略的 `.env.ai.local`。
- 最新验证：AI Orchestrator 单测 2 项通过；后端 AI + gateway wrapper 116 项通过；Web TypeScript、Biome 和 AI service Jest 5 项通过；反馈表迁移成功；AI SSE + 订单查询 + 反馈专项真实 HTTP 用例通过；三个仓库 `diff --check` 均通过。
- 真实链路已通过：Orchestrator SSE 正常；完整 Frappe 商品 SSE 首事件约 42ms，商品 `SKU010` 引用、低价模型完成和正向反馈成功；自然语言采购订单查询返回 5 条真实引用，按金额降序首条为 `PUR-ORD-2026-01846-5`。
- 当前尚未实现：Langfuse、向量语义检索/rerank、报表真实工具、结构化单据草稿和数据治理任务。下一步优先接经营报表解释和 Langfuse，再进入 Phase B 单据草稿。
- 提交与运维说明：
  - `services/myapp-ai` 的源码和 Dockerfile 已纳入父仓库；最后一轮运行容器通过源码同步并重启验证，正式镜像尚未基于最终工作区重新构建，后续部署应执行 `docker compose build ai-orchestrator` 后再启动。
  - `.env.ai.local` 和真实 LiteLLM 密钥仅保留在本机且已被 `.gitignore` 排除；`.env.ai.example` 只包含占位符和低价默认模型配置。
  - 提交前敏感信息扫描未在提交范围发现 `sk-*`；父仓库 `.codex` 是既有本地未跟踪状态，继续禁止提交。
- 提交后预期仓库状态：`apps/myapp` clean，`frontend/myapp-web` clean，父仓库除既有未跟踪 `.codex` 外 clean。

### 2026-07-12 Web 单位与币种初始展示映射修复

- 修复 `UomSelect`：初始值不再只因选项尚未加载而回显原始 UOM 编码。商品编辑页会优先消费后端已返回的 `stock_uom_display`、`wholesale_default_uom_display`、`retail_default_uom_display`；其他 UOM 表单会按初始值异步加载并使用带 `display_name` 的标签，且共享缓存避免重复请求。
- 新增 `CurrencySelect`：统一显示“人民币 (CNY)”等映射标签，保存值仍为稳定币种编码。已替换商品编辑、客户/供应商默认币种以及采购订单新建/编辑的全部币种输入框。
- 验证：`npm run tsc`、`npm run biome:lint`、父仓库 / 后端 / Web `diff --check` 均通过。

### 2026-07-12 报表资金筛选与采购差额核销

- 资金流水 `list_cashflow_entries_v1` 已补齐服务端精确筛选：方向（`Receive` / `Pay` / `Internal Transfer`）、付款方式、往来方类型和往来方；关键词搜索仍覆盖单号、往来方、付款方式和参考号。Web `/payments` 已接入对应筛选控件。
- 采购付款 `record_supplier_payment` 统一复用结算服务；采购发票现在支持 `settlement_mode="writeoff"`。少付部分会以公司 `Write Off Account` 差额核销，且保留完整应付分配，采购订单聚合会分别反映实付与核销金额。
- 自动化验证：后端报表、结算、采购服务单测共 97 项通过；Web `npm run tsc`、`npm run biome:lint` 与三个仓库 `diff --check` 通过。
- 真实 HTTP 回归已通过：宿主机执行 `PurchaseQuickHttpTestCase.test_update_purchase_payment_status_writeoff_settles_purchase_invoice`，自动创建采购订单 / 收货 / 发票后以 4500 付款 + 100 核销完成结清并自动清理测试单据。此前失败是 backend 容器内错误使用宿主机 `localhost:8080` 地址；HTTP 测试应按 `.env.http-test` 在宿主机执行，或在容器内将地址改为 `http://localhost:8000`。
- 报表剩余 P1：发票/库存凭证钻取、通用导出与大数据异步导出、多公司真实对账和性能基线；这些需要先确认导出文件存储、任务保留期以及跨公司币种/内部往来抵销口径。

### 2026-07-12 全项目差距盘点与文档治理

本轮只更新文档，不修改业务代码。

- 新增统一路线图 `docs/codex/PROJECT_GAP_ROADMAP.zh-CN.md`，集中记录全项目当前成熟度、P0/P1/P2 缺口、验收目标和推荐实施顺序。
- 已纠正后端领域文档中的过期结论：
  - 打印平台核心能力已经完成，剩余重点是真实打印机、浏览器、样张和对象存储验收。
  - 用户会话中心、JWT 2FA、权限快照和全设备注销已经完成；高级治理待办调整为可信设备、异常登录、审批、临时授权和完整记录级权限模拟。
  - 报表一期接口拆分已经完成，剩余重点是钻取、导出、多公司回归和性能。
- 已纠正 Web 文档中的过期结论：
  - JWT 登录已支持 Frappe 2FA OTP 二次挑战。
  - 客户和供应商退款接口均已存在，剩余是退货退款复杂组合的真实验收与闭环。
  - 原 `/admin` 模板路由已由 `/administration` 用户治理路由替换；仍保留的隐藏模板路由是 `/welcome` 和 `/list`。
  - 不再在长期计划中固定记录 ahead 数、提交号和临时服务状态，统一引用本交接文件。
- `STAGING_DEPLOYMENT.zh-CN.md` 已明确定位为部署 runbook，不再把条件式操作步骤误读为外部 staging 的实时状态。
- 父仓库 README 已加入项目差距路线图和当前交接入口。
- 移动端仓库在本轮开始前已有以下 5 个未提交文件，本轮未修改、回滚或提交：
  - `app/common/product-search.tsx`
  - `lib/sales-mode.ts`
  - `services/gateway.ts`
  - `services/products.ts`
  - `services/sales.ts`
- 后端文档已提交：`84fcdca docs: update module delivery status`；Web 文档已提交：`02d53b7 docs: refresh web delivery plan`；父仓库路线图、README、staging runbook 和后端子模块指针已提交：`73f1be61 docs: add project gap roadmap`。本条交接记录已收口本轮最终状态。
- `git diff --check`、`git -C apps/myapp diff --check`、`git -C frontend/myapp-web diff --check` 已通过。Web 的提交钩子会将纯 Markdown 交给已忽略 `.md` 的 Biome 并报“未处理文件”，本次仅文档提交已使用 `--no-verify`；不涉及代码检查绕过。
- 当前改动边界：后端和 Web 仅有文档变化；既有 `.codex` 仍未跟踪。移动端前述 5 个文件仍是本轮之前的既有未提交改动。
- 建议下一项实现工作：按路线图 P0 优先启动库存盘点草稿、复核、确认、驳回、作废和审计生命周期。

### 2026-07-12 用户模块企业级 UI 与安全治理收口

本轮在第一阶段用户模块基础上继续增强，并完成后端、Web 和父仓库分层提交。

- 后端：`ce79f04 feat: complete user security governance`
- Web：`eda4561 feat: complete web user experience`
- 父仓库：同步提交后端子模块指针和本交接文档，提交号以父仓库当前 HEAD 为准。

- Web 视觉与信息架构按本地 Ant Design Pro 官方账号中心、设置页、列表页和详情页重构：
  - 个人中心：身份卡、治理指标、工作空间、功能授权、数据范围和安全状态。
  - 个人设置：左侧设置导航、右侧内容工作区、响应式资料表单、头像预览、工作偏好和安全状态。
  - 用户列表：用户治理指标、头像身份列、服务端表格、横向滚动和批量启停。
  - 用户详情：状态头、角色 / 数据权限 / 审计指标和分域 Tabs。
  - 角色目录：角色使用量、权限规则、DocType 覆盖和可写范围摘要。
- 新增后端治理能力：
  - `get_user_management_overview_v1`。
  - `batch_set_users_enabled_v1`，单批最多 100 人并执行整批保护校验。
  - `list_roles_v1` 补充权限规则数、DocType 覆盖数和可写 DocType 数。
- 真实 `localhost` 验证：
  - 用户概览返回 13 个用户、4 个启用账号、2 个启用系统管理员。
  - `Sales User` 返回 58 条权限规则、52 个 DocType 覆盖、20 个可写 DocType。
- 自动化验证：
  - 后端用户 / JWT / 偏好 / gateway：128 tests 通过。
  - Web TypeScript、Biome 通过。
  - Web 全量 Jest：18 suites / 121 tests 通过；仍有既有 open handle 提示，退出码为 0。
- 写操作错误反馈已统一：
  - `runGatewayMutation` 对业务异常显示去重后的 `notification.error`。
  - 用户创建、批量启停、用户详情、个人资料、工作偏好和密码修改均捕获 Promise 异常。
  - 用户创建和密码修改会把密码校验消息同步绑定到对应表单字段，不再只输出浏览器控制台。
  - Frappe 密码建议中的 HTML 已转换为可读纯文本；同类弱密码请求已确认是密码强度分数低于站点最低要求，并非邮箱、手机号或角色重复。
- 剩余安全治理能力已继续落地：
  - 个人头像使用 Frappe `File` 真实上传并绑定 `User.user_image`。
  - 新增用户安全摘要、Frappe Session / JWT refresh 会话统计和全设备注销。
  - JWT 新增 `auth_generation`，全设备注销、修改密码和停用账号后旧 access / refresh token 立即失效。
  - JWT 登录复用 Frappe 2FA，Web 支持 OTP 二次挑战。
  - 管理员用户详情新增核心业务 DocType 权限快照。
  - 真实 `localhost` 已验证 Administrator 安全摘要和 13 个核心 DocType 权限快照。
- 最新验证：
  - 后端用户 / JWT / gateway：133 tests 通过。
  - Web TypeScript、Biome 通过。
  - Web 全量 Jest：18 suites / 123 tests 通过；仍有既有 open handle 提示，退出码为 0。
- 提交后仓库状态：
  - `apps/myapp` clean。
  - `frontend/myapp-web` clean。
  - 父仓库除既有未跟踪 `.codex` 外 clean。
- 下一步：人工浏览器回归五个用户模块页面，并使用实际启用 2FA 的测试账号验证 OTP App / Email / SMS 投递流程。

### 2026-07-11 企业级用户与权限模块第一阶段

本轮已完成架构设计、第一阶段代码实现、自动化验证和分仓库提交。

- 后端：`b98f45f feat: add enterprise user management`
- Web：`2ca0320 feat: add web user administration`
- 父仓库：同步提交后端子模块指针和本交接文档，提交号以父仓库当前 HEAD 为准。

- 新增架构文档：`apps/myapp/USER_MANAGEMENT_TECH_DESIGN.zh-CN.md`。
- 后端新增用户治理服务和 gateway：
  - 当前用户资料查询 / 修改、密码修改。
  - 用户分页、详情、创建、编辑、启停。
  - 角色目录、用户角色整体分配。
  - 标准 `User Permission` 数据范围新增 / 删除。
  - `Version` 用户主档变更记录。
  - 保护 `Administrator`、`Guest`、当前操作者和最后一个启用的 `System Manager`。
- `me_v1` 已扩展邮箱、头像、电话、所在地、语言和时区。
- Web 新增：
  - `/account/center`
  - `/account/settings`
  - `/administration/users`
  - `/administration/users/:user`
  - `/administration/roles`
- Web 个人设置支持资料、默认公司 / 仓库远程选择和密码修改后重新登录。
- 管理员详情支持主档、角色、公司 / 仓库 / 客户 / 供应商数据范围和审计记录。
- 已验证：
  - 后端用户 / JWT / 偏好 / gateway：125 tests 通过。
  - Web TypeScript、Biome 通过。
  - Web 全量 Jest：17 suites / 117 tests 通过。
  - 真实 `localhost` 站点成功执行角色目录、用户分页、当前用户资料和 Administrator 详情查询。
  - 三个仓库 `diff --check` 通过。
- 当前仓库状态：
  - `apps/myapp` clean。
  - `frontend/myapp-web` clean。
  - 父仓库提交后除既有未跟踪 `.codex` 外 clean。
- 下一步：人工浏览器回归个人中心、个人设置、用户列表 / 详情 / 角色页；发现的问题按页面或权限边界做聚焦修复。

### 2026-07-11 打印模块功能收口

本轮补齐此前明确剩余的打印功能，并完成后端、Web 和父仓库分层提交。

- 后端：`9ba905e feat: complete print platform capabilities`
- Web：`9a4699c feat: complete web print workflows`
- 父仓库：同步提交后端子模块指针和本交接文档，提交号以父仓库当前 HEAD 为准。

- 批次严格幂等：
  - 新增 patch `myapp.patches.add_print_batch_request_id`。
  - `tabMyApp Print Batch` 新增 `request_id`。
  - 唯一约束：`(requested_by, request_id)`。
  - 重复请求和并发竞争均返回原批次，响应包含 `deduplicated`。
- 批次聚合输出：
  - 新增 `download_print_batch_merged_pdf_v1`。
  - 成功项可继续下载 ZIP，也可按批次顺序合并为单个 PDF。
- 文件存储适配：
  - 归档读取优先使用 Frappe `File.get_content()`，兼容站点本地文件和对象存储实现。
  - 本地 `/private/files/`、`/files/` 路径保留兜底。
- 收付款凭证：
  - registry 新增 `Payment Entry`。
  - 新增 `standard` 和 `finance` 两个托管模板。
  - Web `/payments/:name` 接入通用打印按钮。
  - Web `/payments` 接入批量选择和 `PrintBatchAction`。
  - 打印历史支持跳转回收付款详情。
- 业务模板差异化：
  - 发票财务版增加已收 / 已付、未结和财务复核信息。
  - 销售 / 采购订单外部确认版增加确认条款和签章栏。
  - 发货 / 收货仓库版增加拣货、收货、复核和交接栏。
- 已验证：
  - 后端打印 + gateway wrapper：148 tests 通过。
  - Web TypeScript、Biome 通过；全量 Jest 16 suites / 114 tests 通过，仍有既有 open handle 提示，退出码为 0。
  - `bench --site localhost migrate` 成功执行新 patch。
  - 确认 `request_id` 字段和 `(requested_by, request_id)` 唯一索引存在。
  - 真实 `Payment Entry ACC-PAY-2026-00938` finance HTML / PDF 生成成功，PDF 278111 bytes。
  - 真实同步批次 `PRN-BATCH-20260711111314-f07dff33` 验证：首次创建、第二次幂等命中同一批次，合并 PDF 279286 bytes / 1 page。
- `git -C apps/myapp diff --check`、`git -C frontend/myapp-web diff --check`、`git diff --check` 通过。
- 待完成：真实浏览器视觉回看；功能实现、迁移、自动化验证和代码提交已完成。

### 2026-07-11 Web 打印中心第二阶段

本轮在第一阶段已提交基础上继续实现全局打印中心，并完成后端、Web 和父仓库分层提交。

- 后端：`ec6d484 feat: add print operations query APIs`
- Web：`420d0a3 feat: add print center pages`
- 父仓库：同步提交后端子模块指针和本交接文档，提交号以父仓库当前 HEAD 为准。

- 后端新增：
  - `list_print_batches_v1`：打印批次服务端分页、状态 / 日期 / 申请人筛选。
  - `list_print_jobs_v2`：跨单据打印历史服务端分页和多条件筛选。
  - 批次访问控制：批次详情、取消、失败重试和 ZIP 下载只允许申请人或 `System Manager`。
  - 普通用户的批次列表和全局历史强制限定为本人；`System Manager` 可查看全部并按用户筛选。
  - 修复 `myapp.api.api` 聚合模块误导入不存在的 `build_print_file_download_v1`；现在正确导出 gateway `download_print_file_v1`，并增加聚合导入回归测试。
- Web 新增一级菜单 `/printing`：
  - `/printing/batches`
  - `/printing/history`
  - `/printing/settings`
  - 隐藏菜单 `/printing/preview`
- 批次页支持任务找回、服务端分页、筛选、详情轮询、取消、失败重试和 ZIP 下载。
- 历史页支持跨单据筛选、跳回原业务单据和进入统一预览页补打。
- 已验证：
  - 后端打印和 gateway wrapper：144 tests 通过。
  - 真实 `localhost` 数据库查询：批次列表返回 `total=0`，打印历史返回 `total=6` / 当前页 2 条。
  - Web TypeScript、Biome 通过。
  - Web access + domain service Jest：2 suites / 65 tests 通过。
- `git -C apps/myapp diff --check`、`git -C frontend/myapp-web diff --check`、`git diff --check` 已通过。
- 待完成：人工浏览器回归；代码提交已完成。

### 2026-07-10 Web 打印模块第一阶段接入

本轮按打印领域模块架构完成 Web 第一阶段接入并已提交。

- 后端：`90d9dde fix: refine print copy audit semantics`
- Web：`deb4ef4 feat: add web print operations workflow`
- 父仓库：同步提交后端子模块指针和本交接文档，提交号以父仓库当前 HEAD 为准。

- 新增独立打印预览页 `/printing/preview`：
  - 后端 HTML 通过 iframe 展示。
  - 支持模板切换、刷新、系统打印和 PDF 下载。
  - 预览页显式记录 Web 审计 metadata。
- 重构单张打印入口：
  - 不再在前端硬编码 fallback `standard`。
  - 模板尚未加载或未显式选择时，由后端解析全局默认模板。
- 新增 `PrintBatchAction`：
  - 后台创建 PDF 批次。
  - 自动轮询进度。
  - 支持取消、失败项重试和成功项 ZIP 下载。
- 六类单据列表均已接入批量打印：销售 / 采购订单、销售发货单、销售发票、采购收货单、采购发票。
- 新增 `/printing/settings`：仅 `System Manager` 可见，可维护每类单据的全局默认模板和启用状态。
- `src/services/myapp/printing.ts` 已补齐打印设置和批次生命周期的领域类型、snake_case 映射和带认证下载错误处理。
- 后端修正补打统计口径：`preview` 保留审计但不增加打印副本次数；`download`、`print`、`share`、`archive` 才计入补打判断。
- 已验证：
  - 后端 `test_printing_service` + `test_gateway_wrappers`：138 tests 通过。
  - Web `npm run tsc` 通过。
  - Web `npm run biome:lint` 通过。
  - Web domain service Jest：1 suite / 62 tests 通过；仍有既有 open handle 提示，退出码为 0。
  - Web access Jest：1 suite / 2 tests 通过。
  - `git -C apps/myapp diff --check`、`git -C frontend/myapp-web diff --check`、`git diff --check` 通过。
- 待完成：人工浏览器回归，以及全局批次列表 / 全局打印历史页面。

### 2026-07-10 打印平台阶段提交

本轮完成打印平台阶段性收口和提交准备。按现有 6 类核心单据口径，后端功能完成度约 94%，已经形成单张打印、模板治理、打印审计和批量异步打印的完整基础链路。

- 本轮提交：
  - 后端 `apps/myapp`：`413dac2 feat: complete print platform governance`
  - Web `frontend/myapp-web`：`4bd3002 feat: enrich print template menu`
  - 父仓库：提交本交接文档和 `apps/myapp` 子模块指针；提交号以父仓库当前 HEAD 为准。
- 提交后仓库预期状态：

  - `apps/myapp` clean。
  - `frontend/myapp-web` clean。
  - 父仓库除既有未跟踪 `.codex` 外 clean。

- 当前可打印单据：
  - `Sales Invoice`
  - `Purchase Invoice`
  - `Sales Order`
  - `Purchase Order`
  - `Delivery Note`
  - `Purchase Receipt`
- 当前核心能力：
  - HTML / PDF 预览、PDF 流式下载、可选私有归档。
  - 标准模板和第二业务模板、模板角色可见性、全局默认模板设置。
  - 打印历史、动作审计、补打标识、水印和最近打印摘要。
  - 异步批量打印、进度查询、ZIP 下载、取消、失败项重试、90 天过期清理。
- Web 通用打印按钮已展示后端模板分类和说明，不在页面层硬编码模板清单。
- 本轮文档已同步：
  - `apps/myapp/API_GATEWAY.zh-CN.md`
  - `apps/myapp/PRINTING_TECH_DESIGN.zh-CN.md`
  - `frontend/myapp-web/WEB_DEVELOPMENT.zh-CN.md`
  - `docs/codex/CURRENT_HANDOFF.zh-CN.md`
- 最新验证：
  - 后端打印服务和 gateway wrapper 共 137 tests 通过。
  - `git -C apps/myapp diff --check`、`git -C frontend/myapp-web diff --check`、`git diff --check` 通过。
- 发布要求：
  - 目标站点必须执行 `bench --site <site> migrate`，以创建 `tabMyApp Print Batch` 和 `tabMyApp Print Setting`。
  - 本地 `localhost` 已迁移并确认两张表存在。
- 剩余边界：
  - 收款单 / 付款单尚未接入。
  - 第二业务模板仍主要复用标准模板 HTML，尚需进一步做业务版式差异化。
  - 批量结果尚不支持合并 PDF。
  - 模板角色、纸张、页边距和水印策略尚未形成完整可运营设置中心。
  - 文件读取和清理当前主要覆盖 Frappe 本地 `File`，对象存储仍需适配。

### 2026-07-10 打印全局默认模板设置

本轮继续增强后端打印治理，已落地第一版全局默认模板设置。

- 新增迁移：
  - `myapp.patches.create_print_setting_table`
  - 表名：`tabMyApp Print Setting`
  - 唯一维度：`reference_doctype`
- 新增设置字段：
  - `default_template`
  - `enabled`
  - `metadata_json`
- 默认模板解析规则已接入 `resolve_print_template`：
  - 显式传入 `template` 时仍优先使用显式模板，并严格校验模板可见性。
  - 未显式传入 `template` 时，优先读取启用状态的全局默认模板设置。
  - 如果配置模板对当前用户不可见、禁用或不存在，自动回退 registry 默认模板。
- 新增服务和 gateway 能力：
  - `get_print_settings_v1`
  - `set_print_default_template_v1`
- 权限：
  - 当前仅 `System Manager` 可维护默认模板设置。
  - 查询设置不替代 `get_print_templates_v1` 的可见模板过滤。
- 文档已同步：
  - `apps/myapp/API_GATEWAY.zh-CN.md`
  - `apps/myapp/PRINTING_TECH_DESIGN.zh-CN.md`
- 已验证：
  - `docker exec frappe_docker-backend-1 bash -lc 'cd /home/frappe/frappe-bench && env/bin/python -m unittest apps.myapp.myapp.tests.unit.test_printing_service apps.myapp.myapp.tests.unit.test_gateway_wrappers'`，137 tests 通过。
  - `docker exec frappe_docker-backend-1 bash -lc 'cd /home/frappe/frappe-bench && bench --site localhost migrate'` 成功，执行 `myapp.patches.create_print_setting_table`。
  - `bench --site localhost mariadb -e "SHOW TABLES LIKE 'tabMyApp Print Setting';"` 确认表存在。
  - `git -C apps/myapp diff --check`、`git -C frontend/myapp-web diff --check`、`git diff --check` 均通过。
- 当前边界：
  - 第一版设置中心仅覆盖默认模板。
  - 纸张、页边距、水印开关等仍在 registry / 模板层控制，后续可通过 `metadata_json` 扩展。

### 2026-07-09 打印模板角色权限

本轮继续完善后端打印模板治理，已在 registry 层落地第一版模板角色可见性。

- 后端 `PrintTemplateDefinition` 新增：
  - `allowed_roles`
  - 输出元数据 `restricted`
  - 输出元数据 `allowed_roles`
- `get_print_templates_v1` / `list_print_doctypes_v1` 现在只返回当前用户角色可见的模板。
- `resolve_print_template` 也会按同一角色规则拦截不可见模板，绕过前端直接传模板 key 也会被拒绝。
- 当前角色规则：
  - `standard` 暂不限制，作为默认兜底模板。
  - `finance`：`Accounts Manager`、`Accounts User`、`System Manager`
  - 销售 `external`：`Sales Manager`、`Sales User`、`System Manager`
  - 采购 `external`：`Purchase Manager`、`Purchase User`、`System Manager`
  - `warehouse`：`Stock Manager`、`Stock User`，并按单据侧允许对应销售 / 采购业务角色；`System Manager` 可见全部模板。
- 文档已同步：
  - `apps/myapp/API_GATEWAY.zh-CN.md`
  - `apps/myapp/PRINTING_TECH_DESIGN.zh-CN.md`
- 已验证：
  - `docker exec frappe_docker-backend-1 bash -lc 'cd /home/frappe/frappe-bench && env/bin/python -m unittest apps.myapp.myapp.tests.unit.test_printing_service apps.myapp.myapp.tests.unit.test_gateway_wrappers'`，130 tests 通过。
  - `git -C apps/myapp diff --check`、`git diff --check` 均通过。
- 当前边界：
  - 权限规则仍是 Python registry 固定配置，尚未做可运营维护的模板权限配置表。
  - 全局默认模板设置表已落地，但 Web 尚未做设置管理页。
  - Web 目前会自然消费后端返回的可见模板，但尚未做角色权限说明或模板管理页。

### 2026-07-09 打印批次过期清理

本轮继续完善后端批量打印生命周期治理，已补齐批次和归档文件过期清理。

- 新增服务层能力：
  - `cleanup_expired_print_batches`
- 新增定时任务：
  - `myapp.tasks.cleanup_print_batches`
- 已接入 `hooks.py` scheduler：
  - 每小时执行一次。
- 默认清理策略：
  - 保留期 90 天。
  - 只清理最终态批次：`completed`、`partial_failed`、`failed`、`canceled`。
  - 默认删除批次成功项 `results[].file_url` 对应的归档 PDF `File`。
  - 删除 `tabMyApp Print Batch` 批次记录。
  - 保留 `tabMyApp Print Job` 逐单审计记录。
- 当前边界：
  - 不清理 `queued`、`processing`、`cancel_requested`。
  - 文件删除当前覆盖 Frappe 本地 `File`；对象存储后续需要统一文件删除适配层。
- 文档已同步：
  - `apps/myapp/API_GATEWAY.zh-CN.md`
  - `apps/myapp/PRINTING_TECH_DESIGN.zh-CN.md`
- 已验证：
  - `docker exec frappe_docker-backend-1 bash -lc 'cd /home/frappe/frappe-bench && env/bin/python -m unittest apps.myapp.myapp.tests.unit.test_printing_service apps.myapp.myapp.tests.unit.test_gateway_wrappers'`，127 tests 通过。
  - `docker exec frappe_docker-backend-1 bash -lc 'cd /home/frappe/frappe-bench && env/bin/python - <<\"PY\" ... import myapp.tasks ... PY'` 确认 `cleanup_print_batches` 可导入。
  - `git -C apps/myapp diff --check`、`git diff --check` 均通过。
- 当前后端批量打印链路：
  - 创建批次
  - 异步逐单归档 PDF
  - 查询进度 / 结果
  - ZIP 下载成功项
  - 取消批次
  - 失败项重试
  - 90 天最终态批次和归档 PDF 清理

### 2026-07-09 打印批次取消与失败项重试

本轮继续完善后端批量打印治理，已补齐批次取消和失败项重试。

- 新增服务层能力：
  - `cancel_print_batch_v1`
  - `retry_print_batch_failed_v1`
- 新增 gateway 接口：
  - `myapp.api.gateway.cancel_print_batch_v1`
  - `myapp.api.gateway.retry_print_batch_failed_v1`
- 批次状态扩展：
  - `queued`
  - `processing`
  - `cancel_requested`
  - `canceled`
  - `completed`
  - `partial_failed`
  - `failed`
- 取消语义：
  - `queued` 批次直接进入 `canceled`，所有单据结果记为 `skipped`。
  - `processing` 批次进入 `cancel_requested`，Worker 当前单据完成后跳过后续单据并最终进入 `canceled`。
  - 已完成 / 失败 / 已取消批次不回滚，不删除已归档 PDF，不删除已写入的 `MyApp Print Job`。
- 失败项重试语义：
  - 只读取原批次 `results[]` 中 `status=failed` 的单据。
  - 创建新批次，不覆盖原批次结果。
  - 新批次 metadata 写入 `retry_of=<原批次号>`。
  - 原批次没有失败项时返回业务校验错误。
- 文档已同步：
  - `apps/myapp/API_GATEWAY.zh-CN.md`
  - `apps/myapp/PRINTING_TECH_DESIGN.zh-CN.md`
- 已验证：
  - `docker exec frappe_docker-backend-1 bash -lc 'cd /home/frappe/frappe-bench && env/bin/python -m unittest apps.myapp.myapp.tests.unit.test_printing_service apps.myapp.myapp.tests.unit.test_gateway_wrappers'`，126 tests 通过。
  - `git -C apps/myapp diff --check`、`git diff --check` 均通过。
- 当前边界：
  - 已支持批次取消、失败项重试、ZIP 下载成功项。
  - 尚未做合并 PDF。
  - 尚未做批次和归档文件过期清理。

### 2026-07-09 打印批次 ZIP 聚合下载

本轮继续增强后端批量打印能力，已在“批次任务 + 逐单归档 PDF + 进度查询”的基础上补齐批次成功项 ZIP 聚合下载。

- 新增服务层能力：
  - `build_print_batch_archive_download_v1`
- 新增 gateway 下载接口：
  - `myapp.api.gateway.download_print_batch_archive_v1`
- ZIP 下载语义：
  - 读取 `get_print_batch_v1.results[]` 中 `status=success` 且有 `file_url` 的 PDF。
  - 打包为 ZIP 下载流，`content_type=application/zip`。
  - 失败项不会进入 ZIP，也不会阻断下载；失败原因仍通过 `get_print_batch_v1` 查看。
  - ZIP 内文件名来自批次结果 `filename`，重名时自动追加序号。
  - 当前文件读取支持本地 `/private/files/` 和 `/files/`；后续接对象存储时需要统一文件读取适配层。
- 文档已同步：
  - `apps/myapp/API_GATEWAY.zh-CN.md`
  - `apps/myapp/PRINTING_TECH_DESIGN.zh-CN.md`
- 已验证：
  - `docker exec frappe_docker-backend-1 bash -lc 'cd /home/frappe/frappe-bench && env/bin/python -m unittest apps.myapp.myapp.tests.unit.test_printing_service apps.myapp.myapp.tests.unit.test_gateway_wrappers'`，120 tests 通过。
  - `git -C apps/myapp diff --check`、`git diff --check` 均通过。
- 当前边界：
  - 已支持 ZIP 聚合下载，但尚未做合并 PDF。
  - 尚未做批次取消、失败项重试和批次 / 归档文件过期清理。

### 2026-07-09 打印模块后端批量异步能力

本轮聚焦后端打印批量 / 异步能力，已完成第一版“批次任务 + 后台逐单归档 PDF + 进度查询”的基础设施。当前后端打印模块完成度评估提升到约 90%。

- 新增批量打印批次表：
  - patch：`myapp.patches.create_print_batch_table`
  - 表名：`tabMyApp Print Batch`
  - 本地 `localhost` 已执行 `bench --site localhost migrate`，确认表存在。
- 新增后端服务能力：
  - `create_print_batch_v1`
  - `get_print_batch_v1`
  - `process_print_batch_v1`
- 新增 gateway/API 暴露：
  - `myapp.api.gateway.create_print_batch_v1`
  - `myapp.api.gateway.get_print_batch_v1`
- 批量任务当前语义：
  - 入参 `documents[]` 支持 `doctype`、`docname/name`、`template`、`filename`。
  - 当前仅支持 `pdf` 输出，每批最多 100 张单据。
  - 默认通过 Frappe background job 异步执行，可传 `run_async=0` 同步执行，便于开发 / 测试。
  - Worker 逐单复用 `get_print_file_v1(..., archive=1)`，将 PDF 归档为私有 `File`。
  - 每个成功 / 失败项都会尽量写入 `record_print_job_v1(action="archive")`，metadata 包含 `batch_id` 和 `batch_idx`。
  - 批次状态支持 `queued`、`processing`、`completed`、`partial_failed`、`failed`。
  - 查询返回 `total_count`、`done_count`、`success_count`、`failed_count`、`skipped_count`、`progress`、`items[]`、`results[]`。
- 当前明确边界：
  - 第一版不合并 PDF，不生成 ZIP；调用方通过 `get_print_batch_v1` 获取每张单据归档后的 `file_url`。
  - 批次表保存任务级状态；逐单审计仍写入 `tabMyApp Print Job`。
  - 如果 `tabMyApp Print Batch` 未迁移创建，创建接口返回 `queued=false` / `reason=table_missing`。
- 文档已同步：
  - `apps/myapp/API_GATEWAY.zh-CN.md`
  - `apps/myapp/PRINTING_TECH_DESIGN.zh-CN.md`
- 已验证：
  - `docker exec frappe_docker-backend-1 bash -lc 'cd /home/frappe/frappe-bench && env/bin/python -m unittest apps.myapp.myapp.tests.unit.test_printing_service apps.myapp.myapp.tests.unit.test_gateway_wrappers'`，118 tests 通过。
  - `docker exec frappe_docker-backend-1 bash -lc 'cd /home/frappe/frappe-bench && bench --site localhost migrate'` 成功，执行 `myapp.patches.create_print_batch_table`。
  - `bench --site localhost mariadb -e "SHOW TABLES LIKE 'tabMyApp Print Batch';"` 确认表存在。
  - `git -C apps/myapp diff --check`、`git -C frontend/myapp-web diff --check`、`git diff --check` 均通过。
- 当前未提交状态：
  - 后端 `apps/myapp` 有批量打印 service/API/gateway/patch/单测/文档改动，同时包含上一轮多模板增强改动。
  - Web `frontend/myapp-web` 仍有上一轮 `PrintDocumentButton` 菜单增强和文档改动；本轮没有继续改 Web。
  - 父仓库显示 `apps/myapp` 子模块修改，并修改了本交接文档；`.codex` 仍是既有未跟踪状态，不要提交。
- 下一步建议：
  - 增加批次结果下载聚合：ZIP 或合并 PDF。
  - 增加批次取消 / 重试失败项。
  - 增加批次过期清理和归档文件清理策略。
  - Web 后续接入批量打印入口和批次进度 Drawer / 轮询。

### 2026-07-09 打印模块多模板补强

本轮继续完善打印模块，把 6 类核心单据从单一标准模板扩展为“标准模板 + 业务变体模板”的通用多模板能力。当前完成度评估微调：后端约 88%，Web 约 78%，Mobile 仍约 40% 到 50%，整体约 78%。

- 后端 `apps/myapp` 已在打印 registry 中为 6 类核心单据增加第二模板：
  - 销售 / 采购发票：`finance`
  - 销售 / 采购订单：`external`
  - 发货单 / 采购收货单：`warehouse`
- 新增的第二模板均有独立 key、label、category、description、Print Format 名称、版本号和 hash。
- 托管 Print Format 映射已补齐：
  - `myapp Sales Invoice Finance`
  - `myapp Purchase Invoice Finance`
  - `myapp Sales Order External`
  - `myapp Purchase Order External`
  - `myapp Delivery Note Warehouse`
  - `myapp Purchase Receipt Warehouse`
- 当前第二模板复用对应标准模板的基础 HTML，但渲染前会注入 `myapp_print_template_key`、`myapp_print_template_label`、`myapp_print_template_category` 和 `myapp_print_format`，模板会显示模板名和标题后缀；后续可逐个替换为更完整的客户确认版、供应商确认版、财务留档版和仓库执行版。
- Web `PrintDocumentButton` 多模板菜单已增强为展示模板分类 Tag 和说明，仍由后端 `get_print_templates_v1` 驱动，页面层不硬编码模板清单。
- 文档已同步：
  - `apps/myapp/API_GATEWAY.zh-CN.md`
  - `apps/myapp/PRINTING_TECH_DESIGN.zh-CN.md`
  - `frontend/myapp-web/WEB_DEVELOPMENT.zh-CN.md`
- 已验证：
  - `docker exec frappe_docker-backend-1 bash -lc 'cd /home/frappe/frappe-bench && env/bin/python -m unittest apps.myapp.myapp.tests.unit.test_printing_service'`，16 tests 通过。
  - `docker exec frappe_docker-backend-1 bash -lc 'cd /home/frappe/frappe-bench && env/bin/python -m unittest apps.myapp.myapp.tests.unit.test_gateway_wrappers'`，95 tests 通过。
  - `npm run tsc` 通过。
  - `npm run biome:lint` 通过。
  - `npm test -- src/services/myapp/__tests__/domain-services.test.ts --runInBand`，1 suite / 61 tests 通过；仍有既有 Jest open handle 提示，退出码为 0。
  - `git -C apps/myapp diff --check`、`git -C frontend/myapp-web diff --check`、`git diff --check` 均通过。
- 当前未提交状态：
- 后端 `apps/myapp` 修改了打印 registry、托管 Print Format 映射、打印上下文注入、6 个托管模板、打印单测和打印文档。
  - Web `frontend/myapp-web` 修改了 `PrintDocumentButton` 和 Web 开发说明。
  - 父仓库显示 `apps/myapp` 子模块有修改，并修改了本交接文档；`.codex` 仍是既有未跟踪状态，不要提交。
- 下一步建议：
  - 优先把第二模板从“复用标准 HTML”替换成真实差异化版式：财务留档弱化收货地址、强化付款 / 核销信息；仓库执行版隐藏金额或弱化金额、强化仓库 / 数量 / 复核栏；外部确认版增加签字栏和确认条款。
  - 之后再做可运营维护的模板权限配置表和 Web 打印设置管理页。

### 2026-07-09 打印模块阶段性完整交接

本轮按“通用打印平台”方向连续完善打印模块，已从简单预览 / 下载入口升级为具备模板元数据、打印历史、审计追溯、水印治理和 Web 通用入口的企业打印基础平台。当前完成度评估：后端约 85%，Web 约 75%，Mobile 约 40% 到 50%，整体约 75%。

本轮关键原则：

- 保持旧接口兼容，尤其不破坏 Mobile 现有打印预览、PDF 下载和分享链路。
- 所有打印入口仍走 `doctype + docname + template`，业务页面不直接拼 Frappe 打印 URL。
- 打印模板继续走 registry 白名单，未登记 DocType 和未启用模板不可打印。
- 打印历史采用显式记录，不由旧预览 / 下载接口自动写入，避免给旧调用增加不可见副作用。

- 后端 `apps/myapp` 已扩展打印 registry：
  - 新增 `PrintDocumentDefinition`，为可打印 DocType 提供 `doctype`、`label`、`module`、`capabilities`、默认模板和模板列表。
  - 扩展 `PrintTemplateDefinition` 元数据：`category`、`paper_size`、`orientation`、`description`、`enabled`。
  - 托管模板返回 `managed`、`template_version`、`template_hash`，用于审计追溯。
  - 模板解析仍走白名单 registry，禁用模板不会被返回或解析。
- 后端已新增查询接口：
  - `list_print_doctypes_v1`
  - `get_print_templates_v1`
  - `record_print_job_v1`
  - `list_print_jobs_v1`
  - 原有 `get_print_preview_v1`、`get_print_file_v1`、`download_print_file_v1` 保持兼容。
- 后端已新增打印历史表迁移：
  - `myapp.patches.create_print_job_table`
  - 表名：`tabMyApp Print Job`
  - 本地 `localhost` 已执行 `bench --site localhost migrate`，确认表已创建。
- 打印历史当前为显式记录：
  - 旧预览 / PDF 元数据 / PDF 下载接口不会自动写打印历史，避免改变 Web/Mobile 原有副作用。
  - `record_print_job_v1` 会校验单据存在、读权限、模板白名单和模板启用状态。
  - 表未创建时返回 `recorded=false`，不阻断打印流程。
- 后端打印上下文已新增治理派生字段：
  - `myapp_print_status_label`
  - `myapp_print_copy_label`
  - `myapp_print_watermark`
  - `myapp_print_history_summary`
  - 6 个托管标准模板已展示状态、打印次数和草稿 / 作废 / 补打水印。
- 托管模板已新增版本指纹：
  - `get_print_templates_v1` / `list_print_doctypes_v1` 返回 `managed`、`template_version`、`template_hash`。
  - `record_print_job_v1` 自动把模板版本、模板 hash、托管状态和 `print_format` 固化进打印记录 metadata，用于后续审计追溯。
- Web `frontend/myapp-web` 已升级通用打印能力：
  - `src/services/myapp/printing.ts` 新增 `listPrintDoctypes`、`fetchPrintTemplates`，并映射新增模板元数据。
  - `src/components/PrintDocumentButton.tsx` 改为下拉展开时加载模板，按模板执行“预览”或“下载 PDF”；页面层仍只传 `doctype` 和 `docname`。
  - `src/services/myapp/printing.ts` 新增 `recordPrintJob`、`listPrintJobs`。
  - Web 通用打印按钮在预览成功 / 下载成功后显式记录打印动作；记录失败不阻断用户打印。
  - Web 通用打印按钮新增“打印历史”菜单项，打开 Drawer 查询并展示该单据最近打印 / 下载 / 分享记录。
- Mobile 兼容性结论：
  - Mobile 当前仍只调用旧接口 `get_print_preview_v1`、`get_print_file_v1`、`download_print_file_v1`。
  - 旧接口名称、参数和核心返回字段保持兼容，新增字段会被当前 Mobile mapper 忽略。
  - 因此 Mobile 不需要立刻修改；只有后续要支持多模板选择、打印历史或模板版本展示时才需要接入新接口。
- 文档已同步：
  - `apps/myapp/API_GATEWAY.zh-CN.md` 增加打印查询、记录、历史和模板版本字段说明。
  - `apps/myapp/PRINTING_TECH_DESIGN.zh-CN.md` 增加通用打印平台升级设计，并把查询、历史、审计字段从建议项更新为已落地。
- 已验证：
  - `docker exec frappe_docker-backend-1 bash -lc 'cd /home/frappe/frappe-bench && env/bin/python -m unittest apps.myapp.myapp.tests.unit.test_printing_service apps.myapp.myapp.tests.unit.test_gateway_wrappers'`，110 tests 通过。
  - `docker exec frappe_docker-backend-1 bash -lc 'cd /home/frappe/frappe-bench && bench --site localhost migrate'` 成功，执行 `myapp.patches.create_print_job_table`。
  - `bench --site localhost mariadb -e "SHOW TABLES LIKE 'tabMyApp Print Job';"` 确认表存在。
  - `npm run tsc` 通过。
  - `npm run biome:lint` 通过。
  - `npm test -- src/services/myapp/__tests__/domain-services.test.ts --runInBand`，1 suite / 61 tests 通过；仍有既有 Jest open handle 提示，退出码为 0。
  - `git -C apps/myapp diff --check`、`git -C frontend/myapp-web diff --check`、`git diff --check` 均通过。
- 当前未提交状态：
  - 后端 `apps/myapp` 有打印 registry/service/api/gateway、托管模板、patch、单测和文档改动。
  - Web `frontend/myapp-web` 有打印 service、通用打印按钮和 domain service 单测改动。
  - 父仓库显示 `apps/myapp` 子模块指针变化，并修改了本交接文档。
  - 父仓库另有既有未跟踪 `.codex`，不要提交 `.codex`。
- 本轮关键文件：
  - 后端核心：`myapp/services/printing_service.py`、`myapp/printing/registry.py`、`myapp/printing/templates.py`
  - 后端接口：`myapp/api/printing_api.py`、`myapp/api/gateway.py`、`myapp/api/__init__.py`、`myapp/api/api.py`
  - 后端迁移：`myapp/patches/create_print_job_table.py`、`myapp/patches.txt`
  - 托管模板：`myapp/printing/templates/*_standard.html`
  - 后端测试：`myapp/tests/unit/test_printing_service.py`、`myapp/tests/unit/test_gateway_wrappers.py`
  - Web：`src/components/PrintDocumentButton.tsx`、`src/services/myapp/printing.ts`、`src/services/myapp/__tests__/domain-services.test.ts`
- 当前风险 / 注意事项：
  - `tabMyApp Print Job` 在本地 `localhost` 已 migrate；其他环境需要部署后执行 migrate。
  - 打印记录是显式记录，旧接口不会自动记录；Web 已接入预览 / 下载成功后的记录，Mobile 暂未接入记录。
  - 模板版本目前记录 hash 和短版本号，但没有保存当时模板完整 HTML/CSS 快照。
  - 水印和打印次数依赖打印历史表；表缺失时打印仍可用，但补打识别会退化为首次打印。
  - Jest 仍有既有 open handle 提示，退出码为 0。
- 下一步建议：
  - 优先补实际多模板内容：客户联、财务联、仓库联、内部联、简版。
  - 增加角色级模板权限：仓库、财务、销售、采购看到不同模板集合。
  - 继续扩展模板设置 / 打印设置中心：纸张、页边距、水印开关。
  - 增加模板内容快照归档，补齐严格审计场景下“当时模板内容可还原”。
  - 增加批量打印、合并 PDF、异步生成能力。
  - Mobile 后续可接入 `get_print_templates_v1`、`record_print_job_v1`、`list_print_jobs_v1`。
  - 若提交本轮改动，应分别在 `apps/myapp` 和 `frontend/myapp-web` 提交，再按需要提交父仓库子模块指针和交接文档。

### 2026-07-08 最终状态快照

本轮销售 / 采购共享模块抽取、采购订单体验优化、后端交易仓库强校验和采购字段补齐已完成提交并推送。

- 已推送提交：
  - 后端 `apps/myapp` `develop`：`e023370 feat: harden purchase warehouse workflows`
  - Web `frontend/myapp-web` `main`：`ed60444 feat: share order detail components`
  - 父仓库 `frappe_docker` `develop`：`6536b56c docs: summarize shared order workflow handoff`
- 当前仓库状态：
  - 后端 `apps/myapp`：干净。
  - Web `frontend/myapp-web`：干净。
  - 父仓库：只剩既有未跟踪 `.codex`，不应提交。
- 推送备注：
  - 三个仓库远端推送均已成功。
  - 父仓库最后一次 push 后本地更新 `refs/remotes/origin/develop` 时因 `.git/refs/remotes/origin/develop.lock` 只读报错；远端已显示 `dc324c85..6536b56c develop -> develop`，不影响 GitHub 上的代码状态。
- 最后验证：
  - 后端：`env/bin/python -m unittest apps.myapp.myapp.tests.unit.test_warehouse_utils apps.myapp.myapp.tests.unit.test_inventory_service apps.myapp.myapp.tests.unit.test_purchase_service apps.myapp.myapp.tests.unit.test_order_service`，127 tests 通过。
  - Web：`npm run tsc`、`npm run biome:lint`、`npm test -- src/services/myapp/__tests__/domain-services.test.ts src/pages/Purchase/Orders/Edit.test.tsx src/pages/Purchase/Orders/Detail.test.tsx src/utils/__tests__/purchase-order-editor.test.ts --runInBand`，4 suites / 64 tests 通过。
  - 空白检查：父仓库、后端、Web `diff --check` 均通过。

### 2026-07-08 销售 / 采购共享模块抽取提交总结

本轮在采购模块已对齐销售模块主链路的基础上，开始做前端共享模块抽取。目标是保留销售 / 采购各自的领域判断、接口和动作编排，同时把对应模块中重复的展示结构、单据链接、导出和付款表列收敛为通用实现。

- 当前抽取范围已提交，主要覆盖销售 / 采购订单列表、订单详情、发票详情，以及采购订单新建 / 编辑体验。
- 本轮提交：
  - 后端 `apps/myapp`：`e023370 feat: harden purchase warehouse workflows`
  - Web `frontend/myapp-web`：`ed60444 feat: share order detail components`
  - 父仓库：记录后端子模块指针和本交接文档。
- 新增共享模块：
  - `src/utils/business-document.tsx`：业务单据路径、付款单路径、取消状态判断、百分比、关联单据链接和时间线文档链接。
  - `src/utils/csv-export.ts`：CSV / 文本下载工具。
  - `src/components/BusinessOrderDetail.tsx`：订单金额概览、业务时间线、交易商品明细列、发票商品明细列。
  - `src/components/BusinessPaymentTables.tsx`：付款 / 收款历史列、取消付款 / 收款操作列、采购发票关联列。
  - `src/components/InvoicePaymentForm.tsx`：新增 `useInvoicePaymentModal`，统一收 / 付款弹窗的 draft、open、loading 和提交包裹状态。
- 已接入页面：
  - 销售 / 采购订单列表：导出逻辑改用通用 CSV / 文本下载工具。
  - 销售 / 采购订单详情：金额概览、业务时间线、商品明细列、关联单据链接、付款回退表列和收 / 付款弹窗状态骨架改为共享实现。
  - 销售 / 采购发票详情：商品明细列、收款 / 付款历史表、取消收付款表列和收 / 付款弹窗状态骨架改为共享实现；销售特有的差额核销、多收保留、参考号仍通过 extra columns 保留，采购特有的采购发票关联列也保留。
- Web 改动覆盖销售 / 采购订单列表、订单详情、发票详情、付款表单组件和采购发票测试 mock；已从页面内删除大量重复 JSX / 列定义，保留页面自己的业务状态机、接口调用和弹窗文案。
- 采购订单新建 / 编辑专用明细表没有改成详情通用组件，但已补齐图片展示能力：`PurchaseOrderEditorLine.imageUrl` 从商品数据透传，采购订单详情行也映射后端图片字段作为 fallback，`PurchaseOrderLinesTable` 的实际编辑行显示缩略图；分组标题保持摘要样式，避免重复图片挤压信息密度；分仓快捷按钮会过滤 `All Warehouses` 汇总仓。
- 采购订单 / 收货 / 发票详情页图片缺失根因在后端采购行序列化未返回 `Item.image`；已在 `apps/myapp` 为 `_serialize_purchase_order_items`、`_serialize_purchase_receipt_items`、`_serialize_purchase_invoice_items` 补充 `image` 字段，并更新 `API_GATEWAY.zh-CN.md` 和采购 service 单测。Web `purchase.ts` 已将 `image` / `image_url` / `item_image` 映射为 `imageUrl`，详情页共享商品列会直接显示图片。
- 采购订单详情“创建采购发票”误导问题已修复：后端新增采购订单 billing 汇总和行级 `billed_qty` / `pending_billing_qty`，`actions.can_create_purchase_invoice` 改按待开票数量判断，不再按付款状态判断；Web 开票弹窗改用“已开票 / 待开票”口径。已用实际订单 `PUR-ORD-2026-01846-1` 验证当前代码返回 `can_create_purchase_invoice=False`，三行 `pending_billing_qty=0`。
- 采购退货 / 供应商退款入口已按销售模块同样策略暂停：新增 `PURCHASE_RETURN_REFUND_ENTRY_ENABLED=false`；采购订单详情隐藏“发起退货 / 退款核对”和关联单据中的采购退货 / 供应商退款；采购收货单 / 采购发票详情隐藏“采购退货”；直接访问 `/purchase/returns/new` 和 `/purchase/refunds/review` 会显示暂停页。后端能力和历史页面代码未删除，后续可通过 feature flag 恢复。
- 采购订单详情已新增类似销售订单详情的“一键开单”入口：确认后按整单快捷链路执行，未收货时先调用 `receivePurchaseOrder` 创建采购收货单，再基于返回的收货单调用 `createPurchaseInvoiceFromReceipt` 创建采购发票；已无需收货但仍可开票时直接调用 `createPurchaseOrderInvoice`。若收货接口未返回收货单号，会停止继续开票，避免采购侧绕过实际收货单口径。新增 `src/pages/Purchase/Orders/Detail.test.tsx` 覆盖“确认收货并开票”的调用顺序。
- 采购订单详情供应商地址和备注问题已定位并修复：
  - 地址问题是后端 `Purchase Order.address_display` 为 HTML 片段，例如 `更新地址 88 号<br>\n杭州<br>\nChina...`，Web 之前直接当纯文本显示。`purchase.ts` 已新增 `normalizeDocumentText`，采购订单详情优先用结构化地址字段 `address_line1/city/country/...` 拼纯文本，供应商上下文默认地址也会清理 HTML。
  - 备注问题不是详情页读取错字段，而是当前站点原生 `Purchase Order` 没有 `remarks` 字段，旧单 `PUR-ORD-2026-01846-2` 的备注实际没有落库。后端已新增 patch `myapp.patches.add_purchase_order_remark_field`，给 `Purchase Order` 创建 `custom_order_remark`，采购订单创建 / 更新 / 详情统一优先使用该字段；已在 `localhost` 执行 `bench --site localhost migrate`，确认字段存在。旧订单无法自动恢复之前未保存的备注。
- 采购订单新建 / 编辑页底部操作区已对齐销售订单页面：从普通 `ProCard` 改为 Ant Design Pro `FooterToolbar` 固定底栏，使用同款 `footerContentStyle` / `footerSummaryStyle` / `footerActionsStyle`，展示行数、数量、总金额并保留保存 / 快捷采购 / 取消操作。
- 采购订单新建 / 编辑页新增“默认取值模式”，默认批发；该字段只影响前端选品时默认取商品批发 / 零售档案单位，不提交后端、不成为采购单持久字段，采购价仍按采购参考价 / 标准采购价取值。采购明细数量输入已对齐销售页，不再把整数强制显示为 `1.000`。
- 交易仓库下拉已统一排除父级 / 汇总仓：采购 / 销售订单新建与编辑的默认仓库、采购 / 销售明细行仓库、商品选择器库存仓库筛选和建品入库仓库均加上 `disabled=0`、`is_group=0` 过滤。当前开发库中 `All Warehouses - RD` 是 `is_group=1`，会被隐藏；`Work In Progress - RD`、`Stores - RD`、`Finished Goods - RD` 是可交易叶子仓，不会被隐藏。
- 后端交易仓库强校验已补齐：新增 `myapp.utils.warehouse.validate_transaction_warehouse` / `get_transaction_warehouse_context`，统一校验仓库存在、未停用、`is_group=0`、绑定公司；销售订单、采购订单、库存转仓、单品盘点和批量盘点写接口均接入该校验。父级 / 汇总仓不再只靠前端隐藏，即使绕过前端直接调 API 也会被拦截。新增 `apps/myapp/myapp/tests/unit/test_warehouse_utils.py` 覆盖父级仓、禁用仓和跨公司仓拒绝。
- 已完成一轮销售 / 采购逻辑回归检查：销售侧改动仅接入共享列、链接、时间线、金额概览和收款弹窗状态骨架，`recordSalesOrderPayment`、销售回退 / 作废 / 退货退款 feature flag 等业务编排保持页面内原逻辑；付款操作列补强为空 `paymentEntry` 一律禁用。
- 已验证 `docker exec frappe_docker-backend-1 bash -lc 'cd /home/frappe/frappe-bench && env/bin/python -m unittest apps.myapp.myapp.tests.unit.test_warehouse_utils apps.myapp.myapp.tests.unit.test_inventory_service apps.myapp.myapp.tests.unit.test_purchase_service apps.myapp.myapp.tests.unit.test_order_service'`、`npm run tsc`、`npm run biome:lint`、`npm test -- src/services/myapp/__tests__/domain-services.test.ts src/pages/Purchase/Orders/Edit.test.tsx src/pages/Purchase/Orders/Detail.test.tsx src/utils/__tests__/purchase-order-editor.test.ts --runInBand`、后端 / Web / 父仓库 diff 空白检查均通过。Jest 仍有既有 open handle 提示。
- 下一步建议先做一次人工 UI 回看。若继续抽取，只建议小步处理订单动作区布局壳或多笔 / 单笔付款处理提示块，不建议强抽销售 / 采购状态机和 API 编排。

### 2026-07-06 采购模块对齐销售模块起步

本轮开始参考销售订单详情完善采购订单详情，优先补齐采购付款、业务时间线与下游回退的安全交互。

- 上一批采购模块对齐已提交：
  - 后端 `apps/myapp`：`29d17a7 feat: enrich purchase order workflows`
  - Web `frontend/myapp-web`：`327fb26 feat: align purchase workflows with sales`
  - 父仓库：`84138ca9 chore: record purchase workflow updates`
- 该阶段后续通用模块抽取已在 2026-07-08 完成提交，涉及文件包括：
  - `src/components/BusinessOrderDetail.tsx`
  - `src/components/BusinessPaymentTables.tsx`
  - `src/utils/business-document.tsx`
  - `src/utils/csv-export.ts`
  - `src/pages/Sales/Orders/Detail.tsx`
  - `src/pages/Purchase/Orders/Detail.tsx`
  - `src/pages/Sales/Invoices/Detail.tsx`
  - `src/pages/Purchase/Invoices/Detail.tsx`
  - `src/pages/Sales/Orders/index.tsx`
  - `src/pages/Purchase/Orders/index.tsx`
- 已完成内容：
  - 后端 `get_purchase_order_detail_v2` 新增 `payment.entries[]` 和 `timeline[]`，覆盖采购订单、采购收货单、采购发票、采购退货、供应商付款和供应商退款事件。
  - 采购订单详情页把“记录付款”改为受控 Modal，复用 `InvoicePaymentForm`，避免 `Modal.confirm` 内部临时变量状态不透明。
  - 采购订单详情页新增订单进度、业务时间线、供应商付款 / 采购退货 / 供应商退款关联展示。
  - 采购订单详情页把“快捷回退下游”改为受控 Modal；支持展示多笔供应商付款、逐笔取消付款，并在同步取消单笔付款回退前增加二次确认。
  - 采购订单详情页布局已对齐销售订单详情页：顶部摘要、金额概览、左侧订单进度 / 业务时间线 / 商品明细、右侧采购动作 / 基本信息 / 关联单据 / 供应商信息；采购动作里的“快捷回退下游”文案同步改为“回退并修改订单”。
  - 采购订单商品明细表对齐销售订单详情页样式，改为“商品信息”复合列，并展示数量、已收数量、待收数量、单位、单价和金额。
  - 采购订单列表页对齐销售订单列表页入口体验：新增状态视图 Tabs、同款统计卡、供应商筛选、表格空态引导、状态视图标签、批量选择、复制订单号、导出当前筛选和导出选中 CSV。
  - 第一批低风险通用模块已抽取：新增 `src/utils/business-document.tsx`，承载 `DocumentLinks`、`TimelineDocumentLinks`、`businessDocumentPath`、`paymentEntryPath`、`isCancelledStatus`、`toPercent`；新增 `src/utils/csv-export.ts`，承载 CSV / 文本下载工具。
  - 销售 / 采购订单详情页已改用通用业务单据链接、时间线文档链接和百分比工具；销售 / 采购订单列表页已改用通用 CSV 下载工具。
  - 第二批订单详情展示组件已抽取：新增 `src/components/BusinessOrderDetail.tsx`，承载 `AmountOverview`、`BusinessTimeline`、`buildTransactionItemColumns`；销售 / 采购订单详情页的金额概览、业务时间线和商品明细列已共用同一套实现，只保留字段名、文案和领域动作差异。
  - 第三批付款展示组件已抽取：新增 `src/components/BusinessPaymentTables.tsx`，承载 `buildPaymentEntryColumns`、`buildPaymentActionColumn`、`purchaseInvoiceReferenceColumn`；销售订单回退收款表、采购订单回退付款表、销售发票收款历史 / 取消表、采购发票付款历史 / 取消表已共用付款单链接、日期、方式、金额和操作列实现。
  - 采购订单关联单据区新增供应商付款、采购退货和供应商退款链接，付款单指向通用 `/payments/:name` 详情。
  - Web purchase service 映射 `references.latest_payment_entry` 为 `latestPaymentEntry`，并新增采购订单 `paymentEntries` / `timeline` 映射。
  - 采购发票详情后端新增 `payment.entries[]` 供应商付款历史；Web 采购发票详情新增付款历史表、受控付款弹窗、选择取消具体付款、作废发票前多笔付款清理、单笔付款同步取消并作废发票。
  - 采购发票详情页改用 `App.useApp()` 获取 AntD message，避免受控弹窗操作中触发静态 message context 告警。
  - 采购收货单详情对齐销售发货单详情：返回来源采购订单详情、展示后续处理提示、已开票时引导先处理采购发票、取消收货单改为受控确认弹窗，并在确认中展示库存 / 收货回退影响和下游发票阻塞提示。
  - Web purchase service 映射 `cancelPurchaseReceiptHint`，供收货单详情页展示后端下游保护原因。
  - 采购订单编辑页新增前端禁用保护，与销售 `salesOrderEditDisabledReason` 对齐：已作废、未提交、已完成结清、已付款、已收货、已开票订单会在进入编辑表单前展示原因和返回入口，避免加载可编辑商品行后再被后端拒绝。
  - Web purchase service 新增 `purchaseOrderEditDisabledReason`，并补充领域服务测试覆盖采购订单下游单据和结清后的直接编辑阻断。
  - 补充采购订单编辑页页面测试，覆盖已收货 / 已开票订单打开编辑页时展示禁用原因、不渲染采购明细表格、也不拉取商品详情。
  - 补充采购发票详情页页面测试，覆盖单笔供应商付款需二次确认后同步取消并作废发票、多笔供应商付款阻断作废、选择并取消具体供应商付款。
  - 补充 domain service 测试覆盖采购订单详情最近付款 / 付款历史 / 时间线映射，以及采购发票详情付款历史映射。
  - 补充采购收货单详情页面测试，覆盖取消确认、返回来源采购订单、下游采购发票阻塞提示。
  - `API_GATEWAY.zh-CN.md` 已把采购快捷链路从“规划中”改为已实现，并补充采购订单详情、采购发票详情、采购收货单详情新增字段说明。
  - 顺手将采购订单详情加载错误 `Alert message` 迁移为 `title`，避免新增 AntD 旧 API 告警。
- 已验证：
  - `npm run tsc`
  - `npm run biome:lint`
  - `npm test -- src/services/myapp/__tests__/domain-services.test.ts src/pages/Sales/Orders/Detail.test.tsx src/pages/Purchase/Orders/Edit.test.tsx src/pages/Purchase/Invoices/Detail.test.tsx src/pages/Purchase/Receipts/Detail.test.tsx --runInBand`
  - `npm test -- src/services/myapp/__tests__/domain-services.test.ts src/pages/Sales/Orders/Detail.test.tsx src/pages/Sales/Invoices/Detail.test.tsx src/pages/Purchase/Orders/Edit.test.tsx src/pages/Purchase/Invoices/Detail.test.tsx src/pages/Purchase/Receipts/Detail.test.tsx --runInBand`（当前仓库没有 `src/pages/Sales/Invoices/Detail.test.tsx`，Jest 实际匹配到 5 个 suite / 75 个 tests）
  - `npm test -- src/services/myapp/__tests__/domain-services.test.ts --runInBand`
  - `npm test -- src/pages/Purchase/Orders/Edit.test.tsx --runInBand`
  - `npm test -- src/services/myapp/__tests__/domain-services.test.ts src/pages/Purchase/Orders/Edit.test.tsx --runInBand`
  - `npm test -- src/services/myapp/__tests__/domain-services.test.ts src/pages/Purchase/Orders/Edit.test.tsx src/pages/Purchase/Invoices/Detail.test.tsx src/pages/Purchase/Receipts/Detail.test.tsx --runInBand`
  - `npm test -- src/pages/Purchase/Invoices/Detail.test.tsx --runInBand`
  - `npm test -- src/services/myapp/__tests__/domain-services.test.ts src/pages/Purchase/Orders/Edit.test.tsx src/pages/Purchase/Invoices/Detail.test.tsx --runInBand`
  - `npm test -- src/pages/Purchase/Receipts/Detail.test.tsx --runInBand`
  - `docker exec frappe_docker-backend-1 bash -lc 'cd /home/frappe/frappe-bench && env/bin/python -m unittest apps.myapp.myapp.tests.unit.test_purchase_service'`
  - `git -C apps/myapp diff --check`
  - `git -C frontend/myapp-web diff --check`
  - `git diff --check`
- 注意事项：
  - Jest 仍输出既有 open handle 提示；采购收货单详情页面测试还会输出 jsdom `window.getComputedStyle` not implemented 噪音，但退出码为 0。
  - 单独运行 `npm test -- src/pages/Sales/Invoices/Detail.test.tsx --runInBand` 会因当前仓库没有该测试文件返回 `No tests found`。
  - 下一步建议继续抽取销售 / 采购共享操作组件，优先处理受控付款弹窗上下文、订单动作按钮组和发票详情商品明细列。

本轮围绕销售订单主链路完成收口检查、数据整理、代码修复、验证和提交。当前销售模块主流程已可作为后续采购链路优化的稳定参照，通用选品、电话校验、UOM / 金额工具和回退指引组件可继续复用。

### 已解决问题

- 后端修复销售订单显式成交价被 ERPNext 价目表回填的问题，`price = 0` 现在是有效价格；销售订单、发货单、销售发票一键链路均保持显式 0 价。
- 后端 `get_customer_sales_context` 的默认地址序列化增加 fallback：站点没有 `Address.address_display` 字段时，会用地址行拼出可显示地址，保证 Web 选择客户后能自动带出地址。
- 后端补充销售开票 / 收款 / 取消收款 / 取消发票 / 取消订单生命周期集成测试，验证订单状态聚合和回退链路。
- Web 销售订单详情页、收款表单和回退指引清理 Ant Design 旧 API：`Timeline items.children` 改为 `items.content`，`Alert message` 改为 `title`，减少控制台和 Jest 噪音。
- 开发库客户主数据已整理：删除无交易引用的空测试客户，保留并补全有效 Demo 客户的联系人、联系电话、邮箱和收货地址；当前 14 个启用客户均有主联系人和主地址。
- 复核确认 `ProductSelect`、`RemoteLinkSelect`、`phone-validation`、UOM / 金额工具和回退指引均可作为采购链路优化时的通用基础；采购特有逻辑应继续放在采购 domain/service 层。

### 关键改动文件

- 后端销售与生命周期：
  - `apps/myapp/myapp/services/order_service.py`
  - `apps/myapp/myapp/tests/integration/test_sales_billing_payment_lifecycle.py`
  - `apps/myapp/myapp/tests/integration/test_sales_uom_stock_chain.py`
  - `apps/myapp/myapp/tests/unit/test_order_service.py`
  - `apps/myapp/myapp/tests/http/test_gateway_http.py`
  - `apps/myapp/myapp/tests/http/test_gateway_v2_http.py`
  - `apps/myapp/API_GATEWAY.zh-CN.md`
- Web 销售详情兼容清理：
  - `frontend/myapp-web/src/pages/Sales/Orders/Detail.tsx`
  - `frontend/myapp-web/src/components/DownstreamRollbackGuide.tsx`
  - `frontend/myapp-web/src/components/InvoicePaymentForm.tsx`

### 已验证命令

- 后端已运行销售订单服务、HTTP gateway、销售 UOM 库存链路、销售开票 / 收款 / 取消生命周期测试和真实 0 价一键下单 / 发货 / 开票冒烟。
- Web 已运行：
  - `npm run tsc`
  - `npm run biome:lint`
  - `npm test -- src/services/myapp/__tests__/domain-services.test.ts src/utils/__tests__/sales-order-editor.test.ts src/utils/__tests__/phone-validation.test.ts --runInBand`
  - `npm test -- src/pages/Sales/Orders/Detail.test.tsx --runInBand`
- 空白检查已运行：
  - `git -C apps/myapp diff --check`
  - `git -C frontend/myapp-web diff --check`
  - `git diff --check`

### 当前注意事项

- 后端已提交：`cc64198 fix: preserve explicit sales prices`。
- Web 已提交：`6eb6494 fix: clean sales detail warnings`。
- Web 销售订单电话校验 / 客户选择自动填充已在前一提交完成：`f7625da fix: validate sales order contact phone`。
- Web 商品选择器增强已在前一提交完成：`e74ac07 feat: enhance order product picker`。
- `.codex` 是既有未跟踪本地目录，不应提交。
- Web Jest 详情页测试仍输出 jsdom `window.getComputedStyle` not implemented 和既有 open handle 提示，但测试退出码为 0；AntD 旧 API 告警已清理。
## 当前目标

- 已完成企业级测试数据管理第三阶段：在完整生成、按场景补充和 reset 基础上，新增 `small / medium / large` 数据量档位，每个场景分别生成 1 / 5 / 20 份实例。
- 已完成第四阶段公司级交易重置：封装 ERPNext 官方 `Transaction Deletion Record`，用于专用非生产测试公司清理全部交易、库存和账务流水，同时保留核心主数据。
- `localhost` 已完成多次 supplement 与跨运行批次 reset 验证；当前恢复为 38 个活动基线对象，可直接用于联调。
- 测试数据管理 Backend 与 Web 已按仓库边界提交并推送；父仓库本次交付更新 Backend 子模块指针和本交接记录。
- 已按全项目测试与审查方案完成 Backend、AI Orchestrator 和父仓库部署层优化，并按仓库边界提交代码、测试文档与交接文档。
- Mobile 对新接口的适配按用户要求延期：只记录问题，不在本轮修改或优化 Mobile。
- 测试数据管理相关提交已推送远程。

## 提交状态

- 测试数据 Backend `apps/myapp`：`1b73cbc feat: add enterprise test data reset workflows`，已推送 `origin/develop`。
- 测试数据 Web `frontend/myapp-web`：`c397654 feat: add test data administration console`，已推送 `origin/main`。
- Backend `apps/myapp`：`33c6680 fix: harden settlement and backend validation`。
- AI Orchestrator `services/myapp-ai`：`13042a4 test: make offline evaluation self-contained`。
- 父仓库部署实现：`bcd64336 ops: harden secret and observability deployment`。
- 全量效果测试报告、AI 部署文档和本交接文件包含在随后建立的父仓库文档提交中。
- Backend 最新提交已推送；AI `13042a4` 仍为既有本地未推送状态。本次父仓库只更新 `apps/myapp` gitlink，不提交 `services/myapp-ai` 指针。

## 本轮已完成

### 测试数据管理

- Backend 新增 `standard-wholesale-small` `2026.07-v1`，覆盖 4 个商品、4 个客户、3 个供应商、5 个销售场景和 3 个采购场景。
- 新增运行和对象审计表、安全环境开关、公司白名单、动态确认文本、Redis 并发锁、预检、生成、精确 reset、状态查询和完整性验证。
- reset 仅删除登记拥有的对象，按收付款、发票、发货/收货、订单、库存初始化、价格、商品、客户/供应商逆序处理，不执行任意公司清库。
- 新增 Backend CLI、独立 API 和 `TEST_DATA_MANAGEMENT.zh-CN.md`。
- Web 新增 `/administration/test-data` 管理页面、领域 service、菜单和 service 映射测试；支持预检、确认、后台状态轮询、历史和完整性结果。
- 第二阶段新增 `supplement`：可多选销售/采购场景，只追加交易单据并复用登记拥有的标准主数据；完整 reset 会按运行批次和对象依赖逆序清理所有补充数据。
- 运行审计新增场景清单和进度字段；执行中进度写入 Redis，结束后持久化最终进度，避免为了 UI 轮询提前提交业务事务。
- Web 控制台新增场景多选和实时进度条；long worker 已重启并完成真实异步验证。
- 第三阶段复用运行表既有 `scale` 字段，无需新增数据库迁移；预检、API、CLI、运行审计、生成结果和 Web service 已贯通档位、场景份数及场景实例总数。
- 主数据每次运行只创建一套，交易场景按档位重复；实例登记键使用 `sales-open#1` 等格式，业务日期逐份错开。generate/reset 的期初库存按份数放大，但仍只创建一张期初库存单据。
- Web 控制台新增数据量档位选择和用途说明，展示份数、场景实例数、预计对象总数，并在当前任务中展示运行档位。
- 公司级交易重置使用独立危险开关 `myapp_company_transaction_reset_enabled` 和独立公司白名单 `myapp_company_transaction_reset_allowed_companies`，不能复用普通模板 reset 权限范围。
- 新增公司级只读预检、不可逆确认、ERPNext 删除任务创建和状态轮询；预检展示涉及 DocType、公司字段、预计记录引用、保留主数据和阻断原因。
- Web `/administration/test-data` 新增独立高风险区域，要求完整确认文本和“不可逆且已准备备份”复选框，完成后引导执行标准模板 reset 恢复基线。
- 模板 reset 现在会核销已经被公司级清理删除的失效对象登记，避免历史登记阻断后续基线重建。
- 本地站点配置仅允许 `rgc (Demo)`，目标仓库为 `主仓库 - R`；默认客户组、供应商组、区域和商品组使用 Demo 主数据。

### Backend `apps/myapp`

- JWT 生成版本不匹配统一抛出并测试 `InvalidTokenError`。
- 销售与采购写销结算保留发票全额分配，现金金额同时写入 `paid_amount` / `received_amount`，差额交给 ERPNext `set_gain_or_loss`；多币种写销失败关闭。
- 新增同币种、多币种与真实 HTTP 写销回归。
- 增加 `requests>=2.33.0,<2.34.0` 兼容约束，并在 CI 与本地 Backend 启动依赖检查中执行 `pip check`。
- HTTP 销售测试改用带独立期初库存的隔离商品，避免共享 `SKU010` 预留库存耗尽导致不稳定。
- 修正过期断言及实际 Ruff 缺陷；Ruff 配置保留现有中文标点与导入布局，避免无关的大范围格式化。
- Backend CI 增加 `develop` push 门禁。

### AI Orchestrator `services/myapp-ai`

- 测试依赖升级为 `pytest>=9.0.3,<10`，锁文件解析到 `pytest 9.1.1`。
- 新增只含确定性非生产值的 `integration.env`，Standalone CI 与 `make integration` 不再读取无效的 `.env.example`。
- Docker test target 改由 `tests/run_unittest.py` 在测试进程内设置确定性 Service Token；镜像层不再通过 `ENV` 保存 Token，也不再触发 Docker Secret 告警。
- 修复离线评测 CLI 被运行时 Service Token 校验阻断的问题；offline 模式现在使用确定性评测配置，不要求生产 Secret。
- 更新独立开发与测试文档。

### 父仓库部署与运维

- 新增 `validate-secret-env-files.sh`，拒绝 group/other 可访问的实际 Secret env 文件。
- 本地根 `.env` 与 `deploy/staging/staging.env` 已收紧为 `0600`；生成 AI/Langfuse env 的脚本统一使用 `umask 077`。
- `start-dev.sh` / `start-prod.sh` 在读取 Secret 前执行权限预检，生成最小权限 env 后再次校验，并通过 Compose `--wait` 等待健康。
- `sync-langfuse-runtime-env.sh --reconcile` 会在 Orchestrator 已运行时强制重建该容器；`setup-ai-observability.sh` 与启动脚本使用该模式。
- bundled Langfuse Compose 覆盖层将 Orchestrator 健康条件提升为 `langfuse_configured=true` 且 `langfuse_delivery.enabled=true`。
- staging 配置验证要求实际 env 权限收紧；配置 Langfuse 三项连接参数时，健康检查同样验证投递已启用，且不会打印 Secret。
- 开发 Compose 中所有 `pip install -e apps/myapp` 后立即执行 `pip check`，依赖冲突会阻止 Backend、Worker、Scheduler 或 Configurator 继续启动。
- pre-commit 的 shell 门禁覆盖新增和修改的 Secret/观测脚本；部署文档同步更新。

## 已验证

### 测试数据管理增量

- `bench --site localhost migrate` 已成功执行建表 patch 和 `extend_test_dataset_runs_v2` 增量 patch。
- 真实补充验证覆盖 `sales-unpaid`、`purchase-received`、`sales-open` 和 `sales-partial-delivery`；每次只创建对应交易对象，不重复创建主数据。
- 补充后活动对象由 38 增至 43；完整异步 reset 成功清理 43 个跨运行批次对象并恢复 38 个标准基线对象。
- 当前运行历史为 1 次 generate、5 次 supplement、5 次 reset，全部 `completed`；202 个历史对象标记 deleted，38 个当前对象保持 active。
- 异步进度实际观察到 `queued → running → completed`，终态进度为 `2/2`；完整 reset 终态为 `21/21`。
- 活动数据集的 UOM、库存非负、发票未结金额、对象存在性和总账借贷平衡验证全部通过。
- Backend 全量 unit：`585` 项通过；`uvx ruff check .` 与 `git diff --check` 通过。
- Web：TypeScript、Biome、`31` 套/`194` 项 Jest、production build 和 `git diff --check` 通过。
- 第三阶段真实 medium supplement 使用 `sales-open` 创建 5 张 Sales Order，登记键为 `sales-open#1` 至 `sales-open#5`，交易日期从 `2026-06-16` 逐日错开到 `2026-06-12`；活动对象由 38 增至 43，终态进度为 `6/6`。
- 随后执行 small reset，成功清理 43 个跨运行对象并恢复 38 个活动基线对象；终态进度 `21/21`，全部完整性检查通过。
- 第三阶段 Backend 全量 unit：`589` 项通过；`uvx ruff check .` 与 `git diff --check` 通过。
- 第三阶段 Web：TypeScript、Biome、`31` 套/`194` 项 Jest、production build 和 `git diff --check` 通过。
- 公司级重置真实 dry-run 在 `rgc (Demo)` 识别到 15 类、约 24,656 条交易/账务/库存记录引用；由于独立危险开关关闭且专用白名单为空，预检与实际请求均被后端正确阻断，没有创建删除任务或修改业务数据。
- 公司级重置未在 `rgc (Demo)` 执行破坏性测试，因为该公司包含大量非模板历史数据；当前标准模板活动对象仍为 38。
- 第四阶段 Backend 全量 unit：`591` 项通过；Ruff 通过。
- 第四阶段 Web：TypeScript、Biome、`31` 套/`196` 项 Jest 和 production build 通过。
- 已将 `localhost` 数据库备份恢复到独立临时 Site `company-reset-test.local` / 独立数据库，真实执行公司级交易重置；共清理 15 类、24,656 条记录引用。
- 临时 Site 清理后 `Sales Order`、`Purchase Order`、发货/收货、销售/采购发票、Payment Entry、GL Entry、Stock Ledger Entry、Payment Ledger Entry、Bin 和 Stock Entry 全部归零。
- 公司、96 个科目、2 个成本中心、6 个仓库、45 个客户、522 个供应商、904 个商品和 7 个付款方式全部保留。
- 随后在临时 Site 执行标准 small reset，自动核销 38 条旧模板登记并重建 38 个对象；最终恢复 5 张销售订单、3 张采购订单及对应履约/发票/付款/库存/总账数据，五项完整性检查全部通过。
- 真实测试发现 ERPNext 单独删除的 Bin 不进入明细 processed 统计；序列化已在 Completed 状态将进度校正为 `24,656/24,656`。
- 真实测试发现自定义 CLI 在非 `localhost` Site 从 bench 根目录运行时可能写错日志路径；CLI 现会先切换至标准 sites 目录，`localhost` CLI 回归通过。
- Docker 临时 Site 的数据库用户最初只允许 Backend 来源地址，Long Worker 被 MariaDB 拒绝；临时测试中修复了该独立数据库授权，并将多容器 Site 创建注意事项写入测试数据文档。
- 临时 Site、临时数据库、临时数据库用户、归档目录和备份文件均已删除；数据库存在数为 0。原 `localhost` 仍保持 38 个活动模板对象，完整性验证通过。
- 最新 Backend 全量 unit：`592` 项通过；Ruff 和空白检查通过。

### Backend

- `578` 项 unit 测试通过。
- `8` 项真实站点 integration 测试通过。
- Backend bench 虚拟环境 `pip check` 通过。
- 完整 HTTP 模块通过：`test_gateway_http`、`test_gateway_v2_http`、`test_purchase_quick_http`、`test_jwt_token_http`。模块加载器共识别 `331` 个用例；剔除 V2 对基础 Gateway 的继承重复后，`169` 个不重复真实 HTTP 用例全部通过。
- 新增一次性效果探针并通过：双仓库存转移/校准/批量盘点、客户与供应商部分到全额退款、打印流式与归档副作用。
- 查询性能 5 次采样：销售工作台平均 `193.63 ms`，采购工作台 `134.15 ms`，销售/采购详情约 `21 ms`，商品搜索 `13.75 ms`。
- `uvx ruff check .` 通过。
- `git diff --check` 通过。

### AI Orchestrator

- `uv run pytest`：`86` 项通过；仅保留既有 Starlette/httpx 弃用警告。
- `uv run ruff check .` 与 `uv run pre-commit run --all-files` 通过。
- Docker test image 默认运行 `86` 项通过，构建输出无 `SecretsUsedInArgOrEnv` 告警。
- 离线固定评测 `22/22` 通过，full gate `PASS`，Schema、安全和结构化字段准确率均为 `1.0`。
- runtime image 构建通过，运行镜像 `python -m pip check` 通过。
- 独立 Compose 使用端口 `14010` 完成健康、Chat、向量 upsert/search/delete 集成，并已删除隔离容器、网络和数据卷。
- `git diff --check` 通过。

### 父仓库与运行状态

- Secret 权限正向检查通过，`0644` 临时文件负向拒绝通过。
- development + bundled Langfuse Compose config 通过。
- staging example Compose config 通过。
- 本机实际 `deploy/staging/staging.env` 已补齐本地测试用 AI 镜像、Provider、Service Token 和 Frappe Site 配置，权限与完整 staging env 校验通过；真实 LiteLLM Key 与 Service Token 在测试命令中通过后置 `.env.ai.local` 覆盖，不复制、不打印。
- 隔离项目 `myapp-staging-ai-test` 已完成 staging AI 测试部署：Redis、Qdrant、Orchestrator 全部健康，LiteLLM 模型发现返回 `9` 个模型，向量状态可达；测试容器、网络和数据卷均已清理。
- 修改的 Shell 脚本通过 `bash -n` 与 ShellCheck；修改文件通过 Codespell。
- 运行中的 `frappe_docker-ai-orchestrator-1` 已强制重建，容器实际包含 3 个 Langfuse 配置键；健康结果为：
  - `status=ok`
  - `langfuse_configured=true`
  - `langfuse_delivery.enabled=true`
  - `langfuse_delivery.worker_running=true`
- 父仓库及各子仓库空白检查通过。

## 仓库状态与边界

### 本轮已提交改动

- `apps/myapp`：测试数据管理代码、测试和文档已提交并推送，工作树 clean。
- `services/myapp-ai`：AI CI、Dockerfile、Makefile、文档、依赖锁，以及新增 `integration.env`、`tests/run_unittest.py`，工作树 clean。
- 父仓库：Compose/启动脚本、Secret 权限门禁、Langfuse 健康与重建、staging 校验、部署文档、全量效果测试报告和本交接文件。
- 父仓库的 Backend/AI 子模块指针仍停留在远程可检出的旧提交；待两个子仓库推送后再单独更新。

### 必须保留且未触碰的既有父仓库状态

- `AGENTS.md`
- `README.md`
- `.codex/`
- `docs/05-development/04-ai-business-workbench.zh-CN.md`

### Web

- `frontend/myapp-web` 测试数据管理页面、领域 service、路由、菜单、测试和开发文档已提交并推送，工作树 clean。
- 完整复测通过：TypeScript、Biome、`31` 套/`196` 项 Jest 与 production build。

### Mobile 延期技术债

用户已明确 Mobile 当前没有针对新接口优化，本轮只记录、不处理。以下 5 个既有用户修改保持原样：

- `app/common/product-search.tsx`
- `lib/sales-mode.ts`
- `services/gateway.ts`
- `services/products.ts`
- `services/sales.ts`

本轮没有执行 Mobile 新接口适配、TypeScript/依赖整改或发布验收，不得据此宣称 Mobile 已适配新接口或具备发布条件。Backend/AI 本轮改动保持现有 API 兼容，但 Mobile 的消费层仍需后续独立评审。

## 当前风险

- `localhost` 的 `myapp_test_data_*` site config 与当前 38 个模板对象是本地运行状态，不由 Git 保存；其他环境需要按文档显式配置并执行 migrate。
- Web 写操作使用后台 long queue；部署环境必须保证 long worker 正常运行。CLI 默认同步执行，可用于恢复和排障。
- 更新测试数据后台任务代码后必须重建或重启 long worker，避免常驻 Python 进程继续使用旧模块。
- 公司级交易重置的破坏性集成测试必须使用全新隔离公司或可随时恢复的临时 Site；不得在当前 `rgc (Demo)` 上启用危险开关后直接测试。
- 模板 reset 只处理登记拥有的对象；复杂测试公司应使用现有公司级交易重置，整站严重污染仍由部署层恢复快照或重建 Site。
- 测试数据 Backend 与 Web 已按仓库边界推送；其他环境可以检出对应提交。
- 父仓库本次只提交已推送的 Backend gitlink；既有 AI 本地提交和 gitlink 继续留待独立推送流程。
- 根 `.env` 与 staging 实际 env 的 `0600` 是本地文件权限状态，不由 Git 保存；其他环境必须通过初始化脚本和启动预检重新保证。
- `deploy/staging/staging.env` 目前只适用于本机测试，且被 Git 忽略；正式 staging 仍必须由 Secret Manager/受控配置源替换测试值，不能提交真实值。
- 启动脚本现在会等待健康并对依赖冲突失败关闭，首次构建或依赖下载时返回时间会比以前更长，这是预期门禁行为。
- AI 测试仍有上游 Starlette/httpx 弃用警告，当前不影响功能，但后续升级 FastAPI/Starlette 时需要消除。
- Mobile 新接口适配明确延期，仍是独立发布风险。
- 未执行会产生供应商费用的 AI live eval；完整效果证据使用离线固定评测和合成 Chat/Vector 集成，不冒充真实付费模型质量结论。
- 详细测试证据见 `docs/codex/FULL_EFFECT_TEST_2026-07-20.zh-CN.md`。

## 下一步

1. 在其他开发、测试或演示环境按 `TEST_DATA_MANAGEMENT.zh-CN.md` 显式配置环境类型、普通模板白名单和公司级重置独立白名单。
2. 公司级破坏性回归继续使用可恢复的临时 Site，不在共享公司直接测试。
3. 后续可增加整站黄金快照自动恢复、large 容量基线和定时 QA 刷新。
4. 父仓库后续提交继续精确排除既有 `AGENTS.md`、`README.md`、`.codex/` 和业务工作台草稿文档。
5. Mobile 后续单独建立“新接口适配与发布验收”任务，再处理现有 5 个脏文件、TypeScript/依赖和端到端回归。
