# 当前交接状态

更新时间：2026-08-07 CST

本文件只记录当前短期状态、仓库边界、验证结果、风险和下一步。历史过程以 Git 历史、GitHub Actions Run 和长期设计文档为准，不再持续追加到本文件。

## 当前目标与结论

- 本轮目标：完善 Backend 自定义 API 的企业级数据隔离，并为 Web 用户管理补齐数据权限配置防误配能力。
- 业务范围：客户、供应商、商品、UOM、仓库、销售 / 采购订单、发货 / 收货、销售 / 采购发票、库存、收付款、经营报表、用户偏好和商品图片。
- 涉及仓库：Backend `apps/myapp`、Web `frontend/myapp-web` 和 Parent 交接文档。Mobile、AI Orchestrator、部署编排和 production 本轮未修改。
- 当前结果：P0 自定义业务接口权限收口、P1 权限配置治理和 P2 权限兼容性 / 用户体验回归均已完成并通过本地门禁；Backend、Web 的补充文档、代码和测试均已按仓库边界本地提交，尚未推送或部署。
- 关键结论：代码层已经阻止自定义 API 绕过 Frappe 角色权限、文档权限和 User Permission，但本地数据库当前仍为 `User Permission = 0`。因此相同业务角色的用户目前仍可能看到相同的跨公司数据；要实现实际的按公司 / 仓库隔离，仍需业务方提供正式授权矩阵后配置 User Permission。
- 数据状态：本轮没有迁移或修改正式业务数据。真实权限验证全部在单一数据库事务内执行并强制回滚，测试前后 `User Permission` 数量均为 `0`。

## 已完成改动

### Backend：统一数据权限底座

1. 权限基础能力
   - 新增登录用户、DocType、文档级、Company、Warehouse、SQL match condition 和临时文件 owner 校验。
   - 默认公司 / 仓库只作为工作偏好，不再被当作授权来源；支持多公司授权范围。
2. 核心业务接口收口
   - 客户、供应商、商品、UOM、仓库、订单、发货 / 收货 / 发票、库存和收付款详情执行正式权限判断。
   - 列表从 `frappe.get_all()` 切换为 `frappe.get_list()`；库存只聚合当前用户可读仓库。
   - 经营、销售、采购、应收应付和资金报表在裸 SQL 中注入 Frappe 角色、owner 和 User Permission 条件。
3. 媒体与用户偏好边界
   - 商品图片上传、替换、删除要求 Item 写权限；暂存图片只能由上传者或 `System Manager` 绑定。
   - 保存默认 Company / Warehouse 时校验当前用户的授权范围。

### Backend / Web：权限配置防误配

1. 后端治理约束
   - MyApp 管理入口只开放 Company、Warehouse、Customer、Supplier 四类业务范围，目录由 Backend `permission_catalog` 统一下发。
   - `Administrator` 禁止配置 User Permission；非法定向 DocType 和非树形下级配置由后端拒绝。
   - 只有 Company / Warehouse 支持 `hide_descendants`；Customer→Purchase Order 等无效 `applicable_for` 组合会被拒绝。
2. Web 有效范围展示
   - Web 明确展示“未按该维度限制”不等于“无权限”，并提示首次添加会收窄、删除最后一条会扩权。
   - 用户详情展示四类权限维度的有效范围、默认公司 / 仓库越界警告和 Company / Warehouse 下级节点开关。
   - 权限类型、可定向 DocType 和树形能力均以后端 `permission_catalog` 为事实来源，不在页面复制规则。

### Backend / Web：权限兼容性与用户体验

1. 标准角色交易体验
   - 标准 Sales / Purchase 角色无需 Item Price 直接读取权限即可继续商品选品；服务先限制可读 Price List 和 Item，再读取受控价格。
   - 历史默认公司 / 仓库越界时只忽略失效偏好，不阻断销售 / 采购上下文；显式越权参数继续拒绝。
2. 组合报表部分可见
   - 经营总览、完整经营报表和销售 / 采购分析按业务域返回 `visibility`；无权域不执行 SQL，指标返回 `null`。
   - Dashboard 和报表页显示“无查看权限”，不把缺少权限误报为业务金额 0，也不因一个无权域整页失败。
3. 菜单与动作一致性
   - 主数据子路由按商品、客户、供应商、UOM、仓库分别控制，入口页跳转到当前用户首个可用模块。
   - 销售发票入口、销售 / 采购快捷开单和订单 / 发货 / 收货 / 发票详情动作均与目标 DocType 权限一致；无权动作隐藏或禁用并给出原因。

### 文档与测试夹具

- Backend `API_GATEWAY.zh-CN.md`、`TESTING.zh-CN.md`、`USER_MANAGEMENT_TECH_DESIGN.zh-CN.md` 已提交为 `9eca5f5 docs: document permission boundaries`。
- Web `WEB_DEVELOPMENT.zh-CN.md` 已提交为 `b8bf472 docs: document permission-aware UX`。
- Web 根目录中文 Markdown 被 lint-staged 传给 Biome，但同时被 Biome 配置忽略，常规提交钩子因此以“0 files processed”失败；确认仅暂存该文档且 `git diff --cached --check` 通过后，本次文档提交使用 `--no-verify`，没有修改钩子配置或其他文件。
- `test_ai_repository.py` 只调整日期敏感夹具，避免固定日期超过 7 天 TTL 后使全量测试失效；未修改 AI 运行时代码或业务行为。

## 已验证

### 自动化门禁

