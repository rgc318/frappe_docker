# 当前交接状态

更新时间：2026-07-20 14:05 CST

本文件只记录当前短期状态、仓库边界、验证结果、风险和下一步。长期规则见 `AGENTS.md` 与 `docs/codex/DEVELOPMENT_GUIDE.zh-CN.md`。

## 当前目标

- 已按全项目测试与审查方案完成 Backend、AI Orchestrator 和父仓库部署层优化，并按仓库边界提交代码、测试文档与交接文档。
- Mobile 对新接口的适配按用户要求延期：只记录问题，不在本轮修改或优化 Mobile。
- 本轮提交均仅保存在本地，尚未推送远程。

## 提交状态

- Backend `apps/myapp`：`33c6680 fix: harden settlement and backend validation`。
- AI Orchestrator `services/myapp-ai`：`13042a4 test: make offline evaluation self-contained`。
- 父仓库部署实现：`bcd64336 ops: harden secret and observability deployment`。
- 全量效果测试报告、AI 部署文档和本交接文件包含在随后建立的父仓库文档提交中。
- AI 与 Backend 提交尚未推送；按子模块可检出规则，父仓库暂不提交这两个新 gitlink。当前父仓库看到 `apps/myapp`、`services/myapp-ai` 为 modified 属于预期状态。

## 本轮已完成

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

- `apps/myapp`：Backend 业务、测试、依赖与 CI/Ruff 改动，共 17 个文件，工作树 clean。
- `services/myapp-ai`：AI CI、Dockerfile、Makefile、文档、依赖锁，以及新增 `integration.env`、`tests/run_unittest.py`，工作树 clean。
- 父仓库：Compose/启动脚本、Secret 权限门禁、Langfuse 健康与重建、staging 校验、部署文档、全量效果测试报告和本交接文件。
- 父仓库的 Backend/AI 子模块指针仍停留在远程可检出的旧提交；待两个子仓库推送后再单独更新。

### 必须保留且未触碰的既有父仓库状态

- `AGENTS.md`
- `README.md`
- `.codex/`
- `docs/05-development/04-ai-business-workbench.zh-CN.md`

### Web

- `frontend/myapp-web` 当前 clean，本轮没有 Web 改动。
- 完整复测通过：TypeScript、Biome、`30` 套/`190` 项 Jest、`--detectOpenHandles` 与 production build。

### Mobile 延期技术债

用户已明确 Mobile 当前没有针对新接口优化，本轮只记录、不处理。以下 5 个既有用户修改保持原样：

- `app/common/product-search.tsx`
- `lib/sales-mode.ts`
- `services/gateway.ts`
- `services/products.ts`
- `services/sales.ts`

本轮没有执行 Mobile 新接口适配、TypeScript/依赖整改或发布验收，不得据此宣称 Mobile 已适配新接口或具备发布条件。Backend/AI 本轮改动保持现有 API 兼容，但 Mobile 的消费层仍需后续独立评审。

## 当前风险

- 本轮代码和文档已按仓库边界提交，但均尚未推送；其他环境暂时无法检出 Backend/AI 新提交。
- 父仓库尚未提交 Backend/AI 新 gitlink。必须先推送 `apps/myapp` 与 `services/myapp-ai`，再更新父仓库子模块指针，最后推送父仓库。
- 根 `.env` 与 staging 实际 env 的 `0600` 是本地文件权限状态，不由 Git 保存；其他环境必须通过初始化脚本和启动预检重新保证。
- `deploy/staging/staging.env` 目前只适用于本机测试，且被 Git 忽略；正式 staging 仍必须由 Secret Manager/受控配置源替换测试值，不能提交真实值。
- 启动脚本现在会等待健康并对依赖冲突失败关闭，首次构建或依赖下载时返回时间会比以前更长，这是预期门禁行为。
- AI 测试仍有上游 Starlette/httpx 弃用警告，当前不影响功能，但后续升级 FastAPI/Starlette 时需要消除。
- Mobile 新接口适配明确延期，仍是独立发布风险。
- 未执行会产生供应商费用的 AI live eval；完整效果证据使用离线固定评测和合成 Chat/Vector 集成，不冒充真实付费模型质量结论。
- 详细测试证据见 `docs/codex/FULL_EFFECT_TEST_2026-07-20.zh-CN.md`。

## 下一步

1. 用户明确要求推送时，先推送 `apps/myapp` 的 `33c6680` 与 `services/myapp-ai` 的 `13042a4`。
2. 两个子仓库推送成功后，在父仓库单独提交 `apps/myapp`、`services/myapp-ai` 的 gitlink 更新，再推送父仓库本轮提交。
3. 父仓库后续提交继续精确排除既有 `AGENTS.md`、`README.md`、`.codex/` 和业务工作台草稿文档。
4. Mobile 后续单独建立“新接口适配与发布验收”任务，再处理现有 5 个脏文件、TypeScript/依赖和端到端回归。
