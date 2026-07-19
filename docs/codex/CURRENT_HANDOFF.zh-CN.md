# 当前交接状态

更新时间：2026-07-19 18:29 CST

本文件只记录当前短期状态、仓库边界、验证结果、风险和下一步。长期规则见 `AGENTS.md` 与 `docs/codex/DEVELOPMENT_GUIDE.zh-CN.md`；历史过程以 Git 提交和专项文档为准，不再在本文件重复维护流水账。

## 当前目标

- AI 商品、销售订单、采购订单和库存调整四类草稿已经统一解决“保存后再次编辑仍读取旧内容”的一致性问题。
- 全项目代码审查中对业务有直接影响的权限、HTTP 方法、幂等、异常信息、部署 Secret 和 Mobile UOM 问题已经整改并完成本地提交。
- Web/Mobile Web 的 HttpOnly Cookie 认证改造经用户确认本轮暂缓，现有 `localStorage + Authorization: Bearer` 调用方式保持不变。
- 当前没有待提交的本轮业务代码；所有新增提交均未推送远端。

## 仓库状态

| 仓库 | 分支状态 | 工作区 | 当前相关提交 |
| --- | --- | --- | --- |
| 父仓库 | `develop`，领先远端 | 有既有未提交文件，见下方说明 | `4b199d05`、`ad9d9794` |
| `apps/myapp` | `develop`，领先远端 | clean | `7ae9ad6`、`d9c12b1` |
| `services/myapp-ai` | `develop`，领先远端 | clean | `c5b5889` |
| `frontend/myapp-web` | `main`，领先远端 | clean | `3a6e841` |
| `frontend/myapp-mobile` | `develop`，领先远端 | 保留 5 个用户既有修改 | `1596c73` |

父仓库未纳入本轮提交的既有状态：

- `AGENTS.md`
- `README.md`
- `.codex/`：本地未跟踪目录，禁止提交
- `docs/05-development/04-ai-business-workbench.zh-CN.md`

Mobile 未纳入本轮提交的用户既有修改：

- `app/common/product-search.tsx`
- `lib/sales-mode.ts`
- `services/gateway.ts`
- `services/products.ts`
- `services/sales.ts`

不得回滚、覆盖或混入上述文件。

## 已完成改动

### AI 草稿编辑一致性

- Web 的 AI 工作台和草稿中心统一使用共享编辑器，只传 `draftId`；每次打开重新调用 `get_ai_draft_v1` 获取最新持久版本，不再使用列表行或生成时 citation 快照作为编辑事实源。
- 保存后使用后端返回的最新 `payload`、`validation` 和 `version` 刷新编辑器及来源卡片。
- Backend `update_ai_draft_v1` 与 `restore_ai_draft_version_v1` 强制校验 `expected_version`，草稿行使用锁和版本比较，防止旧页面覆盖新版本。
- 更新和恢复操作使用请求指纹与幂等键；重复请求不会重复递增草稿版本。
- 相关提交：Backend `d9c12b1`、Web `3a6e841`、Parent `7e9c628c`。

### Backend 业务安全与一致性

- 销售/采购工作台主查询改用应用当前用户权限的 `frappe.get_list`。
- 销售订单、发货单、销售发票、采购订单、采购收货和采购发票详情增加文档级 `read` 权限。
- 销售/采购更新增加 `write` 权限；取消和替换已提交明细增加 `cancel` 权限；销售订单保存不再设置 `ignore_permissions`。
- 状态变更接口统一限制 POST，覆盖销售、采购、库存、客户、UOM、仓库、商品、用户与权限、媒体、结算、打印和 AI 会话。
- 商品昵称/规格回填 HTTP 入口限制为 `System Manager + POST`；CLI 使用内部执行函数。
- Gateway 对未知 500/503 返回稳定通用文案，原始异常只写服务端日志。
- 持久化幂等增加 15 分钟 processing 租约、过期原子接管、数据库成功状态优先持久化和 Redis 非关键缓存。
- AI 草稿更新与执行成功路径不再在 callback 内提前提交，业务结果与外层幂等成功状态在同一事务提交。
- 非 HTTP/后台上下文只在 `frappe.local.form_dict` 为合法映射时读取请求指纹，避免内部服务调用被错误的请求上下文阻断。
- 相关提交：Backend `7ae9ad6`。

### AI Orchestrator 与部署 Secret

- `MYAPP_AI_SERVICE_TOKEN` 必须至少 32 字符，并拒绝缺失值、旧开发默认值、`change-me*` 和 `not-configured` 等占位值。
- staging Compose 对 `MYAPP_AI_SERVICE_TOKEN` 和 `MYAPP_AI_LITELLM_API_KEY` 使用必填变量展开，缺失时配置阶段失败关闭。
- 相关提交：AI `c5b5889`、Parent `ad9d9794`。

### Mobile UOM 展示

- 退货来源 service 透传 `uomDisplay`。
- 采购收货订单行、收货汇总、仓库明细和退货页面统一使用 `resolveDisplayUom`。
- 相关提交：Mobile `1596c73`。

### 审查与认证决策文档

