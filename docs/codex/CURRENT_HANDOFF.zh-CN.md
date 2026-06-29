# 当前交接状态

更新时间：2026-06-29

本文件用于跨新会话交接当前项目状态。长期规则不要写在这里，应写入 `AGENTS.md` 或 `docs/codex/DEVELOPMENT_GUIDE.zh-CN.md`。

## 当前目标

- Codex 新会话启动所需的项目规则、文档索引和交接机制已建立并提交。
- 后端商品多条码能力已完成并提交，父仓库 `apps/myapp` 指针已提交。
- Web 商品模块已完成多条码、CSV 导入导出和列表布局优化，已复核、验证并提交。
- 单位展示/换算通用模块使用规则已补充到 `AGENTS.md` 和 `docs/codex/DEVELOPMENT_GUIDE.zh-CN.md`，当前发现的单据链路 UOM 展示缺口已记录到 `docs/codex/KNOWN_ISSUES.zh-CN.md`。

## 仓库状态

- 父仓库：UOM 文档规则更新准备随本次文档提交完成；`.codex` 是既有未跟踪目录，不处理。
- 后端 `apps/myapp`：最后检查时工作区干净；后端商品多条码测试提交已完成。
- Web `frontend/myapp-web`：商品模块相关改动已提交，工作区干净。

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

## 未完成事项

- 待修复单据链路 UOM 展示缺口：
  - 后端销售/采购单据行项目序列化补 `uom_display`。
  - 退货来源上下文透传 `uom_display`。
  - Web 退货页改用 `resolveDisplayUom(record.uom, record.uomDisplay)`。
  - 编辑页商品详情加载失败的 fallback 行需要明确降级或补足单位上下文。
- 父仓库当前提交完成后，仅剩本地提交尚未推送到远端。
- `.codex` 是既有未跟踪目录，不处理。

## 下一步建议

1. 修复后端销售/采购/退货单据链路的 `uom_display` 返回契约，并补测试。
2. 修复 Web 退货页和编辑页 fallback 的单位展示/换算降级路径。
3. 如需交付远端，分别推送父仓库、后端 `apps/myapp` 和 Web `frontend/myapp-web` 的本地提交。
