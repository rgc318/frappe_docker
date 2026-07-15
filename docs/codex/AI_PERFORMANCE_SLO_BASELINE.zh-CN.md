# AI Orchestrator 性能基线与初始 SLO

更新时间：2026-07-15

## 1. 适用范围

本文件定义 AI Orchestrator 单副本 P0 的可复现性能证据、初始容量边界、错误预算和责任角色。

- 合成 Provider 基线证明共享异步连接池、独立并发池、SSE、Qdrant 检索和批量 Embedding 路径。
- 真实 Provider 基线只用于低成本端到端校准，不代表供应商已通过完整 10/20/50/100 或 20/50/100/200 容量验收。
- 当前结果来自本地单 Uvicorn、单 Qdrant 环境，不能直接外推为生产多副本容量。
- 测试只使用合成 Prompt 和合成向量文档；报告不保存请求正文、模型输出、服务 Token、供应商密钥或 ERP 数据。

## 2. 可复现证据

- `ai-performance-reports/ai-load-synthetic-baseline-20260715.json`
- `ai-performance-reports/ai-load-search-capacity-20260715.json`
- `ai-performance-reports/ai-load-live-baseline-20260715.json`
- 压测器：`services/myapp-ai/scripts/ai_load_test.py`
- 合成 Provider：`services/myapp-ai/scripts/mock_openai_provider.py`

全量合成矩阵每档执行两轮：

| 场景 | 最高档结果 | p95 | 结论 |
|---|---:|---:|---|
| Chat | 100 并发，200/200 成功 | 1122.27 ms | 单副本共享连接池无错误 |
| SSE | 200 并发，400/400 完成 | 首 Token 2338.62 ms；总时延 2419.92 ms | 无无界排队或流泄漏 |
| 销售草稿 | 20 并发，40/40 成功 | 299.56 ms | structured 独立池有效 |
| 检索 | 20/50/100 过载档 | 成功请求最高 p95 403.74 ms | 超出容量时稳定返回 `AI_EMBEDDING_CONCURRENCY_LIMITED` |
| Embedding | 32/64/128 每批均成功 | 43.49 / 55.40 / 80.45 ms | 稳态批量路径通过；冷创建约 1195 ms |

检索容量校准每档执行五轮：

| 提供并发 | 成功/总数 | 错误率 | 成功请求 p95 |
|---:|---:|---:|---:|
| 4 | 20/20 | 0% | 78.84 ms |
| 8 | 40/40 | 0% | 76.23 ms |
| 12 | 60/60 | 0% | 105.78 ms |
| 16 | 70/80 | 12.5% | 128.29 ms |

因此单副本初始受支持的检索提供并发为 12；16 及以上属于过载验证档，429 是预期背压信号，不是扩容证明。

真实低价 Provider 最终小样本：

| 场景 | 样本 | 成功率 | p50 | p95 |
|---|---:|---:|---:|---:|
| Chat，并发 2 | 6 | 100% | 4322.46 ms | 7668.48 ms |
| SSE，并发 2 | 6 | 100% | 7438.30 ms | 8878.22 ms |
| SSE 首 Token | 6 | 100% | 7037.56 ms | 8808.23 ms |

在最终基线前曾出现一次 2 路 SSE 中 1 路快速 `AI_SERVICE_UNAVAILABLE`，随后 2/2 和 6/6 重跑均通过。该瞬时供应商/流式失败不删除、不伪装为成功，继续纳入告警和后续付费 staging 基线。

## 3. 压测发现与修复

1. Orchestrator `ProductVectorUpsertRequest` 原上限为 100，与 Backend 和设计的 128 不一致；已统一为 128 并增加 128 接受、129 拒绝测试。
2. Qdrant 初始容器 `nofile=1024`，在高并发检索后创建 payload index 时真实触发 `Too many open files`；Compose 已提升 soft/hard `nofile` 到 65536，重启后 alias、582 points 和 1024 维保持完整。
3. 检索与索引共享 8 槽 Embedding 池。过载时请求在有限等待后返回稳定 429，未出现无限队列；生产扩容前不得仅通过提高 semaphore 绕过供应商配额评审。

## 4. 初始 SLO 与错误预算

