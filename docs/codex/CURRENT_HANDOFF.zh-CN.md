# 当前交接状态

更新时间：2026-09-03 CST

本文件只记录当前短期状态、运行基线、风险和接手步骤。本轮连续修复总结见 `docs/codex/AI_REPAIR_WORK_SUMMARY_2026-09-01.zh-CN.md`，更早的多模态阶段成果见 `docs/codex/AI_MULTIMODAL_WORK_SUMMARY_2026-08-16.zh-CN.md`；长期规则以 `AGENTS.md` 和 `docs/codex/DEVELOPMENT_GUIDE.zh-CN.md` 为准。

## 2026-09-03 AI 库存调整估值与价格候选 P10：已提交，未推送/部署

- 已提交：Backend `2d7cd65 feat: improve AI inventory valuation review`；Web `f8b8754 feat: clarify AI inventory valuation workflow`。Backend API 契约和 Web 开发说明已同步；父仓本阶段只固定 Backend gitlink 并记录本交接，Web 仍为独立仓库。
- 库存草稿现在优先读取所选仓库 `Bin.valuation_rate / stock_value` 作为实际估值基线，不再把商品详情摘要价误当仓库估值。页面把“本次计价单位价格”和“执行后库存估值单价”分开展示，并实时计算当前/执行后库存数量、当前/执行后库存价值与价值差额；估值变化且已有库存时明确提示 Stock Reconciliation 会一并重新估值已有库存。
- Backend 返回全部当前有效的采购型 Item Price 候选，不限于 Standard Buying。每项携带稳定 Item Price ID、价格表、币种、原价格、计价单位、换算系数、折算后库存单位价格、有效期和可用状态。箱价与件价等不同包装价不再因折算结果不同被误判为冲突；当前估值为零时，仅在所选调整单位恰好有一个可用候选时自动采用，否则要求人工选择或输入。
- 采用采购价时 Web 保存 `valuation_rate_source=buying_price_reference + valuation_rate_reference_id`。Backend 按 Item Price ID 重新校验商品、有效期、币种和单位换算，并忽略客户端伪造的 `valuation_rate`；人工输入通过 `valuation_input_rate + valuation_input_uom` 折算。旧 `standard_buying_reference` 和直接库存单位 `valuation_rate` 继续兼容读取。
- 采购价格表只是估值候选；只有用户采用后折算形成正式 `valuation_rate` 才会影响库存价值，不会创建采购订单、采购发票或供应商应付。库存调整原因新增盘盈、盘亏、期初库存校准、历史数据纠正、单位/包装纠正、破损/报废/过期损耗快捷项，并保留其他原因手工填写。
- 真实站点只读验证：商品 `可口可乐-5000ML-2`、仓库 `Stores - RD` 当前 5604 件，Bin 估值 6/件；调整 1 Box（24 件）默认沿用为 144/箱。候选 `9gvn3s5dm8` 为 70/Box→2.916667/件，`acvmbjn538` 为 2.5/Nos→2.5/件；选择前者并伪造客户端价格 999 时，Backend 仍核验为 70/Box 和 2.916667/件，并返回已有库存重新估值及价值差额 -17209。验证过程只读，没有执行草稿或写入业务数据。
- 验证：Backend `py_compile + test_ai_service` 163 tests PASS，`test_ai_draft_state + test_gateway_wrappers` 158 tests PASS，Backend diff check PASS；Web `npm run tsc` PASS，`npm run biome:lint` 274 files PASS，定向 2 suites / 29 tests PASS，全量 Jest 58 suites / 375 tests PASS，Web diff check PASS。Jest 仍提示既有 open handle，定向回归另提示本地 Browserslist 数据较旧，但退出码均为 0。
- 当前状态：Backend 与 Web 工作树干净；未推送、未部署。父仓既有 `AGENTS.md`、`STAGING_DEPLOYMENT.zh-CN.md`、开发规则/模板/已知问题和 `.codex` 等用户本地改动继续保留，不属于本阶段提交。

## 2026-09-03 商品价格表本地化显示 P9：已提交，未推送/部署

- 已提交：Web `cd5049e feat: localize product price list names`、`4059d93 fix: apply price list localization consistently`。本阶段只有 Web 显示层变化，没有重命名 Price List、修改 Backend 或写入业务数据。
- 新增共享价格表显示映射与 `PriceListName` 组件：简体中文界面将 `Standard Selling / Standard Buying / Wholesale / Retail` 显示为“标准销售 / 标准采购 / 批发 / 零售”，繁体中文使用对应繁体名称；英文、其他未配置语言和自定义价格表保持原始名称。
- 已审查并覆盖所有当前面向用户的价格表只读展示：商品详情摘要与价格矩阵、商品维护工作区、价格编辑器、单位纠错/继任商品流程、AI 商品详情、客户/供应商详情和商品价格审计摘要。AI 商品草稿说明使用“中文（英文标识）”；选择器同样保留原始标识。
- 修复半屏商品详情矩阵列被压缩后中文逐字竖排：价格表列设置明确宽度，整表按列总宽度横向滚动，`PriceListName` 统一使用不换行样式。英文稳定标识仍通过悬停可见。
- 接口提交、Item Price 定位、权限、审计源、内部业务判断与 CSV 导入导出继续使用英文稳定标识；客户/供应商默认价格表编辑框也明确说明输入的是稳定标识。本地化文字不得写回业务字段。
- 验证：`npm run tsc` PASS；`npm run biome:lint` 274 files PASS；定向 7 suites / 40 tests PASS；全量 Jest 58 suites / 375 tests PASS；提交后关键 5 suites / 15 tests PASS；Web `git diff --check` PASS。定向 Jest 仍可能提示既有 open handle，但退出码为 0。

## 2026-09-03 商品资料质量语义 P8：已提交，未推送/部署

- 已提交：Web `b516ecd feat: clarify product quality governance`。本阶段只调整 Web 质量评估与引导，没有 Backend 代码或数据变化。
- 删除“100 分减分”的伪精确资料完整度，不再把条码、品牌、图片、描述、标准售价和标准采购价固定定义为商品建档必填；列表改为“良好 / 需关注 / 异常”，详情按数据错误、业务风险和可选完善建议分级展示数量与明细。
- 数据错误覆盖库存基准单位缺失或系数不为 1、重复/无效单位换算、批发/零售默认单位引用无效、条码或有效价格引用未配置单位和负库存；业务风险覆盖停用仍有库存、历史条码或有效价格缺少单位，以及缺少商品分类；其余资料缺失仅作为不影响“良好”状态的可选建议。
- 每项问题按语义精确进入基本资料、单位与包装、条码、销售价格、采购价格、库存调整或库存流水，不再统一跳回基本资料。Item Price 的修复按钮继续按独立价格权限控制，不与 Item 普通写权限混用。
- 验证：`npm run tsc` PASS；`npm run biome:lint` 270 files PASS；全量 Jest 56 suites / 371 tests PASS；Web `git diff --check` PASS。Jest 仍提示既有 open handle，但进程退出码为 0。

## 2026-09-03 商品 CSV 导出治理 P7：已提交，未推送/部署

- 已提交：Backend `dcaa4c6 feat: provide complete product export data`；Web `90fa747 feat: govern product csv exports`。父仓本轮固定 Backend gitlink；Web 仍为独立仓库。
- 修复商品导出静默截断：Backend `list_products_v2` 单页实际最多 100 条，Web 不再以单次 `limit=1000` 假设完整结果，而是按 `name asc` 稳定排序、每页 100 条、最多 4 个并发请求读取全部分页。
- 浏览器同步导出上限为 5000 条；超限时不生成部分文件，明确要求缩小筛选或后续使用后端异步导出。分页期间总数变化、缺行或重复时同样失败关闭，避免把不完整文件标成成功。
- Backend 商品列表现在批量返回 `barcode` 和完整 `barcodes[]`（含条码行名、顺序、主条码标识与 UOM），避免商品列表与导出条码列长期为空，也避免逐商品查询详情的 N+1 请求。
- 导出字段补齐条码单位、库存单位编码/显示名、单位换算、批发/零售默认单位、销售/采购价格摘要、库存估值、最后修改时间和当前筛选口径；导出按钮显示分页读取进度。
- 验证：Backend `test_wholesale_service + test_gateway_wrappers` 191 tests PASS；真实 HTTP `test_product_barcode_management_v2_roundtrip` PASS，并确认列表与详情返回同一条码/UOM；Backend diff check PASS。Web 全量 55 suites / 365 tests PASS，`npm run tsc` PASS，`npm run biome:lint` 268 files PASS，Web diff check PASS；提交后定向 2 suites / 74 tests PASS、TypeScript PASS。Jest 仍偶发既有 open-handle 提示但退出码为 0。

## 2026-09-03 商品 CSV 导入治理 P6：已提交，未推送/部署

- 已提交：Web `52a2efd feat: govern product csv imports`。本阶段复用 P3 Backend 的商品详情权限与乐观锁能力，没有 Backend 代码变化。
- CSV 导入拆分为解析校验、更新行预检、逐行执行和可恢复结果四个阶段。更新行执行前读取目标商品、检查 `canWrite` 并保存当前 `modified`；执行时携带该版本，版本冲突后必须重新预检。
- 成功行进入终态，后续点击自动跳过；失败行不终止其他行，也不回滚已经成功的记录。新增与更新行按请求载荷保留稳定幂等键，网络不确定失败可使用同一键重试；重新预检并改变更新版本时生成新的幂等键。
- 导入预览区明确展示待预检、预检中、可执行、执行中、成功、可重试、失败和格式错误状态，并提供“重新预检更新行”。未知导入动作、非法数字和非法启停值不再被猜测或静默忽略。
- 更新行预检采用最多 5 个并发请求，避免大文件完全串行；批量导入和既有批量启停/修改关闭逐条成功与错误通知，只保留汇总和逐行结果。
- 验证：Web 全量 54 suites / 361 tests PASS，`npm run tsc` PASS，`npm run biome:lint` 266 files PASS，`git diff --check` PASS；提交后定向 2 suites / 79 tests PASS、TypeScript PASS。全量 Jest 仍偶发既有 open-handle 提示，但退出码为 0。

## 2026-09-03 商品批量维护结果治理 P5：已提交，未推送/部署

- 已提交：Web `ddf7e01 feat: report governed bulk product changes`。本阶段复用 P3 Backend 的单商品写权限与版本冲突保护，没有 Backend 代码变化。
- 商品列表选中行同时保存 `itemCode + modified`，批量启停和批量修改逐条携带对应商品版本；跨页保留选择，并在选中键与版本快照不完整时要求刷新后重选。
- 批量语义明确为“逐条独立提交、允许部分成功”。单条失败不再中断后续商品，也不会回滚已经成功的记录；领域 service 返回 `succeeded[] / failed[]`。
- 页面新增批量结果窗口，逐商品显示成功或失败原因，并明确成功数、失败数与不回滚语义。批量内部关闭逐条错误通知，避免大量 toast/notification 淹没最终结果。
- 验证：Web 全量 53 suites / 352 tests PASS，`npm run tsc` PASS，`npm run biome:lint` 264 files PASS；提交后领域 service 70 tests PASS，`diff --check` PASS。

## 2026-09-03 商品详情写入口一致性 P4：已提交，未推送/部署

- 已提交：Web `cc4bd37 fix: align product detail edit guards`。本阶段没有 Backend 代码变化。
- 商品详情页的编辑商品、启停、单位错误纠正、资料质量补充和条码新增/设主/删除全部读取 `ProductSummary.canWrite`；只读账号不再能从详情页绕过工作区的交互保护。
- 详情页启停与条码动作携带当前 `Item.modified`。`DOCUMENT_VERSION_CONFLICT` 使用与工作区共享的判断函数，显示持久错误和“刷新最新资料”，不再只弹短暂 toast。
- 价格新增/修改/终止继续使用独立 Item Price 权限，不因 Item 普通资料只读而错误关闭价格专职角色的入口。
- 修复详情页三组 `ProDescriptions` 的列跨度告警，并把该页既有 Alert 标题迁移到新版 `title` 属性。
- 新增 `Detail.test.tsx`，覆盖只读态和条码版本传递。验证：Web 全量 53 suites / 351 tests PASS，`npm run tsc` PASS，`npm run biome:lint` 264 files PASS，提交后详情/工作区 2 suites / 9 tests PASS，`diff --check` PASS。定向运行仍有既有 Jest open handle 提示但退出码为 0。

## 2026-09-03 商品维护权限与并发保护 P3：已提交，未推送/部署

- 已提交：Backend `b7d7de9 feat: protect concurrent product maintenance`；Web `9f2c281 feat: guard product workspace edits`。父仓本轮固定 Backend gitlink；Web 继续作为独立仓库维护。
- `get_product_detail_v2` 返回目标 Item 的 `permissions.can_write`；Backend 新增可复用的文档权限判断，普通保存、启停和三个条码即时动作均显式要求目标 `Item.write`，不依赖浏览器按钮作为安全边界。
- 新增共享 `OptimisticLockConflictError`。上述商品写动作接受读取时的 `item_modified`，版本变化时返回 HTTP 409、`DOCUMENT_VERSION_CONFLICT` 和结构化冲突数据，并在任何字段、图片、库存、价格或条码写入前失败关闭。
- Web 将权限映射为 `ProductSummary.canWrite`。无写权限时，普通资料、单位与包装、库存估值、条码、单位风险纠正和保存入口明确只读；价格矩阵仍按独立 Item Price 权限判断。
- 普通资料保存、商品列表启停和条码动作均携带商品版本。冲突不再只显示短暂消息，而是保留持久错误提示，并提供“刷新最新资料”动作；刷新会明确放弃本地未保存内容并载入服务器最新版本。
- 验证：Backend `test_data_permission_service + test_wholesale_service + test_gateway_wrappers` 197 tests PASS；Web 定向 2 suites / 76 tests PASS、全量 52 suites / 349 tests PASS、`npm run tsc` PASS、`npm run biome:lint` 262 files PASS；Backend/Web `diff --check` PASS。既有 Jest open handle 提示仅出现在定向运行且退出码为 0，全量运行正常结束。

## 2026-09-03 商品维护审计时间线 P2：已提交，未推送/部署

- 已提交：Backend `b7df29c feat: add product change audit timeline`；Web `8a72903 feat: show product change audit timeline`。父仓本轮固定 Backend gitlink；Web 继续作为独立仓库维护。

- Backend 新增 `list_product_change_history_v1`，在目标商品读取权限与可见 Price List 范围内聚合商品创建/Version、价格创建/Version、条码与单位子表差异以及 `MyApp Product Correction` 审计。
- 统一事件结构区分 `product / price / barcode / uom / valuation` 和 `created / updated / terminated / corrected`，返回操作时间、操作人、来源记录和字段级前后值；历史长文本受限且过滤凭据型键。
- Web 商品维护工作区“变更历史”已从占位说明替换为正式时间线表格，显示事件分类、摘要、字段差异与操作人；数据只来自 Backend，不根据当前商品值推测历史。
- 价格创建事件会从后续 Version 逆向恢复创建时金额，不把当前价格冒充历史初始值；只有 `valid_upto` 在事件发生日或之前生效时才标记为“终止价格”，未来有效期调整仍属于普通更新。
- 验证：Backend `test_wholesale_service + test_gateway_wrappers + test_product_correction_service` 194 tests PASS；目标真实 HTTP `test_product_change_history_returns_created_and_updated_events` PASS，公开入口返回创建与描述更新的结构化事件；Web 全量 Jest 52 suites / 347 tests PASS；`npm run tsc` PASS；`npm run biome:lint` 262 files PASS；Parent、Backend、Web `diff --check` PASS。
- 真实商品只读验证：`可口可乐-5000ML-2` 返回 10 条可见事件，包括价格创建/更新、单位配置更新和商品创建；未写入或修改该商品、价格、库存和纠正记录。HTTP 回归创建了隔离测试商品与标准 HTTP 测试夹具。

## 2026-09-02 商品全屏维护工作区 P1：已提交，未推送/部署

- 已提交：Backend `2446dfd feat: govern product maintenance workflows`；Web `be97f57 feat: add governed product maintenance workspace`。父仓本轮固定 Backend gitlink；Web 仓库仍保持独立，不由父仓跟踪。
- 新增 `/master-data/products/:itemCode/edit` 全屏商品维护工作区，并确保路由位于动态详情路由之前。商品列表“编辑”、商品详情“编辑商品”和 AI 商品 Drawer“维护商品”统一进入该工作区；新增商品仍保留独立创建弹窗，现有商品编辑代码已从创建弹窗和详情页移除。
- 工作区按基本资料、单位与包装、销售价格、采购价格、条码、库存与估值、变更历史分区。普通资料保存不创建新商品；只有库存基准单位语义或物理商品身份发生高风险变化时才进入单位风险纠正与继任商品流程。
- 销售/采购页签直接维护完整 Item Price 矩阵，支持权限控制下的新增、金额/有效期修改和终止；四个价格摘要不再混入普通资料表单。条码区独立支持新增、设主条码和删除，且每条条码必须选择商品已配置单位。
- 库存基准单位在普通维护中锁定，单位页签提供醒目的“单位风险纠正”入口；库存估值成本与采购价继续保持语义分离。变更历史页签当前明确展示正式来源和后续聚合计划，不伪造尚未具备的审计时间线。
- 工作区具备未保存提示、浏览器关闭保护、返回详情/切换页签放弃修改确认、顶部与 sticky 底部保存入口和保存结果反馈。条码表单已拆为仅在条码页签挂载的独立组件，避免未连接 Form 和嵌套原生 form 告警。
- 新增 `Workspace.test.tsx`，覆盖商品加载与页签、普通资料原地保存、库存基准单位锁定与纠正入口、无 Item Price 权限只读、未保存离开确认；AI Drawer 测试补充“维护商品”工作区链接。
- 验证：定向 Jest 2 suites / 5 tests PASS；前端全量 Jest 52 suites / 345 tests PASS；`npm run tsc` PASS；`npm run biome:lint` 262 files PASS；Parent、Backend、Web `diff --check` PASS。既有 Jest open handle 提示仍存在但退出码为 0。

