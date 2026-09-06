# AI 语义命令 V2 设计

## 1. 背景

当前 AI 工作台已经具备结构化意图解析、草稿、人机复核、权限校验、幂等执行和审计能力，但部分 Backend 代码仍会在模型返回后再次通过中文关键词、正则或修改后的字段猜测用户意图。

典型故障是“修改可口可乐的规格为 500ml”：模型已经正确输出修改操作和新规格，Backend 却把新规格作为旧商品搜索条件，最终无法解析目标商品。继续增加同义词无法解决这类问题，因为根因是目标实体与修改内容没有分离。

## 2. 目标

- 模型负责自然语言理解，输出受 Schema 约束的语义命令。
- Backend 只负责权限、实体解析、业务校验、确定性计算、状态机、幂等和执行。
- 目标实体只能由 `target` 解析，禁止从 `patch` 新值反推目标。
- 模糊目标必须要求用户确认，不能因为只有一个模糊搜索结果就自动写入。
- 正常自动场景必须调用结构化意图模型；本地关键词只允许在模型不可用或输出非法时作为显式降级。
- 商品、订单、库存、客户、供应商和仓库使用一致的实体解析状态：`resolved / ambiguous / not_found`。
- 前端依据结构化错误码和字段路径定位问题，不匹配中文错误文案。

## 3. 非目标

- 不删除权限、公司隔离、记录级权限、状态机和幂等校验。
- 不让模型直接决定库存金额、单位换算、价格换算或正式单据状态。
- 不允许模型绕过草稿复核直接创建、提交或取消正式业务对象。
- 不把模型置信度当作实体唯一性的证明。

## 4. 统一语义命令

长期统一结构如下：

```json
{
  "operation": "create | update | adjust | query",
  "target": {
    "entity_type": "product | sales_order | purchase_order | ...",
    "stable_id": null,
    "query": null,
    "context_ref": null
  },
  "patch": {},
  "line_changes": [],
  "constraints": {},
  "ambiguities": [],
  "evidence": []
}
```

### 4.1 商品草稿

商品命令必须分离：

```json
{
  "operation": "update",
  "target": {
    "item_code": null,
    "barcode": null,
    "query": "可口可乐",
    "context_ref": null
  },
  "patch": {
    "specification": "500ml",
    "item_name": null,
    "new_item_code": null,
    "clear_fields": []
  }
}
```

规则：

- `target.query` 保留修改前商品身份。
- `patch.specification` 是修改后的值，不参与目标搜索。
- `patch.new_item_code` 只用于创建，不作为更新目标。
- `clear_fields` 明确表达清空；普通 `null` 表示用户未修改该字段。
- `context_ref=active_product` 只能引用服务端会话状态中唯一 resolved 的商品。

### 4.2 订单修改

订单更新不能把模型提取出的少量行直接当作完整订单。V2 使用：

```json
{
  "operation": "update",
  "target": {
    "order_number": "SO-0001",
    "context_ref": null
  },
  "header_patch": {
    "delivery_date": "2026-09-05"
  },
  "line_update_mode": "patch",
  "line_changes": [
    {
      "operation": "update",
      "target": {"row_id": null, "item_query": "可口可乐"},
      "patch": {"qty": 5, "uom": "箱"}
    }
  ]
}
```

规则：

- `none`：只修改表头，明细原样保留。
- `patch`：按稳定行 ID 或唯一商品行应用增删改；目标不唯一时阻断。
- `replace_all`：只有用户明确要求“全部替换/以这份清单为准”时允许整单替换。
- 未提及的订单行默认保留。
- 表头 `clear_fields` 是明确清空，必须区别于普通 `null`；销售备注、采购备注和供应商参考号不得因值为 `null` 而回填旧值。
- 新增行优先使用 patch 中的新商品查询，同时兼容结构化模型把新增商品写入行 `target.item_query`；Backend 只消费 Schema，不解析中文原句补救。
- 局部修改且商品、单位均未变化时，未明确价格继续保留原订单价格；替换商品或改变单位会改变计价基础，未明确价格时必须按新商品/新单位重新解析参考价，不能沿用旧行单价。

### 4.3 库存调整

- `adjustment_type` 在无法判断时为 `null`，不得默认 `set_target`。
- 语义层允许多行库存调整；执行层可按风险策略拆分为多个草稿或一个受控批次。
- 估值、单位换算和目标库存数量继续由 Backend 计算。

## 5. 模型优先路由

正常流程：

```text
用户输入
  → Intent 模型
  → 结构化场景和语义命令
  → Backend Schema 校验
  → Entity Resolver
  → 业务草稿
  → 用户复核
  → Backend 执行
```

降级流程仅在 Intent 服务不可用、超时或 Schema 非法时启用：

```text
模型不可用
  → 本地保守分类
  → resolution_mode=degraded_local_rules
  → 禁止自动绑定模糊目标
  → 前端展示降级提示
```

本地规则不得生成 `confidence=1.0`，也不得覆盖一个合法且高置信度的模型场景。

## 6. 统一实体解析

Entity Resolver 输入只能是结构化 target：

- 稳定编码、条码、单据号：精确匹配，可自动 resolved。
- 精确名称：只有权限范围内唯一时 resolved。
- 模糊名称、语义搜索：始终返回候选并要求确认。
- 停用、淘汰或存在继任对象：返回生命周期状态和继任关系，不静默改选。
- 会话引用：只接受服务端维护的 `context_ref`，并重新读取正式实体。

各业务域不得自行使用“唯一搜索结果即自动选中”等不同规则。

## 7. 结构化校验错误

Backend 草稿校验项统一为：

```json
{
  "code": "PRODUCT_TARGET_AMBIGUOUS",
  "field": "target.item_code",
  "message": "商品目标无法唯一匹配。",
  "meta": {"candidate_count": 2}
}
```

