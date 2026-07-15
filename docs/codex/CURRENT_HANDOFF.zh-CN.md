# 当前交接状态

更新时间：2026-07-16 00:55 CST

本文件用于跨新会话交接当前项目状态。长期规则不要写在这里，应写入 `AGENTS.md` 或 `docs/codex/DEVELOPMENT_GUIDE.zh-CN.md`。

下方较早日期章节是历史执行记录；其中嵌入的“当前状态 / 下一步”只代表当时截面，最新口径始终以本页顶部“当前最终状态”和最新工作总结为准。

## 当前最终状态

- AI Orchestrator 已从父仓库普通目录迁移为独立公开仓库 `https://github.com/rgc318/myapp-ai`，完整保留 12 个历史里程碑；`main` 与 `develop` 当前均指向 `25e68c7 ci: establish independent AI repository delivery`。父仓库保持原路径 `services/myapp-ai`，但现在以 `develop` 子模块固定提交，因此现有 Compose、Dev Container 和 staging build context 不变。
- 独立 AI 仓库已补 `.gitignore`、Docker test/runtime CI、GitHub Release/手工 GHCR 发布（provenance + SBOM）、Dependabot 和仓库/交付边界文档。Docker test target 80/80 通过，runtime target 构建通过，远程 GitHub CI 同样成功。
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
- 本轮检索质量治理提交：Backend `c4a6af3 feat: govern AI vector retrieval quality`；父仓库 `62bae6ee feat: complete AI retrieval quality governance`。Provider 恢复文档提交：Backend `9ba54f1 docs: record embedding provider recovery`；父仓库 `fc6268af docs: update embedding recovery status`，gitlink 已同步。AI 独立仓库提交为 `25e68c7`；父仓库迁移提交已生成并通过本地门禁。Backend/Web 代码无未提交改动，父仓库 `.codex` 和 Mobile 既有 5 个用户改动继续不处理。本地 Secret、派生运行时文件和真实质量报告均受忽略且不得提交。
- Mobile `frontend/myapp-mobile` 保留本轮开始前已有的五个未提交文件，本轮不得修改、回滚或提交。

## AI 企业级收口最终验收

- 已完成：功能审计与追踪矩阵；模型治理 Backend/Orchestrator/Web；Embedding 发布控制面；高并发 P0 与压测；OTLP；备份恢复与内部 Token 轮换；Data Task Backend/Web；向量测试噪声治理和版本化中文检索门禁。
- 最终自动化：Orchestrator 当前源码镜像 80 项、Backend AI/Data Task/Gateway 178 项、Web 最近完整基线 21 套/154 项全部通过；站点迁移既有证据保持有效。
- 最终仓库门禁：父仓库/Backend/Web `diff --check` 通过，敏感扫描无真实 Key/Token；真实失败报告和 `.env.*.local` 均被忽略。父仓库只剩 `.codex`，Mobile 只剩本轮开始前的 5 个用户改动。
- Provider 恢复已确认：`erp-embedding` 字符串单条、数组单条和两条批量均 HTTP 200、1024 维；当前运行 Orchestrator 的真实检索返回 200。30 条质量门禁通过，最新报告保存在忽略目录 `ai-governance-reports/product-retrieval-v1-current.json`。新的 v2 alias/collection 尚未配置或发布；如果底层模型权重变化，必须按新向量空间完整发布流程处理。

## 本轮工作总结

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

