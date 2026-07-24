# 全项目完整功能与效果测试报告

测试时间：2026-07-20

测试环境：本地 `localhost` Frappe/ERPNext 真实站点、Web 本地构建环境、AI Docker 隔离环境

Mobile：按用户要求延期，不纳入本轮适配与发布测试

## 1. 结论

本轮完整回归未发现未解决的功能失败。测试不只检查 HTTP 状态，还核对了正式 ERPNext 单据、库存数量、Stock Ledger、应收应付、实收实付、写销、退货退款、幂等重放、回滚后状态、报表口径、打印文件副作用和 AI 固定评测阈值。

本轮发现并修复 1 个测试入口缺陷：AI 离线评测 CLI 在 Service Token 强校验后无法在无生产 Secret 的环境运行。修复后离线 CLI 使用确定性评测配置，`22/22` 用例和完整发布门禁通过。

当前可判定：Backend、Web、AI Orchestrator 和本地部署编排满足本轮功能回归要求。Mobile 新接口适配、付费模型 live eval 和包含正式 ERP staging 镜像/站点迁移的完整发布演练仍属于独立验收边界。

## 2. 测试总量

| 区域                                      | 结果                                                                                                     |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Backend unit                              | `578/578` 通过                                                                                           |
| Backend 真实站点 integration              | `8/8` 通过                                                                                               |
| Backend 真实 HTTP 不重复用例              | `169/169` 通过                                                                                           |
| HTTP 模块原始加载数                       | `331`；其中 `test_gateway_v2_http` 会同时加载继承的 Gateway 基础用例，本报告按不重复业务用例统计为 `169` |
| AI pytest                                 | `86/86` 通过                                                                                             |
| AI 固定离线效果评测                       | `22/22`，full gate `PASS`                                                                                |
| Web Jest                                  | `30` 套、`190/190` 通过                                                                                  |
| Web TypeScript / Biome / production build | 通过                                                                                                     |
| AI Docker test/runtime                    | 构建、默认测试、`pip check` 通过                                                                         |
| AI 合成 Chat + Vector 集成                | 通过，测试资源已清理                                                                                     |
| development / staging AI 部署编排         | 配置、健康、模型发现、向量可达通过                                                                       |

真实 HTTP 不重复用例构成：

- Gateway 基础：`81`
- Gateway V2 新增：`46`
- 采购快捷与回滚：`39`
- JWT 生命周期：`3`

## 3. 复杂销售链路效果

覆盖并通过：

- 销售建单顺序幂等、Header 幂等、同 Key 不同数据冲突、4 路并发只生成一张订单。
- 订单数量 `3` 时部分发货 `2`，最终 Delivery Note 行数量为 `2`、成交价为 `880`。
- 订单数量 `3` 时部分开票 `1`，最终 Sales Invoice 行数量为 `1`、成交价为 `870`。
- 发票金额 `1000`、现金实收 `900`、写销 `100`：发票最终 `outstanding_amount=0`、状态为 `Paid`。
- 超额收款使用未分配金额语义，不错误扩大正式发票分配。
- 已付款销售发票退货后明确要求后续客户退款，不把“退货单已创建”误判为资金已退。
- 客户退款专项长链：
  - 来源销售发票已全额收款。
  - 部分退货生成正式退货 Sales Invoice。
  - 当前可退款金额实测 `400`。
  - 先退一半，退款上下文变为 `partial_refunded`。
  - 相同 `request_id` 重放返回同一 Payment Entry，不重复退款。
  - 再退剩余金额后状态变为 `refunded`、`refundable_amount=0`、禁止继续退款。
- 销售付款取消后发票未收金额恢复；取消发票后订单重新允许开票；取消订单后写操作全部关闭。

## 4. 复杂采购链路效果

覆盖并通过：

- 采购订单、收货、发票、付款各步骤顺序幂等和并发幂等。
- 部分收货、按收货单部分开票、采购退货和来源上下文。
- 采购发票金额 `4600`、实际付款 `4500`、写销 `100`：
  - 聚合结算金额 `paid_amount=4600`
  - 实际现金 `actual_paid_amount=4500`
  - `outstanding_amount=0`
  - `total_writeoff_amount=100`