## 2026-09-02 商品维护与完整价目表 P0：已提交，未推送/部署

- 单位错误纠正不再从空白目标表单开始：当前库存基准单位、完整换算、批发/零售默认单位、价格目标单位和条码目标单位均已预加载；页面新增当前配置对照。价格和条码处理动作仍保持空值并要求逐条人工确认，避免自动复制或迁移高风险主数据。
- 价格动作按策略拆清语义：原地纠正为“保持金额并确认单位 / 修改单位或金额 / 终止这条旧价格”；继任商品为“迁移并保持原金额 / 迁移并重新定价 / 不迁移（保留在源商品）”。预览也分别显示“本次终止旧价格”或“不迁移的源价格”，不再使用含糊的“跳过”。
- Backend 新增完整价格矩阵与维护接口：`list_product_prices_v1`、`upsert_product_price_v1`、`terminate_product_price_v1`。完整记录包含 Price List 类型、币种、UOM、金额、有效期、版本和权限；新增/更新/终止使用正式 Item Price、幂等、归属校验和乐观锁。现有价格的 Price List、币种、UOM 定位键禁止直接改写，错误键必须新增正确记录后终止旧记录；终止只设置 `valid_upto`，不物理删除。
- 商品详情改为销售/采购完整价格矩阵，可明确新增、修改和终止；无 Item Price 权限时维护按钮禁用。P0 曾扩大普通编辑弹窗并将四个常用价格标记为快捷入口；该过渡方案已被上方 P1 全屏维护工作区取代。
- AI 商品快捷 Drawer 现在同时实时读取并展示完整单位换算、全部可见价目、全部条码和仓库库存；回答时快照继续与当前实时数据分开。
- 真实只读验证：`可口可乐-5000ML-2` 通过新服务返回 6 条 Item Price，其中 Standard Buying 仍为独立的 `70/Box` 与 `70/Nos`；本轮没有新增、终止或修改任何真实价格。
- 验证：Backend `test_wholesale_service + test_gateway_wrappers` 186 tests PASS；Web `npm run tsc` PASS、`npm run biome:lint` 260 files PASS、全量 Jest 51 suites / 341 tests PASS；Backend/Web/Parent `diff --check` PASS。既有 Jest open handle 提示仍存在但退出码为 0。

## 2026-09-02 库存估值与采购参考价语义优化：已提交，未推送/部署

- AI 库存调整增加库存时的取值顺序升级为：用户明确输入、商品已有有效库存估值、Standard Buying 标准采购参考价建议。只有三者均无有效正数时才阻止执行；减少库存仍不要求新成本。
- Standard Buying fallback 会写入 `valuation_rate_source=standard_buying_reference` 和 `valuation_rate_reference`。同库存单位直接建议；按箱、包等其他已配置商品单位计价时按 UOM conversion factor 折算为每库存单位成本并展示换算依据；缺少换算关系时不自动采用。后端校验警告及 Web 表单均明确提示“仅为本次库存估值建议”，并说明库存调整执行 Stock Reconciliation，不创建采购单、采购发票或供应商应付。用户改值后来源记为 `user`，后端会验证来源与权威价格是否一致，客户端不能伪造来源。
- 真实商品 `可口可乐-5000ML-2` 当前 `Item.valuation_rate=0`，同时存在 `Standard Buying 70/Nos` 与 `Standard Buying 70/Box`，而 `1 Box=24 Nos`；两条折算为 `70/Nos` 与 `2.916667/Nos`，属于主数据价格单位冲突，不能安全自动选取。Backend 现会返回 conflict 明细，Web 保持库存成本为空并展示两条折算结果。最终应由用户确认 70 元对应“箱”还是“件”，再清理错误 Item Price。
- 复用旧库存活动草稿时，Backend 会重新解析没有来源的历史零估值并刷新为最新建议或价格冲突提示，不再原样打开旧空值；带 `valuation_rate_source=user` 的明确用户输入不会被覆盖。
- localhost 上该商品的两个活动库存草稿 `AI-DRAFT-be9250...`、`AI-DRAFT-2aa53...` 已通过同一服务逻辑从版本 1 刷新为版本 2，均保留成本为空并写入 `price_conflict=true` 与 1 条价格单位冲突警告；没有执行库存调整或修改正式商品价格。
- AI 商品草稿中的“成本价（默认采购价）”已改为“标准采购参考价”，“标准售价（默认单价）”已改为“标准销售参考价”；说明文案明确 Standard Selling 只是销售兜底参考，批发价和零售价为独立销售价格表，Standard Buying 不是库存实时估值。
- 验证：Backend `test_ai_repository + test_ai_service + test_gateway_wrappers` 354 tests PASS；Web `npm run tsc` PASS、`npm run biome:lint` 259 files PASS、全量 Jest 51 suites / 340 tests PASS；父仓、Backend、Web `diff --check` 均 PASS。

## 2026-09-02 AI 卡片动作去重与聊天语义隔离：已提交，未推送/部署

- 商品卡片“编辑商品资料”“调整库存”已从单一布尔防重升级为按“会话 + 公司 + 动作 + 商品”维度的 Web single-flight；同一动作请求期间所有对应按钮 loading/disabled，并复用同一个 Promise 和 ASCII `Idempotency-Key`。请求完成前切换会话时不会污染当前消息或强制打开草稿弹窗。
- Backend 新增业务幂等：按“用户 + 会话 + 公司 + 动作 + 当前有效商品”生成活动草稿键，在会话行锁和唯一索引保护下，同一活动草稿首次返回 `outcome=created`，不同 request id 的后续请求返回同一草稿和 `outcome=reused`。执行、交接、放弃后清空活动键，允许下一轮创建。
- 直接 UI 动作和库存候选选择不再伪造 user/assistant 聊天，统一返回 `messages=[]`；`message_kind=chat|activity` 已贯通 Repository、API 映射和 Web，模型上下文只读取 `chat`。历史 activity 在 Web 使用 AI/系统侧“历史业务操作”标识展示，不再伪装成用户发送。
- Patch `myapp.patches.govern_ai_draft_action_deduplication` 已在 localhost 通过 `bench migrate` 成功执行并写入 Patch Log，也已额外直接重跑一次验证可重入。真实数据中 16 条历史伪聊天已标记为 `activity`，53 条真实聊天保持 `chat`；8 个历史按钮草稿中 2 个重复且 `version_no=1` 的草稿标记为 `superseded`，没有删除记录；唯一索引存在，重复非空活动键为 0。
- 真实 HTTP 回归：同一商品动作使用两个不同 `Idempotency-Key`，第一次 `created`、第二次 `reused`，草稿 ID 相同；新建测试会话最终 `message_count=0` 且消息表记录为 0。迁移曾暴露 MariaDB 参数化 LIKE 百分号和 Frappe DDL 事务边界问题，均已修复后重新迁移成功。
- Backend 验证：`test_ai_repository + test_ai_service + test_gateway_wrappers` 348 tests PASS；目标真实 HTTP 1 test PASS；patch 重跑 PASS；Python compile 与 `git diff --check` PASS。
- Web 验证：`npm run tsc` PASS；`npm run biome:lint` 259 files PASS；全量 Jest 51 suites / 338 tests PASS；既有 Jest open handle 提示仍存在但退出码为 0。
- 本节 Backend 与 Web 改动已分别包含在 `2446dfd` 和 `be97f57`，尚未推送或部署。

## 2026-09-01 AI 库存调整成本前置校验与换算布局修复：已提交，未推送/部署

- 库存调整草稿在目标库存高于当前库存时，现在会在草稿阶段校验库存单位成本。商品已有有效估值时自动带出；无估值但存在 Standard Buying 时带出为带来源警告的参考建议；仍无有效值时必须填写按库存基准单位计价的 `valuation_rate > 0`。减少库存不要求新成本。
- Web AI 草稿编辑器新增“库存单位成本”字段、字段级后端错误映射和执行前校验。填写并保存后草稿版本会增加，Web 执行幂等键随版本变化，不会继续复用旧版本已失败的 `request_id`。
- 换算预览从双列 Grid 的单列子项改为跨整行展示，Grid 使用 `minmax(0, 1fr)` 防止内容撑宽，预览允许安全换行，调整原因也跨整行。
- 本节改动已随 Backend `2446dfd` 与 Web `be97f57` 提交，尚未推送或部署。
- 验证：Backend `test_ai_service` 154 tests PASS；Web 目标 Jest 2 suites / 27 tests PASS；`npm run tsc` PASS；`npm run biome:lint` PASS。Jest 既有 open handle 提示不影响退出码。

## 2026-09-01 商品单位纠正双策略与历史引用修复：本地完成并提交，尚未推送

- 原“单位替代迁移”已升级为双策略：没有历史 Stock Ledger Entry、库存/占用/未完订单均为零且没有既有替代关系时，后端推荐 `in_place`，保留原商品编码受控纠正；存在历史库存流水时即使余额为零也不允许原地改库存单位，推荐 `replacement` 创建继任商品并停用源商品。
- 新增原始审计表 `tabMyApp Product Correction` 和 patch `myapp.patches.create_product_correction_table`，记录纠正类型、源/目标商品、原因、前后快照、幂等请求、执行人和执行时间。localhost 已用 `frappe.modules.patch_handler.run_single` 单独执行并写入 Patch Log；当前审计表为 0 行，没有回填或改写真实商品。
- 新增 `resolve_active_product_v1`：优先沿正式纠正记录解析最多 10 层继任链并检测循环；对上线前遗留数据，仅在“源商品停用 + 唯一单向 Item Alternative + 目标启用”时使用安全 fallback，不在多个替代商品之间猜测。
- AI 历史消息的“完善商品/调整库存”现在先解析当前有效商品。Web 在历史编码已被替代时展示源编码和当前有效编码并要求确认；Backend 也会用有效编码重新创建草稿，最终商品停用且无继任时阻断。
- 商品详情普通编辑已修复价格副作用：0 元价格不再预填，四个汇总价格字段仅在本次确实触碰时提交；每次打开/成功保存会重置 touched 状态，避免后续只改描述或图片仍重复写价格。商品切换后和新增条码成功后，条码单位重置为当前商品库存单位，避免残留旧异常单位。
- 原地纠正会更新原 Item 的单位换算、模式默认单位、条码单位和用户明确映射的价格；`skip` 只把旧价格有效期截止到执行前一日，不删除历史价格。无价格映射时不要求 Item Price 写权限；只有新增价格时要求创建权限。
- 真实验证：`resolve_active_product_v1(可口可乐-5000ML)` 通过 Backend Service 和登录态 HTTP 均返回 `可口可乐-5000ML-2`，`resolution_source=legacy_item_alternative`、`requires_confirmation=true`。没有执行新的商品纠正、价格调整、条码迁移或库存操作。
- Backend：纠正服务、单位纠正、Gateway 和 AI Service 共 314 tests PASS；新增 HTTP 回归 1 test PASS；localhost patch PASS。
- Web：TypeScript PASS；Biome 259 files PASS；全量 Jest 51 suites / 333 tests PASS。Jest 仍有既有 open handle 提示，但退出码为 0。
- Backend commit：`8969453 feat: govern product uom corrections`；Web commit：`37f2ea4 feat: support governed product uom corrections`。真实可口可乐数据最终整理仍需用户确认：库存基准单位选 `Bottle` 还是 `Nos`、`Box` 实际装量、Retail 3 元对应单位、Standard Buying 70 元对应单位；未经确认不得删除、合并或重写两个商品及其价格。

## 2026-09-01 商品单位替代迁移现代化：阶段完成，已并入双策略提交

- Web 已修复中文商品编码写入 `Idempotency-Key` 时浏览器在发请求前直接拒绝的问题；商品编辑、库存调整和单位迁移不再使用原始中文编码作为请求头值。
- 单位迁移提交不再假设源商品一定存在条码或价格；空集合显式按 `[]` 提交，校验失败会提示并滚动到首个错误字段，不再出现按钮无请求、无报错的静默失败。
- 新商品编码由后端按现有编码规则生成建议值，Web 默认带出但允许修改或清空；清空后执行时由后端重新生成，用户无需每次人工发明抽象编码。条码继续保持可选。
- 同一迁移向导现可逐条处理旧价格：保留原金额、手工填写新金额、跳过；也可直接新增独立价格。价格金额支持 6 位小数，单位必须来自新商品换算表。
- 执行前新增最终变更预览，集中展示新旧商品、库存/批发/零售单位、完整换算、条码去向、跳过价格数和最终价格计划；只有二次确认后才调用执行接口。
- Web 与 Backend 均会拒绝同一 `价格表 + 币种 + 单位` 的重复价格计划。Backend 还会预检价格表存在性和 Item Price 创建权限，再停用源商品或创建新商品；事务、源版本复核和幂等保护继续保留。
- 真实只读评估 `可口可乐-5000ML` 已返回：建议编码 `可口可乐-5000ML-2`、4 条旧价格、0 条条码、无 blocker、`can_execute = true`。本轮没有执行迁移，没有修改该商品、库存、价格或历史数据。
- Web 验证：`npm run tsc` PASS；`npm run biome:lint` 259 files PASS；单位迁移、领域 Service、API client、AI action 目标测试 4 suites / 103 tests PASS；`git diff --check` PASS。Jest 仍有既有 open handle 提示，但退出码为 0。
- Backend 验证：`test_product_uom_migration_service + test_gateway_wrappers` 152/152 PASS；`git diff --check` PASS。
- 本阶段改动已与后续双策略、历史引用和审计修复合并提交到 Backend `8969453` 与 Web `37f2ea4`。

## 2026-09-01 当前统一状态与接手结论

### 当前功能基线

| 仓库 | 分支 | 当前提交 | 工作树 |
| --- | --- | --- | --- |
| Parent | `develop` | `baeb2d82 fix(ai): enforce runtime state consistency`；交接文档提交可能位于其后 | 保留用户已有文档修改和未跟踪本地资料 |
| Backend `apps/myapp` | `develop` | `8969453 feat: govern product uom corrections` | clean |
| AI Orchestrator `services/myapp-ai` | `develop` | `25e55e7 fix: refresh stale model health policy cache` | clean |
| Web `frontend/myapp-web` | `main` | `37f2ea4 feat: support governed product uom corrections` | clean |
| Mobile | 未核对 | 本阶段未修改 | 不得顺带清理或提交 |

Parent 当前不应提交或覆盖：`AGENTS.md`、`STAGING_DEPLOYMENT.zh-CN.md`、`docs/codex/DEVELOPMENT_GUIDE.zh-CN.md`、`docs/codex/HANDOFF_TEMPLATE.zh-CN.md`、`docs/codex/KNOWN_ISSUES.zh-CN.md` 中用户已有修改，以及未跟踪 `.codex`、`docs/codex/AI_MULTIMODAL_WORK_SUMMARY_2026-08-16.zh-CN.md`。本轮已在 `KNOWN_ISSUES` 工作树中补充 502 条目并修正旧状态，但该文件包含用户原有未提交内容，提交时不得整文件混入；若继续完善交接或已知问题，应只提交能与用户状态安全分离的文档改动。

### 当前完成度

- AI Run 状态恢复、轮询收敛、僵尸 Run/过期审批回收和五服务 AI Gateway 配置一致性检查：本地代码与验证已完成并提交。
- AI 模型健康瞬时失败治理、商品候选续接、商品完善与库存调整入口、单位与库存 P0～P4：均已完成本地代码阶段并分别提交。
- 当前尚未推送本轮 2026-09-01 本地提交，尚未部署新的 staging 候选；production 未操作。
- 仍需在 staging 验收运行中刷新、切换会话后返回、审批后网络中断、终态后 Sender 恢复、商品候选续接、库存调整，以及配置不一致失败关闭。
- 真实异常商品 `可口可乐-5000ML` 仍未执行替代迁移；必须由用户确认新商品编码、库存基准单位、完整换算和四条历史价格的迁移决定，不能自动猜测。

## 2026-09-01 本地 Web 502 已恢复，自动预防尚未实现

- 用户本地通过 `http://localhost:8001` 测试时，登录与 AI 工作台接口稳定返回 502。诊断时 Backend `8000` 为 200、AI Orchestrator `4010` 为 200/healthy，只有 Frappe Frontend `8080 → Backend` 为 502。
- 根因是本轮为刷新 AI Gateway 环境，只 recreate 了 `backend / queue-short / queue-long / queue-ai-vector / scheduler`。Backend 容器地址从 `172.19.0.5` 变化为 `172.19.0.9`，已运行约 34 小时的 Frontend Nginx 仍把 upstream 固定到旧地址 `172.19.0.5:8000`，日志明确为 `connect() failed (111: Connection refused)`。
- 已执行 `docker compose restart frontend`，Nginx 重新解析 `backend` 为 `172.19.0.9`。恢复后 Backend `8000`、Frontend `8080`、Web 开发代理 `8001` 和 AI `4010` 全部 HTTP 200；没有修改代码、数据库、卷或 Secret。
- 该 502 不是 AI 模型、Provider、Backend 业务逻辑、Prompt 版本或数据库错误；不要通过重建 AI 镜像、修改模型策略或回滚本阶段代码处理。
- 自动预防尚未实现：凡是只 recreate Backend 而不重启 Frontend 的本地操作，都可能再次触发。至少应覆盖 `rotate-ai-service-token.sh`、本地精确 recreate 和可能只重建 Backend 的启动流程；安全方案是在 Backend 就绪后 reload/restart Frontend 并验证 `8001 → 8080 → backend` Ping，或改造 Nginx 使用 Docker DNS 动态解析。完成自动化前，手工恢复命令为 `docker compose restart frontend`。
- staging 使用同一 Frontend/Backend 拓扑，部署验收必须在容器切换后检查真实 Frontend Gateway Ping，不能只检查 Backend 直连和 AI `/health`。

## 2026-09-01 AI Run 状态一致性与运行配置收敛已完成并本地提交