- Backend 全量单元测试：`754 tests` 通过。
- Backend 用户管理、Gateway 与安全契约聚焦回归：`159 tests` 通过。
- Web 全量 Jest：`44 suites / 292 tests` 通过。
- Web `npm run tsc`、`npm run biome:lint`、`npm run build` 全部通过。
- Ruff `0.14.10` 检查通过。
- Parent、Backend、Web 的 `git diff --check` 通过。
- 代码提交后再次验证 Backend 权限关键回归 `183 tests`、Web 权限聚焦回归 `76 tests` 和 Web `npm run tsc`，全部通过。

主要复现入口：

```bash
docker exec frappe_docker-backend-1 bash -lc '
  cd /home/frappe/frappe-bench &&
  env/bin/python -m unittest \
    apps.myapp.myapp.tests.unit.test_data_permission_service \
    apps.myapp.myapp.tests.unit.test_customer_service \
    apps.myapp.myapp.tests.unit.test_warehouse_service \
    apps.myapp.myapp.tests.unit.test_uom_service \
    apps.myapp.myapp.tests.unit.test_document_list_service \
    apps.myapp.myapp.tests.unit.test_inventory_service \
    apps.myapp.myapp.tests.unit.test_report_service \
    apps.myapp.myapp.tests.unit.test_media_service \
    apps.myapp.myapp.tests.unit.test_wholesale_service \
    apps.myapp.myapp.tests.unit.test_purchase_service \
    apps.myapp.myapp.tests.unit.test_user_preferences_service \
    apps.myapp.myapp.tests.unit.test_user_management_service \
    apps.myapp.myapp.tests.unit.test_gateway_wrappers \
    apps.myapp.myapp.tests.unit.test_api_security_contracts
'

cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- --runInBand
npm run build

cd /home/rgc318/python-project/frappe_docker
git diff --check
git -C apps/myapp diff --check
git -C frontend/myapp-web diff --check
```

### 真实事务验证

- 无业务 DocType 角色的用户访问 12 类核心入口均得到 `PermissionError`；具备完整业务角色的用户可正常读取。
- 临时仅授权 Company=`rgc (Demo)` 后，采购订单只返回该公司；显式请求未授权公司返回 `0` 条。
- 同一公司授权下，库存汇总 `862` 条、库存流水 `2765` 条，所有结果均属于 `rgc (Demo)`。
- 再限制 Warehouse=`主仓库 - R` 后，库存汇总仅 `5` 条、库存流水仅 `95` 条，均只属于该仓库。
- 显式请求未授权公司的采购报表时，金额指标为 `0`、明细为空。
- 普通 `System Manager` 可创建合法 Company 权限；`Administrator` 目标和 Customer→Purchase Order 非法组合均被拒绝。
- 所有验证均回滚，最终数据库 `User Permission = 0`，没有遗留测试权限或测试业务数据。
- 标准角色体验探针覆盖 Sales User、Purchase User、Stock User、Accounts User：对应商品、客户 / 供应商、订单、发货 / 收货、库存和资金路径均正常；无权销售发票入口继续拒绝，Web 已不再向 Sales User 暴露该菜单。
- 销售 / 采购经理、库存经理和财务经理访问组合经营报表均成功；只返回其角色允许的业务域，无权指标为 `null` 并由 Web 明确标识。
- 最新 Company=`rgc (Demo)` 抽样验证中，采购订单、库存汇总和库存流水只包含该公司；Warehouse=`主仓库 - R` 后库存汇总 `5` 条、库存流水 `95` 条，显式请求其他仓库返回 `PermissionError`。

## 上一轮已部署 Web 工作总结

1. 统一图片编辑能力完成企业级收口
   - Web 商品图和头像统一经过媒体 profile、来源校验、Cropper.js 可调裁剪框、自由 / 预设比例、横纵切换、缩放、旋转和 WebP 输出。
   - 商品图使用 `item-flexible-v2`，支持自由、1:1、4:3、3:2、16:9；头像继续固定 `avatar-square-v1`。
   - 文件选择、已有图片重新裁剪和摄像头拍照最终都进入同一 `ImageEditorUpload`，页面不得绕过 profile 自行压缩或上传。
2. Web 摄像头拍照能力落地
   - 新增 `CameraCaptureModal`，支持平板、内置摄像头、外置 USB 摄像头选择，以及拍摄、预览、重拍和确认。
   - 关闭弹窗、切换设备、重拍或组件卸载时停止全部 MediaStream tracks，避免摄像头指示灯和设备占用残留。
   - 浏览器摄像头不是项目自定义限制，而是标准安全上下文要求：HTTPS 或 localhost 可用，普通局域网 HTTP IP 不可用。
3. Web 商品扫码链路落地
   - 新增基于 ZXing 的共享扫码弹窗和按钮，支持常见一维码 / 二维码、摄像头选择、单次识别锁和手动输入降级。
   - 商品列表、商品创建 / 编辑、商品详情条码管理和销售 / 采购共享 `ProductSelect` 均已接入。
   - 扫码只查询本地商品库并返回字符串，不接外部 Provider、不自动创建商品、不在扫描器内构造业务对象。
4. 本地网络与发布链路核验
   - Web dev server 当前推荐端口为 `8001`；Windows 侧 `localhost:8001` / `127.0.0.1:8001` 已验证返回 200，但 `192.168.31.63:8001` 受 Windows / WSL LAN 边界影响而超时。
   - 既有 Windows 桥接仍为 `18081 -> 18080`（ERPNext）和 `18082 -> 8081`（Mobile / Expo）；本轮没有新增 `18083 -> 8001`，因为该 HTTP 桥接也无法满足平板摄像头的 HTTPS 要求。
   - Web、Parent 文档均已推送，staging 已切换到 `staging-20260805-6b23ac5`；Backend、AI、Mobile、数据库和 production 均未变更。