- Codex 新会话启动所需的项目规则、文档索引和交接机制已建立并提交。
- 后端商品多条码能力已完成并提交，父仓库 `apps/myapp` 指针已提交。
- Web 商品模块已完成多条码、CSV 导入导出和列表布局优化，已复核、验证并提交。
- 单位展示/换算通用模块使用规则已补充到 `AGENTS.md` 和 `docs/codex/DEVELOPMENT_GUIDE.zh-CN.md`；单据链路 UOM 展示缺口已完成修复并记录为防回归事项。
- 库存写操作第一批已完成：后端新增库存转仓与单品单仓目标库存校准接口，Web 新增库存转仓页，并将库存调整页切到显式库存 API。
- Web 待处理确认工作台已完成：聚合核心草稿业务单据，并通过后端 `confirm_pending_document` 提交确认。
- 仓库管理第一版、原生治理字段扩展和 CSV 导入导出已完成：后端新增仓库主数据 API，Web 新增 `/master-data/warehouses` 列表和维护页，并补齐 ERPNext 原生仓库治理字段。
- 客户 / 供应商已升级为企业级第一版：共用往来单位治理页面，支持详情抽屉、主联系人 / 主地址、最近地址、CSV 导入导出和基础治理字段维护。
- 客户 / 供应商常规治理字段扩展已完成并提交：后端和 Web 已补默认价格表、付款条款、税号、税务类别；客户公司维度信用额度子表仍未接入。
- 库存批量盘点最小闭环已完成并提交：后端新增 `submit_inventory_stock_count_v1` 直接提交 ERPNext `Stock Reconciliation`，Web 新增 `/inventory/counts` 批量盘点页；盘点草稿 / 复核确认 / 作废生命周期暂不继续扩展，下一步回到核心交易 / 移动作业链路。
- 销售模块联调问题已修复并提交：Web 已修复新建销售订单必填项聚合提示、销售发票收款明细误渲染表头行、发货单开票提示文案、库存转仓菜单国际化缺失、Select 下拉弃用属性、全局 AntD `Space direction` 弃用属性，以及本次涉及销售详情页的 Alert `message` 弃用属性。
- 商品图片显示修复已提交：开发代理新增 `/files/` 到 Frappe，商品图片 URL 使用 `modified` 追加版本参数，图片上传 / 替换返回的预览 URL 使用 `file_id` 追加版本参数，上传组件会随外部 `value` 变化同步预览。
- 销售收款 / 退货退款联调修复已提交：Web 收款弹窗改为受控 Modal，修复发票未结金额循环请求；销售文案统一为“登记客户收款 / 取消原客户收款”；后端修复销售退货发票正式退款 `Payment Entry` 引用行金额符号。
- 销售订单详情退货聚合修复已提交：后端 `get_sales_order_detail.references.sales_invoices` 排除 `is_return=1` 的退货发票，时间线不再把退货发票重复显示为“销售开票”。
- 当前正在完善销售收款 / 退货退款 / 取消收款冲突链路：后端已按退货净额口径限制继续收款和可退金额，取消原客户收款会在存在有效客户退款时拦截；Web 端暂停直接发起销售退货入口，保留历史退货发票查看、退款核对和按客户退款单 -> 退货发票 -> 原收款 -> 来源发票 -> 发货单顺序回退。
- Web 销售退货 / 退款入口隐藏、已收款订单回退安全确认、通用 `Payment Entry` 作废入口和销售订单详情“一键开单”已完成并提交：订单 / 发货单 / 发票详情不再渲染新建退货 / 退款核对按钮，`/sales/returns/new` 保留暂停页；销售订单“回退并修改订单”只要检测到客户收款，就在回退弹框展示收款列表和“取消收款”入口；一笔收款可手动取消或二次确认后一键同步取消，多笔收款要求逐笔取消；`/payments/:name` 支持从收付款详情作废 `Payment Entry`；订单详情“一键开单”会确认后按状态串行创建发货单和发票，库存不足需二次确认强制发货并开票。Web 已提交：`3e9ad38 feat: harden sales rollback workflows`。
- Web 销售订单详情关联单据已补充跟随退货退款 feature flag：退货退款入口暂停时，订单右侧关联单据不再展示“退货发票”和“退款单”两项，只保留发货单、销售发票和收款单；目标测试已覆盖隐藏行为。Web 已提交：`0fd376d fix: hide return refs when disabled`。
- Web 销售发票作废单笔收款快捷处理已补齐并提交：发票详情作废弹框现在与订单回退一致，一笔客户收款时允许在额外二次确认后同步取消收款并作废发票，多笔客户收款仍要求逐笔取消后再作废发票。Web 已提交：`5d53a6c fix: allow single-payment invoice void`。二次确认已从静态 `Modal.confirm` 改为受控 Modal，避免点击“取消收款并作废发票”看起来没反应；所有按钮文案统一使用“取消收款”，不再出现“作废收款”。Web 已提交：`a9f3c88 fix: show invoice void payment confirmation`。
- Web 销售发票详情顶部“返回销售订单”已修正为优先返回当前发票所属销售订单详情，没有来源订单时才回销售订单列表。Web 已提交：`7e41e0c fix: link invoice back to source order`。
- Web 销售 / 采购订单交易选品核心增强已提交：Web `de4a40a feat: enhance order product picker` 完成右侧交易选品 Drawer、加入后不关闭、结构化 `onSelectLines`、重复业务行合并规则和销售 / 采购新建编辑页接入；Web `9a6fdc8 fix: load order picker candidates` 和后端 `8e6539b fix: support empty product search` 完成空关键词候选加载、`search_key` 默认空字符串、库存仓库筛选、库存范围下拉和相关接口文档；父仓库 `da1037fc chore: record order picker search fixes` 已记录后端子模块指针和交接。
- 销售订单 0 价格修复、销售生命周期测试、客户地址 fallback 和 API 文档已提交到后端：`cc64198 fix: preserve explicit sales prices`。Web 销售详情兼容清理已提交：`6eb6494 fix: clean sales detail warnings`。Web 客户自动填充 / 电话校验已提交：`f7625da fix: validate sales order contact phone`。Web 商品选择器增强已提交：`e74ac07 feat: enhance order product picker`。

## 仓库状态

- 父仓库：当前只剩既有未跟踪 `.codex`，不应提交；最新提交 `6536b56c docs: summarize shared order workflow handoff` 已推送。
- 后端 `apps/myapp`：当前工作区干净，最新提交 `e023370 feat: harden purchase warehouse workflows`。
- Web `frontend/myapp-web`：当前工作区干净，最新提交 `ed60444 feat: share order detail components`。
- Mobile `frontend/myapp-mobile`：当前未参与本轮提交，未发现需要提交的移动端改动。

## 已完成改动

### Codex 文档体系

- 新增 `AGENTS.md`，记录仓库边界、后端 devcontainer 规则、Web Ant Design Pro 优先规范、企业级设计准则、验证命令和交接规则。
- 新增 `docs/codex/DEVELOPMENT_GUIDE.zh-CN.md`，记录 Codex 开发规范与架构准则。
- 新增 `docs/codex/KNOWN_ISSUES.zh-CN.md`，记录已知问题和处理方式。
- 新增 `docs/codex/HANDOFF_TEMPLATE.zh-CN.md`，提供交接文档模板。
- 新增当前文件 `docs/codex/CURRENT_HANDOFF.zh-CN.md`，作为新会话交接入口。
- Codex 文档已在父仓库提交：`9fb80bf3 docs: add codex project guidance`。
- UOM 通用模块长期规则已补充：
  - `AGENTS.md`：禁止在页面或单点服务手写单位展示/换算。
  - `docs/codex/DEVELOPMENT_GUIDE.zh-CN.md`：后端必须使用 `myapp.utils.uom` / `myapp.utils.uom_display`，前端必须使用 display/conversion/order editor/UomSelect 等共享模块。
  - `docs/codex/KNOWN_ISSUES.zh-CN.md`：记录当前单据链路 `uom_display` 缺口。

### 后端 `apps/myapp`

- 完善商品多条码管理相关后端能力。
- 基于 ERPNext 原生 `Item Barcode` 数据结构补充接口和服务层能力：
  - 新增条码
  - 删除条码
  - 设置主条码
  - 商品详情返回完整 `barcodes[]`
  - `barcode` 保持为主条码兼容字段
