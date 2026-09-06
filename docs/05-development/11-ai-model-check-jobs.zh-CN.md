# AI 模型异步检测设计与运维

## 目标与依据

采用异步请求-响应模式：HTTP 创建任务，客户端查询持久化进度。参考 [Microsoft 异步请求-响应模式](https://learn.microsoft.com/en-us/azure/architecture/patterns/async-request-reply)、[Frappe Background Jobs](https://docs.frappe.io/framework/user/en/api/background_jobs)、[LiteLLM 健康检查](https://docs.litellm.ai/docs/proxy/health)。这些是设计参考，不宣称对产品最新版本进行了实测。

原问题不是浏览器没有 async/await，而是 HTTP 等待全部模型及能力探测结束，整体超时后已完成结果不能及时展示或保存。延长 HTTP 超时不能解决任务生命周期问题。

## 实现约定

单项、已选批量、全部和定时检测共用后台任务引擎。Web 不再调用同步 availability 接口。任务写入站点数据库原生表 `tabMyApp AI Model Check Job`，提交后进入 Frappe long 队列。

| 维度 | 约定 |
| --- | --- |
| basic 快速模式 | 只测最小 Chat/Embedding 请求，保留工具、结构化、视觉能力及其错误记录 |
| full 完整模式 | 基础请求加结构化、工具、双图片挑战，会发起多次计费请求 |
| 范围 | 提交时冻结 alias 列表；最多 100 项；显式空列表拒绝；运行前再次检查生命周期 |
| 并发 | 每站点一个活动任务，任务内串行逐模型，不在线程中共享 Frappe 数据库上下文 |
| 防重 | 唯一活动槽、相同模式子集复用、请求幂等键、worker 条件更新认领 |
| 保存 | 每项健康与审计提交后保存任务明细；执行失败 rollback 并记录安全错误码，继续下一项 |
| 取消 | 排队任务立即取消；运行中在当前模型结束后停止，不撤销已保存结果 |
| 失联 | 30 分钟无进度派生 interrupted，下一次提交回收过期活动槽；不自动重试计费请求 |
| 上限 | 单模型 Backend→AI 请求 180 秒；任务逻辑截止 5 小时，RQ 硬超时 6 小时 |
| 权限 | start/get/cancel 均要求治理管理权限；本站管理人员共享可见性，worker 逐项复核权限 |

任务状态为 queued → running → completed / partial / cancelled / interrupted。completed 只表示执行结束，不代表模型全部通过；partial 表示部分检测执行错误，不代表全站 AI 服务不可用。

Web 采用 Ant Design Select、Progress、Table 展示模式、进度、基础可用数和逐项错误。轮询不重叠、卸载清理、刷新恢复最近任务；进度查询失败单独提示，不修改模型健康。“重试异常及未完成项”沿用原模式，只重试基础未通过、执行错误和未检测项。完整检测中单项能力失败仍在注册表能力列查看，不等同基础失败。

定时检测默认 basic，每天 03:15（站点时区）创建相同后台任务，沿用既有站点开关、范围和 TTL。任务记录提交者、时间、模式、范围与结果；单模型更新继续写治理审计。

## API 与兼容

新增 Gateway POST `start_ai_model_check_v1(model_aliases?, mode="full", request_id?)`、POST `cancel_ai_model_check_v1(job_id, request_id?)`、读取 `get_ai_model_check_v1(job_id?)`。详情包含 job_id/status/mode/model_aliases/total/completed/items/cancel_requested/creation/modified。省略 job_id 返回本站最近任务或 null。HTTP 仍沿用 Gateway envelope，不返回裸 202。

旧 `check_ai_model_availability_v1` 暂保留同步兼容契约，**不属于新任务活动槽控制范围**；新页面和定时任务不再调用。外部客户端迁移后才能下线，不能宣称所有历史入口均已取消长 HTTP。

Orchestrator availability 新增 `mode=basic|full`，默认 full。basic 返回能力字段不是本次能力结论，Backend 必须保留旧能力快照。

## 部署与恢复

正式部署运行 `bench --site <site> migrate` 创建表；本地可定向执行幂等补丁 `myapp.patches.create_ai_model_check_job.execute`。更新 AI 镜像、Backend、long worker 和 scheduler，确认 `/readyz`、Backend ping 正常。

HTTP smoke 不创建 ERP 商品或订单；不传 alias 只查询进度，传 alias 才执行一次真实 basic 检测：

```bash
MYAPP_HTTP_BASE_URL=http://localhost:8000 \
MYAPP_HTTP_MODEL_CHECK_ALIAS=<获准检测的模型> \
python3 -m unittest apps.myapp.myapp.tests.http.test_ai_model_check_http -v
```

排队不动先查 long worker、Redis 和队列；任务提交成功不代表 worker 健康。排队任务可取消后重建；失联超过 30 分钟可重试未完成项。不要将模型改为 unavailable 来处理队列故障。

## 边界

- 当前有界串行，不承诺全量总耗时显著缩短；收益是解除长 HTTP、逐项可见、失败隔离和 basic 降低请求数。更高吞吐需独立子任务、按 Provider 限速，后续另行扩展。
- 健康提交后、任务明细保存前崩溃可能留下明细缺口，人工重试可能再次调用模型，不承诺 Provider exactly-once。
- 队列不可用或等待超过 30 分钟按中断处理；尚无独立 outbox 自动补投、历史检索页面或记录清理策略。
- 基础健康、能力、人工启停和场景资格保持独立；基础通过不是完整业务验收。