- Backend 已提交 `46f5d48 fix(ai): converge durable run state`；Web 已提交 `b4112fe fix(ai): restore durable run state`；Parent 已提交 `baeb2d82 fix(ai): enforce runtime state consistency`。AI Orchestrator 本阶段未修改。
- `get_ai_conversation_v1` 现返回当前用户最新持久 `latest_run`，包括可空 `message_id`。即使助手消息尚未生成，Web 也能恢复 `running / waiting_approval / completed / failed / expired / cancelled`；若旧回答已存在但不在当前消息分页中，不会把它重复追加到会话末尾。
- Web 重开或刷新会话不再把所有非失败 Run 误标为已完成。`running / waiting_approval` 每 3 秒读取一次持久快照，终态后替换临时占位并恢复 Sender；活动 Run 期间禁止重复发送、上传和移除待发送附件。轮询失败保留最后已知状态，不伪造完成结果。
- Scheduler 新增每 10 分钟 watchdog。默认 900 秒没有持久更新的 `running` Run 收敛为 `failed / AI_RUN_STALE_TIMEOUT`；超过审批有效期且仍停在 `waiting_approval` 的 `pending / approved / rejected` 决定统一收敛为 `expired / AI_AGENT_APPROVAL_EXPIRED`，覆盖“决定已保存但恢复请求中断”的半完成状态。处理时吊销能力令牌、设置取消标记，并为失败 Run 补齐助手错误占位。
- 父仓库新增 `verify-ai-gateway-runtime-env.sh`，比较期望 Gateway-safe env、五个运行容器的实际 `Config.Env` 以及容器间一致性，只输出不一致变量名，不输出 Token 或 Secret。检查已接入本地 dev/prod 启动、Service Token 轮换和 staging start/deploy；新增 `MYAPP_AI_AGENT_RUNTIME_ENABLED` 与 `MYAPP_AI_RUN_STALE_TIMEOUT_SECONDS` 的同步和 Compose 配置。
- 本地首先准确检出 Backend、Scheduler 尚未加载新增参数，以及 Backend 的 `MYAPP_AI_VECTOR_EXCLUDED_ITEM_PREFIXES` 仍是旧值；执行 `sync-ai-gateway-env.sh` 并只 recreate `backend / queue-short / queue-long / queue-ai-vector / scheduler` 后，五容器一致性检查 PASS。没有删除 orphan、数据库、卷或本地 Secret 文件。
- 本地 `bench --site localhost migrate` 成功；`myapp.tasks.cleanup_stale_ai_runs` 已注册为 `*/10 * * * *`。Backend Ping 返回 `pong`；真实数据库回滚式调用 watchdog 与 `get_conversation` 新查询均成功，没有保留测试写入。
- 最终验证：Backend 全量 857 tests PASS、定向 45 tests PASS、容器 Python compile PASS；Web TypeScript、Biome、51 suites / 328 tests PASS，AI 定向 58 tests PASS；Shell `bash -n`、三仓库 `git diff --check` PASS。Jest 仍输出项目既有 open-handle 提示，但退出码为 0。
- 本阶段不增加关键词寒暄、机械回复或前端伪完成；模型/Provider 自身首 Token 慢继续由后续模型选择和治理策略处理。本阶段未推送、未部署 staging/production。
- 下一步只有在用户明确要求后才推送并部署 staging。staging 人工验收应覆盖：运行中刷新、切换会话后返回、审批后网络中断、终态后 Sender 恢复，以及故意制造一组容器旧环境时部署脚本能失败关闭。

## 2026-09-01 本地 AI 模型健康误阻断修复已完成并本地提交

- 根因不是模型配置版本或商品/库存代码：03:16 定时探测中 `gpt-5.5`、`gpt-5.6-luna` 单次收到 `PROVIDER_HTTP_429`，Backend 旧逻辑立即持久化为 `unavailable`；模型恢复后 Orchestrator 仍可能在 30 秒缓存内读取旧健康快照，固定模型请求因此在首 Token 前被 `AI_MODEL_HEALTH_UNAVAILABLE` 阻断。
- Backend 健康状态改为三态：成功立即 `available`；401/403、alias 缺失等确定性错误立即 `unavailable`；429、超时、5xx 和连接异常首次为 `degraded`，连续瞬态失败才 `unavailable`。首次降级保留既有工具/视觉能力，模型同步也不会覆盖三态健康事实。
- 健康写入与审计先提交数据库，再调用受 Service Token 保护的 Orchestrator 缓存失效端点；通知失败不回滚健康结果，并通过 `runtime_cache_invalidated=false` 暴露。
- Orchestrator `RuntimePolicyResolver.invalidate()` 只使缓存过期，保留最后已验证快照作为依赖故障兜底。固定模型缓存为不可用、或自动模型链全部缓存为不可用时，普通 Chat、SSE 和结构化草稿会强制刷新一次快照，刷新后仍不可用才由 Runtime Guard 阻断。
- Web 模型选择器把 `degraded` 显示为“临时波动”且保持可选；`unavailable` 继续显示“不可用”并禁用。模型管理页和健康检查结果同步展示可用、临时波动、不可用三类数量。
- 当前验证：Backend 30 tests PASS，容器 Python compile PASS；AI 33 tests + 6 subtests PASS，Ruff PASS；Web 定向 43 tests PASS，TypeScript、Biome PASS；三仓库 `git diff --check` PASS。Jest 仍输出既有 open-handle 提示但退出码为 0。
- 已提交：Backend `f919642 fix(ai): tolerate transient model health failures`；AI Orchestrator `25e55e7 fix: refresh stale model health policy cache`；Web `24ac7ff fix(ai): distinguish transient model health`。尚未推送、未部署 staging/production。
- 本地已只重建/重启 `ai-orchestrator`，新容器为 healthy。Backend 容器通过内部 Service Token 调用缓存失效端点返回 `invalidated=true`；随后固定 `gpt-5.6-luna` 的真实最小 Chat 请求返回 HTTP 200 和实际 `model_alias=gpt-5.6-luna`，未再出现 `AI_MODEL_HEALTH_UNAVAILABLE`。本次没有部署测试服务器。
- 下一步由用户决定何时推送和部署 staging；production 未操作。

## 2026-09-01 AI 商品候选续接与库存编辑流程已完成并本地提交

- Backend 已提交 `3af5961 fix(ai): streamline product and inventory draft actions`；Web 已提交 `8e4cec1 fix(ai): continue product inventory workflows`。
- 商品查询卡片的“编辑商品资料”和“调整库存”现直接调用确定性草稿接口并打开共享编辑器，不再把商品名填回输入框，也不调用模型或创建 AI Run。确定性动作仍保存来源会话中的用户动作、系统回执、草稿版本和幂等信息；草稿 `source_run` 使用唯一 `AI-ACTION-*` 业务动作标识满足现有数据库约束，但不存在对应模型 Run 或模型用量。
- 未唯一匹配商品的库存草稿直接显示候选按钮。用户下一条文字如“可口可乐”能唯一命中当前草稿候选时，Web 调用 `select_ai_draft_product_candidate_v1` 更新同一个草稿，保留增减方式、数量、单位、仓库、原因和日期；“百事可乐”等仍匹配多个候选时不猜测、不重新搜索，而是打开原草稿要求明确选择。
- 商品完善弹窗新增公司总库存、分仓库存、库存基准单位和“调整此商品库存”入口。库存仍通过独立库存调整草稿处理，不与商品主数据混写；已有商品的库存基准单位在普通完善流程中继续锁定。
- 库存草稿和商品上下文都会检查 `UOM.myapp_business_selectable`。异常、科学或未纳入日常业务目录的库存基准单位返回 `requires_uom_migration` 并阻断库存执行；Web 改为“处理单位异常”，直接进入 `/master-data/products/{item_code}?uom_migration=1` 的受控单位错误迁移流程。
- 真实 HTTP 用例 `GatewayHttpTestCase.test_ai_product_actions_prepare_drafts_without_model_generation` PASS，确认 Web 参数组合、Frappe Gateway 路由、`ai_api` adapter 和 Service 全链路可用，响应没有 `run_id`。为完成本地 HTTP 验证，只在现有 Backend 容器内启动 `bench serve --port 8000 --noreload --nothreading`；未重启容器、数据库、队列或卷。
- 真实数据库回滚式演练以 `Administrator` 验证：正常商品可准备商品完善与库存调整草稿并返回已配置单位；真实异常商品 `可口可乐-5000ML / Wavelength In Megametres` 被单位治理阻断；没有创建模型 Run；最终 rollback 后新增会话和草稿均为 0。
- 最终验证：Backend unit 全量 854 tests PASS，新增 HTTP smoke PASS，Python compile、Ruff、Backend diff check PASS；Web TypeScript、Biome、51 suites / 326 tests、Web diff check PASS。Jest 仍保留既有 JSDOM `getComputedStyle` 与 open-handle 噪音，但退出码为 0。
- 本阶段未推送、未部署 staging 或 production。下一步仅需按用户安排进行真实浏览器人工验收，或在明确要求后推送并部署测试环境；本地代码阶段已完成。

## 2026-08-31 单位与库存 P4 包装单位目录去歧义已完成并本地提交

- Backend 已提交 `9b9712d fix(inventory): disambiguate packaging units`；Web 已提交 `e778f3c fix(inventory): clarify packaging unit choices`。
- 根因确认：标准目录同时把 `Box / Case / Carton` 标记为日常业务可选，且三者数据库 symbol 都是“箱”；后端展示又优先读取中文 symbol，导致稳定编码不同但下拉标签重复。真实商品 `可口可乐-5000ML` 的换算表始终只有错误库存基准单位和 `Box=24`，并不存在四套“箱”换算。
- 目录治理结果：`Box` 继续作为副食、批发场景唯一默认“箱”单位；`Case / Carton` 不删除、不改写历史引用，但默认 `myapp_business_selectable=0`，分别显示为“箱装/纸箱”。管理员仍可在单位管理页显式重新设为业务可选。
- 标准 UOM 同步只在新建标准单位时应用业务可选默认值，不再覆盖管理员对已有单位的业务可选治理选择。新增一次性 patch 负责把既有 `Case / Carton` 默认关闭并修正 symbol，新安装场景也由原字段 patch 按当前目录默认值初始化。
- Web 展示兼容旧响应中的 `Case/Carton + symbol=箱`，仍强制区分为“箱装/纸箱”。AI 库存草稿继续只使用唯一匹配商品返回的 `available_uoms`；商品刚在表单中更换但尚未保存重新校验时，单位下拉保持禁用并提示保存后加载，不回退全局 UOM。
- 本地 `bench --site localhost migrate` 成功。迁移前 `Box / Case / Carton` 均为“箱”且业务可选；迁移后为 `Box=箱/1`、`Case=箱装/0`、`Carton=纸箱/0`。以 `Administrator` 真实调用 `list_uoms_v2(search_key="箱", enabled=1, business_selectable=1)` 只返回 `Box（箱）`；历史展示映射仍返回 `Case=箱装`、`Carton=纸箱`。
- 真实商品数据未改写：`可口可乐-5000ML` 仍为 `Wavelength In Megametres=1` 与 `Box=24`。本阶段只治理 UOM 主数据目录和显示，不执行 P3 商品替代迁移。
- 最终验证：Backend 全量 847 tests PASS，Python compile、Ruff、Backend diff check PASS；Web TypeScript、Biome、50 suites / 321 tests、Web diff check PASS。Jest 仍保留既有 open-handle 提示但退出码为 0。
- 本阶段未推送、未部署 staging 或 production。父仓库本次提交同步 Backend 子模块指针与本交接记录；Web 仍为独立仓库提交。

## 2026-08-31 单位与库存 P3 受控错误商品迁移已完成并本地提交

- Backend 已提交 `1419849 feat(inventory): add controlled product UOM migration`；Web 已提交 `1aef312 feat(inventory): add product UOM migration workflow`。
- 新增只读 `assess_product_uom_migration_v1`：仅 `Administrator / System Manager` 可用，返回源商品版本、现有单位、全部 Bin 库存与占用、历史 Stock Ledger Entry、未完/草稿销售采购订单、全部价格、全部条码、现有 Item Alternative、blocker 与 warning。
- 新增幂等 POST `execute_product_uom_migration_v1`：强制 `Idempotency-Key`、源 `modified` 乐观锁、源 Item 与现有 Bin 行锁；执行前重新评估，不接受旧评估结果直接写入。
- 执行规则：不原地修改历史商品 `stock_uom`；用户必须明确提供新商品编码、正确业务可选库存单位、完整换算表，并逐条决定价格 `copy / skip`、条码 `move / keep` 及目标单位。任何遗漏、未知单位或自动猜测均失败关闭。
- 有实际库存、预留/在途/计划/请购数量、未完成或草稿销售采购订单、模板/变体、固定资产时阻断。零库存时创建新 Item、原子迁移选中条码、复制选中 Item Price、创建 ERPNext 原生 `Item Alternative`，成功后停用源商品；失败整体回滚，历史 SLE、历史单据和源价格不改写。
- Web 商品详情新增“单位错误迁移”入口：先展示评估报告和阻断项，再填写新商品与换算表；价格/条码迁移动作初始均为空，必须人工选择。blocker 存在时执行按钮禁用，成功后跳转新商品详情。
- 真实商品 `可口可乐-5000ML` 只读评估结果：实际库存 0、库存占用 0、历史 SLE 2、条码 0、旧价格 4；当前 `can_execute = true`。四条价格仍为原错误单位 `Wavelength In Megametres`，本阶段没有猜测或修改真实数据。
- 本地数据库事务演练使用临时商品验证完整执行：源商品停用、新商品 `Nos + Box=24`、箱码迁移、箱价复制、Item Alternative 创建均成功；随后整体 rollback，确认临时 Item 不存在。
- 最终验证：Backend 全量 841 tests PASS；定向 154 tests PASS；Python compile、Ruff、Backend diff check PASS。Web TypeScript、Biome、49 suites / 317 tests、Web diff check PASS；JSDOM 保留既有 `getComputedStyle` / open-handle 噪音但退出码为 0。
- 本阶段未推送、未部署 staging 或 production。真实错误商品的最终替代迁移仍需要用户确认：新商品编码、正确库存基准单位、换算表，以及四条价格分别复制到哪个单位或跳过。实际执行应安排短暂受控作业窗口，避免同一商品并发收发或改单。

## 2026-08-31 单位与库存 P1/P2 已完成并本地提交

- P1：Backend `7eb245c`、Web `b42a166`、Parent `9c1bb67f`。通过 `UOM.myapp_business_selectable` 分离“系统保留单位”和“日常业务可选单位”；标准业务单位自动可选，科学单位保留但不进入普通业务下拉。迁移后本地 UOM 275 个，业务可选 48 个；`Box / Nos` 可选，`Wavelength In Megametres` 不可选。
- P2：Backend `22dae4c`、Web `d578390`、Parent `891c05a0`。正式使用 ERPNext 原生 `Item Price.uom` 与 `Item Barcode.uom`；Item Price 以商品、价格表、币种、单位定位，同一价格表可同时维护件价和箱价。新增条码必须选择商品已配置单位，商品详情按单位显示价格与条码。
- P2 没有自动修正历史空单位或错误单位数据；真实错误商品四条价格保持原样，交由 P3 受控迁移人工确认。

## 2026-08-31 单位与库存 P0 治理已完成并本地提交

- Backend 已提交 `0b2471e fix(inventory): enforce item unit conversions`。统一单位解析支持商品已配置单位的稳定编码、中文展示名、符号和标准别名；未知或歧义单位失败关闭；整数单位拒绝小数数量。AI 销售、采购、库存草稿同步返回 `available_uoms` 与 `uom_resolution_error`，不再把未知单位静默替换为库存基准单位。
- 单品库存调整已从 `Material Receipt / Material Issue` 改为正式 `Stock Reconciliation`，与批量盘点语义统一；差异原因必填，响应新增 `stock_reconciliation` 并保留兼容字段 `stock_entry = None`。
- Web 已提交 `31a5ed6 fix(inventory): govern product units and stock adjustments`。商品新增/编辑可完整维护单位换算表，已有商品的库存基准单位在普通编辑中锁定；普通保存不再用一条基准单位换算覆盖既有 `Box=24` 等配置。
- 库存盘点、库存转仓与 AI 草稿的单位选项只来自当前商品已配置单位，并显示输入数量、换算系数、基准数量和库存差异预览。AI 草稿更换商品后先清空旧单位，保存并重新校验后再加载新商品可选单位，避免旧商品单位串用。
- 真实本地数据确认商品 `可口可乐-5000ML` 当前错误 `stock_uom = Wavelength In Megametres`，同时存在 `Box = 24` 和历史 Stock Ledger Entry。共享解析已能把 `1000 箱` 解析为 `1000 Box = 24000` 基准单位，但本阶段没有直接修改该商品；ERPNext 会阻止对存在历史流水的商品直接改库存基准单位，后续必须走受控迁移。
- 最终验证：Backend 定向 164 tests PASS；此前本阶段 Backend 全量 481 tests PASS；Python compile、Ruff lint、Backend diff check PASS。Web TypeScript、Biome、48 suites / 313 tests、Web diff check PASS。Jest 保留既有 open-handle 提示但退出码为 0。
- 本阶段未推送、未部署 staging 或 production。按用户约定，大功能阶段先提交再继续开发，不把部署作为下一开发步骤的前置条件。
- 后续阶段：建立“系统 UOM / 日常业务可选 UOM”目录隔离科学单位；补齐 Item Price 按 UOM、Item Barcode 按 UOM；设计并演练错误商品受控迁移流程，再处理真实错误商品数据。

## 2026-08-31 AI 发送延迟与图片预览修复已部署 staging