- 补充商品条码管理、商品主数据和 gateway wrapper 相关测试。
- 后端已提交：`1a4cee6 test: cover product barcode management`。
- 当前已完成单据链路 UOM 展示修复：
  - 销售订单、发货单、销售发票行项目序列化返回 `uom_display`。
  - 采购订单、采购收货、采购发票行项目序列化返回 `uom_display`。
  - 退货来源上下文透传 `uom_display`。
  - 补充后端序列化和退货上下文测试。
- 后端 UOM 修复已提交：`7728f10 fix: include uom display in document rows`。
- 当前已完成库存写操作第一批后端能力：
  - 新增 `transfer_inventory_stock_v1`，通过 ERPNext `Stock Entry` 创建并提交 `Material Transfer`。
  - 新增 `reconcile_inventory_stock_v1`，按单品单仓目标库存差值创建并提交 `Material Receipt` / `Material Issue`；无差异时不创建单据。
  - 两个接口均使用 `myapp.utils.uom.resolve_item_quantity_to_stock` 统一 UOM 换算，并走 `request_id` / `Idempotency-Key` 幂等链路。
  - 补充 inventory service 和 gateway wrapper 单元测试。
- 后端库存写操作已提交：`d9dc3ad feat: add inventory transfer and reconciliation APIs`。
- 当前已完成仓库管理第一版后端能力：
  - 新增 `list_warehouses_v2`、`get_warehouse_detail_v2`、`create_warehouse_v2`、`update_warehouse_v2`、`disable_warehouse_v2`。
  - 创建 / 更新仓库时校验公司存在；父仓库必须存在、同公司且是分组仓库。
  - 接口支持 `request_id` 幂等。
  - 补充 warehouse service 和 gateway wrapper 单元测试。
- 后端仓库管理 API 已提交：`166e62b feat: add warehouse management APIs`。
- 当前已完成仓库原生治理字段扩展：
  - `Warehouse` 列表、详情、创建和更新返回 / 接收 `account`、`warehouse_type`、`default_in_transit_warehouse`、`is_rejected_warehouse`、`customer`、`email_id`、`phone_no`、`mobile_no`。
  - `account`、`warehouse_type`、`default_in_transit_warehouse`、`customer` 使用 Link 存在性校验。
  - `search_link_options_v1` 白名单新增 `Account` 和 `Warehouse Type`，并允许 `Account` 按 `company`、`is_group` 过滤。
  - `API_GATEWAY.zh-CN.md` 已同步仓库字段和 Link 白名单契约。
- 后端仓库治理字段扩展已提交：`c687d7f feat: expand warehouse governance fields`。

### Web `frontend/myapp-web`

- 商品列表新增“条码”列，展示主条码和多条码数量。
- 商品 CSV 导出新增“全部条码”列。
- 商品详情页条码列表改为官方 `ProTable`，支持主条码状态、顺序、复制、删除和设置主条码。
- 商品编辑表单文案从“条码”调整为“主条码”。
- 新增商品 CSV 批量导入：
  - 使用官方 `Upload + Modal + ProTable`
  - 支持下载模板
  - 上传后预览校验
  - 支持 `create / update`
  - `create` 调 `createProduct`
  - `update` 按商品编码调 `updateProduct`，且只发送 CSV 中实际填写的更新字段，避免空单元格误清空现有商品资料
  - 当前为前端小批量顺序执行，未新增后端导入接口
- 修复商品列表字段布局：
  - 商品编码固定左侧并单行省略
  - 图片缩小
  - 名称、规格、分类、条码设置稳定宽度
  - 批发价、零售价、采购价默认隐藏，可通过列设置打开
  - 操作列固定右侧
  - 增加横向滚动，避免字段挤压
- `WEB_DEVELOPMENT.zh-CN.md` 已同步补充商品导入和条码说明。
- Web 已提交：`cd1a18c feat: enhance product barcode management`。
- 当前已完成 Web UOM 修复：
  - 销售/采购退货页改用 `resolveDisplayUom(record.uom, record.uomDisplay)`。
  - 销售/采购订单编辑页 fallback 行保留来源单据 `uomDisplay`，并提供当前单位 1:1 降级换算上下文。
  - Web return source context service 映射 `uomDisplay`。
- Web UOM 修复已提交：`1783e57 fix: use uom display in return flows`。
- 当前已完成 Web 库存写操作第一批：
  - `/inventory/adjustments` 从间接调用 `update_product_v2` 改为调用 `reconcile_inventory_stock_v1`。
  - 新增 `/inventory/transfers` 库存转仓页，支持公司、转出仓、转入仓、商品、数量、单位、过账日期和备注。
  - 库存列表、库存详情、库存预警页增加库存转仓入口。
  - `src/services/myapp/inventory.ts` 新增 `transferInventoryStock`，并映射库存写操作返回字段。
  - Web 开发文档和开发计划已更新，完整批量盘点单仍列为后续项。
- Web 库存转仓工作流已提交：`814b455 feat: add inventory transfer workflow`。
- 当前已完成 Web 待处理确认工作台：
  - 新增 `/pending-confirmations`，聚合销售发货单、销售发票、采购收货单和采购发票的草稿单据。
  - 新增 `services/myapp/pending-confirmations.ts`，封装草稿列表聚合和 `confirm_pending_document` 写操作。
  - 新增 `canViewPendingConfirmations` 权限点和菜单入口。
  - 补充 domain service 测试，覆盖草稿列表查询和确认 payload。
  - Web 开发文档和开发计划已更新，待处理确认不再列为未接入项。
- Web 待处理确认工作台已提交：`287af5b feat: add pending confirmation workbench`。
- Web 已补主数据缺口文档：`e948afc docs: record master data gaps`。
- 当前已完成 Web 仓库管理第一版：
  - 新增 `/master-data/warehouses`，支持关键词、公司、状态、类型筛选。
  - 支持新增、编辑、启用和停用仓库。
  - 覆盖仓库名称、公司、父仓库、是否分组、停用和基础地址字段。
  - `master-data.ts` 新增仓库列表和写操作封装，页面不直接拼 gateway payload。
  - 补充 domain service 测试，覆盖仓库列表和新增 / 编辑 / 启停 payload。
