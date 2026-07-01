# 当前交接状态

更新时间：2026-07-01

本文件用于跨新会话交接当前项目状态。长期规则不要写在这里，应写入 `AGENTS.md` 或 `docs/codex/DEVELOPMENT_GUIDE.zh-CN.md`。

## 当前目标

- Codex 新会话启动所需的项目规则、文档索引和交接机制已建立并提交。
- 后端商品多条码能力已完成并提交，父仓库 `apps/myapp` 指针已提交。
- Web 商品模块已完成多条码、CSV 导入导出和列表布局优化，已复核、验证并提交。
- 单位展示/换算通用模块使用规则已补充到 `AGENTS.md` 和 `docs/codex/DEVELOPMENT_GUIDE.zh-CN.md`；单据链路 UOM 展示缺口已完成修复并记录为防回归事项。
- 库存写操作第一批已完成：后端新增库存转仓与单品单仓目标库存校准接口，Web 新增库存转仓页，并将库存调整页切到显式库存 API。
- Web 待处理确认工作台已完成：聚合核心草稿业务单据，并通过后端 `confirm_pending_document` 提交确认。
- 仓库管理第一版、原生治理字段扩展和 CSV 导入导出已完成：后端新增仓库主数据 API，Web 新增 `/master-data/warehouses` 列表和维护页，并补齐 ERPNext 原生仓库治理字段。
- 客户 / 供应商已升级为企业级第一版：共用往来单位治理页面，支持详情抽屉、主联系人 / 主地址、最近地址、CSV 导入导出和基础治理字段维护。

## 仓库状态

- 父仓库：工作区干净，仅 `.codex` 是既有未跟踪目录，不处理；本地 `develop` 当前领先远端 30 个提交。
- 后端 `apps/myapp`：工作区干净；本地 `develop` 当前领先远端 27 个提交。
- Web `frontend/myapp-web`：工作区干净；本地 `main` 当前领先远端 49 个提交。

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

## 已验证

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

本地 Web 开发服务器：

```text
http://localhost:8003
```

## 未完成事项

- 父仓库、后端和 Web 当前仅剩本地提交尚未推送到远端。
- `.codex` 是既有未跟踪目录，不处理。
- 库存完整批量盘点单和盘点单生命周期仍未接入 Web。
- 待处理确认当前覆盖核心草稿业务单据提交；如后续需要工作流动作审批，需要补 action 列表/状态来源。
- 客户 / 供应商已覆盖企业级第一版；联系人 / 地址多条独立维护、信用 / 账期 / 付款条款 / 税务 / 交易历史聚合、应收应付钻取、标签归属和审计记录仍未接入。
- 仓库管理已覆盖 ERPNext 原生基础治理字段和 CSV 导入导出；库位 / 容量、负责人、默认成本中心、仓库权限、审计记录和更细粒度治理仍未接入。

## 下一步建议

1. 如需交付远端，分别推送父仓库、后端 `apps/myapp` 和 Web `frontend/myapp-web` 的本地提交。
2. 后续库存模块可继续补批量盘点单、盘点单确认/作废生命周期和相关权限收口。
3. 待处理确认后续可扩展工作流 action、更多单据类型和真实浏览器联调。