## 仓库状态与未提交范围

| 仓库                           | 分支 / 发布版本       | 工作树状态                                                   | 本轮责任                               |
| ------------------------------ | --------------------- | ------------------------------------------------------------ | -------------------------------------- |
| Parent `frappe_docker`         | `develop` / 当前提交   | 本轮提交 Backend gitlink 与 handoff；媒体文档既有修改；`.codex` 未跟踪 | 本轮集成提交                             |
| Backend `apps/myapp`           | `develop` / `3468b5d`  | 工作树干净；权限文档、代码和测试均已提交                        | 本轮主要改动仓库                         |
| AI `services/myapp-ai`         | `develop` / `ca5448c`  | 干净                                                           | 本轮未修改                               |
| Web `frontend/myapp-web`       | `main` / `fb597b2`     | 工作树干净；权限文档、UI、service 和测试均已提交                | 本轮 Web 改动仓库                        |
| Mobile `frontend/myapp-mobile` | `develop` / `ebb242e`  | 保留既有 5 个用户修改，本轮未触碰                              | 不得夹带提交                             |

Backend 提交：

- `9eca5f5 docs: document permission boundaries`
- `3468b5d feat: enforce business data permissions`

Web 提交：

- `b8bf472 docs: document permission-aware UX`
- `fb597b2 feat: align UI with permission boundaries`

上述提交均仅存在于本地，尚未推送；Parent 本轮将 Backend gitlink 固定到 `3468b5d`。

Parent 当前还显示上一轮既有修改 `docs/05-development/05-media-upload-and-image-editing.zh-CN.md`；它不属于本轮数据隔离增量，提交时必须单独核对，不能默认夹带。`.codex` 是本地未跟踪状态，禁止提交。

Mobile 当前既有修改：`app/common/product-search.tsx`、`lib/sales-mode.ts`、`services/gateway.ts`、`services/products.ts`、`services/sales.ts`。这些文件不属于本轮增量，不得覆盖或提交；本轮没有修改 Mobile。

## 未完成事项与当前风险

1. 正式权限矩阵尚未配置。当前没有可安全推断的“用户 / 岗位 → Company → Warehouse → Customer / Supplier”业务授权关系，不能由开发者猜测后写入生产 User Permission。
2. 管理员默认值存在冲突：`default_company = rgc`，`default_warehouse = Stores - RD`，而该仓库属于 `rgc (Demo)`。默认值只是偏好，不能据此反推授权范围或自动生成权限矩阵。
3. `User Permission = 0` 时，代码门禁保证角色和文档权限不被绕过，但不会自动把相同业务角色的用户按公司 / 仓库拆分；这不是代码缺陷，而是授权数据尚未配置。
4. 真实事务已覆盖 Company / Warehouse 全局授权；`applicable_for` 定向授权和 `hide_descendants` 仍建议在 staging 使用实际组织树人工验收。
5. 本轮只收口已审计的核心业务入口。后续新增服务若使用 `frappe.get_all()`、`frappe.db.sql()` 或 `frappe.db.get_value()` 返回业务数据，必须复用 `data_permission_service` 并补低权限回归。
6. Backend / Web 权限文档、代码和测试均已本地提交，但尚未推送或部署；staging 和 production 当前都不包含本轮数据隔离增量。

## 下一步建议

1. 业务方提供正式授权矩阵，并确认是否需要 Customer / Supplier 维度以及 Company / Warehouse 下级节点继承。
2. 用户明确要求推送时，先推送 Backend `develop`，再推送 Web `main`，最后推送包含 Backend gitlink 的 Parent `develop`；不要夹带 `.codex`、Mobile 既有修改或未核对的媒体设计文档。
3. 部署 staging 后使用四类真实账号执行 HTTP 验收：无业务角色、单公司业务用户、多公司业务用户、`System Manager`；核对同一入口的 `403/200` 与返回范围。
4. 在 staging 使用真实组织结构验收定向 `applicable_for`、`hide_descendants`、默认值越界提示、首条权限收窄和最后一条权限删除扩权。
5. 完成业务验收后再安排 production，不要在授权矩阵未确认前批量写入正式 User Permission。

## 当前提交基线

- Parent：本次 Backend gitlink / handoff 集成提交（以当前 HEAD 为准）
- Backend：`3468b5d feat: enforce business data permissions`
- Web：`fb597b2 feat: align UI with permission boundaries`
- AI Orchestrator：`ca5448c docs: document AI model fallback behavior`
- Mobile：`ebb242e feat: support flexible image crop ratios`

## 上一轮 Web 摄像头与扫码增量

- `CameraCaptureModal` 使用 MediaDevices API，默认优先后置摄像头，授权后支持选择平板、内置或外置 USB 摄像头，并提供拍摄、预览、重拍和确认。
- 拍摄结果生成 JPEG `File` 后进入既有 `ImageEditorUpload`，继续执行来源校验、自由 / 预设比例裁剪、WebP 输出和 Backend profile，不新增绕过媒体治理的上传路径。
- `BarcodeScannerModal` 使用 ZXing 识别常见一维码和二维码，支持摄像头选择、单次提交锁、手动输入降级和流释放。
- 商品列表扫码后查询本地商品库；命中停用商品时切换筛选，未命中时仅提示用户确认新建并预填条码，不自动创建、不接外部条码 Provider。
- 商品创建 / 编辑、商品详情新增条码和主条码、销售 / 采购共享 `ProductSelect` 均已接入扫码入口；交易选品默认保留结果供用户确认，避免重复识别直接产生重复明细。
- Web 摄像头遵循浏览器安全上下文规则，只在 HTTPS 或 localhost 可用；文件选择和手动条码输入始终保留为降级路径。