- 付款大于未付金额、零付款和负付款均被拒绝，拒绝后付款状态与未付金额不变。
- 快捷采购编排覆盖订单→收货→开票→付款，以及付款步骤失败后的可恢复重试。
- 快捷回滚覆盖：
  - 部分付款后恢复可编辑订单。
  - 手工取消付款/发票/收货后继续剩余回滚步骤。
  - 多收货、多发票、多付款失败关闭。
  - 存在收货退货或发票退货时失败且不产生部分变更。
  - 禁止付款回滚时明确阻断，允许后续修正参数重试。
- 供应商退款专项长链：
  - 来源采购发票已全额付款。
  - 部分退货生成正式退货 Purchase Invoice。
  - 当前可退款金额实测 `500`。
  - 先退一半后状态为 `partial_refunded`。
  - 幂等重放不生成第二张付款单。
  - 补退剩余金额后状态为 `refunded`、可退金额归零。

## 5. UOM、库存与 Stock Ledger 效果

真实站点 integration 验证：

- 销售 `2 Box`，换算因子 `12`，扣减 `24 Nos`；Bin 与 Stock Ledger Entry 同步为 `-24`。
- 销售 `5 Nos` 扣减 `5 Nos`。
- 明确价格 `0` 不会被标准价覆盖，订单总额保持 `0`。
- 原订单 `1 Box=12 Nos` 修改为 `7 Nos` 后，发货只扣减 `7 Nos`。
- 仅有 `10 Box=120 Nos` 时尝试发货 `11 Box=132 Nos` 被拒绝，拒绝前后库存完全不变。
- 采购收货 `2 Box` 增加 `24 Nos`，Bin 与 Stock Ledger Entry 一致。
- 采购 `3 Box` 开票后支付一半，订单聚合、发票未付金额和最新 Payment Entry 保持一致。

库存专项 HTTP 长链使用独立商品与两个真实仓库：

1. 初始源仓 `50 Nos`、目标仓 `0`。
2. 转仓 `2 Box`，换算因子 `10`，实际转移 `20 Nos`。
3. 相同请求重放返回同一 Stock Entry，不再次扣减。
4. 转仓后源仓 `30`、目标仓 `20`。
5. 目标仓校准到 `3 Box=30 Nos`，正式差异为 `+10`。
6. 再次校准到相同数量不创建 Stock Entry，`qty_delta=0`。
7. 双仓批量盘点后源仓为 `25`、目标仓为 `3.5 Box=35 Nos`，`difference_count=2`。
8. 相同最终数量再次盘点不创建 Stock Reconciliation。
9. 负库存目标被拒绝，目标仓仍为 `35`，无副作用。

## 6. 主数据、查询、报表与打印效果

主数据和查询：

- 原子建商品与期初库存、负库存拒绝、重复条码拒绝、并发同 Key 只建一个商品。
- 条码新增、主条码切换、删除全生命周期通过。
- 同名不同规格商品保持独立；停用其中一个不会影响同名其他规格。
- 商品昵称、规格、条码均可搜索；商品规格贯通销售/采购单据详情。
- 销售/采购日期、金额排序、分页、状态和取消单可见性过滤符合预期。

报表：

- 拆分后的经营总览与原综合报表 KPI 一致。
- 现金流报表与综合报表收支汇总一致。
- 应收应付拆分表与综合报表一致。
- 无效日期范围和过大时间范围失败关闭。
- 现金流明细分页与 Payment Entry 引用追踪通过。

打印专项 HTTP 效果：

- Sales Invoice HTML 预览包含当前单号。
- 默认 PDF 流模式生成有效 PDF，本次实测 `255199` 字节，不创建后端 File。
- `archive=1` 只创建一条私有 File，路径位于 `/private/files/`，并正确挂接到来源发票。
- 不支持的 `docx` 输出被拒绝。
- 专项归档文件验证后已删除，不保留测试附件。

## 7. 权限、认证、幂等与异常