- Backend `develop` 已推送到 `44314ba41bf2422684188636dc10632c8ba812f5`，包含自动场景路由稳定性与一次性场景解析复用。
- Parent `develop` 已推送到 `9c0082227a51dd84f0925f64fb0a734773f866f7`，准确固定 Backend `44314ba` 和 AI Orchestrator `51f584f`。
- Web 业务候选为 `148878daacff63782dd349abd81141ffd25aba29`，包含立即回显、路由阶段停止、场景解析复用和私有图片预览代理。部署 workflow 的 GHCR 长期 PAT 已失效并返回 `denied`，现以 `e8a09f1dbe7c431d43473d6843b68dc32a04608c` 改为 `packages: read` + 当前 Run 短期 `GITHUB_TOKEN`；同时修复 Markdown-only 提交被 lint-staged 错误交给 Biome 的钩子配置。
- 不可变标签：ERP/AI `staging-20260831-9c008222`；Web `staging-web-20260831-148878d`。均未推送 `latest`。
- Build：Parent Run `33346569707` SUCCESS；Web Run `33346571474` SUCCESS，包含 TypeScript、Biome、全量 Jest 和镜像推送。
- ERP/AI 首次 Deploy Run `33346825883` 在 GHCR 拉取阶段因外部 `EOF` 失败；同一标签一次有上限重试 Run `33346911195` SUCCESS。`bench migrate` 完成，`check-staging.sh` 通过，Backend、Frontend、Worker 与 AI Orchestrator 均使用新标签；AI、数据库和 Qdrant healthy，Backend→AI 认证、有效 Policy、tool-ready/vision-ready 模型、首页和 Ping 均通过。
- Web 首次 Deploy Run `33347046183` 因旧 GHCR PAT `denied` 失败，旧容器未被删除；凭据 workflow 修复后，同一业务镜像 Deploy Run `33347322049` SUCCESS。Web 镜像 digest `sha256:3538b715eab768806d6fb1fa817733fe9cce6ad08a81f5826f861acf866579ba`。
- 测试网 `192.168.31.229:30080`：`/healthz` 200、`/user/login` 200、`/api/method/ping` 200 `pong`；未认证 `/private/files/...` 返回 Backend 403，证明私有文件代理未落到 SPA。
- 使用真实测试账号执行 `resolve_ai_scenario_v1`：200、`AI_SCENARIO_RESOLVED`、`product_search`、返回 `resolution_id`。随后复用该 ID 的正式 SSE：200，约 8.79 秒完成，存在 `completed` 且无 `error`；此前 HTTP 500、Prompt 版本不一致和重复 intent 问题均未复现。
- staging 图片真实验收：上传 PNG 200；Backend 规范化后经 Web 私有路径预览 200 `image/webp`；测试附件删除 200 且 `discarded=true`，未留下测试图片。
- production 未操作。剩余仅为用户在真实浏览器中确认即时回显、缩略图视觉显示和停止按钮交互。

## 2026-08-30 AI 图片上传后本地预览失败：本地修复记录（现已部署 staging）

- 截图中的图片并非上传失败。附件 `AI-ATT-587bb61cba36394c91c478bf3534c801` 已处于 `uploaded`，真实文件 `/private/files/3e66bab3a7190ca67efa185c627c5c6f2d5dd2.webp` 已落盘，大小 70,782 bytes，尺寸 984×762。
- 根因是 `frontend/myapp-web/config/proxy.ts` 只转发 `/api/method/` 和公开 `/files/`，遗漏 Frappe 私有文件路径 `/private/files/`。在未配置绝对 API Base URL 的本地环境中，AI 附件预览请求会落到 Umi 8001，因此上传成功后仍显示预览失败。
- Web 已为 `dev/test/pre` 补齐 `/private/files/` 代理，并新增配置回归测试，要求公开与私有文件代理保持同一 Backend target；Web 开发文档已同步说明修改代理后需重启开发服务。
- 提交：Web `148878d fix(ai): proxy private attachment previews`。现已推送并随 `staging-web-20260831-148878d` 部署 staging。
- 验证：TypeScript PASS；Biome 253 files PASS；定向代理测试 6/6 PASS；全量 48 suites / 313 tests PASS；`git diff --check` PASS。
- 真实运行态使用本地 JWT 访问 `http://localhost:8001/private/files/3e66bab3a7190ca67efa185c627c5c6f2d5dd2.webp`，返回 `200 image/webp`、70,782 bytes，并识别为 984×762 WebP。无 JWT 时返回 Backend 403，证明请求已正确经过代理且私有文件认证仍然生效。
- 同一附件经 Web 8001 → Gateway → `resolve_ai_scenario_v1` 的真实只读多模态请求返回 `200 / AI_SCENARIO_RESOLVED`，场景为 `product_search` 且生成 `resolution_id`。验证后数据库仍为 `status=uploaded`，`conversation/message_id/source_run` 均为空，未提前绑定或消耗用户待发送附件。
- 仍需用户在现有浏览器登录态重新选择或重新打开该图片，确认缩略图视觉显示正常；该人工 UI 确认不影响继续本地开发，也不要求先部署。

## 2026-08-30 AI 工作台发送延迟二期：重复 intent 已修复并部署 staging

本节是当前最高优先级状态。用户已确认点击发送后消息可以立即进入对话列表；本阶段继续处理复杂 `auto` 请求中由项目代码造成的重复模型串行，不处理 Provider/模型自身首 Token 性能，也不增加关键词问候、固定寒暄或页面伪造 AI 回复。

### 已完成

- Web 路由阶段现可直接点击“停止生成”；同一 `AbortController` 从 `resolve_ai_scenario_v1` 复用到正式 SSE，路由尚未完成时停止不会继续启动 Chat，也不会在没有 Run ID 时错误调用 `cancel_ai_run_v1`。
- `resolve_ai_scenario_v1` 现返回短期 opaque `resolution_id`。Web 对只读 `auto` Chat 把它作为 `scenario_resolution_id` 原样交给正式 SSE。
- Backend 只在当前用户、规范化内容、公司、会话 ID、`conversation-state-v2` 版本、附件 ID 和固定模型全部一致时一次性复用服务端缓存的结构化 intent。过期、重复、篡改或上下文变化自动回退正常 intent 解析；浏览器不能提交或修改 intent JSON。
- 因此复杂查询链路从“前置 intent + Chat 内重复 intent + 正式模型”收敛为“前置 intent + 正式模型”。该改动不改变模型回复内容、工具权限、公司隔离或草稿人工复核边界。

### 提交

- Web：`34f9370 fix(ai): allow stopping during scenario routing`
- Backend：`44314ba perf(ai): reuse automatic scenario resolution`
- Web：`55ecf0a perf(ai): reuse automatic scenario routing`
- Parent：`9c008222 chore(ai): pin scenario resolution reuse`
- 上述提交现已推送并随 `staging-20260831-9c008222` / `staging-web-20260831-148878d` 部署 staging；production 未操作。

### 验证

- Web：TypeScript PASS；Biome 252 files PASS；AI 页面与领域 Service 54/54 PASS；全量 47 suites / 307 tests PASS；`git diff --check` PASS。
- Backend：`test_ai_service + test_gateway_wrappers` 286/286 PASS；新增测试覆盖一次性上下文绑定、缓存失配回退、Gateway → `ai_api` → Service 参数贯通；`git diff --check` PASS。
- 本地真实 HTTP 顺序 `resolve_ai_scenario_v1 → stream_ai_message_v1(scenario_resolution_id)` PASS，单用例约 33.095 秒完成。
- 同一验证时间窗的 Orchestrator 日志只有 1 次 `/internal/v1/intent/parse`、1 次受控商品向量查询和 1 次 `/internal/v1/chat/stream`，没有第二次 intent。
- 为载入 Backend 新源码，仅精确重启本地 `frappe serve --port 8000 --noreload --nothreading` 进程；容器、数据库、队列、卷和 staging 均未变更，最终 Ping 返回 `pong`。

### 当前结论与后续节奏

- 已确认的项目代码额外等待包括“发送后延迟回显”和“复杂 `auto` 双 intent 串行”，两项均已修复。当前真实链路仍需一次结构化 intent 和一次正式模型生成，剩余主要等待取决于可用模型与 Provider 首 Token。
- 用户明确要求：模型自身回复慢不做机械关键词回复；后续通过模型选择、生产级 fallback、健康熔断和治理策略处理。
- 用户明确要求：一个功能或阶段完成后先提交，再继续开发；大改动期间不频繁部署，部署不是进入下一开发步骤的前置条件。当前阶段已按 Backend、Web、Parent 边界提交，继续开发前不部署。
- 下一步若继续优化延迟，只评估不会改变回答语义的模型治理、快速 intent 专用模型或统一服务端 Run 架构；不得重新引入关键词回答。若转入其他缺陷，则从本节提交基线继续。

## 2026-08-30 AI 工作台发送延迟一期修复：本地已完成，待人工浏览器验收与提交

本节是当前最高优先级状态。它补充并更新下方“Web 自动场景识别 HTTP 500”章节：本地公开场景解析、正式 SSE 顺序和 Provider fallback 已完成真实 HTTP 验证；staging 尚未部署，仍不能表述为 staging Web 端到端通过。

### 根因与本轮修复

- Web 原流程在 `await resolveAiScenario()` 返回后才追加用户消息、清空输入框和设置发送态。意图模型等待期间页面看起来像点击无反应，`loading` 保护也设置过晚，快速双击可能重复进入提交函数。
- Web 现已在任何网络请求前同步设置 `submitInFlightRef`，立即追加用户消息和 assistant 占位消息、清空输入与待发送附件，并显示 `routing / 正在识别业务场景`；场景解析失败进入统一可见错误状态，最终统一释放发送锁。
- Backend `resolve_ai_scenario_v1` 对无附件的精确问候/帮助/感谢文本，以及确定性的四类写草稿操作，仍完成用户、公司、会话和模型权限校验，但跳过远程 intent 模型。复杂语义、图片和非精确问候继续使用结构化 intent，不把关键词解释复制到 Web 页面。
- 审查真实 SSE 后发现正式 `stream_ai_message_v1(scenario=auto)` 会在 `_prepare_chat_run` 内再次调用 intent。现已为同一组无附件精确问候和明确草稿增加 `local_fast_path`，避免“前置 resolve 已本地识别，正式 Chat 又调用一次 intent”的重复模型串行。
- 本地模型注册表显示默认 `opencode-deepseek-v4-flash` 为 `unavailable / PROVIDER_HTTP_403`，同时没有已发布 Policy，系统默认 fallback 为空。仅在本地忽略文件 `.env.ai.local` 配置 `gpt-5.5,gpt-5.6-luna` 有序 fallback，并强制替换 `ai-orchestrator`；没有修改 AI 源码、治理 Policy、数据库、卷或 staging。

### 本地真实结果

- `resolve_ai_scenario_v1(content="你好", company + conversation_id)`：`0.010s`，返回 `general`，Orchestrator 无 `/intent/parse`。
- 补正式 Chat 快速路径前，同一条完整 SSE：首事件 `17.781s`，总计 `35.202s` 后失败且无 Token。
- 补正式 Chat 快速路径后、尚未配置 fallback：首事件 `0.039s`，总计 `18.311s` 后返回 `MODEL_PROVIDER_REJECTED`；日志只有 `/chat/stream`，无 `/intent/parse`。
- 配置本地自动 fallback 后：首事件 `0.014s`，首个正文 Token `18.988s`，总计 `20.524s` 完成，返回 133 字；模型从不可用默认 alias 切到 `gpt-5.5`，无 intent 请求。
- 因此“点击后数秒消息才进入列表”和双 intent 串行已修复；当前剩余约 19 秒主要是可用正式模型的首 Token 延迟，不再是前端回显或场景路由阻塞。

### 已通过验证

- Web：`npm run tsc` PASS；`npm run biome:lint` 252 files PASS；`npm test -- --runInBand src/pages/AI/index.test.tsx` 27/27 PASS。Jest 仍输出既有 JSDOM `getComputedStyle` 和 open handle 提示，但退出码为 0。
- Backend：`test_ai_service` 143/143 PASS；`test_gateway_wrappers` 140/140 PASS；新增快速路由定向 4/4 PASS。
- Parent、Web、Backend、AI `git diff --check` 全部 PASS。
- 本地 Backend 已以 `/home/frappe/frappe-bench/sites` 为工作目录、使用 bench virtualenv Python 和 `frappe serve --port 8000 --noreload --nothreading` 重载；`localhost:8080/api/method/ping` 正常。AI `/health` 为 revision `51f584f9...`、Prompt `erp-readonly-v11 / erp-intent-v6`。

### 当前工作树与下一步

- Web `frontend/myapp-web` 未提交：`src/pages/AI/index.tsx`、`src/pages/AI/index.test.tsx`。
- Backend `apps/myapp` 未提交：本轮 `myapp/services/ai_service.py`、`myapp/tests/unit/test_ai_service.py`，以及下方 HTTP 500 修复已有的 API、文档和测试文件；不得拆掉或覆盖先前修复。
- Parent 继续保留用户已有文档修改、`.codex` 和工作总结；本节只更新当前交接文件。`.env.ai.local` 是本地忽略配置，不得提交或在日志/文档中记录 Key、Token。
- 尚未执行真实浏览器人工验收。接手后应验证：点击立即回显和清空、快速双击只提交一次、“你好”无 intent、明确四类草稿正确路由、复杂查询仍调用 intent、图片仍走多模态识别。
- 当前约 19 秒的正式模型首 Token 延迟已确认属于模型/Provider 性能。用户明确要求不为此增加关键词模板或机械问候回复；后续通过选择更合适的模型、生产级有序主模型/fallback、健康熔断和按错误类型停止无效重试处理。统一服务端单 Run 仍可作为减少编排往返的长期架构优化，但不得用页面伪造回复掩盖模型延迟。
- 尚未提交、推送或部署 staging/production。提交时 Web 只在独立 Web 仓库提交；Backend 在 `apps/myapp` 提交，用户要求完整 Backend submission 时再更新 Parent submodule pointer。

## 2026-08-29 Web 自动场景识别 HTTP 500：本地已修复，待提交与 staging 验收

本节是当前最高优先级状态，优先于下方“staging 测试候选已部署”的健康与 Agent 语义验收结论。用户通过 Web 工作台 `auto` 模式发送消息时会先调用 `resolve_ai_scenario_v1`；该接口原先在本地和 staging 均可稳定复现 HTTP 500。Backend 本地工作树现已完成代码与回归测试修复，公开 HTTP 入口不再返回 500；修复尚未提交、推送或部署 staging，因此 staging 仍运行受影响 revision，继续属于发布阻断项，不得归类为网络或 Provider 瞬时波动。

### 现象与根因

- 浏览器请求 `POST /api/method/myapp.api.gateway.resolve_ai_scenario_v1` 返回 `INTERNAL_ERROR / 系统内部错误，请稍后重试`。
- Frappe `Error Log` 连续三次记录：`TypeError: resolve_ai_scenario_v1() got an unexpected keyword argument 'company'`。
- `myapp.api.gateway.resolve_ai_scenario_v1` 已接收并向下一层传递 `company`、`conversation_id`；但中间 `myapp.api.ai_api.resolve_ai_scenario_v1` 包装函数仍只接受 `content`、`attachment_ids`、`model_alias`，没有接受和转发新增参数。异常发生在 Backend Python 调用边界，请求尚未进入 AI Orchestrator。
- 修复前 Backend 工作树为 clean，Host 与容器内源码一致，Backend 基线 revision 为 `50217ab7250b2703b548376d56d7c3ee36676efd`；这不是未重启、挂载不同步或本地脏改动造成的版本混用。当前 Backend 已在该 revision 上产生未提交修复，staging 仍运行原 revision，因此 Web 自动场景链路在 staging 仍受影响。

### 为什么此前门禁没有发现

- Gateway 单元测试 patch 了 `myapp.api.gateway.resolve_ai_scenario_v1_service`，只断言 Gateway 传出了新增参数，实际中间 `ai_api` 包装函数没有执行。
- `ai_service` 单元测试直接覆盖最底层服务；最底层函数本身已经支持 `company`、`conversation_id`，因此也无法发现中间包装层签名漂移。
- Web 服务测试 mock 了 Gateway HTTP 调用，只验证请求载荷和响应映射，不会执行 Backend Python 包装链。
- 之前“带莫字”和“可乐”staging 验收验证的是同 revision 的真实 Agent Runtime、工具、真实数据和回答结果，但调用路径绕过了 Web `requestedScenario=auto` 的前置场景解析请求；它是有效的 Agent 语义旁证，不是完整浏览器端到端验收。
- `check-staging.sh` 当前覆盖容器、AI 健康、Backend→AI 认证、Policy、首页和 Ping，不覆盖 `Web → Gateway → ai_api → ai_service → Orchestrator` 的业务入口。

### 已完成修复与验证

1. `myapp.api.ai_api.resolve_ai_scenario_v1` 已增加 `company`、`conversation_id` 参数并完整转发到 Service。
2. 新增 `test_resolve_ai_scenario_preserves_context_through_ai_api_adapter`，测试只 Mock adapter 之后的 Service，真实执行 `gateway → ai_api`，防止中间包装层再次漂移。
3. 新增 `test_ai_auto_scenario_resolution_accepts_company_and_conversation`，创建带公司范围的真实会话后，通过公开 HTTP 入口携带 `content + company + conversation_id` 调用场景解析。
4. Backend 容器内 `test_gateway_wrappers` 140 tests PASS；新增真实 HTTP 回归 1 test PASS；本地 `Host: localhost` Ping 正常。
5. 为载入修改，仅按既有 `.vscode/launch.json` 参数重启了 `bench serve :8000 --noreload --nothreading`；没有重建容器、修改数据库或删除卷。
6. Backend 500 修复后，本地浏览器进一步暴露 `AI_PROMPT_VERSION_MISMATCH`：本地 AI 容器仍运行旧 revision `98f01b82...`，只支持 `erp-readonly-v9 / erp-intent-v5`，而当前 Backend 与 AI 源码要求 `erp-readonly-v11 / erp-intent-v6`。已按 AI revision `51f584f9ea01b139883374e173b02f545d397a32` 单独重建并替换 `ai-orchestrator`；新 `/health` 返回对应 revision、Prompt versions `erp-readonly-v11 / erp-intent-v6`，随后真实 HTTP 场景解析回归再次 PASS。没有删除 orphan 容器、数据库、卷、向量数据或治理报告。

### 仍需完成