- 全项目审查及整改状态记录在 `docs/codex/PROJECT_REVIEW_2026-07-19.zh-CN.md`。
- HttpOnly Cookie 改造经用户确认暂缓；文档已记录当前风险、未来迁移范围和禁止局部删除 Token 的边界。
- 相关提交：Parent `ad9d9794`、`4b199d05`。

## 已验证

Backend 完整单元测试：

```bash
docker exec frappe_docker-backend-1 bash -lc '
  cd /home/frappe/frappe-bench &&
  env/bin/python -m unittest discover -s apps/myapp/myapp/tests/unit -p "test_*.py"
'
```

结果：`576` 项通过。宿主机和 Backend 容器当前均没有 Ruff，Backend Ruff 未运行。

AI Orchestrator：

```bash
cd services/myapp-ai
uv run pytest
uv run ruff check .
```

结果：`85` 项 pytest 通过，Ruff 通过；只有既有 Starlette/httpx 弃用警告。

Web AI 草稿一致性改动：

```bash
cd frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- --runInBand
npm run build
```

结果：TypeScript、Biome、30 套/190 项 Jest 和 production build 通过。

Mobile：

```bash
cd frontend/myapp-mobile
npx tsc --noEmit
npm run lint
```

结果：通过。

staging Compose：

```bash
docker compose --env-file deploy/staging/staging.env.example \
  -f deploy/staging/compose.staging.yaml config --quiet
```

结果：通过。

空白检查：

```bash
git diff --check
git -C apps/myapp diff --check
git -C services/myapp-ai diff --check
git -C frontend/myapp-web diff --check
git -C frontend/myapp-mobile diff --check
```

结果：通过。

## 未完成事项

- 当前安全契约以单元测试为主；仍建议在真实站点增加普通用户、跨公司、User Permission 和 GET 调写接口返回 405 的 HTTP 集成回归。
- Web/Mobile Web 的长期 Token 仍存储在 `localStorage`。用户已确认本轮不实施 HttpOnly 改造，后续必须作为独立认证项目处理。
- 所有本轮提交尚未推送；父仓库 gitlink 当前指向仅存在于本地的 Backend/AI 提交。
- staging 新配置要求部署环境显式提供 AI Service Token 和 LiteLLM API Key；部署前必须确认 Secret 已注入。
- Mobile 5 个用户既有修改尚未审查或提交，不属于本轮 UOM 提交。

## 当前风险

- 发布顺序风险：必须先推送 Backend 和 AI 子仓库，再推送包含新 gitlink 的父仓库；否则其他环境无法检出对应子模块提交。
- 认证安全风险：保留 `localStorage` Token 意味着同源 XSS 仍可能读取长期凭据；当前决定是暂缓，不代表风险消失。
- 幂等恢复风险：processing 租约当前为 15 分钟；若未来出现超过 15 分钟的单次同步业务，应增加按 namespace 配置或租约续期机制。
- 集成验证风险：权限与 POST-only 已有代码级契约，但真实角色/User Permission 组合仍需 HTTP 回归确认。
- 工作区风险：父仓库与 Mobile 存在明确的用户既有脏文件，后续提交必须继续精确暂存。

## 下一步建议

1. 如用户要求推送，按 Backend → AI Orchestrator → Web/Mobile → Parent 的顺序推送，并在推送后核对子模块远端可达性。
2. 使用普通业务用户和跨公司 User Permission 在真实 `localhost` 站点补销售/采购详情、搜索、更新、取消和 GET 405 HTTP 回归。
3. staging 部署前生成并注入至少 32 字符的高熵 `MYAPP_AI_SERVICE_TOKEN`，同时确认 `MYAPP_AI_LITELLM_API_KEY` 已配置。
4. HttpOnly 认证迁移保持暂缓；只有在登录/刷新/退出、CSRF、CORS、Mobile 原生安全存储和灰度回退方案一起确定后再启动。

## 最新提交

Backend `apps/myapp`：

- `7ae9ad6 fix: harden business transaction boundaries`
- `d9c12b1 fix: protect AI draft updates`

AI Orchestrator `services/myapp-ai`：

- `c5b5889 fix: require secure AI service tokens`

Web `frontend/myapp-web`：

- `3a6e841 fix: keep AI draft edits consistent`

Mobile `frontend/myapp-mobile`：

- `1596c73 fix: display business UOM labels consistently`

父仓库：

- `4b199d05 docs: defer HttpOnly token migration`
- `ad9d9794 fix: apply project security review`
- `d7ba505d docs: record full project review`
- `7e9c628c fix: update AI draft consistency backend`

## 关键文档

- 全项目审查：`docs/codex/PROJECT_REVIEW_2026-07-19.zh-CN.md`
- Backend API 契约：`apps/myapp/API_GATEWAY.zh-CN.md`
- Backend 测试规则：`apps/myapp/TESTING.zh-CN.md`
- AI 配置：`services/myapp-ai/docs/CONFIGURATION.zh-CN.md`
- Web AI 设计：`frontend/myapp-web/AI_WEB_FRONTEND_DESIGN.zh-CN.md`
- Web 请求结果契约：`frontend/myapp-web/REQUEST_RESULT_CONTRACT.zh-CN.md`
