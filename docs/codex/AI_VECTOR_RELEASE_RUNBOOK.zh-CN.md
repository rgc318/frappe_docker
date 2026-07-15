# AI Embedding 双 Collection 发布与回滚 Runbook

更新时间：2026-07-15

## 1. 不可变边界

- `MYAPP_AI_QDRANT_ALIAS` 是在线检索和增量写入的稳定引用；物理 collection 名称必须版本化且不可复用。
- 新 Embedding 模型、维度或向量空间必须新建 collection，全量补建后才能切换 alias。
- 候选构建使用独立 `MyApp AI Vector Release` 和逐商品 `MyApp AI Vector Build Item`，不得覆盖当前在线索引状态。
- 在线和候选构建必须使用同一 `MYAPP_AI_VECTOR_EXCLUDED_ITEM_PREFIXES`；排除项不得计入候选总点数或质量集候选。
- 发布前必须满足：注册模型健康、数据区域/留存已复核、全量商品构建完成、Qdrant 点数精确一致、维度有效、受控 full gate 报告匹配、双人审批。
- Alias 发布与回滚只允许 `System Manager` 执行，必须填写原因并产生 critical 审计。

## 2. 当前基线

- 稳定 alias：`myapp-products-live`
- 当前物理 collection：`myapp-products-v1`
- 2026-07-15 质量治理后真实核对：ERP Item 582、Sales Order 854；在线 alias `myapp-products-live → myapp-products-v1` 保持不变，143 points / 1024 维，`HTTP-` payload 为 0，SKU001～SKU010 全部存在。
- 2026-07-15 23:57 CST：`erp-embedding` 单条/批量恢复为 HTTP 200、1024 维；30 条中文门禁 Top-1 96.67%、Top-3 100%、Provider error 0、排除泄漏 0、p95 211.745ms。该结果满足当前 v1 在线质量门槛，但不是 v2 full-gate；新 collection 的全量补建、权限、删除/恢复、审批、发布和回滚仍必须独立完成。

## 3. Full Gate 报告

Orchestrator 只读取部署侧只读挂载的 `MYAPP_AI_GOVERNANCE_EMBEDDING_GATE_REPORT_PATH`。报告至少包含：

```json
{
  "schema_version": "myapp-ai-embedding-release-report-v1",
  "release_code": "products-embedding-v2",
  "embedding_model": "erp-embedding-v2",
  "collection": "myapp-products-v2",
  "index_version": "product-semantic-v2",
  "summary": {
    "passed": true,
    "gate_scope": "full",
    "release_gate_eligible": true,
    "threshold_failures": []
  }
}
```

报告生成器必须同时覆盖固定语义集 Top-1/Top-3、权限二次过滤、删除幂等、删除后恢复、维度/点数、p50/p95、Provider 失败和关键词降级；客户端上传的 JSON 不能充当发布证据。

## 4. 发布流程

1. 在模型注册表维护新的不可变 Embedding 别名，完成区域、留存和健康复核。
2. 确认 Backend 与 Orchestrator 都配置同一 `MYAPP_AI_QDRANT_ALIAS`。
3. 先 dry-run 并执行 `cleanup_excluded_ai_product_vectors_v1`，确认只移除明确测试前缀的向量且 ERP Item/历史交易数量不变。
4. 运行 30 条版本化中文检索质量集，确认无排除候选泄漏；Provider 错误时停止发布。
5. 在 `/administration/ai/models` 的“Embedding 发布”创建候选版本，指定新物理 collection。
6. 独立 `ai-vector` Worker 按 64 商品一批补建；失败项保留错误并可重试。
7. 上传由受控评测生成的 full gate 报告，执行“校验门禁”。
8. `AI Model Approver` 审批；生产起草人与审批人不得相同。
9. `System Manager` 发布。Orchestrator 使用 Qdrant `/collections/aliases` 单请求删除旧映射并创建新映射，原子切换。
10. 保留旧物理 collection 至回滚窗口结束；备份和质量观察完成前不得删除。

## 5. 回滚与恢复

- 在“Embedding 发布”选择状态为 `superseded` 的历史版本并执行回滚；系统原子把同一 alias 指回旧 collection。
- 若 Alias 已切换但数据库事务未完成，读取 `/internal/v1/vector/governance/status` 对比 Qdrant alias 与发布表，按真实 alias 状态重新执行发布/回滚幂等请求并补审计。
- 候选构建失败不会影响在线 alias。修复 Provider 后只重试非 indexed 构建项。
- 旧 collection 被误删时，停止发布动作，按 Qdrant snapshot 恢复后再回滚；不得把另一向量空间临时改名冒充旧 collection。

## 6. 验证命令

```bash
docker exec frappe_docker-ai-orchestrator-1 python -c '
import json, os, httpx
r = httpx.post(
  "http://localhost:4010/internal/v1/vector/governance/status",
  headers={"Authorization": "Bearer " + os.environ["MYAPP_AI_SERVICE_TOKEN"]},
  json={"collection": "myapp-products-v1", "alias_name": "myapp-products-live"},
  timeout=10,
)
print(json.dumps(r.json(), ensure_ascii=False))
'
```

验收输出必须同时证明 alias 目标、collection 存在、点数、维度和发布表状态；只看到容器健康或 alias 存在不算完整发布证据。