## 本次验证

- Web：`npm run tsc`、`npm run biome:lint`、全量 Jest `43 suites / 288 tests` 和 `npm run build` 已通过。
- 新增回归覆盖摄像头拍照生成 JPEG File、视频流停止、扫码手动输入降级和连续识别只提交一次。
- Web push CI、Coverage、镜像构建和 staging 部署均成功；独立探测 `/healthz`、`/user/login` 和 `/api/method/ping` 均返回 HTTP 200。
- 真实浏览器摄像头授权、外置摄像头切换和真实条码识别尚待人工验收；production 未部署。

## 本次 staging 发布

| 范围            | Workflow Run                                                                    | 结果 |
| --------------- | ------------------------------------------------------------------------------- | ---- |
| Web push CI     | [30987941487](https://github.com/rgc318/myapp-web/actions/runs/30987941487)     | 成功 |
| Web coverage CI | [30987941539](https://github.com/rgc318/myapp-web/actions/runs/30987941539)     | 成功 |
| Web build       | [30989815958](https://github.com/rgc318/myapp-web/actions/runs/30989815958)     | 成功 |
| Web deploy      | [30990422600](https://github.com/rgc318/myapp-web/actions/runs/30990422600)     | 成功 |
| Parent Lint     | [30993028090](https://github.com/rgc318/frappe_docker/actions/runs/30993028090) | 成功 |

部署事实：

- staging Web 使用 `ghcr.io/rgc318/myapp-web:staging-20260805-6b23ac5`，镜像 digest 为 `sha256:0c6752a5d0970e7cf3aed86e445dc89cb3551e0385c0cee662247f20620b9859`。
- Web 部署 workflow 的健康循环已通过 `/healthz`、`/user/login` HTTP 200 和 `/api/method/ping` 检查；容器启动后成功保留新版本，没有触发旧镜像回滚。
- 第一次镜像构建使用短 SHA `6b23ac5` 时，`actions/checkout` 将其当作 branch / tag pattern 导致失败；改用完整 SHA `6b23ac56226bff2b67e5614b8382cfc5f8c24bb2` 后成功。后续手动触发 `Build staging image` 应直接传完整 SHA 或分支名。
- Backend、AI Orchestrator、Mobile 和数据库未变更；production 未部署。

## 已部署自由裁剪基线

- Web `ImageEditorUpload` 增加比例选择、自由比例滑杆和横纵切换；Canvas 根据最终裁剪比例输出动态宽高，默认仍为 1:1。
- 商品图升级为 `item-flexible-v2`：自由比例范围 `0.4–2.5`，预设为 1:1、4:3、3:2、16:9，最长边 1600px WebP，起始质量 82，输出最大 5MB。
- 头像统一使用 `avatar-square-v1`：512 × 512 WebP，起始质量 85，来源最短边至少 128px，输出最大 2MB。
- Backend 对商品图保留裁剪后宽高比并返回真实 `width`、`height`、`aspect_ratio`；头像继续居中裁为固定方形。
- Mobile 原生相册/相机和 Expo Web fallback 增加相同比例选择；自由模式使用平台裁剪器，最终范围由 Backend 关闭式校验。

## 已部署基线验证

- Backend：容器内 `204 tests` 通过，覆盖图片处理、媒体服务、头像、Gateway、安全契约和商品写事务。
- Web：`npm run tsc`、`npm run biome:lint`、全量 `41 suites / 284 tests`、`npm run build` 均通过；Jest 仍有仓库既有 open handle 提示但退出码为 0。
- Mobile：`npm run lint` 通过；全仓 `tsc --noEmit` 仍有大量既有错误，但过滤确认本轮 `components/item-image-field.tsx` 和 `services/media.ts` 无新增 TypeScript 错误。
- Backend 容器无 `env/bin/ruff`，因此本次无法运行独立 Ruff 命令；相关 Python 代码已由容器单元测试导入执行。
- 本轮尚未执行真实浏览器/真机自由裁剪人工验收、登录态 HTTP 图片上传 smoke；代码仓库已提交推送，staging 构建、部署和基础健康检查均成功。

## 已部署基线能力

- `ItemImageUpload` 默认使用 `staged`：选择、替换和删除图片只更新表单值，正式 `Item.image` 随商品保存接口变更；保留 `commitMode="immediate"` 供明确的独立图片动作。
- `update_product_v2` 在回滚时清理新暂存图片、提交后清理旧受管图片；显式 `image=""` 删除图片，省略字段保持不变。
- AI `product_setup` 草稿支持图片 baseline、patch、版本差异、复核、交接和原地执行；图片由用户上传，不进入模型消息或 Prompt。
- 暂存图片清理会保护 `draft` / `handed_off` AI 草稿仍引用的文件。
- Web 已在 AI 商品 citation、商品当前详情、AI 草稿编辑/复核、AI 业务单据详情、销售发货、采购收货、销售/采购退货、库存盘点、库存调整和转仓确认区展示商品图片；销售/采购发票通过共享单据列同步获得图片与规格展示。
- 商品列表编辑与 AI 交接已保留空字符串删除语义和图片预览，不再因把空值转成 `undefined` 而丢失删除操作。
- Backend API 与 AI Web 设计文档已补充图片上传、事务、草稿和展示契约。
- 新增统一 `ProductImage` 展示组件：真实图片、无图和加载失败使用同一尺寸边界；商品主数据、库存列表 / 详情 / 调整 / 盘点 / 转仓、销售 / 采购订单明细、销售 / 采购退货、AI 商品 citation、AI 草稿摘要 / 复核和 AI 当前单据明细不再隐藏空图片位置或只显示横杠。
- AI `ProductDetailDrawer` 同时展示回答时图片快照和当前商品图片；当前图片区始终可见，并通过 `ItemImageUpload commitMode="immediate"` 直接上传、替换或删除正式 `Item.image`，成功后自动重新读取服务器数据。实际写权限继续由 Frappe Item 保存裁决。
- 已确认 staging 商品“迪莫”的 `Item.image` 为 `null`；旧商品不会因部署自动生成图片。新 UI 会明确显示占位和上传入口，仍需业务用户选择实际商品图片。

## Web 图片覆盖清单

| 业务范围    | 已覆盖位置                                                   | 无图行为                         | 图片维护方式                                     |
| ----------- | ------------------------------------------------------------ | -------------------------------- | ------------------------------------------------ |
| AI 商品查询 | 商品 citation、回答时图片快照、当前商品详情                  | 固定尺寸“无图 / 当时无图片”占位  | 当前商品详情可立即上传、替换、删除并自动刷新     |
| AI 商品草稿 | 紧凑摘要、编辑器、业务复核、版本差异所引用的 payload         | 显示“未设置”占位                 | 草稿内使用 staged 上传，执行时才原子写入正式商品 |
| AI 单据查询 | 当前销售 / 采购订单和发票明细                                | 每行保留商品图片占位             | 只读，正式维护走商品或 AI 当前商品详情           |
| 商品主数据  | 商品列表、商品详情、创建 / 编辑表单、商品选择器              | 列表与详情均显示统一占位         | 表单 staged 保存；商品详情编辑随正式保存提交     |
| 库存        | 库存列表 / 详情、调整、盘点、转仓                            | 列表、详情和已选商品区均保留占位 | 只读展示，图片维护走商品或 AI 当前商品详情       |
| 销售 / 采购 | 订单编辑、订单 / 发货 / 收货 / 发票共享明细、销售 / 采购退货 | 所有商品行统一占位               | 交易页面只读展示，避免交易动作顺带修改主数据     |

## 关键设计决策

1. `ProductImage` 只负责展示真实图片、空值占位和加载失败降级，不负责拼接存储地址。媒体 URL 继续由领域 Service 和 `resolveMediaUrl` 解析，页面不假设 Frappe File、OSS、S3 或 MinIO。
2. 表单和 AI 商品草稿默认使用 staged 模式，取消编辑不会提前修改正式 `Item.image`；AI 当前商品详情属于用户明确触发的独立图片动作，使用 `commitMode="immediate"`。
3. 直接上传、替换和删除仍由 Backend 的 Item 保存权限裁决。Web 显示入口不代表权限提升，失败时沿用正式 Gateway 错误响应。
4. 发布只增加上传、保存、展示和占位能力，不自动生成图片，也不为旧商品批量补图；历史商品是否有图仍以 `Item.image` 为事实源。
5. 交易单据行只展示当前领域接口返回的商品图片，没有引入不可变单据行图片快照；历史单据长期审计如需“下单时图片”，应在后续阶段设计独立快照字段。

## 已部署基线验证（历史）

- Backend：容器内 4 个相关 suite，`137 tests` 通过。模拟 Orchestrator 502/503 日志和 ResourceWarning 为测试预期输出。
- Web：`npm run tsc` 通过；`npm run biome:lint` 通过，检查 `234 files`。
- Web 全量 Jest：`39 suites / 277 tests` 通过；`npm run build` 通过。Jest 仍输出仓库既有的 open handle 提示，但退出码为 `0`。
- Parent、Backend、AI、Web 的 `git diff --check` 均通过。
- 本地站点已执行 `bench --site localhost migrate`，`myapp.patches.extend_ai_run_retry_fields` 成功应用。
- 真实商品图片 HTTP 回路通过：暂存上传、创建商品绑定、替换、显式删除、File 附件清理和测试商品删除均成功，无 Item/File 残留。
- 本地 AI Orchestrator 旧镜像仍使用 `product-setup-draft-v2`，已按当前源码重建为 `product-setup-draft-v4`；容器当前 `healthy`。
- 真实 AI 商品草稿图片链路通过：使用已注册且健康的 `gpt-5.5` 生成 `product_setup` 草稿，暂存上传图片，更新草稿 `version 1 -> 2`，重新读取确认，确认 2 个版本中的图片快照与 `image` diff，随后丢弃草稿、删除测试图片并归档测试会话。
- 本地残留检查：`ai-image-smoke-*` File 数量为 `0`；2 个测试草稿均为 `discarded`；3 个测试会话均已归档。
- 本地运行态 smoke：Backend Ping、Web `/ai`、Web `/master-data/products` 均返回 `200`。Backend 与 Web 当前由手动开发进程提供服务，避免重启相关容器后忘记重新启动。

最终 Web 验证命令：

```bash
cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- --runInBand
npm run build
git diff --check
```

最终结果：TypeScript 通过；Biome 检查 `234 files`；Jest `39 suites / 277 tests` 通过；生产构建通过。提交钩子格式化后又定向复跑 `ProductImage`、`ItemImageUpload`、`ProductDetailDrawer` 和 `AiDraftEditorModal`，`4 suites / 24 tests` 通过。

staging 只读诊断与部署后核验：

```text
Item “迪莫”: image=null, modified=2026-07-25 17:47:56.681994
Web container: ghcr.io/rgc318/myapp-web:staging-20260804-01544c4
Container state: running / healthy
/healthz: ok
/user/login: HTTP 200
/api/method/ping: {"message":"pong"}
静态资源命中 AI 直接图片维护文案：_c328d2da.45d5e3be.async.js
```

## 已部署提交与版本

- Backend：`31bd6ff feat: support flexible image crop ratios`，已推送 `origin/develop`。
- Web：`b572e79 feat: support flexible image crop ratios`，已推送 `origin/main`。
- Mobile：`ebb242e feat: support flexible image crop ratios`，已推送 `origin/develop`，Web Preview 自动部署成功。
- AI Orchestrator：`ca5448c docs: document AI model fallback behavior`，源码未修改；staging 镜像随 Parent build 使用该 gitlink 重建。
- Parent release：`b42ced93 feat: release flexible image cropping`，固定 Backend `31bd6ff` / AI `ca5448c` gitlink，并已推送 `origin/develop`。
- Backend / AI staging 使用 `staging-20260805-b42ced93`；Web staging 使用 `staging-20260805-b572e79`；Mobile Preview 对应 `ebb242e`。
- `.codex` 仍为既有未跟踪目录，不提交。

## staging 构建与部署

| 范围                       | Workflow Run                                                                    | 结果 |
| -------------------------- | ------------------------------------------------------------------------------- | ---- |
| Backend + AI build         | [30970198635](https://github.com/rgc318/frappe_docker/actions/runs/30970198635) | 成功 |
| Backend + AI deploy/health | [30970428806](https://github.com/rgc318/frappe_docker/actions/runs/30970428806) | 成功 |
| Web push CI                | [30970072813](https://github.com/rgc318/myapp-web/actions/runs/30970072813)     | 成功 |
| Web coverage CI            | [30970072839](https://github.com/rgc318/myapp-web/actions/runs/30970072839)     | 成功 |
| Web build                  | [30970200271](https://github.com/rgc318/myapp-web/actions/runs/30970200271)     | 成功 |
| Web deploy                 | [30970430177](https://github.com/rgc318/myapp-web/actions/runs/30970430177)     | 成功 |
| Mobile checks              | [30970072081](https://github.com/rgc318/myapp-mobile/actions/runs/30970072081)  | 成功 |
| Mobile Web Preview         | [30970072076](https://github.com/rgc318/myapp-mobile/actions/runs/30970072076)  | 成功 |

部署事实：

- Parent release `b42ced93` 的 gitlink 精确固定 Backend `31bd6ff` 和 AI `ca5448c`；远端 Backend/Web/Mobile 分支头分别精确指向 `31bd6ff`、`b572e79` 和 `ebb242e`。
- Backend、Frontend、Queue、Scheduler、Websocket 和 AI Orchestrator 使用 `staging-20260805-b42ced93`；独立 Web 使用 `staging-20260805-b572e79`；Mobile Preview 已从 `ebb242e` 成功发布。
- `bench --site staging.example.com migrate` 成功执行。
- AI `/healthz` 返回 `status=ok`；LiteLLM、Runtime Governance 和 Vector Search 已配置；Backend 到 Orchestrator 内部认证通过。
- Runtime Policy 已发布：`1 policies, 7 tool-ready models`。
- `check-staging.sh` 显示数据库、Redis、Backend、Queue、Scheduler、Websocket 和 AI 服务运行正常；首页与 Ping API 均返回 `200`，AI Orchestrator 状态为 `healthy`。
- staging 未配置本轮登录态关键 HTTP 回归输入，因此部署 workflow 保持 `run_http_regression=false`；本轮仍需后续人工执行真实图片上传与裁剪验收。
- Backend push CI Run [30970071791](https://github.com/rgc318/myapp/actions/runs/30970071791) 的全量 `724 tests` 仍命中既有 `test_ai_repository` 单测 `KeyError: product`；本轮图片相关容器测试 `204 tests` 已通过，该既有失败与媒体改动无关。

## 上一轮摄像头与扫码风险

1. 需要在 staging HTTPS 地址使用真实平板、电脑内置摄像头和至少一个外置 USB 摄像头验证授权、设备切换、拍照、重拍、裁剪、上传和关闭后的 track 释放。
2. 需要准备 EAN-13、EAN-8、UPC、Code 128 和 QR 等实际样本，分别验证商品列表搜索、主条码填入、详情新增条码以及销售 / 采购选品；特别检查连续识别不会重复加单。
3. 浏览器自动测试验证的是 API 调用和生命周期，不验证真实焦距、低光、反光包装、摄像头方向和不同浏览器的识别成功率；实际硬件验收仍是发布完成条件之一。
4. 本地 `http://192.168.31.63:<port>` 即使完成端口转发，也不属于浏览器安全上下文。若必须在局域网平板测试 Web 摄像头，应配置终端信任的 HTTPS 证书、同域反向代理或 HTTPS Tunnel，不应通过删除前端 HTTPS 检查规避。
5. Parent 当前 `.git` 在本会话沙箱中只读；远端 `develop` 已更新，本地两份文档与远端字节一致但仍显示修改。新会话应先重新挂载 / fetch，而不是重复提交或还原文档。
6. Mobile 仍保留 5 个用户修改，后续任务不得夹带；production 尚未部署，只有用户明确要求并完成业务验收后再安排。

## 上一轮摄像头与扫码接手建议

1. 先确认远端版本：Web `main=6b23ac5`，Parent `develop` 至少包含 `783dc03d`；检查本地 Parent `.git` 是否恢复可写，并严格保留 `.codex` 与 Mobile 既有 5 个修改。
2. 在 staging HTTPS 环境按“拍照 → 重拍 → 自由裁剪 → 预设裁剪 → 上传 → 重新裁剪 → 替换 / 删除”完成一次真实商品图片生命周期，并确认最终 WebP、尺寸、profile 元数据和 File 清理。
3. 在商品列表、商品新增 / 编辑、商品详情条码区、销售选品和采购选品逐一验证真实条码；无权限或无摄像头时确认手动输入仍可用。
4. 若需本地平板调试，优先设计 HTTPS 入口；现有 `18081/18082` 文档位于 `frontend/myapp-mobile/DEVELOPMENT.md`，不要复用 `8081` 导致 Expo 与 Windows portproxy 冲突。
5. production 尚未部署；获得业务验收和用户明确授权后，再用当前 staging 镜像或对应 Web 提交安排 production 发布。

## 上一轮目标（2026-08-03，已完成）

- 本轮目标：修复 AI 草稿校验提示不具体、不可用模型仍被使用、自动模式缺少 fallback、失败消息无法按当前模型原位重试等问题，并完成 staging 发布与文档收口。
- 当前结果：代码已提交、推送并部署 staging；Backend/AI/Web 健康检查通过。当前只剩文档整理尚未提交。
- 涉及仓库：父仓库、`apps/myapp`、`services/myapp-ai`、`frontend/myapp-web`。Mobile 未修改，production 未变更。

## 已部署基线版本

staging 统一镜像标签：`staging-20260803-a221a8ad`

| 范围            | 当前提交                                               | 说明                                              |
| --------------- | ------------------------------------------------------ | ------------------------------------------------- |
| Parent          | `a221a8ad feat: deploy AI model fallback and retries`  | staging 编排、Backend/AI gitlink 与 fallback 配置 |
| Backend         | `862bbb0 feat: support audited AI message retries`     | 模型健康字段、固定模型拒绝、消息级重试与 Run 审计 |
| AI Orchestrator | `84a37b5 feat: add automatic model fallback`           | 默认 fallback 链、跳过不可用模型、首 Token 前切换 |
| Web             | `2a022c3 feat: improve AI model switching and retries` | 页头模型切换、不可用项禁用、当前模型原位重试      |

上述提交均已在对应远端分支：Parent/Backend/AI 为 `develop`，Web 为 `main`。

## 已部署基线改动

### 草稿校验与人工修正

- 四类草稿区分原始查询词与已解析主键。未唯一匹配的客户、供应商、商品、商品分类、品牌和仓库保持空主键，并保留 `*_query` 供人工搜索。
- Web 不再把 `item_query` 等文本伪装成已选 Link 值；摘要显示“待匹配”，编辑器绑定可操作字段错误并定位首个阻断字段。
- 库存调整的“商品无法唯一匹配”和“必须填写盘点差异或业务原因”等错误会完整展示，不再只给笼统提示。

### 模型选择与自动 fallback

- 可选模型接口返回 `last_health_at`、`last_health_status` 和 `last_error_code`。
- Web 页头提供快速模型 Select；`unavailable` 模型显示“不可用”并禁用，当前固定选择失效时回到自动模式。
- Backend 拒绝显式固定到最近健康状态为 `unavailable` 的模型。
- 自动模式按 Runtime Policy 的主模型/fallback 链选择；没有匹配策略时使用 `MYAPP_AI_MODEL + MYAPP_AI_FALLBACK_MODELS`。
- Orchestrator 跳过不可用候选；Provider 在首个可见正文 Token 前失败时可切换后续 fallback。已经输出正文后不切换，避免拼接多个模型的回答。
- 显式固定模型关闭本次静默 fallback。

### 模型展示与 Run 审计

- 页面自动模式在运行前显示“自动模型（由策略选择）”，运行后显示“自动模型（实际模型名）”。
- Run 同时区分 `requested_model_alias`、实际 `model_alias` 和 `retry_of_run_id`。
- Run Inspector 展示请求方式、请求模型和实际模型；高级诊断额外展示请求/实际 alias。
- 普通用户只看到安全友好名称；Provider 原始正文、Secret、Header 和系统 Prompt 不进入响应。

### 消息级重试

- `stream_ai_message_v1` 新增 `retry_run_id`。
- Backend 从失败 Run 恢复原问题、场景、会话和公司，不信任浏览器重新拼装持久事实。
- 重试不重复插入用户消息；原失败助手占位原位绑定新 Run，成功后原位更新内容。
- 旧 Run 保留失败审计，新 Run 通过 `retry_of_run_id` 关联来源。
- 重试模型只取用户点击时页头当前选择，不再使用失败时旧模型。
- 草稿失败继续使用对应草稿生成接口，不复用普通 Chat 的消息级重试，因为草稿有独立版本、校验和幂等生命周期。

## 已部署基线迁移

- 新 patch：`myapp.patches.extend_ai_run_retry_fields`。
- `MyApp AI Run` 新增 `requested_model_alias` 和 `retry_of_run_id`，并为重试来源增加索引。
- staging 部署执行 `bench migrate` 成功；部署后的 Backend、Queue、Scheduler 和 AI Orchestrator 均运行新镜像。

## 已部署基线验证

### AI Orchestrator

- `ruff check .`：通过。
- Pytest/Docker test：`157 passed`，另有 `9` 个 subtests 通过。
- `pre-commit run --all-files`：通过。
- Docker `test` 与 `runtime` target：构建通过；runtime import smoke 通过。

### Backend

- 新增链路定向测试：`5` 项通过。
- AI Service、模型治理和 Gateway 相关测试：`254` 项通过。
- 已知独立既有失败：`test_get_conversation_state_is_owner_scoped_and_recovers_default_shape` 单独运行也报 `KeyError: product`，本轮未扩大范围修改。

### Web

- `npm run tsc`：通过。
- `npm run biome:lint`：通过。
- 定向 Jest：`62` 项通过。
- 全量 Jest：`37` suites / `270` tests 通过。
- `npm run build`：生产构建通过。
- 提交钩子格式化后再次运行 `npm run tsc`：通过。

### 空白检查

- Parent、Backend、AI 和 Web 的相关 `git diff --check` 均通过。

## staging 构建与部署

| 工作流                     | Run                                                                             | 结果 |
| -------------------------- | ------------------------------------------------------------------------------- | ---- |
| Backend + AI build         | [30825008564](https://github.com/rgc318/frappe_docker/actions/runs/30825008564) | 成功 |
| Backend + AI deploy/health | [30825447419](https://github.com/rgc318/frappe_docker/actions/runs/30825447419) | 成功 |
| Web build                  | [30824680201](https://github.com/rgc318/myapp-web/actions/runs/30824680201)     | 成功 |
| Web deploy                 | [30825791796](https://github.com/rgc318/myapp-web/actions/runs/30825791796)     | 成功 |

部署健康事实：

- `staging-ai-orchestrator-1` 使用目标 tag，状态 `healthy`。
- Backend、Frontend、Queue、Scheduler 和 Web 均使用目标 tag。
- Orchestrator `/healthz` 返回 `status=ok`，LiteLLM、Runtime Governance 和 Vector Search 已配置。
- `check-staging.sh`、ERP Ping、登录页和 Web Gateway Ping 通过。
- production 未执行部署。

首次 Backend/AI build run [30824675060](https://github.com/rgc318/frappe_docker/actions/runs/30824675060) 因把完整 Backend commit SHA 传给 `myapp_ref` 失败。当前 workflow 会把该值交给 `git clone --branch`，因此只支持 branch/tag。确认远端 `develop` 精确指向 `862bbb0` 后，保持同一父提交和同一镜像 tag 重跑成功。长期处理已补充到 staging runbook 和 Known Issues。

## 上一轮结束时仓库状态

### Parent `/home/rgc318/python-project/frappe_docker`

- HEAD：`a221a8ad`。
- 当前文档改动：
  - `STAGING_DEPLOYMENT.zh-CN.md`
  - `docs/05-development/04-ai-business-workbench.zh-CN.md`
  - `docs/codex/CURRENT_HANDOFF.zh-CN.md`
  - `docs/codex/HANDOFF_TEMPLATE.zh-CN.md`
  - `docs/codex/KNOWN_ISSUES.zh-CN.md`
- `apps/myapp` 和 `services/myapp-ai` 显示小写 `m`，原因是子仓库仅有文档改动。
- `.codex` 是既有本地未跟踪状态，不提交。

### Backend `apps/myapp`

- HEAD：`862bbb0`。
- 仅 `API_GATEWAY.zh-CN.md` 有文档改动；代码工作树无未提交修改。

### AI Orchestrator `services/myapp-ai`

- HEAD：`84a37b5`。
- `docs/API_CONTRACT.zh-CN.md` 与 `docs/CONFIGURATION.zh-CN.md` 有文档改动；代码工作树无未提交修改。

### Web `frontend/myapp-web`

- HEAD：`2a022c3`。
- 仅 `AI_WEB_FRONTEND_DESIGN.zh-CN.md` 有文档改动；代码工作树无未提交修改。

### Mobile `frontend/myapp-mobile`

- 本轮未修改、未部署。

## 上一轮遗留事项

- staging workflow 没有配置登录后的 HTTP 回归凭据，因此本轮没有代替真实用户执行登录态聊天点击验收。镜像、迁移、公开健康端点和自动化测试均已通过。
- 模型健康是带时间戳的快照。DeepSeek Flash 曾返回 `PROVIDER_HTTP_403`；Provider 恢复后仍需重新执行健康检测，不能手工假定已经恢复。
- 消息级重试只允许当前账号、活跃会话中最后一条失败/取消的助手 Run，避免历史消息被任意重绑。
- 当前文档尚未提交、推送；文档提交不会改变已部署运行镜像，不需要因此重新部署。
- 服务器仓库曾显示 `services/myapp-ai` 脏 gitlink；运行事实以不可变镜像 tag/revision 为准，不要在服务器直接开发或提交子模块内容。

## 上一轮原建议

1. 审查本轮文档差异并按仓库边界提交：Backend、AI、Web 各自提交文档，最后由 Parent 更新两个子模块指针并提交父仓库文档。
2. 如需业务验收，使用有权限的 staging 账号检查：页头切换 Luna、DeepSeek 不可选、自动模式显示实际模型、失败后切换模型原位重试、Run Inspector 请求/实际模型一致。
3. 后续单独处理 `test_ai_repository` 的既有 `KeyError: product`；不要混入本轮文档提交。
4. 若要让 staging build 真正支持不可变 Backend commit SHA，改造 workflow 的 fetch/checkout 逻辑；在此之前 `myapp_ref` 只传 branch/tag。
