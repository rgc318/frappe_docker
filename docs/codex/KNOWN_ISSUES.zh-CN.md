# 已知问题与处理方式

本文档记录本项目中反复遇到、容易误判或需要固定处理方式的问题。新问题只有在具有长期复用价值时才加入这里。

## 1. 宿主机 Python 无法导入 Frappe

现象：

```text
ModuleNotFoundError: No module named 'frappe'
```

常见触发方式：

```bash
python3 -m unittest apps.myapp.myapp.tests.unit.test_wholesale_service
```

原因：

- Frappe 服务层测试依赖 bench 环境。
- 宿主机 Python 通常没有加载 `/home/frappe/frappe-bench` 的虚拟环境和依赖。

正确方式：

```bash
docker exec frappe_docker-backend-1 bash -lc '
  cd /home/frappe/frappe-bench &&
  env/bin/python -m unittest apps.myapp.myapp.tests.unit.test_wholesale_service
'
```

关键点不是“是否进入容器”，而是“是否使用 bench 虚拟环境 Python”。

可检查 Frappe 是否可导入：

```bash
docker exec frappe_docker-backend-1 bash -lc '
  cd /home/frappe/frappe-bench &&
  env/bin/python -c "import frappe; print(frappe.__version__)"
'
```

## 2. 容器内系统 Python 也可能失败

现象：

```text
ModuleNotFoundError: No module named 'frappe'
ModuleNotFoundError: No module named 'orjson'
```

原因：

- `/usr/local/bin/python` 或系统 `python3` 不等于 bench Python。
- 即使命令在 backend 容器内执行，也可能没有使用正确虚拟环境。

处理：

始终使用：

```text
/home/frappe/frappe-bench/env/bin/python
```

## 3. Web useRequest 返回 undefined

现象：

- 详情页显示空态。
- service 明明返回了对象，页面 `data` 却是 `undefined`。

原因：

- `@umijs/max` 的 `useRequest` 默认会取 `result?.data`。
- 本项目领域 service 已经完成响应解包，通常直接返回业务对象。

处理：

```ts
const { data } = useRequest(() => getSalesOrderDetail(orderName), {
  formatResult: (result) => result,
  refreshDeps: [orderName],
});
```

完整说明见：

```text
frontend/myapp-web/REQUEST_RESULT_CONTRACT.zh-CN.md
```

## 4. Umi dev server 旧 chunk 或 MIME 类型错误

现象：

```text
Unexpected token '<'
Refused to apply style ... MIME type ('text/html')
```

原因：

- dev server 重启、重新编译或浏览器缓存导致旧 chunk 文件名失效。
- 浏览器请求旧 JS/CSS，服务端 fallback 返回 HTML。
- 同一工作区可能同时启动了多个 dev server。

处理：

1. 停止多余的 Umi dev server。
2. 强刷浏览器。
3. 必要时清理缓存后重启：

```bash
cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
rm -rf src/.umi src/.umi-production node_modules/.cache dist
npm run start:dev -- --port 8001
```

注意：

- 项目通过 `public/umi.css` 为 dev HTML 引用提供空 CSS 兜底，不要随意删除。

## 5. 商品列表字段挤压

现象：

- 商品编码强制换行。
- 名称、规格、价格、条码等列互相挤压。
- 操作列被推到不可见区域。

处理原则：

- 使用 ProTable 官方能力：`width`、`ellipsis`、`fixed`、`scroll.x`、`columnsState`。
- 高频字段保留在主视图。
- 低频价格或辅助字段默认隐藏，允许用户通过列设置打开。
- 操作列固定右侧。
- 编码、条码等长文本用单行省略和 tooltip。

## 6. Web 批量导入的当前边界

当前商品 CSV 导入是前端小批量能力：

- 使用 `Upload + Modal + ProTable` 预览。
- `create` 调用 `createProduct`。
- `update` 按商品编码调用 `updateProduct`。
- 按行顺序执行，不新增后端批量导入接口。

适用：

- 小批量维护。
- 运营人员临时补录或修正。