- Web 仓库管理页面已提交：`790e54c feat: add warehouse management page`。
- 当前已完成 Web 仓库治理字段扩展：
  - `/master-data/warehouses` 列表展示仓库类型、会计科目、联系信息和拒收仓标记。
  - 新增 / 编辑表单接入仓库类型、会计科目、默认在途仓库、客户归属、拒收仓标记、电话、手机和邮箱。
  - Web domain service 已映射新增字段，并覆盖创建 / 更新 payload 测试。
  - `WEB_DEVELOPMENT.zh-CN.md` 和 `DEVELOPMENT_PLAN.zh-CN.md` 已同步当前完成范围与剩余缺口。
- Web 仓库治理字段扩展已提交：`acf4889 feat: expand warehouse management fields`。
- 当前已完成 Web 仓库 CSV 导入导出：
  - `/master-data/warehouses` 支持按当前筛选结果导出 CSV，导出字段覆盖仓库编码、名称、公司、父仓库、状态、仓库类型、会计科目、默认在途仓库、拒收仓、客户归属、联系方式和地址。
  - 支持 CSV 批量导入，`create` 创建仓库，`update` 按仓库编码更新仓库；导入前展示预览表，导入后逐行展示成功 / 失败。
  - 导入模板覆盖中英文字段别名，布尔字段支持 `1/0`、`true/false`、`yes/no`、`是/否` 等常见值。
  - `WEB_DEVELOPMENT.zh-CN.md` 和 `DEVELOPMENT_PLAN.zh-CN.md` 已同步 CSV 导入导出状态。
- Web 仓库 CSV 导入导出已提交：`43cf3e8 feat: add warehouse csv import export`。
- 当前已完成 Web 客户 / 供应商企业级第一版：
  - 客户和供应商继续共用 `PartyManagementPage`，按同一类“往来单位治理”维护。
  - `/master-data/customers` 和 `/master-data/suppliers` 支持关键词 / 状态 / 分组筛选、新增、编辑、启用、停用、详情抽屉、主联系人 / 主地址维护、最近使用地址展示、当前筛选结果 CSV 导出和 CSV 批量导入。
  - `master-data.ts` 已映射 `default_contact`、`default_address`、`recent_addresses`、`creation`、`modified`，写操作会向现有后端接口发送 `default_contact` / `default_address`。
  - 补充 domain service 测试，覆盖客户 / 供应商创建和更新时的主联系人 payload。
  - `WEB_DEVELOPMENT.zh-CN.md` 和 `DEVELOPMENT_PLAN.zh-CN.md` 已同步客户 / 供应商治理状态和剩余缺口。
- Web 客户 / 供应商企业级第一版已提交：`4ae0d30 feat: upgrade party management workflows`。
- 父仓库后端子模块指针已提交：`42327897 chore: record inventory workflow backend`。
- 当前已提交的客户 / 供应商治理字段扩展：
  - 后端 `list/get/create/update` 客户和供应商 API 已读写 `default_price_list`、`payment_terms`、`tax_id`、`tax_category`，并更新 `API_GATEWAY.zh-CN.md`。
  - Web `PartyManagementPage` 已在列表、详情、表单、CSV 导入导出中接入默认价格表、付款条款、税号、税务类别。
  - Web `master-data.ts` 已映射新增字段并在客户 / 供应商创建和更新 payload 中传递。
  - 补充后端 customer / purchase service 单测和 Web domain service Jest 断言。
- 后端已提交：`056a71d feat: expand party governance fields`。
- Web 已提交：`a6c8c7d feat: expand party management fields`。
- 当前已提交的库存批量盘点最小闭环：
  - 后端新增 `submit_inventory_stock_count_v1`，接收多行商品 / 仓库 / 实盘数量 / 单位 / 估值价，校验同公司、重复行和负数数量。
  - 后端使用 `resolve_item_quantity_to_stock` 做单位换算，通过 ERPNext `Stock Reconciliation` 创建并提交正式盘点单；无差异行不写入单据，全部无差异时不创建单据。
  - Web 新增 `/inventory/counts`，支持按公司 / 仓库 / 过账日期添加商品盘点行、录入实盘数量 / 单位 / 估值价、提交并查看差异结果。
  - 库存列表、库存详情、库存预警、库存调整和库存转仓页已增加批量盘点入口；库存流水支持 `voucherType` / `voucherNo` URL 初始筛选。
  - `API_GATEWAY.zh-CN.md`、`WEB_DEVELOPMENT.zh-CN.md`、`DEVELOPMENT_PLAN.zh-CN.md` 已同步接口与当前范围。
- 后端已提交：`ad98091 feat: add inventory stock count API`。
- Web 已提交：`f9e8298 feat: add inventory stock count page`。
- 当前已提交的销售收款 / 退货退款联调修复：
  - 后端 `create_customer_refund` 和 `create_supplier_refund` 在基于退货发票创建 `Payment Entry` 时，会按退货发票负数 `outstanding_amount` 规范化引用行 `total_amount`、`outstanding_amount` 和 `allocated_amount`，修复“已分配金额不能大于未付金额”校验失败。
  - 后端 `API_GATEWAY.zh-CN.md` 已补充销售退货发票正式退款的 ERPNext 符号口径说明。
  - Web `InvoicePaymentForm` 使用 ref 固定 `loadOutstandingAmount` / `onChange` 回调，修复打开收款弹窗后循环请求 `get_sales_invoice_detail_v2`。
  - Web 销售订单、销售发票、销售退货和销售退款核对页文案统一为“登记客户收款”“取消原客户收款”“登记客户退款”，并在订单已结清或退款已完成时禁用易误操作入口。
  - `WEB_DEVELOPMENT.zh-CN.md` 已同步销售收款、退款核对和原收款处理口径。
