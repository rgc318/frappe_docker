# 2026-09-12 全局隐患检查

检查开始于 2026-09-12，报告于 2026-09-13 收尾；以下测试结果来自本轮检查。

第三批进展（2026-09-13）：Backend `3072b99` 增加已绑定站点幂等存储不可用时失败关闭；真实快捷开单 3 tests 覆盖正式单据/库存/账务回滚、外层唯一回执和缺表拒绝，全量 Backend 1076 tests、HTTP 4 tests 通过。R5 归档停止跟踪但磁盘原件完整保留，新增当前快照配置/归档 CI 检查；历史密码与本地唯一站点当前配置不匹配，未验证远程或旧凭据失效。旧 Git 历史仍有归档，未轮换/改写历史/推送，详见 `CREDENTIAL_ARCHIVE_REMEDIATION.zh-CN.md`。不能将这一部分治理当作 R5 全部关闭。

第二批进展（2026-09-13）：第一批已按仓提交。R4 已接入账号/IP/OTP 失败跟踪及锁定 HTTP 429；R6 已加入最终生产 override 和启动前静态校验，取消双代理与开发继承。Backend 1073 单测、JWT HTTP 3 tests、真实 Redis tracker 2 tests、Production 5 tests（含两种实际 Compose 渲染）、Parent staging 31 tests 通过。未推送、部署或轮换密码；生产镜像、迁移、TLS/恢复仍需真实验收。R5/R8/R9 尚未修复；历史审查证据保留如下。

修复进展（2026-09-13）：用户已授权开始优化。R1/R2/R3/R7 已有第一批源码修复及回归，尚未提交部署；Backend 1065 单测、真实失败商品回滚 1 test、公共 HTTP 错误包络 1 test、Web tsc/Biome/63 suites 420 tests 通过。R2 尚缺真实整单 HTTP 原子性验收，显式 commit 编排仍需继续排查；R7 尚未实现跨标签页互斥。其余问题未关闭。以下正文保留审查时证据，最新工作树状态以 CURRENT_HANDOFF 为准。

结论：业务功能、领域分层和自动化覆盖已经比较完整，具备继续 staging 业务验收的基础；当前还不能认定为正式上线已完善。本次确认 6 项 P1 问题，涉及事务完整性、权限回放、登录防护、历史凭据和生产启动配置，另有 3 项 P2 可靠性与质量问题。

本报告中的 P1 表示应优先修复、影响正式上线判断；P2 表示需要安排收敛的可靠性或工程质量问题。依赖审计的 high/critical 是上游公告分级，与这里的业务优先级不是同一口径。

## 检查基线与范围

| 仓库 | 当前提交 | 开始检查时的工作树 |
| --- | --- | --- |
| Parent | `93339eca` | AGENTS、开发规范、模板、已知问题已有修改；`.codex` 和多模态总结未跟踪 |
| Backend | `b7edd99` | 干净 |
| AI Orchestrator | `6700dcc` | 干净 |
| Web | `b556b9f` | `public/scripts/loading.js` 已有修改 |
| Mobile | `ebb242e` | 商品搜索、sales-mode、gateway、products、sales 共 5 个文件已有修改 |

覆盖四个应用仓库与父仓的核心代码、认证/权限、事务/幂等、商品单位/生命周期、AI 契约、前端认证、CI、生产启动、备份跟踪和依赖审计。没有修改应用源码、提交、推送或部署，也没有调用计费模型。真实数据库测试仅使用临时夹具并回滚；专门的失败探针还拦截了所有 commit。

## P1：优先处理

### R1. Gateway 吞掉异常后，失败请求仍会进入框架提交路径