不适用：

- 大数据量导入。
- 需要异步任务、错误报告下载、回滚和审批的正式治理流程。

后续如进入企业级大批量导入，应设计后端异步导入任务、导入批次、错误明细、审计记录和权限控制。

## 7. 多条码能力边界

ERPNext 原生支持 `Item Barcode` 子表，本项目后端也已围绕商品详情和条码管理补充接口。

当前约定：

- `barcode` 是主条码兼容字段。
- `barcodes[]` 是完整条码列表。
- 页面展示条码管理时优先使用 `barcodes[]`。
- 商品列表可展示主条码和多条码数量。
- 搜索应继续支持条码命中。

相关 Web service：

- `addProductBarcode`
- `setPrimaryProductBarcode`
- `deleteProductBarcode`

相关后端接口：

- `add_product_barcode_v2`
- `set_primary_product_barcode_v2`
- `delete_product_barcode_v2`

## 8. 单据链路单位展示防回归

历史现象：

- 商品详情、商品列表、新建销售/采购订单等路径可以正确使用 `uom_display`、`all_uoms` 和换算系数。
- 但已保存单据详情、退货来源上下文、编辑页 fallback 行可能只拿到 `uom`，前端只能靠静态 fallback 显示单位。
- 当数据库 `UOM` 主数据维护了新的中文展示名、`symbol` 或自定义单位时，这些页面可能显示不一致。

已修复的缺口：

- `apps/myapp/myapp/services/order_service.py` 的销售订单、发货单、销售发票行项目序列化已返回 `uom_display`。
- `apps/myapp/myapp/services/purchase_service.py` 的采购订单、采购收货、采购发票行项目序列化已返回 `uom_display`。
- `apps/myapp/myapp/services/return_service.py` 的退货来源上下文已透传 `uom_display`。
- `frontend/myapp-web/src/pages/Sales/Returns/New.tsx` 和 `frontend/myapp-web/src/pages/Purchase/Returns/New.tsx` 已改为消费后端 `uomDisplay`。
- 销售/采购编辑页从已有单据 fallback 构造行项目时，已保留当前行的 `uomDisplay`，并把当前单位作为 1:1 降级换算上下文。

处理原则：

- 后端单据序列化函数应使用 `myapp.utils.uom_display.build_uom_display_map`，凡是返回 `uom` 的行项目都同时返回 `uom_display`。
- 退货上下文应从来源单据明细透传 `uom_display`。
- 前端退货页应改为 `resolveDisplayUom(record.uom, record.uomDisplay)`。
- 编辑页 fallback 行如果无法加载商品详情，应保留单据行已有 `uomDisplay`，并只提供当前单位的降级选项；能加载商品详情时必须使用商品接口返回的 `all_uoms` 和 `conversion_factor`。
- 相关改动必须保留后端序列化测试和 Web service 映射测试，覆盖自定义单位展示名。

## 9. LiteLLM Chat 因 request_timeout 为空而全局失败

现象：

```text
litellm.APIConnectionError: float() argument must be a string or a real number, not 'NoneType'
```

- `/v1/models` 可以正常返回。
- `/v1/embeddings` 可能仍然正常。
- 多个不同聊天模型的 `/v1/chat/completions` 都在路由前返回 HTTP 500。

原因：

- LiteLLM 全局 `request_timeout` 被解析为 `None`。
- Chat completion 的 timeout resolver 会执行 `float(litellm.request_timeout)`，因此不是某一个供应商模型故障，也不是 Frappe、Qdrant 或 Embedding 故障。

处理：

在 LiteLLM 服务端配置中显式设置数值，例如：

```yaml
litellm_settings:
  request_timeout: 60
```

重启 LiteLLM 后分别验证一个聊天别名和 Embedding 别名。不要只检查 `/v1/models`，因为模型注册成功不代表 Chat 路由已经可调用。

如果业务侧 API Key 对 `/config/list` 等管理端点返回 403，必须由 LiteLLM 管理员在服务端修复，不能通过普通推理 Key 修改全局配置。
