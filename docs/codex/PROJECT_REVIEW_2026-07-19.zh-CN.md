# 全项目代码审查报告（2026-07-19）

## 1. 审查范围

- 父仓库：Compose、staging、Secret 与运行文档
- Backend：`apps/myapp`
- AI Orchestrator：`services/myapp-ai`
- Web：`frontend/myapp-web`
- Mobile：`frontend/myapp-mobile`

本次审查为只读审查；除 AI 草稿一致性修复及本报告外，未实施下述风险修复。

## 2. 本轮已提交内容

- Backend：`d9c12b1 fix: protect AI draft updates`
- Web：`3a6e841 fix: keep AI draft edits consistent`
- 父仓库 Backend 指针：`7e9c628c fix: update AI draft consistency backend`

本轮提交尚未推送远端。

## 3. 高优先级发现

### 3.1 Backend 交易写接口缺少记录级权限校验

销售订单与采购订单更新链路直接 `frappe.get_doc`，未执行 `check_permission("write")`；销售订单保存还设置 `ignore_permissions`，已提交采购订单则通过 `db_set` 修改。只要登录用户知道单号，就可能绕过标准记录权限修改业务数据。

主要位置：

- `apps/myapp/myapp/services/order_service.py`：`_get_sales_order_doc_for_update`、`_save_sales_order_after_update`、`update_order_v2`
- `apps/myapp/myapp/services/purchase_service.py`：`_get_purchase_order_doc_for_update`、`update_purchase_order_v2`

建议统一增加读、写、提交、取消权限检查，并补普通用户、跨公司、User Permission 和无权单据的 HTTP 回归。

### 3.2 Backend 工作台查询绕过记录权限

销售/采购状态摘要和搜索使用 `frappe.get_all`。该 API 不应用 Frappe 记录权限过滤，因此可能向普通登录用户返回其无权查看的订单、客户、供应商、金额和履约信息。

主要位置：

- `apps/myapp/myapp/services/order_service.py`：`get_sales_order_status_summary`、`search_sales_orders_v2`
- `apps/myapp/myapp/services/purchase_service.py`：`get_purchase_order_status_summary`、`search_purchase_orders_v2`

建议改用带权限的查询，或显式合并 Frappe permission query conditions，并保证关联单据聚合只处理可见主单据。

### 3.3 大量交易写接口未限制 POST

销售、采购、收发货、开票、付款、退货和取消接口大量使用无 `methods` 参数的 `@frappe.whitelist()`。这些写接口可被 GET 调用，增加 CSRF、误触发、代理缓存和审计语义错误风险。

主要位置：

- `apps/myapp/myapp/api/gateway.py`
- `apps/myapp/myapp/api/orders_api.py`
- `apps/myapp/myapp/api/purchase_api.py`

建议所有变更状态的接口统一声明 `@frappe.whitelist(methods=["POST"])`，并增加 GET 返回 405 的 HTTP 测试。

### 3.4 白名单维护脚本可批量修改商品

`myapp.scripts.backfill_item_nickname_and_specification.run` 对所有登录用户开放；传入 `commit=1` 后会扫描全部启用商品并通过 `db_set` 批量修改字段，没有 System Manager、角色或 Item 写权限检查。

位置：`apps/myapp/myapp/scripts/backfill_item_nickname_and_specification.py`

建议移除白名单入口，或强制 System Manager/专用维护角色，并逐项执行权限、审计和 dry-run 确认。

### 3.5 持久化幂等存在业务已提交但记录永久 processing 的窗口

`run_idempotent` 先执行 callback，再写缓存并把幂等记录标记为 `succeeded`。多个 callback 内部会主动 `frappe.db.commit()`。如果进程在业务提交后、幂等成功记录落库前退出，同一 request ID 之后只会等待并提示“处理中”；清理任务又只删除终态记录，不处理过期 `processing`。

主要位置：

- `apps/myapp/myapp/utils/idempotency.py`：`_wait_for_record_result`、`_execute_and_store_result`、`cleanup_expired_idempotency_records`
- `apps/myapp/myapp/services/ai_service.py`：AI 草稿更新 callback 内部提交

建议让业务结果与幂等成功状态处于同一数据库事务，或为 processing 增加 owner/lease、超时接管和结果对账机制，并补进程崩溃窗口测试。

## 4. 中优先级发现

### 4.1 Web 与 Mobile Web 把长期凭据放入 localStorage

Web 保存 access token 和 refresh token；Mobile Web 保存 Bearer token 和 CSRF token。任何同源 XSS 都可读取并带走长期 refresh token，目前项目内也未发现明确 CSP 配置。

主要位置：

- `frontend/myapp-web/src/services/myapp/auth-storage.ts`
- `frontend/myapp-mobile/lib/auth-storage.ts`

建议优先使用 Secure、HttpOnly、SameSite Cookie 保存 refresh token；access token 仅保存在内存或使用更短生命周期，并配置严格 CSP。

### 4.2 AI 内部 Token 默认值未完全失败关闭

AI Orchestrator 在未配置环境变量时使用公开的开发默认 Token；staging Compose 也提供可预测 fallback。标准脚本会校验 staging env，但绕过脚本直接启动 Compose 或独立启动服务时仍可能带着已知 Token 运行。

主要位置：

- `services/myapp-ai/myapp_ai/config.py`
- `deploy/staging/compose.staging.yaml`

建议生产/staging 使用 `${VAR:?required}`，并在 Orchestrator 启动时拒绝默认值、占位值和过短 Token。

### 4.3 Gateway 向客户端返回原始 500 异常文本

Gateway 对未知异常映射为 500 后仍将 `str(exc)` 直接写入响应，可能泄露数据库表名、约束、Provider 返回内容或内部实现细节。

主要位置：

- `apps/myapp/myapp/api/gateway.py`：`_handle_gateway_call`
- `apps/myapp/myapp/utils/api_response.py`：`map_exception_to_error`

建议 500 仅返回稳定错误码、通用文案和 request ID，详细异常只写服务端日志。

### 4.4 Mobile 部分采购与退货页面直接显示 UOM 编码

Mobile service 已映射部分 `uomDisplay`，但采购收货和退货页面仍直接渲染 `item.uom`、`group.uom` 或 `line.uom`，自定义 UOM 展示名会与 Web、打印和主数据不一致。

主要位置：

- `frontend/myapp-mobile/components/return-create-screen.tsx`
- `frontend/myapp-mobile/app/purchase/receipt/create.tsx`

建议统一使用 `resolveDisplayUom`，并确认收货、发票、退货 service 全程保留 `uomDisplay`。

## 5. 测试与治理缺口

- 销售/采购 Gateway 缺少无权限用户、跨公司和 User Permission 的 HTTP 回归。
- 写接口缺少 GET 必须返回 405 的契约测试。
- 幂等测试覆盖成功、失败和重试，但未覆盖 callback 已提交后进程退出、缓存写失败和过期 processing 接管。
- Token 存储测试验证了 localStorage 行为，但没有安全架构门禁或 CSP 验证。
- Mobile UOM 展示缺少自定义 `uom_display` 回归。

## 6. 建议修复顺序

1. 先封堵 Backend 记录权限与写接口 HTTP 方法问题。
2. 关闭白名单维护脚本的普通用户入口。
3. 重构持久化幂等事务与 processing 租约恢复。
4. 收敛 Web/Mobile Token 存储和部署 Token 默认值。
5. 修复 Gateway 500 信息泄露与 Mobile UOM 展示。
6. 为以上边界补 HTTP、并发、崩溃恢复和自定义 UOM 测试。