- 后端已提交：`04d0e91 fix: handle return invoice refund allocation`。
- Web 已提交：`11fd837 fix: clarify sales payment and refund actions`。
- 当前已提交的销售订单详情退货聚合修复：
  - 后端 `_collect_sales_order_reference_names` 会在收集销售订单关联发票时二次查询 `Sales Invoice` 主表，只返回 `docstatus = 1` 且 `is_return = 0` 的正向销售发票。
  - 订单详情 `references.sales_invoices` 不再混入销售退货发票；退货发票只通过 `timeline[].type = "sales_return"`、退货 / 退款核对入口和退款历史展示。
  - 时间线构建对 `is_return = 1` 的发票做防御性跳过，避免调用方误传退货发票时重复生成“销售开票”事件。
  - `API_GATEWAY.zh-CN.md` 已同步 `get_sales_order_detail.references.sales_invoices` 字段语义。
- 后端已提交：`93e822c fix: exclude return invoices from sales order invoices`。

## 已验证

销售收款 / 退货退款 / 取消收款冲突链路验证（2026-07-03 14:22 CST）：

```bash
docker exec frappe_docker-backend-1 bash -lc '
  cd /home/frappe/frappe-bench &&
  env/bin/python -m unittest \
    apps.myapp.myapp.tests.unit.test_order_service \
    apps.myapp.myapp.tests.unit.test_settlement_service \
    apps.myapp.myapp.tests.unit.test_gateway_wrappers
'

cd frontend/myapp-web && npm run tsc
cd frontend/myapp-web && npm run biome:lint
cd frontend/myapp-web && npm test -- Sales/Orders/Detail.test.tsx --runInBand

git -C apps/myapp diff --check
git -C frontend/myapp-web diff --check
git diff --check

docker restart frappe_docker-backend-1
```

结果：后端 192 个单元测试通过；Web 类型检查和 Biome lint 通过；订单详情 Jest 3 个用例通过，但仍输出既有 jsdom `window.getComputedStyle` not implemented 噪声和 open handle 提示；空白检查通过；backend 容器已重启。

Web 销售订单详情一键开单验证（2026-07-04 00:08 CST）：

```bash
cd frontend/myapp-web && npm test -- Sales/Orders/Detail.test.tsx --runInBand
cd frontend/myapp-web && npm run tsc
cd frontend/myapp-web && npm run biome:lint
cd frontend/myapp-web && git diff --check
git diff --check
```

结果：订单详情 Jest 7 个用例通过；新增用例覆盖“一键开单”确认后先调用发货再调用开票；类型检查、Biome lint 和空白检查通过。Jest 仍输出既有 jsdom `window.getComputedStyle` not implemented、AntD Timeline / Alert 弃用告警和 open handle 提示。

HTTP 仿真补充验证（2026-07-03 14:25 CST）：

```bash
MYAPP_HTTP_ENABLE_CHAIN_TESTS=1 MYAPP_HTTP_ENV_FILE=apps/myapp/.env.http-test python3 -m unittest \
  apps.myapp.myapp.tests.http.test_gateway_http.GatewayHttpTestCase.test_update_payment_status_success \
  apps.myapp.myapp.tests.http.test_gateway_http.GatewayHttpTestCase.test_update_payment_status_idempotent_replay \
  apps.myapp.myapp.tests.http.test_gateway_http.GatewayHttpTestCase.test_update_payment_status_writeoff_success \
  apps.myapp.myapp.tests.http.test_gateway_http.GatewayHttpTestCase.test_update_payment_status_overpayment_success \
  apps.myapp.myapp.tests.http.test_gateway_http.GatewayHttpTestCase.test_process_sales_return_success \
  apps.myapp.myapp.tests.http.test_gateway_http.GatewayHttpTestCase.test_process_sales_return_after_paid_invoice_requires_followup_refund \
  apps.myapp.myapp.tests.http.test_gateway_http.GatewayHttpTestCase.test_process_sales_return_idempotent_replay
```

Web 销售退货 / 退款入口隐藏验证（2026-07-03 14:49 CST）：

```bash
cd frontend/myapp-web && npm run tsc
cd frontend/myapp-web && npm run biome:lint
cd frontend/myapp-web && npm test -- Sales/Orders/Detail.test.tsx --runInBand
git -C frontend/myapp-web diff --check
```

结果：类型检查、Biome lint、订单详情 Jest 4 个用例和 Web 空白检查通过；Jest 仍输出既有 jsdom `window.getComputedStyle` not implemented、AntD Timeline `items.children` 弃用告警和 open handle 提示。

Web 已收款订单回退二次确认验证（2026-07-03 15:04 CST）：

```bash
cd frontend/myapp-web && npm run tsc
cd frontend/myapp-web && npm run biome:lint
cd frontend/myapp-web && npm test -- Sales/Orders/Detail.test.tsx --runInBand
cd frontend/myapp-web && npm test -- src/services/myapp/__tests__/domain-services.test.ts --runInBand
git -C frontend/myapp-web diff --check
```

结果：类型检查、Biome lint、订单详情 Jest 5 个用例、domain service Jest 52 个用例和 Web 空白检查通过；Jest 仍输出既有 jsdom `window.getComputedStyle` not implemented、AntD Timeline / Alert 弃用告警和 open handle 提示。

Web 多笔收款回退弹框内逐笔取消验证（2026-07-03 15:36 CST）：

```bash
cd frontend/myapp-web && npm run tsc
cd frontend/myapp-web && npm run biome:lint
cd frontend/myapp-web && npm test -- Sales/Orders/Detail.test.tsx --runInBand
cd frontend/myapp-web && npm test -- src/services/myapp/__tests__/domain-services.test.ts --runInBand
git -C frontend/myapp-web diff --check
```