- 定位：[gateway.py:289](../../apps/myapp/myapp/api/gateway.py#L289)、[idempotency.py:495](../../apps/myapp/myapp/utils/idempotency.py#L495)、[wholesale_service.py:3629](../../apps/myapp/myapp/services/wholesale_service.py#L3629)。框架旁证为 `apps/frappe/frappe/app.py:139/416`。
- `_handle_gateway_call` 捕获异常，设置 HTTP 错误码并正常返回，但没有 rollback。Frappe 的成功返回分支调用 `sync_database()`；POST 是否提交由 HTTP 方法决定，不根据已经设置的 422/500 决定。
- 具体触发：调用 `create_product_v2`，不传可选幂等键，提供合法商品资料和 `warehouse_stock_qty=-1`。商品先 insert，随后初始库存校验报错。现有 Web mutation 通常会发送幂等键，但公开接口允许省略，服务端不能以客户端一定发送为前提。
- 已验证：真实 Gateway → adapter → Service → 本地数据库返回 `ok=false / VALIDATION_ERROR / HTTP 422` 时，临时 Item 仍在事务中；调用框架 `sync_database()` 后捕获到一次 commit。探针拦截了该 commit 并最终 rollback，确认临时 Item 不存在。此为真实服务与数据库验证、模拟 POST 后处理，不冒充完整 HTTP/浏览器验收。
- 修复方向：建立统一失败回滚边界，校验尽量前置；确需独立持久化的失败审计应有明确事务策略。补充有/无幂等键的真实失败回归，断言错误响应与数据库状态一致。

### R2. 嵌套幂等调用提前提交，破坏快捷开单的整单原子性

- 定位：[idempotency.py:191](../../apps/myapp/myapp/utils/idempotency.py#L191)、[idempotency.py:219](../../apps/myapp/myapp/utils/idempotency.py#L219)、[order_service.py:2979](../../apps/myapp/myapp/services/order_service.py#L2979)、[order_service.py:3001](../../apps/myapp/myapp/services/order_service.py#L3001)。
- `quick_create_order_v2 → create_order_v2 → submit_delivery/create_sales_invoice` 会多层进入 `run_idempotent`。每层插入 processing 和记录成功都对同一业务连接执行 commit。
- 具体后果：使用幂等键快捷开单时，进入发货幂等层会提交前面的订单，发货完成会再次提交；之后开票失败时，外层 rollback 无法撤销已提交的订单和库存变化。这与业务设计明确要求的“任一步失败整体回滚、不留主单”不一致。
- 已验证：用内存事务适配器调用真实幂等模块，模拟下单 → 发货 → 开票失败。最终 committed 集合仍包含 Sales Order 和 Delivery Note。该探针不创建真实交易单据；真实嵌套关系已逐层核对源码。
- 额外影响：其他复用这些服务的 AI 草稿/数据任务，也需要审计子调用 commit 是否提前释放外层锁、导致正式对象与执行回执不一致；这部分尚未做完整并发故障注入。
- 修复方向：由最外层业务操作拥有事务；幂等占位、结果与业务提交必须协调，子服务不能任意提交父事务。增加开票失败、后置回执失败及并发重试的事务回归。

### R3. 幂等回放没有按用户隔离，可绕过业务回调内的权限检查

- 定位：[idempotency.py:61](../../apps/myapp/myapp/utils/idempotency.py#L61)、[idempotency.py:330](../../apps/myapp/myapp/utils/idempotency.py#L330)、[order_service.py:3519](../../apps/myapp/myapp/services/order_service.py#L3519)。
- 数据库记录虽然写了 owner，但查找和缓存键只有 `namespace + request_id`。读取成功结果时既不校验 owner，也不重新执行业务回调。
- 触发条件：同一站点的另一名已登录用户获知/复用原用户的幂等键及相同请求参数，即可命中原结果。参数 hash 只能区分请求内容，不能替代用户授权。
- 已验证：替换持久化读取边界为用户 A 的成功记录，以用户 B 调用真实 `create_sales_invoice` 服务，直接得到 A 的发票回执；会触发权限拒绝的 `get_doc` 回调调用次数为 0。没有读取其他真实用户的数据。
- 修复方向：将用户身份纳入幂等作用域，明确站点/公司范围；成功回放之前仍检查当前访问权限。覆盖跨用户同键、权限被撤销后的重放、缓存与数据库两条路径。

### R4. JWT 登录绕过 Frappe 的账号/IP 登录失败跟踪

- 定位：[token_api.py:25](../../apps/myapp/myapp/auth/token_api.py#L25)、[token_api.py:108](../../apps/myapp/myapp/auth/token_api.py#L108)。框架对照：`apps/frappe/frappe/auth.py:255`。
- 自定义匿名登录接口直接使用 `User.find_by_credentials`。该方法检查密码，但账号/IP 的 `LoginAttemptTracker` 位于 `LoginManager.authenticate`，不会自动由这个方法执行。
- 已验证：隔离凭据校验结果，连续模拟 10 次错误密码，自定义入口的框架失败跟踪调用次数为 0；未对真实账号发送密码尝试。自定义 OTP 校验也没有相应失败计数路径。
- 影响：系统中配置的普通登录失败封锁不能自然覆盖这个公开 JWT 入口；若依赖这一保护，会留下暴力尝试路径。没有检查外部 WAF 是否另有保护。
- 修复方向：复用框架完整认证防护或提供等价的账号/IP/OTP 限流、失败计数与封锁；同时保留现有 JWT 和双因素契约。

### R5. 已提交的历史站点压缩包含数据库密码

- 定位：[sites-backup.tar.gz](../../sites-backup.tar.gz)，由 `4b3b2ae8`（2026-03-03）引入，当前仍在 Git 跟踪集合中。
- 归档内 `data/localhost/site_config.json` 含非空 `db_password`。检查只输出了字段名，没有输出密码值，也没有尝试使用该密码。归档内未发现 SQL 备份或私有业务文件。
- 影响：能够获取仓库及其历史的人员可以读取该历史凭据。尚未确认凭据现在是否有效、是否被其他环境复用或远端仓库是否公开，不能把它描述为已经证实的外部入侵。
- 修复方向：核查使用范围并轮换仍有效/复用的凭据，从当前版本移出备份并加入排除及归档内容扫描；若已传播，另行协调历史清理。删除当前文件不能消除 Git 历史中的内容。

### R6. `start-prod.sh` 的组合存在端口冲突，并继承开发运行配置

- 定位：[start-prod.sh:51](../../start-prod.sh#L51)、[compose.yaml:55](../../compose.yaml#L55)、[compose.traefik.yaml:35](../../overrides/compose.traefik.yaml#L35)、[compose.https.yaml:24](../../overrides/compose.https.yaml#L24)、[compose.mariadb.yaml:12](../../overrides/compose.mariadb.yaml#L12)。
- 生产入口同时加载两个定义独立代理的 override：`traefik` 与 `proxy` 都发布同一个 `${HTTP_PUBLISH_PORT:-80}:80`。正常单机启动会竞争同一宿主端口。
- 该组合还保留 `bench serve`、启动时 `pip install -e`、业务源码 bind mount、`ENABLE_PYCHARM_DEBUG=1`，以及没有 loopback 约束的 `5678/8000/3307` 端口发布。
- 已验证：仅渲染与脚本一致的 Compose 文件组合，输出上述两个 80 端口映射、开发命令和端口。为补齐本地不存在的 Traefik 插值配置，使用了仅子进程可见的审计占位值；没有运行 `start-prod.sh` 或启动/切换任何容器。
- 修复方向：提供独立生产 Compose，只保留一个代理、受控入口和不可变运行镜像，使用正式应用服务器；发布前进行生产组合的配置及启动验收。staging 已部署成功不能替代这个生产入口的验收。

## P2：可靠性与质量收敛

### R7. Web 并发刷新令牌会把成功的新登录态清掉

- 定位：[auth.ts:245](../../frontend/myapp-web/src/services/myapp/auth.ts#L245)、[requestErrorConfig.ts:174](../../frontend/myapp-web/src/requestErrorConfig.ts#L174)。
- 多个请求同时 401 时，各自调用 `refreshMyAppJwt`，没有共享刷新 Promise。它们读取同一旧 refresh token；第一项成功轮换并保存新 token，第二项因旧 token 已使用而失败，catch 无条件清空 token 并跳回登录。
- 已验证：执行当前 `auth.ts`，仅替换内存 token store 与 HTTP 边界，两个并发刷新发出两次相同 token 请求；第一项保存新 token，第二项 401 后 token store 变为空。
- 修复方向：单页面合并刷新请求，考虑多页签协调；失败清理前校验令牌是否已被其他刷新更新，避免迟到响应删除新会话。

### R8. Mobile 类型检查长期失败，CI 未覆盖且 Node 版本契约冲突

- 定位：[mobile_checks.yml:48](../../frontend/myapp-mobile/.github/workflows/mobile_checks.yml#L48)、[package.json:5](../../frontend/myapp-mobile/package.json#L5)、[tsconfig.json](../../frontend/myapp-mobile/tsconfig.json)。
- 当前 `tsc --noEmit` 有 **371 个错误，涉及 27 个文件**。集中在采购开单 155 个、采购商品分组组件 95 个、销售订单详情 36 个，另有报表、商品与退货 service 的类型不一致。
- 为排除将历史问题全部归因于用户未提交修改，在同一依赖/生成文件环境中，仅通过内存 CompilerHost 将 5 个改动文件替换为 HEAD 内容，仍得到 **365 个错误 / 27 个文件**；没有 checkout 或修改工作树。
- 当前 mobile lint 通过，CI 仅运行 lint；APK 发布也没有类型检查。`package.json` 要求 Node `>=22 <23`，检查和 APK workflow 却使用 Node 20。
- 修复方向：按领域修复类型契约后将类型检查加入 CI/发布门禁，统一 Node 版本。不能将 lint 或 Expo 转译成功作为类型正确的证据；也不能从这些诊断直接推断 371 个独立运行时故障。

### R9. 依赖维护仍有明显欠账，移动端尤其集中

本次 `npm audit --omit=dev` 的受影响依赖统计：

| 项目 | Low | Moderate | High | Critical | 合计 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Web | 1 | 3 | 0 | 0 | 4 |
| Mobile | 90 | 36 | 69 | 3 | 198 |

- Web 涉及 DOMPurify/Mermaid 及依赖传播，当前 lockfile 的自动修复结果为 `fixAvailable=false`。实际攻击可达性取决于 Markdown/图表使用方式，本轮未声称已复现浏览器 XSS。
- Mobile 的 critical 根公告涉及 `shell-quote` 与 `tar`；npm 提示它们有可用修复，但其他 Expo/React Native 依赖链不能一律自动升级。
- 这些合计是受影响包及传递依赖链的统计，不是独立漏洞数量，也不表示全部存在于已打包 APK 的可攻击路径。Expo CLI/构建工具也可能处于 production dependency 分类；需要按构建、预览服务和客户端运行面分别判断。
- 修复方向：安排兼容的依赖升级与扫描门禁，优先处置可修复的高危根依赖；对暂不能升级的路径记录可达性与限制，避免直接无评估执行强制升级。

## 实际验证结果

| 验证 | 结果 |
| --- | --- |
| Backend 容器 bench Python 全量 unit | **1057 tests PASS** |
| Backend 运行环境 `pip check` | PASS |
| 商品 Repack 真实回滚集成 | **2 tests PASS**，覆盖零估值和非零估值价值守恒 |
| 商品生命周期真实回滚集成 | **8 tests PASS**，包括跨用户拒绝、第二项失败回滚、执行前新增引用阻断 |
| AI `pytest` | **226 tests PASS + 25 subtests PASS** |
| AI Ruff | PASS |
| Web TypeScript / Biome | PASS；Biome 检查 278 files |
| Web Jest | **62 suites / 415 tests PASS** |
| Mobile lint | PASS |
| Mobile TypeScript | **FAIL：371 errors / 27 files** |
| Parent AI 发布治理测试 | **31 tests PASS** |
| 五仓 `git diff --check` | PASS |
| 本地 Backend ping / AI `/readyz` | HTTP 200 |
| 本地 Backend → AI 运行契约 | PASS：7 schemas / 9 scenarios |
| 新增失败/隔离探针 | R1/R2/R3/R4/R7 均观察到报告所述问题 |

主要验证命令：

```bash
docker exec frappe_docker-backend-1 bash -lc 'cd /home/frappe/frappe-bench && env/bin/python -m unittest discover -s apps/myapp/myapp/tests/unit -t apps/myapp'
docker exec -e MYAPP_UOM_REPACK_TEST_SITE=localhost -w /home/frappe/frappe-bench/sites frappe_docker-backend-1 /home/frappe/frappe-bench/env/bin/python -m unittest myapp.tests.integration.test_product_uom_migration_repack -v
docker exec -e MYAPP_LIFECYCLE_TEST_SITE=localhost -w /home/frappe/frappe-bench/sites frappe_docker-backend-1 /home/frappe/frappe-bench/env/bin/python -m unittest myapp.tests.integration.test_product_lifecycle_plans -v
# services/myapp-ai
uv run --frozen --no-sync pytest -q
./.venv/bin/ruff check --no-cache .
# frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- --runInBand
# frontend/myapp-mobile
./node_modules/.bin/tsc --noEmit
CI=1 npm run lint
# 父仓
PYTHONPATH=apps/myapp python3 -m unittest discover -s deploy/staging/tests
timeout 25s bash verify-ai-runtime-compatibility.sh frappe_docker-backend-1
```

审计探针临时存放于 `/tmp/myapp-global-audit-zqfMiV/`：`probe_backend.py`、`probe_product_rollback.py`、`probe_web_refresh.cjs`、`mobile_typecheck.cjs`。它们是本轮验证材料，不是已加入仓库的正式回归测试；后续修复应将对应用例纳入各自测试体系。

验证过程中的环境说明：AI 测试首次因 uv 缓存位于只读目录而失败，获准访问缓存后通过；父仓测试首次缺少 `PYTHONPATH=apps/myapp`，补齐后 31 项通过。Web 保留既有 Jest open-handle/Browserslist 提示，但退出码为 0；这些提示没有被计作新的业务缺陷。

## 本次不能宣称已验证的部分

- 没有重新访问 staging/production，没有部署、全量业务 HTTP 写链路或登录态浏览器端到端验收。本地 Web 约定的 `:8001` 未监听，请求超时；没有为审查启动它。
- 没有调用真实 Provider，不能用单元测试与 `/readyz` 证明所有模型和自然语言场景当前都可用。
- 本地运行契约虽然通过，但返回 `release=local-product-pricing-v8-wip / runtime=unversioned`，不能把当前运行镜像认定为精确对应 `6700dcc` 的已验证制品。
- 没有进行真实压力测试、跨公司全角色矩阵、故障停机演练或异地备份恢复。已有脚本/历史报告不等于本次重新验证通过。
- 没有轮换凭据、删除压缩包或改写 Git 历史；这些需要在明确目标与影响后作为修复任务处理。

建议先完成 R1/R2 事务统一、R3 用户隔离和 R4 登录防护，核查 R5 凭据范围并修正 R6 生产组合；随后收敛前端刷新、移动端类型与依赖门禁，最后补多角色真实业务与发布验收。此次结论是“功能较完整，仍需一轮安全与一致性加固”，不建议继续以功能数量判断正式上线完成度。
