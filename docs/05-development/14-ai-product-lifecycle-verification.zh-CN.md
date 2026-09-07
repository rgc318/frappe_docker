# AI 商品生命周期提交前回归记录

日期：2026-09-08（Asia/Shanghai）。范围：商品启用/停用/删除计划、既有草稿范围锁定、SSE 引用保持、逐轮模型选择，以及跨模块回归。仅本地验证，不是 staging/production 发布报告。

提交：Backend 功能 `e824a66`、价格校验独立修复 `49e4ca3`；AI `ab94491`（按子模块规则已推送）；Web `74a3a78`。Backend/Web 未推送，无服务器部署。父仓本次固定 Backend/AI 指针并保存本报告。

## 结果

| 验证层次                                          | 结果                 | 覆盖及限制                                                                                                                                 |
| ------------------------------------------------- | -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Backend 全量单元测试                              | 1019 PASS            | 包括商品、销售、采购、库存、报表、打印、权限、JWT、AI/Gateway 等现有单元用例；不是全部真实业务流程 E2E                                     |
| Backend 站点事务                                  | 8 PASS               | 启停、删除、原生 Deleted Document、Gateway/adapter、幂等重放、版本变化、第二项失败整批回滚、提交后回调清空、新价格引用阻断、跨用户计划隔离 |
| Backend 真实 HTTP：生命周期及编辑                 | 4 PASS               | 固定 gpt-5.6-luna；删除自动解析→独立计划、非法确认拒绝、旧编辑入口拒绝删除、正常编辑草稿与动作/目标改绑拒绝                                |
| Backend 真实 HTTP：原有路由与 SSE                 | 2 用例最终通过       | 公司/会话参数路由；自动解析凭据复用至 SSE。公司/会话用例首次 RemoteDisconnected，独立一次复测 PASS；原失败不隐去                           |
| Web 全量组件/页面/服务测试                        | 60 suites / 404 PASS | 包括新计划确认/阻断/过期/历史重开、删除不回退编辑/Chat、原有业务页面及 SSE/模型切换回归                                                    |
| Web tsc / Biome / production build                | PASS                 | 已构建所有现有路由；public 静态脚本不因此获得运行时正确性保证                                                                              |
| AI Docker test target                             | 223 PASS             | Chat、结构化草稿、意图 Schema/Prompt、Agent、安全、治理及向量单测                                                                          |
| AI 独立容器集成                                   | PASS                 | 独立 Redis/Qdrant/合成 Provider；健康、聊天、向量 upsert/search/delete，使用 14010 避免影响现有 4010 服务                                  |
| Backend/AI Ruff、AI pre-commit、四仓 diff --check | PASS                 | 价格终止接口原有 F823 缺陷修复后 Backend 全仓 Ruff 通过                                                                                    |

事务测试只创建随机 `LIFECYCLE-TEST-*` 夹具并全部 rollback；未启停或删除用户商品。HTTP 使用现有百事可乐-2/-3，但只生成/放弃计划或草稿，归档测试会话，不执行 Item 写入。独立集成项目 `myapp-ai-lifecycle-verify` 的容器、网络及两个测试卷已删除；未清理现有 ERP/AI 数据卷，未改 4010 在线服务。

## 本轮额外发现

1. 原有 `terminate_product_price_v1` 内 `_` 局部变量遮蔽翻译函数。新增测试在修复前稳定复现错误商品和过期版本两种 UnboundLocalError；将未使用的日期变量改名后返回预期校验异常，且不保存价格。此修复独立提交。
2. Web 已有未提交 `public/scripts/loading.js` 开头为 `npmnpm/**`，会使加载脚本运行时报错。它不属于本轮 AI 改动，已向用户询问是否修复；在未收到明确答复前保留且不纳入提交。因此不能宣称当前整个脏工作区“没有任何问题”。
3. 保留既有 Jest open-handle、Browserslist 过期提示、Frappe job_name 弃用、Mock HTTPError ResourceWarning；相应成功命令退出码为 0。

## 可重跑命令

Backend 全量（容器 bench Python）：

```bash
docker exec frappe_docker-backend-1 bash -lc 'cd /home/frappe/frappe-bench && env/bin/python -m unittest discover -s apps/myapp/myapp/tests/unit -t apps/myapp -q'
docker exec -e MYAPP_LIFECYCLE_TEST_SITE=localhost -w /home/frappe/frappe-bench/sites frappe_docker-backend-1 /home/frappe/frappe-bench/env/bin/python -m unittest myapp.tests.integration.test_product_lifecycle_plans -v
```

真实 HTTP 运行入口：`test_product_lifecycle_http.LifecycleHttpTest`、`test_ai_draft_action_http.DraftActionHttpTest`。凭据读取 Backend 忽略的 `.env.http-test`，测试变量见 Backend `TESTING.zh-CN.md`。原有 AI HTTP 支持 `MYAPP_HTTP_AI_MODEL_ALIAS=gpt-5.6-luna`，在解析与 SSE 两端传同一固定模型；不会仅修改预期返回模型而漏传请求参数。

Web：在 `frontend/myapp-web` 运行 `npm run tsc && npm run biome:lint && npm test -- --runInBand --silent && npm run build`。AI：Docker test、Ruff/pre-commit，以及独立 Compose 集成栈；不得直接在现有端口启动集成栈或删除现有数据卷。

## 验收边界

在以上覆盖范围内，生命周期实现符合预期，未发现本轮 AI 改动造成其他功能回归。没有进行真实浏览器、Mobile、多进程压力或提交后外部索引恢复验收；不能用单元测试证明所有实际业务组合均无缺陷。删除仍保守阻断引用/附件/封面，不承诺任意第三方裸 SQL 写入下的全局引用完整性。上线须同步 Backend/AI intent v8/Web，并执行 migrate。