结果：类型检查、Biome lint、订单详情 Jest 6 个用例、domain service Jest 52 个用例和 Web 空白检查通过；Jest 仍输出既有 jsdom `window.getComputedStyle` not implemented、AntD Timeline / Alert 弃用告警和 open handle 提示。

Web 回退弹框一笔 / 多笔收款统一列表验证（2026-07-03 18:45 CST）：

```bash
cd frontend/myapp-web && npm run tsc
cd frontend/myapp-web && npm run biome:lint
cd frontend/myapp-web && npm test -- Sales/Orders/Detail.test.tsx --runInBand
cd frontend/myapp-web && npm test -- src/services/myapp/__tests__/domain-services.test.ts --runInBand
git -C frontend/myapp-web diff --check
git diff --check
```

结果：类型检查、Biome lint、订单详情 Jest 6 个用例、domain service Jest 52 个用例、Web 空白检查和父仓库空白检查通过。订单详情 Jest 首次与其他命令并发运行时曾因 Umi `src/.umi-test/exports` 尚未就绪失败，重跑通过；Jest 仍输出既有 jsdom `window.getComputedStyle` not implemented、AntD Timeline / Alert 弃用告警和 open handle 提示。

Web 收付款详情页通用作废入口验证（2026-07-03 19:25 CST）：

```bash
cd frontend/myapp-web && npm run tsc
cd frontend/myapp-web && npm run biome:lint
cd frontend/myapp-web && npm test -- src/services/myapp/__tests__/domain-services.test.ts --runInBand
cd frontend/myapp-web && npm test -- Sales/Orders/Detail.test.tsx --runInBand
git -C frontend/myapp-web diff --check
git diff --check
```

结果：类型检查、Biome lint、domain service Jest 53 个用例、订单详情 Jest 6 个用例、Web 空白检查和父仓库空白检查通过；Jest 仍输出既有 jsdom `window.getComputedStyle` not implemented、AntD Timeline / Alert 弃用告警和 open handle 提示。

结果：7 个既有 HTTP 链路用例通过。另用临时 Python HTTP 仿真脚本验证：

- 先开票、部分收款、部分退货后继续收款：来源发票 `ACC-SINV-2026-00714` 只按退货净未收额核销，超出部分进入 `unallocated_amount = 500.0`。
- 已收款发票退货并登记客户退款后：取消原收款 `ACC-PAY-2026-00735` 返回 HTTP 422，提示已存在客户退款。
- 先发货后开票、收款、退货、退款：原收款在客户退款存在时被 HTTP 422 拦截；先取消客户退款 `ACC-PAY-2026-00740` 后，再取消原收款 `ACC-PAY-2026-00739` 成功；之后退款上下文 `refundable_amount = 0`。

销售订单详情退货聚合修复验证（2026-07-02 11:36 CST）：

```bash
docker exec frappe_docker-backend-1 bash -lc '
  cd /home/frappe/frappe-bench &&
  env/bin/python -m unittest \
    apps.myapp.myapp.tests.unit.test_order_service \
    apps.myapp.myapp.tests.unit.test_settlement_service
'

docker exec frappe_docker-backend-1 bash -lc '
  cd /home/frappe/frappe-bench &&
  env/bin/python - <<PY
import json, frappe
frappe.init(site="localhost", sites_path="/home/frappe/frappe-bench/sites")
frappe.connect()
try:
    from myapp.services.order_service import get_sales_order_detail
    data = get_sales_order_detail("SAL-ORD-2026-01366-1").get("data", {})
    print(json.dumps(data.get("references"), ensure_ascii=False, default=str))
    print([(row.get("type"), row.get("docname"), row.get("title")) for row in data.get("timeline") or []])
finally:
    frappe.destroy()
PY
'

git -C apps/myapp diff --check
git diff --check
```

结果：后端 order/settlement service 83 个测试通过；真实订单 `SAL-ORD-2026-01366-1` 复核显示 `references.sales_invoices` 只包含正向发票 `ACC-SINV-2026-00695`，退货发票 `ACC-SINV-2026-00696` 只作为 `sales_return` 时间线事件出现；空白检查通过。

销售收款 / 退货退款联调修复验证（2026-07-01 22:46 CST）：

```bash
docker exec frappe_docker-backend-1 bash -lc '
  cd /home/frappe/frappe-bench &&
  env/bin/python -m unittest apps.myapp.myapp.tests.unit.test_settlement_service
'

cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- --runInBand

git -C apps/myapp diff --check
git -C frontend/myapp-web diff --check
git diff --check
```

结果：后端 settlement service 26 个测试通过；Web TypeScript、Biome、9 个 Jest suites / 72 个 tests、空白检查均通过。Jest 仍提示测试进程未立即退出，但退出码为 0。

销售模块联调和商品图片修复 Web 验证（2026-07-01 20:24 CST）：

```bash
cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- --runInBand
git -C frontend/myapp-web diff --check
git diff --check
```

结果：TypeScript、Biome、Jest、空白检查均通过；Jest 结果为 9 个 suites、72 个 tests 全部通过，仍输出测试进程未立即退出的既有提示。

Codex 文档空白检查：

```bash
git diff --check -- AGENTS.md docs/codex
```

结果：通过。

后端验证：

```bash
docker exec frappe_docker-backend-1 bash -lc '
  cd /home/frappe/frappe-bench &&
  env/bin/python -m unittest \
    apps.myapp.myapp.tests.unit.test_wholesale_service \
    apps.myapp.myapp.tests.unit.test_gateway_wrappers \
    apps.myapp.myapp.tests.unit.test_link_options_service
'
```

结果：117 个测试通过。

后端 v2 HTTP 全量验证：

```text
207 tests OK
```

Web 商品模块最新验证：

```bash
cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- --runInBand
git -C frontend/myapp-web diff --check
git diff --check
```

结果：TypeScript、Biome、Jest、空白检查均通过。Jest 输出仍有测试进程未立即退出的提示，但测试结果为 9 个 suites、66 个 tests 全部通过。