迁移期同时保留旧 `errors: string[]` 和新增 `issues: object[]`。Web 优先消费 `issues`，旧字符串只用于兼容展示，不再参与控制流。

## 8. 迁移阶段

### Phase 1：语义边界

- 商品草稿升级为 `target + patch`。
- 修复商品名称修改被丢弃的问题。
- 商品目标解析不再使用新规格、新品牌和新名称。
- 自动场景改为模型优先，关键词仅在模型不可用时降级。
- 增加商品修改端到端评测。

### Phase 2：订单行级变更

- 销售、采购订单升级为 `target + header_patch + line_changes`。
- 默认保留未提及行。
- 只有明确 `replace_all` 才调用整单明细替换。
- 增加重复商品行、删除行、增加行和只改表头测试。

### Phase 3：统一解析与错误契约

- 抽取统一 Entity Resolver。
- 客户、供应商、仓库和商品采用相同匹配等级。
- Backend 返回结构化 `issues`。
- Web 删除中文文案字段映射和版本冲突文案判断。

### Phase 4：清理旧链路

- 删除会话指代正则的业务决策职责。
- 删除 Runtime 对模型查询参数的正则覆盖。
- 查询 DSL 关键词解析只保留为可观测的兼容降级，最终在覆盖率达到要求后移除。
- 删除已经没有调用者的旧 Schema、Prompt 和测试断言。

## 9. 验收标准

- “修改可口可乐的规格为 500ml”必须输出目标“可口可乐”和 patch“500ml”，不得搜索“可口可乐 500ml”作为旧实体。
- “把这个商品名称改为无糖可乐”必须形成 `item_name` patch。
- “把订单里的可乐改成 5 箱”不得删除其他订单行。
- “只改交货日期”不得调用订单明细替换接口。
- 模型正常可用时，自动场景不得记录 `local_fast_path`。
- 降级时必须记录 `degraded_local_rules` 和警告。
- Web 不得通过 `error.includes(...)` 决定业务字段。
- 自然语言到模型 Schema、Backend 目标解析、草稿和执行前重校验必须有完整回归。

## 10. 当前实施状态（2026-09-04）

- Phase 1 已实现：商品 `product-setup-draft-v7` 使用 target/patch；自动场景模型优先，本地规则仅标记为 `degraded_local_rules`。
- Phase 2 已实现首轮：销售/采购 v5 支持 header patch 与 line changes；Backend 在完整订单快照上合并，表头-only 不触碰明细，重复商品行无 row ID 时阻断；明确清空表头通过 `header_clear_fields` 贯通草稿生成、Web 编辑保存、执行前刷新、正式执行和版本差异审计；`replace_all`/新建只接受 add 行；商品或单位变化时重新解析价格基础，单纯数量等修改继续保留原订单价格。
- Phase 3 已实现迁移契约，但统一解析器尚未完成：Backend 返回 `validation.issues[]` 并保留旧 errors；Web 已删除中文错误文本和版本冲突文案控制流。库存错误已提供稳定 code/field，其他领域在滚动迁移期允许 field 为空并继续显示旧 errors。客户、供应商、仓库和商品尚未全部收敛到同一个 Entity Resolver。
- 2026-09-06 商品目标衔接修复：商品完善草稿已消费共享商品解析器返回的确定性 `selected`，不再出现“解析器已 resolved、草稿适配层却丢弃目标”的假未找到。没有 `selected` 的单一模糊候选仍要求人工确认，并与多候选、零候选分别返回 `PRODUCT_TARGET_CONFIRMATION_REQUIRED / PRODUCT_TARGET_AMBIGUOUS / PRODUCT_TARGET_NOT_FOUND`；三者字段均为 `target.item_code`。该修复没有放宽“模糊目标不能自动写入”的安全边界。
- Phase 4 已完成关键清理，但不是全部完成：Runtime 不再用“带某字”正则覆盖模型工具参数；简单问候与明确草稿不再走 local fast path。订单 V2 的订单/商品指代只消费 Schema `context_ref`；客户/供应商指代和库存 v3 仍保留会话正则兼容路径，旧平铺订单 Schema 和查询 DSL 也仍作为显式兼容/降级保留，待对应 Schema 升级和真实模型覆盖率稳定后删除。

因此，当前可以认定 Phase 1 和 Phase 2 首轮闭环已完成并具备回归保护；不能把长期 Phase 3/4 路线描述为全部完成。

## 11. 验证基线

2026-09-04 收口验证：

- Backend：Python compile、AI service 183 tests、AI repository/draft-state/gateway 205 tests、全量 unit 918 tests 通过。
- AI Orchestrator：Ruff、pre-commit、全量 199 tests、Docker test/runtime 镜像构建和容器测试通过。
- Web：TypeScript、Biome、生产构建、全量 58 suites / 377 tests 通过。
- Parent、Backend、AI Orchestrator、Web 的 `git diff --check` 通过。

上述结果证明当前实施范围可以进入下一阶段，但不替代 staging 的真实模型、真实权限账号和可回滚业务数据验收。

## 12. 下一阶段入口

1. 为销售/采购客户与供应商补充正式 `context_ref`，移除正常 V2 路径的会话中文正则绑定。
2. 将库存命令升级为 `target + patch`，由 Schema 表达商品会话引用和调整内容。
3. 抽取统一 Entity Resolver，并统一商品、往来单位、仓库和单据的解析等级与稳定错误码。
4. 在真实模型评测覆盖率稳定后，删除旧平铺订单 Schema、旧会话指代兼容路径和无调用者断言。
5. 使用相同不可变提交完成 staging 真实浏览器和可回滚业务验收；外部瞬时失败按 staging 策略有限重试，不通过修改代码追逐环境波动。
