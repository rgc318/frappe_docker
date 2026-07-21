# 当前交接状态

更新时间：2026-07-21 15:58 CST

本文件只记录当前短期状态、仓库边界、验证结果、风险和下一步。长期规则见 `AGENTS.md` 与 `docs/codex/DEVELOPMENT_GUIDE.zh-CN.md`。

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