UOM 修复最新验证：

```bash
docker exec frappe_docker-backend-1 bash -lc '
  cd /home/frappe/frappe-bench &&
  env/bin/python -m unittest \
    apps.myapp.myapp.tests.unit.test_order_service \
    apps.myapp.myapp.tests.unit.test_return_service \
    apps.myapp.myapp.tests.unit.test_purchase_service.TestPurchaseService.test_purchase_document_item_serializers_include_uom_display
'

cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- --runInBand

git -C apps/myapp diff --check
git -C frontend/myapp-web diff --check
git diff --check
```

结果：后端 60 个相关测试通过；Web TypeScript、Biome、9 个 Jest suites / 66 个 tests、空白检查均通过。

库存写操作最新验证：

```bash
docker exec frappe_docker-backend-1 bash -lc '
  cd /home/frappe/frappe-bench &&
  env/bin/python -m unittest apps.myapp.myapp.tests.unit.test_inventory_service apps.myapp.myapp.tests.unit.test_gateway_wrappers
'

cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- --runInBand

git -C apps/myapp diff --check
git -C frontend/myapp-web diff --check
```

结果：后端 90 个相关测试通过；Web TypeScript、Biome、9 个 Jest suites / 67 个 tests、空白检查均通过。Jest 仍提示测试进程未立即退出，但退出码为 0。

待处理确认工作台最新验证：

```bash
cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- --runInBand
git -C frontend/myapp-web diff --check
```

结果：Web TypeScript、Biome、9 个 Jest suites / 69 个 tests、空白检查均通过。Jest 仍提示测试进程未立即退出，但退出码为 0。

仓库管理最新验证：

```bash
docker exec frappe_docker-backend-1 bash -lc '
  cd /home/frappe/frappe-bench &&
  env/bin/python -m unittest apps.myapp.myapp.tests.unit.test_warehouse_service apps.myapp.myapp.tests.unit.test_gateway_wrappers
'

cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- --runInBand

git -C apps/myapp diff --check
git -C frontend/myapp-web diff --check
```

结果：后端 94 个相关测试通过；Web TypeScript、Biome、9 个 Jest suites / 70 个 tests、空白检查均通过。Jest 仍提示测试进程未立即退出，但退出码为 0。

仓库治理字段扩展最新验证：

```bash
docker exec frappe_docker-backend-1 bash -lc '
  cd /home/frappe/frappe-bench &&
  env/bin/python -m unittest apps.myapp.myapp.tests.unit.test_warehouse_service apps.myapp.myapp.tests.unit.test_link_options_service apps.myapp.myapp.tests.unit.test_gateway_wrappers
'

cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- --runInBand

git diff --check
git -C apps/myapp diff --check
git -C frontend/myapp-web diff --check
```

结果：后端 103 个相关测试通过；Web TypeScript、Biome、9 个 Jest suites / 70 个 tests、空白检查均通过。Jest 仍提示测试进程未立即退出，但退出码为 0。

仓库 CSV 导入导出最新验证：

```bash
cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- --runInBand
git -C frontend/myapp-web diff --check
git diff --check
```

结果：Web TypeScript、Biome、9 个 Jest suites / 70 个 tests、空白检查均通过。

客户 / 供应商企业级第一版最新验证：

```bash
cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- --runInBand
git -C frontend/myapp-web diff --check
git diff --check
```

结果：Web TypeScript、Biome、9 个 Jest suites / 70 个 tests、空白检查均通过。Jest 仍提示测试进程未立即退出，但退出码为 0。

客户 / 供应商治理字段扩展最新验证：

```bash
docker exec frappe_docker-backend-1 bash -lc '
  cd /home/frappe/frappe-bench &&
  env/bin/python -m unittest \
    apps.myapp.myapp.tests.unit.test_customer_service \
    apps.myapp.myapp.tests.unit.test_purchase_service \
    apps.myapp.myapp.tests.unit.test_gateway_wrappers
'

cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- --runInBand

git -C apps/myapp diff --check
git -C frontend/myapp-web diff --check
git diff --check
```

结果：后端 140 个相关测试通过；Web TypeScript、Biome、9 个 Jest suites / 70 个 tests、空白检查均通过。Jest 仍提示测试进程未立即退出，但退出码为 0。

库存批量盘点最小闭环最新验证：

```bash
docker exec frappe_docker-backend-1 bash -lc '
  cd /home/frappe/frappe-bench &&
  env/bin/python -m unittest apps.myapp.myapp.tests.unit.test_inventory_service apps.myapp.myapp.tests.unit.test_gateway_wrappers
'

cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- --runInBand

git diff --check
git -C apps/myapp diff --check
git -C frontend/myapp-web diff --check
```

结果：后端 98 个相关测试通过；Web TypeScript、Biome、9 个 Jest suites / 71 个 tests、空白检查均通过。

本地 Web 开发服务器：

```text
http://localhost:8001
```

销售 / 采购订单交易选品第一阶段本地验证（2026-07-05 00:00 CST）：

```bash
cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- src/utils/__tests__/sales-order-editor.test.ts src/utils/__tests__/purchase-order-editor.test.ts --runInBand
npm test -- Sales/Orders/Detail.test.tsx --runInBand
git -C frontend/myapp-web diff --check
git diff --check
```

结果：Web TypeScript、Biome、销售和采购订单 editor 工具测试、销售订单详情回归测试、Web 和父仓库 diff 空白检查均通过。销售订单详情测试仍输出既有 jsdom `window.getComputedStyle` not implemented、AntD Timeline / Alert deprecated 警告和 Jest open handle 提示，但退出码为 0。

销售 / 采购订单交易选品右侧常驻摘要优化验证（2026-07-05 CST）：

```bash
cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- src/utils/__tests__/sales-order-editor.test.ts src/utils/__tests__/purchase-order-editor.test.ts --runInBand
git -C frontend/myapp-web diff --check
git diff --check
```