1. 在本地 Web 工作台以 `requestedScenario=auto` 执行“场景解析 → 后续 Chat/SSE 或草稿”的完整发送顺序；当前已验证前置公开 HTTP 入口，但尚未把浏览器后续请求作为同一条端到端用例验收。
2. 提交并推送 Backend 修复；需要完整后端提交时，再更新并提交 Parent 的 Backend submodule pointer。
3. 按 staging 规则构建同一 immutable revision、部署并运行真实浏览器入口或等价 HTTP 顺序 smoke。只有 staging 验收完成后，才能表述“Web AI 工作台完整链路已通过”；在此之前现有 staging AI 语义结果仍只能作为底层 Agent/工具链旁证。

## 2026-08-29 商品空结果重试汇总修复：staging 测试候选已部署

本节是当前最新状态，优先于下方旧快照。本次仅部署测试服务器，不是 production 或 release-grade 正式发布；用户已明确纯 Provider 超时、网络延迟和单次模型空响应不阻断测试部署，只有业务逻辑、权限、安全、数据一致性或可复现的原则性错误才阻断。

### 版本与部署

- Parent `develop`：`a04023587f5a68cc9a2e5d674d6091b1396d0e26`，提交 `chore(ai): pin staging product retry fix` 已推送。
- Backend：`50217ab7250b2703b548376d56d7c3ee36676efd`，本轮未改源码。
- AI Orchestrator：`51f584f9ea01b139883374e173b02f545d397a32`，修复确定性多工具汇总保留已被后续成功重试取代的旧 `search_products not_found` 文案。
- staging 标签：`staging-20260829-a0402358`。
- Build run `33244522287` 成功；Deploy run `33244666523` 成功，包含 `bench migrate` 与 `check-staging.sh`。
- AI 镜像 revision 已核对为 `51f584f...`，镜像 ID `sha256:70d7e16b06916b52d9e91e5a552e116e4e85d314baed1dd68a6418b137f111a9`。
- Policy 保持 `agent-general-staging-rgc-demo` v31、active；没有发布 v32，没有替换服务器现有正式治理报告。
- AI Orchestrator healthy、RestartCount 0；Backend running、RestartCount 0；Backend 到 AI 内部认证、首页与 Ping 均通过。

### 门禁边界

- `51f584f` 已通过 Ruff、pre-commit、宿主机 195 tests、Docker 195 tests、runtime image、offline 40/40、targeted live 15/15 和恢复预检 3/3。
- canonical live full gate 为 38/40；失败仅为 `PROVIDER_TIMEOUT` 与 `AI_AGENT_MODEL_EMPTY_DECISION`，工具选择、参数、权限、trajectory、Grounding、安全和禁止模式均为 100%。这份报告必须如实保留为 38/40，不能冒充正式 PASS，也不能用于发布新治理 Policy。
- 根据用户明确授权，本 revision 仅作为 staging 测试候选部署；production 仍未操作。

### staging 真实业务验收

- “查询一下有没有带莫字的商品”：Run `AI-RUN-35866288275942aebbd1f954a809c6ba`，Policy v31，返回“1 个待确认候选：迪莫”并询问是否正确；没有声称唯一匹配，没有 Grounding 失败。
- “查询可乐相关商品，把候选都列出来让我确认”：Run `AI-RUN-9ab8fe68a3a4474caf3a227837ee0bcc`。真实轨迹为第一次 `search_products` 返回 0、第二次放宽查询返回 4；最终完整列出 `可口可乐-5000ML`、`百事可乐`、`百事可乐-2`、`百事可乐-3` 并要求按名称、编码或规格选择。
- “可乐”最终回答不再包含“未找到匹配商品”，不声称唯一匹配，不自动选择第一条，未出现 `AI_AGENT_OUTPUT_GROUNDING_FAILED`。本轮修复目标已在真实 staging 数据上验证完成。

### 当前运行风险与保留状态

- 2026-08-29 已对目标服务器执行定向空间清理：删除 54 个未被任何运行或停止容器引用的旧 `myapp-erpnext`、`myapp-ai`、`myapp-web` staging 标签，删除 3 个未引用的旧 Mobile Preview dangling 镜像，并回收 36.94MB 无引用构建缓存；未使用全局 `docker system prune`，未清理 volume 或其他项目镜像。
- 清理后服务器根盘约 98GB，已用 64GB，可用 30GB，使用率 69%（清理前为已用 89GB、可用 4.3GB、96%）。Docker Images 从 35.43GB 降至 12.74GB。
- 当前 ERP/AI `staging-20260829-a0402358`、上一条回滚基线 `staging-20260825-ea64c9c6`、当前 Web `staging-20260824-a786d94c` 与上一条 Web 回滚基线 `staging-20260820-27c4dbf` 均已保留并核对镜像 ID。
- 清理后 `check-staging.sh` 完整通过：AI、Backend 内部认证、有效 Policy、tool/vision-ready 模型、首页和 Ping 均正常；Backend、AI、Web、数据库、Redis、Qdrant RestartCount 均为 0。
- 服务器继续保留既有 `M services/myapp-ai`、`?? backups/`、`?? tmp/`，不得清理或覆盖。
- Parent 本地继续保留用户已有 `AGENTS.md`、本交接文件、未跟踪 `.codex` 和工作总结文件；本次只提交了 AI gitlink，交接更新未提交。

### 本地开发环境恢复

- 2026-08-29 17:35 左右，Dev Container 因 `shutdownAction=stopCompose` 触发整栈停止；Docker 明确记录 `hasBeenManuallyStopped=true`、`OOMKilled=false`，不是内存不足或业务代码崩溃。
- 8080 的历史 502 根因是 Dev Container 模式下 Backend 只保持 `tail -f /dev/null`，Frappe `bench serve :8000` 未运行，Frontend 日志为 `connect() failed (111: Connection refused) while connecting to upstream`。
- 已原位启动现有数据库、Redis、Qdrant、Backend、Frontend、Worker、AI 和 Langfuse 容器，没有重建或删除卷；随后按 `.vscode/launch.json` 参数启动 `bench serve --port 8000 --noreload --nothreading`。
- 最终本地 `http://localhost:8000/api/method/ping` 与 `http://localhost:8080/api/method/ping` 均返回 `pong`，`http://localhost:8080/` HTTP 200；数据库、AI Orchestrator 和 Qdrant healthy。当前 Frappe 站点名为 `localhost`，直接以 `127.0.0.1` 作为 Host 访问会因未命中站点而返回 404，这不表示服务故障。
- 2026-08-30 已将本地 AI 容器从旧 Runtime revision `98f01b82...` 单独重建为 `51f584f9ea01b139883374e173b02f545d397a32`。当前 `/health` 为 `status=ok`，Prompt versions 已对齐 `erp-readonly-v11 / erp-intent-v6`；Backend 携带 `content + company + conversation_id` 的真实 HTTP 场景解析回归 PASS。

### 后续提交与部署约定

- 长期规则已写入 `AGENTS.md`、`docs/codex/DEVELOPMENT_GUIDE.zh-CN.md`、`STAGING_DEPLOYMENT.zh-CN.md` 和 `docs/codex/KNOWN_ISSUES.zh-CN.md`。
- 日常 staging 是本地验证后的真实环境效果检查；单次网络、Registry、SSH、DNS、Provider 或 CI Runner 波动不再阻断，也不再触发反复改代码、重建候选或无上限完整门禁重跑。
- 只有可复现业务错误、确定性测试/构建/迁移失败、权限安全问题、数据风险、制品来源不一致或服务无法健康运行才阻断 staging。
- production、最终正式发布候选、重大迁移和安全敏感发布仍执行完整严格门禁；失败或 partial 报告始终如实保留，不能伪装为 PASS。

## 历史快照：2026-08-27（仅供追溯）

以下内容是 2026-08-27 的历史状态，已被上方 2026-08-29 部署与验收结论取代，不得再作为当前 staging 阻断依据。当时商品语义查询、候选澄清和 Web 商品选择器修改均已提交推送，但 staging 仍运行旧基线。

| 环境 | 当前版本 | 状态 | 接手动作 |
| --- | --- | --- | --- |
| 本地 | Parent `df86bbd8`、Backend `4009f29`、AI `af53a18`、Web `fc85745` | Backend/AI/Web 均已提交推送；Parent 尚未提交 Backend/AI gitlink | 等 Provider 稳定后只对同一 AI revision 重新执行一次完整 live gate；通过前不得发布 |
| staging ERP/AI | `staging-20260825-ea64c9c6` | 保持上一版已验证基线；本轮 revision 未部署 | 只有同 revision 完整 live gate PASS 后才可发布新 Policy、构建和部署 |
| staging Web | `staging-20260824-a786d94c` | 未变更 | 随本轮最终 staging 发布统一验收 |
| production | 未操作 | 未部署本轮修改 | 未经用户明确授权不得操作 |

本节及 0H、0G、0F 等后续章节仅用于历史追溯，其中的旧 revision、旧失败数和旧 staging 基线不能覆盖文件顶部的当前状态与新分级规则。

### 仓库状态与不可触碰内容

- Parent `develop` 与 `origin/develop` 同步，HEAD `df86bbd8ea5631eba926e0a90c9630e4746548a1`。Backend/AI gitlink 显示 modified；本地另保留用户的 `AGENTS.md`、本交接文件、未跟踪 `.codex` 和 `docs/codex/AI_MULTIMODAL_WORK_SUMMARY_2026-08-16.zh-CN.md`，不得批量提交、清理或覆盖。
- Backend `apps/myapp`：HEAD `4009f29`，clean，已推送 `origin/develop`。
- AI `services/myapp-ai`：HEAD `af53a18afde7cefa37b3d88ff4a369f30da7744d`，clean，已推送 `origin/develop`。本轮后续提交依次为 `0017d42`、`6a7010e`、`9600b91`、`4b2ad28`、`af53a18`。
- Web `frontend/myapp-web`：HEAD `fc85745`，已推送 `origin/main`。
- Mobile `frontend/myapp-mobile`：`develop` 与远端同步，但存在用户未提交修改：`app/common/product-search.tsx`、`lib/sales-mode.ts`、`services/gateway.ts`、`services/products.ts`、`services/sales.ts`。Mobile 不属于本轮修改，不得提交、回滚或格式化这些文件。

### 发布门禁结论

- Backend 165 tests PASS；Web 47 suites / 304 tests、TypeScript、Biome PASS。最终 AI revision `af53a18...` 为 Ruff、pre-commit、宿主机 180 tests + 14 subtests PASS，Docker test 内 180 tests PASS，runtime image 构建 PASS，canonical offline 40/40 PASS。
- 最终“可乐” targeted live 3/3 PASS：模型用核心词 `可乐` 调用 `search_products`，允许 `auto/contains/semantic` 非精确召回，工具返回 `ambiguous` 后列出可口可乐与百事可乐并要求确认；禁止 `exact`、唯一匹配和自动选第一条。grounding 已允许工具规格字符串中的 `500ml`，同时继续拒绝把规格数字冒充库存数量。
- 最终 canonical live full gate 第一次 38/40 FAIL：`draft.inventory.set_target` 为 `PROVIDER_TIMEOUT`，`agent.product_contains_mo_variant` 为 `PROVIDER_HTTP_500`。两条恢复预检随后 2/2 PASS。
- 唯一一次完整 retry 仍为 38/40 FAIL：`agent.product_contains_mo_variant` 为 `PROVIDER_HTTP_500`，`agent.product_empty_retry_bounded` 为 `PROVIDER_TIMEOUT`；全部已执行场景的结构化字段、工具参数、授权、预算、trajectory、grounding、安全与禁止模式均为 100%。
- 服务器日志确认根因在上游链路：LiteLLM 记录 `chatgpt.com/backend-api/codex/responses` EOF 和 HTTP/2 `PROTOCOL_ERROR`；`cli-proxy-api` 同期记录 `/v1/chat/completions`、`/v1/responses` HTTP 500。不是本轮业务逻辑或 Schema 回归。
- 用户再次明确要求尝试继续部署后，模型列表 HTTP 200、最近 10 分钟 LiteLLM/CPA 无新错误，三个历史失败场景恢复预检 3/3 PASS；但新的独立 canonical full gate 仍为 38/40 FAIL。此次没有 Provider 错误：`agent.product_contains_mo` 触发 `AI_AGENT_OUTPUT_GROUNDING_FAILED / quantity:1`，`agent.order_documents_selection` 遗漏两组 required concepts。两条随后带内容诊断均 2/2 PASS，实际输出分别正确表达“1 个带莫字商品”和完整日期、未完成销售订单，说明仍存在真实模型输出波动；该 partial 不能替代完整门禁。
- 不得通过继续盲目重跑、拼接多次 partial 结果、复制旧报告、降低阈值或沿用旧 Policy 绕过门禁。只有同一 immutable revision 的完整报告 `summary.passed=true`，才能安装 governance reports、发布引用新 manifest 的 Policy 并启动 staging Build/Deploy。

### 接手执行顺序

1. 当前 Provider 健康检查已恢复，但 `gpt-5.6-luna` 在完整 40-case 序列中仍有约 5% 的输出/guardrail 波动；不要继续无上限重跑。应先决定是提升模型链路稳定性、使用经过完整门禁的其他模型，还是进一步增加不会削弱安全性的确定性回答规范。
2. 稳定性调整后，对同一 immutable AI revision `af53a18...`（若代码不变）执行一份新的 canonical 40-case live full gate。旧失败报告和 targeted 结果不能拼接成通过证据；若代码或 dataset 改变，必须重新走 Docker/offline/targeted 全套门禁。
3. full live gate PASS 后，将 `/tmp/myapp-ai-gates-af53a18-offline.json` 与新的 live full 报告安装为治理报告，校验 revision、Prompt manifest、Tool manifest、dataset SHA 和模型别名完全一致，再发布 staging Policy。
4. 使用唯一 staging tag 构建 Parent/Backend/AI，部署后执行 `bench migrate`、`check-staging.sh` 和容器 revision/digest 核对；不得覆盖现有回滚基线。
5. 最后做真实登录态验收：唯一商品/订单自然指代、多候选澄清、空结果清除旧实体、客户/供应商指代、跨公司/归档/并发失败关闭，以及“查询可口可乐后修改这个商品”。

### 本地复核与恢复命令

本地健康复核：

```bash
curl --noproxy '*' -fsS http://127.0.0.1:4010/health
curl --noproxy '*' -fsS -H 'Host: localhost' \
  http://127.0.0.1:8000/api/method/ping
docker ps --format '{{.Names}} {{.Status}}' | \
  rg 'frappe_docker-(ai-orchestrator|backend|queue-short|queue-long|scheduler|queue-ai-vector)-1'
```

Backend 使用 Dev Container override，重启容器会终止由 VS Code/F5 启动的独立 Web 进程。如果容器为 Up 但 8000 连接被重置，先检查 `frappe serve`；没有运行时可按现有 `.vscode/launch.json` 参数恢复：

```bash
docker exec -d \
  -w /home/frappe/frappe-bench/sites \
  -e DEV_SERVER=1 \
  frappe_docker-backend-1 \
  /home/frappe/frappe-bench/env/bin/python \
  /home/frappe/frappe-bench/apps/frappe/frappe/utils/bench_helper.py \
  frappe serve --port 8000 --noreload
```

不要输出 `docker compose config` 的 environment，不要打印 Token/Key。服务器清理不得使用带 volumes 的全局 prune，也不得删除数据库、sites、Qdrant、Redis、治理报告、备份或用户既有服务目录状态。

## 0H. 2026-08-27 商品语义理解与候选澄清升级（未提交、未部署）

- 根因：现有系统已经有 LLM 意图解析和向量检索，但商品身份主要压缩为一个 `product_query` 字符串；共享解析器还会把仅有一个模糊/语义候选误判为 `resolved`，造成界面或后续草稿看起来像“唯一匹配”。Agent 商品工具声明的 `match_mode/search_fields/limit` 也没有完整进入共享检索边界。
- AI Orchestrator 将意图 Prompt 升级为 `erp-intent-v6`：新增 `product_terms`、`product_hypotheses` 和结构化 `product_attributes`（品牌、品类、颜色、口味、规格、容量、包装）。例如“红色可乐饮料”以“可乐”为核心词，保留红色/饮料线索，可把“可口可乐”作为未确认假设；“可乐”不锁定品牌；“两升的红色可乐”保留容量、颜色和品类线索。
- `search_products` Agent 工具升级到 v2，严格参数携带核心词、查询变体、假设和属性。Backend 对旧 v1 调用保持滚动部署兼容；新字段进入关键词与向量混合检索、候选重排和审计上下文。
- 自动解析安全边界收紧：编码/条码精确命中，或只有一个真正精确的名称/昵称结果时才允许 `resolved`；仅一个模糊或语义候选也返回 `ambiguous + clarification.required=true`。多候选必须全部展示供用户确认，不得自动选择第一条或声称“唯一匹配”。
- 混合重排会用未确认身份假设提升相关候选排序，但假设不参与精确自动绑定。语义结果增加相对分数门槛；本地真实数据中“红色可乐饮料”从原先包含红牛、雪碧、苏打水、Coffee Mug 等 8 条噪声，收敛为可口可乐和 3 条百事可乐共 4 条，并把可口可乐排在首位。
- 本地真实数据旁证：`红色可乐饮料`、`可乐`、`两升的红色可乐` 均返回 `ambiguous / clarification.required=true`；库内没有精确 2 升商品时继续展示现有可乐候选，不伪造或硬选规格。
- 2026-08-27 对照 OpenAI Agents/Responses、Anthropic Tool Use、Microsoft Copilot Studio generative orchestration、Salesforce Agentforce 和 Google ADK 官方资料复核：当前设计已覆盖 LLM 语义规划、严格结构化工具、混合检索/真实数据 grounding、缺参和歧义澄清、服务端状态、权限与审批、追踪和自动评测等主流生产级边界。确定性关键词/规则仍存在于召回、精确标识和安全失败关闭层，已不再作为主要意图理解器。
- 正式 core 评测新增 `intent.product_descriptive_cola`、`intent.product_generic_cola` 和 critical `agent.product_descriptive_cola_clarification`：长期门禁“红色可乐”抽取核心词与不确定假设、“可乐”不锁品牌、多候选必须确认且禁止声称唯一匹配。
- Prompt 版本同步：Backend 与 AI 的只读查询统一为 `erp-readonly-v10`，意图统一为 `erp-intent-v6`，采购草稿统一为 `purchase-order-draft-v4`，消除本地代码中既有版本漂移。
- 已验证：Backend `test_ai_service + test_ai_agent_tool_service + test_ai_vector_service` 共 165 tests PASS；AI Ruff、pre-commit 全量通过，全量 173 tests 和 14 subtests PASS，canonical offline core 40/40 PASS；Parent/Backend/AI/Web `git diff --check` PASS。当前 Shell 未提供 live eval 开关、LiteLLM Key 或 URL，运行中也没有新 AI Orchestrator 容器；因此尚未运行新候选 Docker test/runtime、同 revision live full gate、构建或部署。