- JWT 登录、`me`、刷新轮换、注销撤销完整生命周期通过。
- 无效 Bearer Token 返回认证失败；普通 Session 登录不隐式下发 JWT Cookie。
- 状态写接口 POST-only 契约由 unit 门禁覆盖。
- 同一幂等 Key 相同数据返回同一业务单据；同一 Key 不同数据返回 `409`。
- 销售订单、采购订单、商品创建和供应商付款并发请求只产生一个正式结果。
- 退款、退货、收付款和快捷回滚均覆盖幂等重放。
- 多币种写销在 Backend 服务层失败关闭。

## 8. AI 效果测试

AI pytest `86/86` 通过，覆盖：

- 配置和强 Service Token 校验。
- Chat、SSE、四类结构化草稿。
- Prompt 版本冲突。
- 运行时限流、预算、并发和熔断。
- Langfuse 失败开放、异步批处理、重试和丢弃指标。
- 模型发现、策略验证和向量发布门禁。
- Qdrant upsert/search/delete、alias 切换和只读业务过滤。

离线固定评测：

- `22/22` attempts passed。
- `gate_scope=full`。
- `schema_valid_rate=1.0`。
- `safety_pass_rate=1.0`。
- `structured_field_accuracy=1.0`。
- 覆盖销售草稿、采购草稿、库存调整、商品建档、grounding、Prompt Injection、禁止正式写操作和敏感信息提取。
- 评测命令无需 Service Token、Provider Key 或生产 Secret，且不访问网络。

Standalone 合成集成：

- Redis、Qdrant、Orchestrator、合成 OpenAI/Frappe Provider 健康。
- Chat 返回确定性结果。
- 向量 upsert/search/delete 闭环通过。
- 测试容器、网络和数据卷已清理。

未执行付费 live eval，因为它需要显式开启计费开关；本轮不将合成评测冒充真实供应商模型质量结论。

## 9. Web 效果测试

- TypeScript：通过。
- Biome：`219` 个文件通过。
- Jest：`30` 套、`190/190` 通过。
- `--detectOpenHandles` 复测通过，未复现普通运行结束时的一次性异步句柄提示。
- Production build：通过，全部业务路由成功生成。

## 10. 部署与运行验证

- 实际 Secret 文件权限检查通过；`0644` 临时 Secret 文件被正确拒绝。
- development + bundled Langfuse Compose config 通过。
- Langfuse 同步后 Orchestrator 强制重建成功：
  - `langfuse_configured=true`
  - `langfuse_delivery.enabled=true`
  - `langfuse_delivery.worker_running=true`
- staging env 权限和必填变量校验通过。
- 隔离 staging AI 部署通过：Redis、Qdrant、Orchestrator 健康，发现 `9` 个 LiteLLM 模型，向量状态可达。
- ShellCheck、Codespell 和空白检查通过。
- 所有隔离部署资源均已清理，当前开发 Orchestrator 保持健康。

## 11. 查询性能基线

每个接口采样 `5` 次：

| 接口                           |        平均 |         P95 |        最大 |
| ------------------------------ | ----------: | ----------: | ----------: |
| `search_sales_orders_v2`       | `193.63 ms` | `195.89 ms` | `200.45 ms` |
| `search_purchase_orders_v2`    | `134.15 ms` | `134.92 ms` | `136.92 ms` |
| `get_sales_order_detail`       |  `21.67 ms` |  `21.54 ms` |  `23.71 ms` |
| `get_purchase_order_detail_v2` |  `20.98 ms` |  `21.23 ms` |  `22.69 ms` |
| `search_product_v2`            |  `13.75 ms` |  `13.72 ms` |  `14.98 ms` |

当前本地基线未发现明显慢接口；销售/采购工作台查询数据量已超过千级，仍保持在约 `200 ms` 以内。

## 12. 剩余边界与风险

- Mobile 新接口适配按用户要求延期，本报告不代表 Mobile 发布就绪。
- 未执行会产生供应商费用的 AI live eval。
- 未重新构建包含本地未提交 Backend 代码的正式 ERP staging 镜像，因此没有把本轮结果描述为完整生产发布演练；当前 Backend 效果通过真实开发站点 HTTP 与容器集成验证。
- 真实 HTTP 回归会在本地测试站点生成大量 `HTTP-*` 商品及销售/采购测试单据；这些数据不应进入生产数据库。
- AI 仍有既有 Starlette/httpx 弃用警告，不影响当前功能。
