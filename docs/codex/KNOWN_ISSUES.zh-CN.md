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