以下为单副本 P0 的发布门槛。正式生产多副本 SLO 必须由 staging 完整付费矩阵重新校准。

| SLI | 初始 SLO | 适用容量 |
|---|---|---|
| Orchestrator Chat 可用性 | 月度被接纳请求成功率 ≥ 99.5% | 单副本提供并发 ≤ 100；不含客户端 4xx |
| Chat 服务层延迟 | 合成 Provider p95 ≤ 1500 ms | 单副本提供并发 ≤ 100 |
| SSE 完成率 | 月度被接纳流完成率 ≥ 99.5% | 单副本提供并发 ≤ 200 |
| SSE 服务层首 Token | 合成 Provider p95 ≤ 3000 ms | 单副本提供并发 ≤ 200 |
| Structured 草稿 | 成功率 ≥ 99.5%，p95 ≤ 500 ms | 单副本提供并发 ≤ 20 |
| 商品向量检索 | 成功率 ≥ 99.5%，p95 ≤ 250 ms | 单副本提供并发 ≤ 12 |
| 过载拒绝 | 100% 返回稳定 429 + `Retry-After`，拒绝 p95 ≤ 500 ms | 超出支持容量时 |
| 批量 Embedding | 32/64/128 每批成功率 ≥ 99%，稳态 p95 ≤ 2 s | 独立 ai-vector 队列 |
| 真实 Provider Chat | 暂定 p95 ≤ 15 s，成功率 ≥ 99% | 仅低并发；待 staging ≥100 样本确认 |
| 真实 Provider SSE 首 Token | 暂定 p95 ≤ 15 s，完成率 ≥ 99% | 仅低并发；待 staging ≥100 样本确认 |

月度错误预算：

- 99.5% SLO 对应 0.5% 被接纳请求错误预算；按时间折算约 3 小时 36 分/月，但告警和发布判断优先使用请求型 SLI。
- 在已声明支持容量内的本地 `AI_LOCAL_CONCURRENCY_LIMITED` / `AI_EMBEDDING_CONCURRENCY_LIMITED` 计入容量错误预算。
- 超出声明容量的压力档单独计入 saturation 指标，不可用来掩盖支持容量内的拒绝。
- 真实 Provider 429、超时和 5xx 计入端到端错误预算，并触发熔断/同能力降级；权限、Schema 和业务校验错误不计入供应商错误预算。

## 5. 告警与责任角色

| 事件 | Warning | Critical | 主责 | 协同/审批 |
|---|---|---|---|---|
| Chat/SSE/草稿 5 分钟错误率 | > 1% | > 5% | AI Platform Operations | AI Model Manager |
| 支持容量内本地 429 | > 0.5% | > 2% | AI Platform Operations | Backend Operations |
| SSE 首 Token p95 | > 15 s | > 30 s | AI Model Manager | Provider/LiteLLM Owner |
| Qdrant `nofile` 使用率 | > 70% | > 85% 或出现 `Too many open files` | Vector Platform Operations | Infrastructure Operations |
| Qdrant 检索 p95 | > 250 ms | > 500 ms | Vector Platform Operations | AI Platform Operations |
| ai-vector 队列最老任务 | > 5 min | > 15 min | Backend Operations | AI Model Manager |
| 月度错误预算消耗 | > 50% | > 100% | AI Platform Operations | AI Model Approver / AI Auditor |

责任角色必须在生产值班系统中映射到具名 on-call；当前仓库只定义职责，不虚构人员姓名。预算耗尽后暂停非紧急模型/Prompt/Embedding 发布，紧急回滚仍由 System Manager 执行并保留审计。

## 6. 未完成边界

- 外部 `erp-embedding` 仍存在 Provider `float + str` 配置故障，真实 32/64/128 Embedding 尚未验收。
- 尚未执行 staging 真实 Provider 的完整付费矩阵和单副本摘除/多副本一致性演练。
- OTLP、Qdrant snapshot 恢复、Langfuse PostgreSQL/ClickHouse/MinIO 联合恢复尚未完成。
- 因此当前只能宣称高并发 P0 代码与单副本合成基线完成，不能宣称生产高可用或供应商容量完成。