## 0G. 2026-08-26 AI 草稿商品候选与搜索修复（未提交、未部署）

- 根因已由 staging 真实草稿和代码共同确认：库存草稿后端已经为“可乐”返回 4 个权限内候选，并正确提取 `increase + 500 + 箱`；但弹窗使用通用 `RemoteLinkSelect doctype="Item"`。通用 Link 服务没有允许 `Item`，且只适合按 DocType Link 名称搜索，因此界面显示“暂无数据”，同时也没有消费草稿已有 `candidates`。
- Web 新增 `RemoteProductSelect`，统一调用正式 `search_product_v2` 商品领域接口，支持编码、名称、昵称、条码、描述和规格搜索，并携带商品业务上下文、公司和仓库。库存、销售、采购草稿、商品完善和 AI 商品数据治理入口不再通过通用 Link 下拉搜索 Item。
- AI 草稿已有候选会直接预载到下拉并展示“名称（编码）”；多候选提示显示真实候选数量，用户仍可继续远程搜索。通用 `RemoteLinkSelect` 的读取失败现在展示真实错误，不再伪装成空数据。
- 库存紧凑摘要在商品未唯一匹配时保留原始操作、数量和单位，例如“增加 500 箱（选择商品后计算目标库存）”，并展示候选数量，不再只显示 `- → -`。
- staging 只读旁证：以当前业务账号调用正式 `search_product_v2`，关键词“可乐”、`item_context=inventory`、公司 `rgc (Demo)`、仓库 `Stores - RD` 返回可口可乐和 3 条百事可乐，共 4 条，和草稿候选一致。
- 已验证：`npm run tsc`、`npm run biome:lint`、定向 3 suites / 27 tests、全量 47 suites / 304 tests、Web 与 Parent `git diff --check` 全部通过。Jest 继续输出既有异步 handle 提示，但退出码为 0。
- 当前仅 `frontend/myapp-web` 和本交接文档存在本轮未提交改动；没有修改 Backend/AI 源码，没有提交、推送、构建镜像或部署 staging/production。

## 0F. 2026-08-26 跨轮业务实体上下文统一修复（已提交推送、本地已部署，staging 门禁阻断）

### 0F.1 根因与架构修复

- 截图中的“这个商品/这个订单”问题不是模型看不到所有历史文字，而是查询结果中的真实业务实体此前主要作为展示结果和旧场景状态携带，没有形成跨商品、单据、客户、供应商统一且权威的 typed entity state；部分固定场景规则还会先于结构化语义解析消费泛化词，导致把“这个商品”当成新的搜索词或只修复单一草稿场景。
- 最终 live 验证进一步发现两个更底层的数据流缺口：Agent Runtime 的 `_initial_payload` 曾清空 Backend 传来的全部 `context`，导致模型实际看不到 `conversation-state-v2`；eval runner 的 `_agent_request` 也硬编码 `context=None`，使 offline replay 掩盖了真实 Runtime 丢上下文的问题。两处现均已修复并有回归测试。
- Backend 将会话状态从 `conversation-state-v1` 升级为 `conversation-state-v2`，新增 `product`、`business_document`、`business_partner` 三类活动实体槽位。查询结果保存 typed `entity_refs`，并兼容读取旧状态。
- `resolved / ambiguous / not_found` 现在是权威解析状态。歧义和空结果会覆盖旧实体，禁止后续回退“复活”过期目标；会话归档、TTL、乐观并发和状态版本冲突也保持失败关闭。
- 商品、销售/采购订单、销售/采购发票、客户和供应商统一通过服务端实体状态解析自然指代。显式 ID 优先；唯一已解析实体可被“这个/刚才那个”引用；多候选或找不到时必须澄清，不能猜测。
- 精确“查看这个订单”会把已解析单据投影为 `target_document_entity / target_document_name`，清除旧列表日期、状态、金额和取消排除条件；工具执行层再次要求单据号完全匹配，拒绝部分匹配。
- Agent 多工具 Run 按成功工具顺序合并实体状态，不再只消费最后一个工具结果。denied/retryable 空信封不清空先前实体；成功空查询仍写入 `not_found`。初次运行、失败恢复和审批恢复均携带同一 `conversation_state`。
- 草稿生成、人工编辑和正式执行都会重新投影实体；新商品和新订单只有正式执行成功后才成为活动正式实体。跨公司订单不会被用作更新草稿基线。
- 自动场景路由改为结构化 AI 语义优先，本地规则只在模型失败、低置信度、非法输出或防止明确写操作误入只读 Agent 时兜底。Web 自动路由始终传当前公司和会话 ID，不再在页面端自行解释自然指代。
- AI Orchestrator 将 `query_business_documents` 从 v1 升级到 v2，增加严格 `document_name` 和 `entities.minItems=1`；Backend 和 AI 两侧 Schema 验证器均真正执行 `minItems`，且精确单据号只能搭配一种单据类型。
- Runtime 只白名单接收 `conversation-state-v2.active_entities`，将已解析实体 ID 放入 `<conversation_state>` 和 `<resolved_entity_references>`；`ambiguous/not_found` 不携带旧 ID。业务记录、金额、库存和实时状态不得写入 Prompt，模型仍必须通过受控工具重新查询，避免把旧快照当成事实。
- 采购 Prompt 从 `purchase-order-draft-v3` 升级到 v4，统一 `operation=create/update`、带空格数量单位和 remarks 语义；只读 Prompt 从 `erp-readonly-v8` 升级到 v9。

### 0F.2 代码审查结论

- 当前结构已符合主流 Agent 架构的关键边界：模型负责语义解释和工具参数生成，服务端会话状态负责实体记忆，业务服务负责权限、公司隔离、精确匹配、并发和正式写入；前端只传上下文并展示结果，不持有第二套实体解析规则。
- 已审查查询、Agent 多工具、草稿生成/编辑/执行、场景路由、Web 调用、Schema 和状态持久化链路，没有发现会让旧问题继续局限于单一商品场景的遗漏。
- 本轮同时修复了审查中发现的非截图问题：多工具状态只取最后结果、空工具信封误清状态、`minItems` 只声明不执行、精确单据查询残留列表过滤条件、跨公司草稿基线、归档会话仍写状态、恢复 Run 未携带会话状态、Runtime 丢弃 typed context，以及评测 runner 未真实覆盖 request context。
- Backend CI 还发现普通订单列表 DSL 因统一字段投影多出两个 `None` 字段。最终兼容修复保持普通列表 DSL 原契约，只在精确单据查询时输出目标字段，避免上下文修复破坏既有调用者。
- `apps/myapp/myapp/api/gateway.py` 中仍有一处既有演示接口 `custom_calculate` 使用 `print`，不在本轮 AI 调用链和改动 diff 中；后续清理网关示例代码时可单独处理，不应混入本次提交。

### 0F.3 提交、CI 与确定性验证

- Backend commits `ea6ac70c95af17c068e2adfd5f643a9ce0071bfb`、`f8282394b2efaf31f998423556e4da92086bec50` 已推送；Backend CI run `32946009596` 成功，全量 816 tests PASS。
- AI commits `5c356cea22f3f1168b128f60e48367eb98d6f793`、`98f01b82db9968ceaa433ff9bce9419e298aa003` 已推送；AI CI run `32952670126`、CodeQL run `32952670219` 成功。Ruff、pre-commit、172 tests、Docker test 镜像内 172 tests 和 runtime 镜像构建均通过。
- Web commit `9b63dcd9dcb7ad21ab6222f7b43381c70e29cfaa` 已推送；CI run `32945082627`、coverage run `32945082602` 成功。TypeScript、Biome、46 suites / 300 tests 和 production build 已通过。
- Parent commits `2c76f26c`、`24dc6847`、`df86bbd8ea5631eba926e0a90c9630e4746548a1` 已推送；最终 Parent Lint run `32952770954` 成功。
- 最终 AI revision `98f01b82...` canonical offline full eval 37/37 PASS，报告为 `/tmp/myapp-ai-eval-offline-98f01b8-canonical-20260826.json`。
- targeted live 中采购语义 2/2 PASS；`agent.context_exact_order` 1/1 PASS，模型收到已解析 `SO-EVAL-100` 后实际调用 `query_business_documents(document_name="SO-EVAL-100")`，证明“这个订单”已进入真实模型上下文并产生精确工具参数。
- Parent、Backend、AI、Web 最终 `git diff --check` 全部通过。

### 0F.4 live full gate 与 staging 决策

- 第一次最终 canonical live full gate 为 34/37 FAIL，报告 `/tmp/myapp-ai-eval-live-98f01b8-canonical-20260826.json`；三个失败均为 `PROVIDER_HTTP_500`。项目自身 critical、安全、结构化字段、工具选择/参数/授权/轨迹指标均为 100%。
- 有上限的完整重试为 33/37 FAIL，报告 `/tmp/myapp-ai-eval-live-98f01b8-canonical-retry1-20260826.json`；失败包含两个 `PROVIDER_HTTP_500`、一个 `PROVIDER_TIMEOUT`，以及普通场景 `chat.order_grounded_summary` 一次 required concept 措辞偏差。已停止盲目重跑，不拼接 partial 结果、不降低门禁。
- 最终 Prompt manifest 为 `61051529f00996fa3f62cf309b412588b3cf84f04413d30cf8c7f321af44893c`，Tool manifest 为 `1098f2446c088127938aad5dcc29949a07c6f21dc7c059f496e7e8a060d7750a`。
- 因最终 revision 的完整 live gate 未通过，没有触发新的 Build/Deploy workflow、没有安装新治理报告、没有发布新 Policy。staging ERP/AI 保持 `staging-20260825-ea64c9c6`、Policy 保持 `agent-general-staging-rgc-demo` v27，Web 保持 `staging-20260824-a786d94c`。

### 0F.5 本地部署、工作树与下一步

- 本地 AI runtime 镜像 `frappe_docker-ai-orchestrator` 已按最终 revision 重建，image digest 为 `sha256:21e7ce5ffdaceb052d38e6b35a95d7113420054d9f88c1a72f8635485cf8dde6`；正式 `ai-orchestrator` 已强制替换并 healthy。
- `http://127.0.0.1:4010/health` 返回 HTTP 200，`runtime_revision=98f01b82db9968ceaa433ff9bce9419e298aa003`，Prompt/Tool manifest 与最终候选一致，运行 `erp-readonly-v9` 和 `purchase-order-draft-v4`。
- Backend、queue-short、queue-long、scheduler、queue-ai-vector 已重启且运行；Backend→AI 内部鉴权和向量状态请求返回 HTTP 200。Backend `/api/method/ping` 返回 HTTP 200 / `pong`。
- 本地 Backend 使用 Dev Container override，容器本身只执行 `tail -f /dev/null`，Frappe Web 由 VS Code/F5 或独立 `frappe serve` 进程启动。重启 Backend 容器会终止该独立 Web 进程；本轮已按 `.vscode/launch.json` 参数恢复 8000 端口。后续看到“容器 Up 但 8000 reset”时先检查 Web 进程，不要误判为业务代码回归。
- Parent 继续保留用户既有 `AGENTS.md`、本交接文件、未跟踪 `.codex` 和 `docs/codex/AI_MULTIMODAL_WORK_SUMMARY_2026-08-16.zh-CN.md`，不得误提交或覆盖；Backend、AI、Web 子仓库预期 clean 并与远端同步。
- `npm audit --omit=dev` 仍报告 1 low / 3 moderate，来自 `@ant-design/x-markdown` / Mermaid 间接引入的 DOMPurify，当前上游为 `No fix available`；这是既有依赖风险，不是本轮引入。
- 尚未执行真实浏览器登录态业务验收。staging 发布前仍需获得一份同 revision、完整且通过的 live full gate，再发布引用新 manifest 的 Policy，并验证：查询可口可乐后修改“这个商品”；查询唯一订单后查看/修改“这个订单”；多结果时拒绝猜测；空查询后不恢复旧实体；客户、供应商、销售/采购单据跨轮指代；归档/跨公司/并发冲突失败关闭。

## 0E. 2026-08-25 销售草稿可靠性修复（已部署 staging）

### 0E.1 修复与候选

- AI Orchestrator 将销售 Prompt 升级为 `sales-order-draft-v4`：明确 `create/update/auto` 语义；只有用户明确说零售或批发时才填写 `default_sales_mode`，未明确时返回 `null`；数量和单位之间存在空格、换行或常规分隔符时仍必须提取明确 UOM。
- `SalesOrderDraftCandidate.default_sales_mode` 改为可空，递归 strict JSON Schema 约束保持不变。离线评测同步把未明确销售模式的销售用例期望值改为 `null`。
- Backend 新建销售草稿未明确模式时使用 `wholesale`；更新草稿未明确模式时继承现有订单的 `retail/wholesale`。商品解析按最终模式选择 `retail_default_uom` 或 `wholesale_default_uom`，从 `all_uoms` 获取换算系数，用户显式有效 UOM 始终优先。
- Backend commit `c16194e29cb405ad7ef5d74ecb29eb3d5c386a0e`、AI commit `174e55eb4db1a4beb6d0fccabb23d1c70bdf4227`、Parent gitlink commit `ea64c9c63bc698e470b449078f4d109669c87374` 均已推送 `develop`。

### 0E.2 测试与治理证据

- Backend 容器组合回归 `test_ai_service + test_gateway_wrappers + test_api_security_contracts`：265 tests 通过。
- AI：169 tests 通过；Ruff、pre-commit 通过；Docker test 镜像内 169 tests 通过；Docker runtime target 构建成功。
- AI revision `174e55e...` 的 canonical offline full gate：36/36 PASS；canonical `gpt-5.6-luna` live full gate：36/36 PASS。critical、安全、Schema、普通场景、结构化字段、工具参数/授权/预算和轨迹均为 100%，`release_gate_eligible=true`。
- 新 Prompt manifest `a752f26f...`，Tool manifest `3c84ef2c...`；销售 Prompt 为 `sales-order-draft-v4`，SHA `6a733ac7...`。
- Backend CI run `32804925943`、AI CI run `32804928082`、AI CodeQL run `32804928110`、Parent Lint run `32805544606` 均成功。
- 服务器旧 canonical 报告已备份到 `/srv/frappe_docker/backups/ai-governance-20260825-174e55e/`，新 offline/live 报告已安装为 `ai-governance-reports/offline-gate.json` 与 `live-gate.json`。
- Policy `agent-general-staging-rgc-demo` 已按草稿、校验、审批、发布流程从 v26 升级为 v27：`active`、validation valid、`release_gate_eligible=true`。

### 0E.3 部署状态

- 唯一标签 `staging-20260825-ea64c9c6`；Build run `32805569511`、Deploy run `32805909947` 均成功，部署包含 `bench migrate` 与 `check-staging.sh`。
- ERP digest `sha256:11f20fad6a4d4394daddba26382223aaa92e11c59274f6d0daacd0aec673b4d1`；AI digest `sha256:fe2f09bd68b1804e27fded5e843b3ed7159486f2574f0f8a81ed2a38e28873f5`；AI Runtime revision `174e55e...`。
- Backend、ERP Frontend、AI、Queue、Scheduler、Websocket 均运行新标签且 RestartCount=0；AI healthy。`check-staging.sh` 显示 1 个有效策略，tool-ready/vision-ready 均为 `gpt-5.6-luna`，Backend→AI 内部认证、首页和 Ping 均通过。
- Web 未修改，继续运行 `staging-20260824-a786d94c`，RestartCount=0；`/healthz`、`/user/login`、`/api/method/ping`、`/ai/workspace` 均 HTTP 200。
- staging Orchestrator 真实结构化 smoke 确认 Runtime `174e55e...`、Prompt `sales-order-draft-v4`、模型 `gpt-5.6-luna`，输入“销售 3 个 SKU-EVAL-002”返回 `operation=create`、`default_sales_mode=null`、`qty=3`、`uom=个`。自动选择路径第一次出现一次脱敏 HTTP 502，第二次成功；这与既有 CPA 间歇性事实一致，但本次 canonical live full gate 为 36/36 PASS。
- 部署前根盘 87%、13GB 可用；部署后 88%、12GB 可用。未执行 prune，未删除镜像、volume、`backups/`、`tmp/` 或服务器既有 `services/myapp-ai modified` 状态。

### 0E.4 仍需人工业务验收

- 本轮没有 staging 登录态凭据，因此未在真实 AI 工作台会话中生成、编辑、确认或执行销售订单草稿，也没有创建或修改正式 Sales Order。
- 需人工登录验证：未明确模式的销售草稿默认由 Backend 解析为 wholesale；修改现有 retail 订单时继承 retail；未明确 UOM 时分别采用商品零售/批发默认 UOM；明确 UOM 始终优先。
- Parent 本地继续保留既有 `AGENTS.md`、本交接文件、`.codex` 和 `docs/codex/AI_MULTIMODAL_WORK_SUMMARY_2026-08-16.zh-CN.md` 状态，不要误提交。

## 0D. 2026-08-24 图片商品身份进入受控查询（已提交，live gate 阻断，未部署）

### 0D.1 根因与修复