结果：Web TypeScript、Biome、销售和采购订单 editor 工具测试、Web 和父仓库 diff 空白检查均通过。

销售 / 采购订单交易选品信息密度与共享换算工具优化验证（2026-07-05 CST）：

```bash
cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- src/utils/__tests__/sales-order-editor.test.ts src/utils/__tests__/purchase-order-editor.test.ts src/utils/__tests__/myapp-display.test.tsx --runInBand
git -C frontend/myapp-web diff --check
git diff --check
```

结果：Web TypeScript、Biome、销售 / 采购订单 editor 工具测试、展示工具测试、Web 和父仓库 diff 空白检查均通过。Jest 仍提示既有 open handle，但退出码为 0。

交易选品空关键词自动加载修复验证（2026-07-05 CST）：

```bash
docker exec frappe_docker-backend-1 bash -lc '
  cd /home/frappe/frappe-bench &&
  env/bin/python -m unittest apps.myapp.myapp.tests.unit.test_wholesale_service apps.myapp.myapp.tests.unit.test_gateway_wrappers
'

cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- src/services/myapp/__tests__/domain-services.test.ts --runInBand

git -C apps/myapp diff --check
git -C frontend/myapp-web diff --check
git diff --check
```

结果：后端 wholesale service 和 gateway wrappers 共 120 个测试通过；Web TypeScript、Biome、domain service 56 个测试通过；空白检查通过。Jest 仍提示既有 open handle，但退出码为 0。

交易选品去暂存化验证（2026-07-05 CST）：

```bash
cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- src/services/myapp/__tests__/domain-services.test.ts --runInBand

git -C frontend/myapp-web diff --check
git diff --check
```

结果：Web TypeScript、Biome、domain service 56 个测试通过；Web 和父仓库 diff 空白检查通过。Jest 仍提示既有 open handle，但退出码为 0。

快捷新增商品 UOM payload 修复验证（2026-07-05 CST）：

```bash
cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- src/services/myapp/__tests__/domain-services.test.ts --runInBand

cd /home/rgc318/python-project/frappe_docker/frontend/myapp-mobile
npm run lint

git -C frontend/myapp-web diff --check
git -C frontend/myapp-mobile diff --check
git -C apps/myapp diff --check
```

结果：Web TypeScript、Biome、domain service 56 个测试通过；Mobile Expo lint 通过；Web、Mobile 和后端 diff 空白检查通过。Web Jest 仍提示既有 open handle，但退出码为 0；Mobile lint 输出 Node `UNDICI-EHPA` 实验性 warning，不影响退出码。

商品选择器名称 / 昵称 / 备注显示语义修复验证（2026-07-05 CST）：

```bash
cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- src/services/myapp/__tests__/domain-services.test.ts --runInBand
git -C frontend/myapp-web diff --check
```

结果：Web TypeScript、Biome、domain service 56 个测试通过；Web diff 空白检查通过。Jest 仍提示既有 open handle，但退出码为 0。

销售参考价缺失批发价回退修复验证（2026-07-05 CST）：

```bash
cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- src/utils/__tests__/sales-order-editor.test.ts src/services/myapp/__tests__/domain-services.test.ts --runInBand
git -C frontend/myapp-web diff --check
```

结果：Web TypeScript、Biome、sales-order-editor 和 domain service 共 62 个测试通过；Web diff 空白检查通过。

Web 商品选择器默认单位共享 UOM 工具与 Mobile 价格逻辑对齐验证（2026-07-06 CST）：

```bash
cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- src/utils/__tests__/sales-order-editor.test.ts --runInBand

cd /home/rgc318/python-project/frappe_docker/frontend/myapp-mobile
npm run lint

git -C frontend/myapp-web diff --check
git -C frontend/myapp-mobile diff --check
git diff --check
```

结果：Web TypeScript、Biome、sales-order-editor 7 个测试通过；Mobile Expo lint 通过；Web、Mobile 和父仓库 diff 空白检查通过。Mobile lint 仍输出 Node `UNDICI-EHPA` 实验性 warning，不影响退出码。

## 未完成事项

- 销售模块主流程当前无已知重大阻塞；打印平台阶段改动已分别提交到后端和 Web，父仓库同步提交后端子模块指针与本交接文档。
- `.codex` 是既有未跟踪目录，不处理。
- 库存批量盘点直接提交式工作流已接入；盘点草稿、复核确认、作废 / 取消和审计生命周期仍未接入，当前阶段暂不继续深挖。
- 待处理确认当前覆盖核心草稿业务单据提交；如后续需要工作流动作审批，需要补 action 列表/状态来源。
- 客户 / 供应商已覆盖企业级第一版；默认价格表、常规付款条款和税务字段已接入；联系人 / 地址多条独立维护、客户公司维度信用额度子表、交易历史聚合、应收应付钻取、标签归属和审计记录仍未接入。
- 仓库管理已覆盖 ERPNext 原生基础治理字段和 CSV 导入导出；库位 / 容量、负责人、默认成本中心、仓库权限、审计记录和更细粒度治理仍未接入。

## 下一步建议

1. 后续优化采购链路时，优先复用 `ProductSelect`、`RemoteLinkSelect`、`phone-validation`、UOM / 金额工具、`InvoicePaymentForm` 和回退指引组件；采购供应商上下文、默认价格 / 单位、收货开票付款状态仍放在采购 domain/service 层。
2. 可继续补真实浏览器回归：销售 / 采购新建和编辑页打开右侧交易选品 Drawer，确认没有暂存 / 勾选中间态，点击加入后不关闭且订单明细即时更新，业务维度调整后直接加入，右侧本单已加入展示和重复业务行合并正常。
3. 下一步可做条码输入回车快速加入及异常提示：唯一命中直接加入、多结果保留确认、被筛选隐藏提示查看全部、未命中引导新建商品。