- staging Run 已确认首次“我们的商品中有没有这个商品”虽然识别为 `product_search`，但结构化意图调用没有收到本轮 Attachment，因此先用“我们、这个商品”等泛化词完成了空查询；后续普通聊天模型才识别出“可口可乐”。根因是多模态数据流缺口，不是单纯视觉模型未看出商品。
- Backend 现把本轮图片交给 `erp-intent-v5`，使用模型提取的条码、SKU、品牌加商品名或稳定商品名完成关键词和语义检索，并审计 `query_source=multimodal_intent`、原请求/解析查询哈希及 `executed`。
- 图片没有可靠商品身份，且文字只有泛化指代时，Backend 不执行数据库查询，返回 `query_resolution.status=unresolved / retrieval.status=query_unresolved / query_status=unresolved_image_entity / executed=false`，并要求回答“尚未执行查询”，不能误报“数据库未找到”。
- Backend 额外拒绝“红色罐装饮料、蓝色小瓶包装”等纯外观/容器/模糊类别，即使模型违约输出为 `product_query` 也失败关闭；用户文字明确提供“矿泉水、SKU-001”等线索时仍允许查询。
- 当前消息带新图片时不继承上一次商品查询词，避免图片识别失败后错误查询旧商品。未带图的普通连续追问继续兼容既有商品上下文。
- 未解析图片查询不会污染商品工作状态，也不会生成空的 `last_result_set`。旧商品查询上下文没有 `query_resolution` 时仍按原行为兼容。
- AI Orchestrator Prompt 明确要求查看当前 Attachment、选择最短可靠商品身份、不得补充不可确认规格、不得沿用旧图片/旧商品身份。意图 Prompt 版本由 `erp-intent-v4` 升级为 `erp-intent-v5`。
- 首轮 live gate 进一步暴露四类草稿的 Pydantic Schema 不符合 OpenAI Responses strict schema：对象缺少 `additionalProperties=false`，可选字段未全部列入 `required`，导致每个结构化请求先 400 再回退普通 JSON。AI 现通过统一 Schema 生成器递归补齐 strict 契约，本地候选模型同时 `extra=forbid`；Provider 不支持 strict schema 的明确 HTTP 400 兼容回退继续保留，HTTP 5xx 不会伪装为兼容回退。

### 0D.2 当前验证

- Backend 容器：`apps.myapp.myapp.tests.unit.test_ai_service` 118 tests 通过。
- AI Orchestrator 最终候选：Ruff、pre-commit 通过；全量 169 tests 通过；Docker test 镜像内 169 tests 通过；runtime target 构建通过。
- Parent、Backend、AI `diff --check` 通过。
- Backend commit `e927053` 已推送。图片意图修复 AI commit `d5d739a`、strict schema 修复 AI commit `8821def` 已推送；Parent commits `fbf6138d`、`d63bf7f8` 已推送。
- Backend CI run `32717942840` 成功；最终 AI CI run `32728084056`、CodeQL run `32728083994` 成功；最终 Parent Lint run `32728470273` 成功。
- 最终 AI revision `8821def9094874b158460e032024243222cac92e` 的 offline full gate 36/36 PASS，`release_gate_eligible=true`；Prompt manifest `32a028e9...`，Tool manifest `3c84ef2c...`。
- 旧 AI revision `d5d739a` 的两次 live full gate 分别 34/36、33/36 FAIL。除 normal 用例 `draft.sales.missing_customer` 偶发遗漏“3 个”的单位/默认模式外，阻断错误来自 `gpt-5.6-luna` 上游 `cli-proxy-api:8317 -> chatgpt.com/backend-api/codex/responses` 的 EOF/HTTP 500；LiteLLM 已重试 2 次仍失败。
- 最终 revision `8821def` 的四类结构化 targeted live 为 2/4：采购、商品草稿通过；销售草稿 Schema 合法但单位/默认模式评分失败；库存草稿仍因上游 EOF/HTTP 500 失败。LiteLLM 最近日志不再出现 `Invalid schema`，证明 strict schema 修复生效；当前剩余阻断是 8317 模型代理链路不稳定。该 targeted 报告不能替代 full gate。
- 用户于 2026-08-25 明确要求开始部署后，发布前再次执行最终 revision `8821def...` 的完整 `gpt-5.6-luna` live gate，结果 30/36 FAIL：critical 78.57%、Schema 91.67%、normal 86.36%，结构化字段 98.43%。三个 critical Agent 用例因 CPA 上游 HTTP 500 失败；三个销售草稿 normal 用例存在默认销售模式、operation 或“3 个”单位偏差。因门禁未通过，部署在镜像构建前停止，staging 未发生变更。
- 为对照用户在 LiteLLM UI 的单次成功测试，随后只对三个失败 Agent 用例各重复 3 次：8/9 成功，`agent.product_and_sales_report_multi_tool` 第一次返回 `PROVIDER_HTTP_500`，后两次成功；另两个 Agent 用例 6/6 成功。该结果直接证明链路可访问但存在间歇性失败，而不是完全不可用或固定配置错误。
- 用户再次要求“尝试部署”后，只对上一轮六个失败场景执行一次发布前 targeted live 预检；结果 4/6 PASS。三个 Agent Function Calling 场景本次全部通过，未再出现 HTTP 500；三个销售草稿场景仍有两个失败：`draft.sales.complete` 的 `default_sales_mode` 偏差，`draft.sales.missing_customer` 的 `default_sales_mode` 和明确“3 个”的 `uom` 偏差。该 partial 报告的 normal 通过率为 33.33%、结构化字段准确率为 92.31%，不能替代 full gate，也证明当前候选尚未解决已知销售草稿质量阻断。因此仍在镜像构建前停止，未触发 Build/Deploy、未迁移站点、未修改 Policy，staging 继续保持 `staging-20260824-a786d94c`。诊断报告为 `/tmp/myapp-ai-eval-live-8821def-deploy-preflight-20260825.json`。

### 0D.3 当前工作树与下一步

- Backend、AI 工作树已清洁；Parent 继续保留既有 `AGENTS.md`、本交接文件、`.codex` 和 `docs/codex/AI_MULTIMODAL_WORK_SUMMARY_2026-08-16.zh-CN.md`，不要误提交。
- 下一步优先修正销售草稿对明确单位、`default_sales_mode` 和 `operation` 的语义提取，并保留 CPA Function Calling 稳定性回归；形成新 AI revision 后重新执行全量测试、Docker、offline full gate 和一次 canonical `gpt-5.6-luna` live full gate。不得继续盲目重跑、降低 critical/Schema 阈值或把旧 revision/partial 报告冒充新候选证据。
- 只有新的完整 live 报告 `summary.passed=true` 且治理校验通过后才能构建并部署 staging；当前未部署本阶段改动，staging 继续运行 `staging-20260824-a786d94c`。
- staging 真实验收必须上传同一可口可乐图片并发送“我们的商品中有没有这个商品”，确认检索身份为“可口可乐”、直接命中 `可口可乐-5000ML`，且不再出现“我们、这个商品”等搜索词；模糊图片必须明确显示本轮未执行查询。

### 0D.4 本轮工作总结与接手决策

- 功能结论：用户截图中的问题不是“模型单纯没看出来”，而是本轮 Attachment 未进入结构化意图解析，受控商品查询在视觉识别之前已经错误执行。该数据流缺口、旧商品上下文误继承、泛化搜索词和外观词失败关闭均已在 Backend/AI Prompt 两层修复并提交。
- Provider 结论：LiteLLM 和 `gpt-5.6-luna` 可以访问。2026-08-25 最小请求经 `192.168.31.229:4000/v1/chat/completions` 返回 HTTP 200、有效 choice、`finish_reason=stop`。用户在 LiteLLM UI 单次测试成功与该事实一致。
- 稳定性结论：LiteLLM 把 Luna 的复杂 Agent/Function Calling 请求转发到 CPA `cli-proxy-api:8317`，再访问 `chatgpt.com/backend-api/codex/responses`。单次成功不能覆盖连续调用事实；三个 Agent 用例各重复三次时 8/9 成功，同一多工具用例第一次 HTTP 500、后两次成功，属于可访问但间歇性失败。
- Schema 结论：早期结构化调用还存在项目自身 strict JSON Schema 不合规问题，导致先 400 再回退；`8821def` 已修复，最新 CPA/LiteLLM 日志不再出现 `Invalid schema`。后续不能再把上游 EOF 与已修复的 Schema 400 混为一类。
- 模型质量结论：即使排除 HTTP 500，`gpt-5.6-luna` 对销售草稿仍会偶发把明确“3 个”的 `uom` 输出为 null，并把 `operation/default_sales_mode` 输出为非预期值。结构化字段总准确率仍超过 95%，但当前完整 normal 通过率只有 86.36%，应补 Prompt/语义回归后再评测。
- 发布结论：用户已授权部署，但最终 live full gate 为 30/36 FAIL，且三个 critical Agent 用例直接因 Provider 500 失败，因此本轮有意在镜像构建前停止。未触发新的 Build/Deploy workflow、未拉取新镜像、未迁移站点、未修改 Policy；staging 和回滚基线完全保持 `staging-20260824-a786d94c`。
- 接手顺序：先用与评测相同的 `/v1/responses + tools` 请求检查/稳定 CPA，而不是只测试普通聊天；同时修正销售草稿明确单位和默认模式提取；形成新 AI revision 后重跑 169+ tests、Docker、offline full gate 和一次 canonical live full gate。全部通过后使用唯一标签（建议 `staging-20260825-<parent-short-sha>`）构建 Backend/AI，再部署并执行真实可口可乐图片验收。
- 服务器边界：目标仍为 `vivy@192.168.31.229:22`，部署目录 `/srv/frappe_docker`。根盘最近检查为 98GB、已用 81GB、可用 13GB、87%；不得全局 prune、不得删除卷、`backups/`、`tmp/` 或服务器既有 `services/myapp-ai modified` 状态。
- 本地评测报告位于 `/tmp/myapp-ai-eval-*`，属于临时诊断证据，尚未安装为服务器 canonical governance report。任何新 revision 都必须重新生成报告，不能复制这些旧报告进入发布配置。

## 0C. 2026-08-24 商品查询结果绑定完善草稿（已部署 staging）

### 0C.1 根因与修复

- 商品查询 citation 和工作上下文已经保存 `item_code`，但 `generate_ai_product_setup_draft_v1` 原先只把会话文字和附件交给结构化模型，没有消费服务端商品工作状态；“修改这个商品”因此只识别到 `operation=update`，目标商品为空。
- Backend 现仅在用户明确表达修改/完善意图并使用“这个商品、它、刚才查询到的商品”等指代时，从当前有效会话继承 `resolution_status=resolved` 的唯一商品，或最近商品结果集中唯一的实体。显式编码优先；多候选、过期/已清除上下文继续失败关闭。
- 明确商品编码现在是权威目标：解析成功后不再叠加同名商品造成多候选；编码不存在时不回退到另一个同名商品。
- Run 工具审计记录 `target_item_code` 与 `target_source`；正式商品仍由 Backend 按当前账号、公司和权限重新读取，并写入草稿 `_state.entity`。
- Web 商品 citation 增加“完善此商品”，把明确编码预填到 Sender 并选择本次商品草稿场景。“当前页查看”继续只表示查看详情。
- 商品完善草稿未绑定目标时显示可搜索的“选择现有商品”；选择保存并经 Backend 重校验后，编码切换为只读。字段错误文案改为直接指向该选择器，消除禁用字段死锁。

### 0C.2 验证与提交

- Backend 容器：`apps.myapp.myapp.tests.unit.test_ai_service` 112 tests 通过。
- Web：`npm run tsc`、`npm run biome:lint` 通过；全量 46 suites / 300 tests 通过。
- Parent、Backend、Web `diff --check` 通过。
- Backend commit `4415711`、Web commit `d0c9c45`、Parent commit `a786d94c` 已推送；Parent Lint run `32682005344` 成功。AI Orchestrator 源码未修改，继续固定 revision `2e80454`。
- Web staging build 首次传入短 SHA 的 run `32682080581` 因 `actions/checkout` 无法按浅克隆解析短 SHA 失败，未发布镜像；改用精确指向 `d0c9c45` 的远端 `main` 后，run `32682230495` 完整执行 tsc、lint、300 tests 和镜像构建并成功。

### 0C.3 发布状态

- 统一发布标签 `staging-20260824-a786d94c`；Backend/AI build run `32682052555` 成功。部署通过 `vivy@192.168.31.229:22` 直接执行现有 staging 脚本，`bench migrate` 成功。
- ERP digest `sha256:933d29baf1ad291a271cfcc4a637b0584caf4e90a815f4e80726759ac0a7b918`；AI digest `sha256:ed80f13dfc3da15269959e6e7890d862d7c57524b77912dc3668ddeacf1a3cf2`；Web digest `sha256:a8fd7f39a98b4f9edda7f80ed519dc946a38485bbfc7ea6116ffecf449dcdf9d`。
- `check-staging.sh` 通过：1 个有效策略，tool-ready/vision-ready 均为 `gpt-5.6-luna`，Backend→AI 内部认证、首页和 Ping 正常。Backend、AI、ERP Frontend、Web RestartCount 均为 0；Web `30080` 的 `/healthz`、`/user/login`、`/api/method/ping`、`/ai/workspace` 均 HTTP 200。
- 运行容器 smoke 已确认 Backend 能从唯一会话商品解析 `ITEM-SMOKE`，Web 构建产物包含“完善此商品”和“选择现有商品”。根盘 98GB，已用 81GB，可用 13GB，使用率 87%；未执行 prune，服务器继续保留 `services/myapp-ai` modified、`backups/`、`tmp/`。

### 0C.4 仍需人工登录态验收

- 当前没有 staging 登录态测试凭据，无法自动代替用户完成真实会话验收。需登录后验证：查询唯一商品后直接说“修改这个商品”；查询多商品后点击某条“完善此商品”；旧失败草稿通过选择器补目标；确认草稿展示正确编码、baseline、图片和价格 patch，且未确认执行前不修改正式 Item。

## 0B. 2026-08-21 历史会话图片进入商品草稿（已部署 staging）

### 0B.1 根因与修复

- Chat Core V2 已让模型看到历史消息自己的 Attachment，但商品草稿仍只使用本次请求顶层 `attachment_ids` 构造 `source_attachments` 和默认商品图；用户下一轮说“图片使用我发的图片”时，本轮附件数组为空，因此草稿显示无图片。
- 原商品草稿还只允许 `operation=create` 自动设置图片；`operation=update` 即使本轮重新上传图片，也不会在用户明确要求时形成图片 patch。
- Backend 已增加受控附件提升规则：优先使用模型 evidence 指定且确实存在于当前用户、当前会话有效消息窗口的 Attachment；没有精确 evidence 时，只在当前文字明确引用之前/刚才/用户已上传图片时回退到最近带图消息的第一张图。
- 完善现有商品默认继续保留正式商品图片；只有明确的使用/替换主图意图才派生暂存商品图并写入 update patch。显式要求图片但附件不存在或不符合封面要求时，草稿失败关闭并要求重新上传，不再静默显示无图片。
- AI Orchestrator 在图片内容块前增加服务端 Attachment ID 标记；`product-setup-draft-v6` 要求图片来源字段写入 `evidence[].attachment_id`，明确主图意图写入 `field=image / value=use_as_product_image`。Backend 仍验证该 ID 必须属于当前有效上下文。
- Web 无需修改：现有草稿卡片和商品确认弹窗会直接消费 Backend 返回的 `payload.image`；既有商品图片保留逻辑不变。

### 0B.2 本地验证

- Backend 容器：`test_ai_service + test_ai_attachment_service` 共 109 tests 通过。
- AI Orchestrator：Ruff 通过；全量 167 tests、9 subtests 通过；pre-commit 全部通过。仅保留既有 Starlette/httpx 弃用警告。
- Parent、Backend、AI `diff --check` 通过；Web 未修改。
- Backend commit `0702db0`、AI commit `2e80454` 均已推送且 CI 成功；AI CodeQL 成功。
- Parent 功能提交 `d20f157a`，格式门禁修复提交 `d9dc6a14`；最终 Parent Lint run `32627629547` 成功。
- 最终 AI revision `2e80454a7903b52458a3bb27be1f9e25ffe7c7a1` 的 offline full gate 36/36 PASS；canonical live full gate（`gpt-5.6-luna`）35/36 PASS，critical/safety/schema/tool/trajectory 100%，normal 95.45%，structured 99.61%，`release_gate_eligible=true`。
- 新报告绑定 Prompt manifest `4d228874...`、Tool manifest `3c84ef2c...`、Dataset SHA `7298680c...`；旧报告备份到 `/srv/frappe_docker/backups/ai-governance-20260821-2e80454/`。

### 0B.3 发布状态

- Build run `32627773751`、Deploy run `32627961516` 均成功；部署标签 `staging-20260821-d9dc6a14`。
- ERP digest `sha256:c38633ade8c9c11b5debf09ca312dc405e851a2348129f68a6af15fe0d1d0015`；AI digest `sha256:f28cb85219098ed15afc668d8bfeccc5c8b7a9853efa53de690b67c8f1ef888b`；AI Runtime revision `2e80454`。
- Web 未改动，继续运行 `staging-20260820-27c4dbf`，digest `sha256:117418451e4fab4f63f8b11a0cfb23bfe543a50fdda63650103275155def8f63`。
- Policy `agent-general-staging-rgc-demo` v26 已按草稿、校验、审批、发布流程生效：`active`、100%、`gpt-5.6-luna`、无 fallback、validation valid、release gate eligible。
- 最终 `check-staging.sh` 通过：1 个有效策略，tool-ready/vision-ready 均为 `gpt-5.6-luna`，Backend→AI 内部认证、首页和 Ping 正常。Backend、AI、Web RestartCount 均为 0；Web `30080` 的 `/healthz`、`/user/login`、`/api/method/ping`、`/ai/workspace` 均 HTTP 200。
- 根盘 98GB，已用 80GB，可用 14GB，使用率 86%；未清理镜像、volume、`backups/` 或既有 `tmp/`。服务器继续保留 `services/myapp-ai` modified、`backups/`、`tmp/`。

### 0B.4 仍需人工登录态验收

- 当前没有 staging 登录态测试凭据，无法自动复现用户截图中的真实浏览器会话。需由用户登录后验证：先上传商品图，下一轮明确要求完善现有商品并使用该图，确认草稿卡片、确认弹窗和最终 update patch 都带图。
- 同时验证普通“根据图片完善资料”不覆盖已有主图；多张历史图片时应只采用明确 evidence 指定的图片，未明确图片意图时不得误用旧订单截图。

## 0A. 2026-08-20 Chat Core V2 staging 部署完成

### 0A.1 发布结果

- Backend/AI/Web Chat Core V2 第一阶段已部署 staging；服务器操作均使用 `vivy@39.104.204.79:10022`。
- Backend commit `df02078`；AI 原功能 commit `dfe2ce4`；Web commit `27c4dbf`；Parent 原发布 commit `20076156`。
- Live gate 暴露固定评测仍按旧订单字段精确评分；已在 AI commit `0870dda` 修复 `operation/evidence` 评测契约并补回归，Parent 子模块指针 commit 为 `8ee3c21d`。
- AI `0870dda` 已通过 Ruff、pre-commit 和 167 tests；新构建 run `32375914343`、Backend/AI 部署 run `32376273762`、Web 部署 run `32377753296` 均成功。
- 首次新构建 run `32375497694` 因 workflow 的 `myapp_ref` 使用短 commit 而失败；该参数由 `bench init` 按分支浅克隆，重跑时改用当前固定到 `df02078` 的 `develop`，没有发布失败候选。

### 0A.2 模型治理

- 真实 Provider 探测：`gpt-5.5`、`gpt-5.6-luna` 均 available/tools/vision；原策略链 `nvap-gpt-5.6-sol`、`nvap-gpt-5.6-terra` 返回稳定码 `PROVIDER_HTTP_403`。
- 双模型首次 live full gate 为 53/72，确认旧 fixture 把合法的 `operation/evidence` 新字段误判为 unexpected；`gpt-5.5` 另有一个 critical 安全措辞失败，因此未发布该双模型链。
- 当前 canonical offline gate：36/36 PASS；live gate（`gpt-5.6-luna`）：35/36 PASS，critical/safety/schema/tool/trajectory 均 100%，normal 95.45%，structured 99.61%，`release_gate_eligible=true`。
- 报告绑定 Runtime `0870dda46f33dd8a755d5dc5fb348ad4be7a8bef`、Prompt manifest `1edf812b...`、Tool manifest `3c84ef2c...`、Dataset SHA `7298680c...`。
- 旧治理报告已备份到服务器 `/srv/frappe_docker/backups/ai-governance-20260820-2149/`。
- `gpt-5.6-luna` 数据区域按真实未知状态审计登记为 `provider-managed-unspecified`，留存策略保持 `managed-by-provider`，未伪造具体地区。
- Policy `agent-general-staging-rgc-demo` v25 已通过草稿、校验、审批、发布正式流程：`active`、staging、rollout `100%`、主模型 `gpt-5.6-luna`、无 fallback、validation valid、release gate eligible。
- 完整 `deploy/staging/check-staging.sh` 已通过：1 个有效策略，tool-ready 与 vision-ready 均为 `gpt-5.6-luna`，Backend→AI 内部认证通过。

### 0A.3 当前镜像与健康

- ERP 镜像 `staging-20260820-8ee3c21d`，digest `sha256:e649765bc7c364ca4ab9cd772d990eb1bb75bba55f7b2a16fd342a695554a40f`。
- AI 镜像 `staging-20260820-8ee3c21d`，digest `sha256:d65163e2f6963507fddda95980f5a1da626d3ed63f3577d8e25c0087aa2aeecb`，Runtime revision `0870dda`。
- Web 镜像 `staging-20260820-27c4dbf`，digest `sha256:117418451e4fab4f63f8b11a0cfb23bfe543a50fdda63650103275155def8f63`。
- Backend、AI、Web 容器均 running，AI/Web healthy，三个容器 RestartCount 均为 0。
- Web `30080` 的 `/healthz`、`/user/login`、`/api/method/ping`、`/ai/workspace` 均 HTTP 200。
- 根盘当前 98GB，已用 79GB，可用 15GB，使用率 85%；Docker images 25.87GB，其中 16.76GB 显示可回收。本轮未清理任何既有镜像、volume、`backups/` 或 `tmp/`。
- 服务器 Parent 为 `8ee3c21d`，继续保留既有 `services/myapp-ai` modified、未跟踪 `backups/` 和 `tmp/` 状态。

### 0A.4 仍需人工登录态验收

- 当前没有可用的 staging 登录态回归凭据，因此未执行真实浏览器账号下的首轮图片、第二轮“继续分析这张图”、固定纯文本模型阻止、会话切换附件隔离、带图失败重试和历史私有图片预览。
- 下一步应使用有权限测试账号完成上述浏览器验收；不要在未完成业务验收前发布 production。

## 0. 2026-08-18 Chat Core V2 第一阶段（未提交、未部署）

本节是当前最新状态，优先于下方 2026-08-16 已部署基线。

### 0.1 已完成

- 新增 `docs/05-development/07-ai-chat-core-v2.zh-CN.md`，把当前问题定位为聊天内核结构缺口，而不是推倒 ERP/Agent/草稿治理体系。
- Backend 模型上下文开始恢复每条历史用户消息自己的 Attachment；Chat 和四类结构化草稿共用该消息级上下文构建入口。
- 未绑定 Attachment 继续按 24 小时清理；已绑定 Attachment 的有效期使用会话与活动草稿保护期的较晚值，并在首次绑定时至少延长到会话保留期。
- AI Orchestrator 的 `ChatMessage` 支持消息级 `attachments[]`，旧 `ChatRequest.attachments[]` 保持兼容；重复 Attachment ID 去重，历史图片不再全部挂到最后一条用户消息。
- 视觉模型校验、运行预算和 Langfuse 输入摘要覆盖消息级附件；Langfuse 即使启用内容采集也不记录图片 base64。
- Web 待发送附件按会话键隔离，上传队列固定原会话；失败重试和当前有效消息窗口的图片事实会参与固定模型视觉能力预检。
- staging 检查新增失败关闭门禁：必须存在有效时间、正灰度的 staging 策略，且策略链中至少有 tool-ready 和 vision-ready 模型。
- 已同步多模态设计、AI API 契约、Web AI 设计、staging runbook 与 README。

### 0.2 当前验证

- Backend 容器定向：144 tests 通过。
- AI：`uv run ruff check .` 通过；全量 166 tests 通过（仅既有 Starlette/httpx 弃用警告）。
- Web：`npm run tsc`、`npm run biome:lint` 通过；全量 46 suites / 299 tests 通过。Jest 仍输出既有异步 handle 提示，但退出码为 0。
- Parent/Backend/AI/Web `git diff --check` 通过。
- staging 门禁脚本通过 `bash -n`、`py_compile` 和合成策略函数检查。

### 0.3 当前仓库状态

- Backend、AI Orchestrator、Web 均有本阶段未提交改动。
- Parent 有本阶段文档和 staging 门禁改动，同时继续保留用户已有 `AGENTS.md`、本交接文件、未跟踪 `.codex` 和 `AI_MULTIMODAL_WORK_SUMMARY_2026-08-16.zh-CN.md`。
- 本阶段尚未 commit、push、构建镜像或部署 staging。

### 0.4 部署前阻断条件

- 最新 staging 诊断显示发布策略 `agent-general-staging-rgc-demo` 的 `rollout_percentage=0`，聊天模型注册表没有 `supports_vision=true` 的候选。
- 新 `check-staging.sh` 会有意拒绝这种状态。部署前必须先用真实 Provider 重新执行视觉能力探测，发布正灰度的有效 staging 策略，并确认策略主模型或 fallback 中存在 vision-ready 模型。
- 不得通过放松门禁、静默丢弃图片或把纯文本模型标成视觉模型绕过。

### 0.5 下一步

1. 复核本阶段 diff 和 API 兼容性，按 Backend、AI、Web、Parent 仓库边界分别提交。
2. 先在本地完成最终静态检查；如候选 revision 变化，重新运行对应测试。
3. 配置 staging 视觉模型事实与有效策略后，再构建单一候选并部署。
4. staging 浏览器验收首轮图片、多轮图片追问、会话切换附件隔离、图片历史预览、固定纯文本模型阻止和带图失败重试。
5. Chat Core V2 Phase 2 继续实现 `client_request_id`、Durable Run Event 和可恢复 SSE；本阶段未实现这些能力。

## 1. 当前结论

- AI 多模态商品与订单主链路已经完成、提交、推送并部署 staging。
- 本地迁移、真实 Provider 视觉探测、合成图片业务 smoke、三仓库自动化测试和 staging 健康检查均通过。
- staging 当前运行本阶段 Backend/AI/Web 镜像；production 未部署。
- smoke 只生成并 discard AI Draft，没有创建或修改正式 Item、Sales Order 或 Purchase Order。
- AI 图片输入器与私有预览修复已提交、推送并部署 staging，详见第 9 节。Parent 继续保留用户已有 `AGENTS.md`、本交接更新和未跟踪 `.codex`，提交时必须按仓库边界处理。

## 2. 当前仓库状态

| 仓库            | 分支与提交             | 状态                                                |
| --------------- | ---------------------- | --------------------------------------------------- |
| Parent          | `develop` / `3a8934dd` | 已推送；包含 release `d072d538` 和最终 staging 交接 |
| Backend         | `develop` / `0001e0c`  | 已推送，CI 成功，工作树干净                         |
| AI Orchestrator | `develop` / `0f15f02`  | 已推送，CI/CodeQL 成功，工作树干净                  |
| Web             | `main` / `520f573`     | 已推送，CI/coverage、镜像构建和 staging 部署成功    |
| Mobile          | 未核对                 | 本阶段未修改，保留用户既有状态                      |

不应提交：

- Parent `AGENTS.md`：用户提供的项目指令更新。
- Parent `.codex`：既有本地未跟踪状态。

## 3. Staging 运行基线

### 3.1 镜像

- Backend/Worker/Frontend：`staging-20260815-d072d538`
  - digest：`sha256:2cf9ccc013be39a6ee2f67249fb4d62c4c32686597260a55fb0b36ea944b1aed`
- AI Orchestrator：`staging-20260815-d072d538`
  - digest：`sha256:35100f3f44acf752436325138351f77e7c065c2197cd6638ba35eaf8483316f8`
  - Runtime revision：`0f15f02`
- Web：`staging-20260816-520f573`
  - digest：`sha256:e408523e5f3eccbd9541502a5e896519f9cddd2ca7076d6d64e13899a0a2f16c`

### 3.2 部署后事实

- `staging.example.com` 的 `bench migrate` 成功。
- Backend、Frontend、Queue、Scheduler、Websocket 已运行新镜像。
- AI Orchestrator 为 healthy；AI `/health` 返回 `status=ok`。
- LiteLLM、Runtime Governance、Vector Search 已配置。
- Backend 到 AI Orchestrator 内部认证通过。
- Agent Runtime Policy：1 个已发布策略，7 个 tool-ready 模型。
- staging 首页和 Ping API 返回 HTTP 200。
- Web `/healthz`、`/user/login`、`/api/method/ping` 检查通过。
- Web 部署前磁盘检查：根盘 98GB，已用 76GB，可用 18GB，使用率 82%；Docker Images 23.47GB，其中 14.35GB 可回收。本次未执行清理。
- 登录态 HTTP 回归没有执行：Parent 仓库未配置对应 staging 凭据。

## 4. 发布与 CI 证据

| 范围                       | Run                                                                             | 结果 |
| -------------------------- | ------------------------------------------------------------------------------- | ---- |
| Backend CI                 | [31882343611](https://github.com/rgc318/myapp/actions/runs/31882343611)         | 成功 |
| AI CI                      | [31882350624](https://github.com/rgc318/myapp-ai/actions/runs/31882350624)      | 成功 |
| AI CodeQL                  | [31882350656](https://github.com/rgc318/myapp-ai/actions/runs/31882350656)      | 成功 |
| Web CI                     | [31945378668](https://github.com/rgc318/myapp-web/actions/runs/31945378668)     | 成功 |
| Web coverage               | [31945380353](https://github.com/rgc318/myapp-web/actions/runs/31945380353)     | 成功 |
| Backend + AI build         | [31882464128](https://github.com/rgc318/frappe_docker/actions/runs/31882464128) | 成功 |
| Backend + AI deploy/health | [31882650200](https://github.com/rgc318/frappe_docker/actions/runs/31882650200) | 成功 |
| Web build                  | [31945606589](https://github.com/rgc318/myapp-web/actions/runs/31945606589)     | 成功 |
| Web deploy                 | [31945829785](https://github.com/rgc318/myapp-web/actions/runs/31945829785)     | 成功 |
| Parent final Lint          | [31923429583](https://github.com/rgc318/frappe_docker/actions/runs/31923429583) | 成功 |

## 5. 本地验证基线

### 5.1 自动化

- Backend 全量：772 tests 通过。
- Backend 最终定向：109 tests 通过。
- AI Ruff、pre-commit：通过。
- AI 全量：162 tests 通过。
- AI 最终定向：60 tests 通过。
- AI Docker test/runtime：通过；test 镜像内 162 tests 通过。
- Web TypeScript、Biome：通过。
- Web 当前修复：TypeScript、Biome、生产构建通过；45 suites / 297 tests 通过。
- Parent、Backend、AI、Web `git diff --check`：通过。

### 5.2 迁移与 Provider

- `localhost` 已完整备份并成功执行 `bench --site localhost migrate`。
- 已执行：
  - `myapp.patches.add_ai_model_multimodal_health_fields`
  - `myapp.patches.create_ai_multimodal_tables`
- `tabMyApp AI Attachment`、`supports_vision`、`last_vision_error_code` 存在。
- `myapp.tasks.cleanup_ai_attachments` 已注册为 Hourly。
- `gpt-5.5`：available、tools=true、vision=true。
- `gpt-5.6-luna`：available、tools=true、vision=true。
- `erp-embedding`：available。
- 当前 Provider 返回 401/403 的 opencode/kimi alias 已标记 unavailable。

### 5.3 Smoke 数据

- 关键本地会话：`AI-CONV-58cdc73eff17466b8097ddd718355df5`。
- 商品、销售订单和订单修改 Draft 均已 discarded。
- bound Attachment 会按 24 小时保留期清理。
- 不要绕过生命周期直接删除 Run、Draft 或 Attachment 审计数据。

本地备份目录：`/home/frappe/frappe-bench/sites/localhost/private/backups/`。

## 6. 当前风险与未完成事项

1. 尚未在 staging 用真实浏览器、平板或摄像头验证 20MB 上传、4 图、历史预览、刷新恢复和网络中断重试。
2. 尚未在 staging 用可回滚业务数据执行商品新增/完善和销售/采购订单创建/修改。
3. Parent 未配置 staging 登录态 HTTP 回归凭据，本次只有公开 HTTP、内部认证、迁移和容器健康证据。
4. 标准 Deploy Workflow 本次没有单独执行发布前备份；后续 Schema 发布应先显式备份。
5. Provider 健康是时间快照；401/403 alias 恢复后必须重新探测。
6. production 尚未部署，只有用户再次明确授权并完成业务验收后才能发布。

## 7. 接手步骤

### 7.1 开始前

1. 阅读本文件、阶段工作总结和多模态设计文档。
2. 确认四仓库 HEAD 与上方提交一致，保留 Parent `AGENTS.md` 和 `.codex`。
3. 若本地 Backend 容器重启过，确认 `bench serve` 已手工启动，再检查 `Host: localhost` Ping。
4. 不要输出 Compose Service Token、LiteLLM Key、Provider 原始正文或系统 Prompt。

### 7.2 下一轮推荐验收顺序

1. staging 浏览器图片上传、历史预览、模型选择和失败带图重试。
2. 商品无候选新增、疑似重复后新增、完善现有商品且不覆盖图片。
3. 销售/采购图片创建、按本系统订单号修改、只改表头、替换明细和并发冲突。
4. 配置受控 staging HTTP 凭据并重新运行登录态回归。
5. 形成业务验收记录，再决定是否申请 production 发布授权。

## 8. 参考入口

- 阶段工作总结：`docs/codex/AI_MULTIMODAL_WORK_SUMMARY_2026-08-16.zh-CN.md`
- 多模态设计：`docs/05-development/06-ai-multimodal-product-and-order.zh-CN.md`
- AI 工作台设计：`docs/05-development/04-ai-business-workbench.zh-CN.md`
- Backend API：`apps/myapp/API_GATEWAY.zh-CN.md`
- AI API：`services/myapp-ai/docs/API_CONTRACT.zh-CN.md`
- Web 设计：`frontend/myapp-web/AI_WEB_FRONTEND_DESIGN.zh-CN.md`

## 9. Web 图片输入器修复发布

- 根因：AI Attachment 使用 `/private/files/...`，但页面原先直接交给 `<img>`；JWT Bearer 不会由图片标签自动携带，导致待发送和历史缩略图破图。
- 修复：Web 使用当前 JWT `fetch` 私有图片并转为临时 Blob URL；组件卸载时释放 Object URL。
- Sender 已改为一体化图片输入器：回形针入口和缩略图位于输入框内部，支持文件选择、剪贴板粘贴、拖拽和只有图片时直接使用统一发送按钮。
- 修改范围只在 `frontend/myapp-web`；包含页面、领域 Service、附件预览组件、测试和 Web 设计文档。
- 已验证：`npm run tsc`、`npm run biome:lint`、`npm test -- --runInBand`（45 suites / 297 tests）、`npm run build`、`git diff --check`。
- Web commit：`520f573 fix: improve AI image attachment experience`，已推送 `main`。
- staging 镜像：`staging-20260816-520f573`，digest `sha256:e408523e5f3eccbd9541502a5e896519f9cddd2ca7076d6d64e13899a0a2f16c`。
- staging 部署成功，Workflow 与本机复核的 `/healthz`、`/user/login`、`/api/method/ping` 均为 HTTP 200。
- 仍需使用有权限测试账号做真实浏览器验收：选择/粘贴/拖拽、4 图上限、图片-only 发送、历史恢复和刷新后的私有预览。
