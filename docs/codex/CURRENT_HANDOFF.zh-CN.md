# 当前交接状态

更新时间：2026-08-15 CST

本文件只记录当前短期状态、验证结果、未提交范围、风险和下一步。长期规则以 `AGENTS.md` 和 `docs/codex/DEVELOPMENT_GUIDE.zh-CN.md` 为准。

## 当前目标与结论

- 当前目标：完成 AI 多模态模型治理、图片附件、商品照片建档/完善、销售/采购订单照片生成/修改的代码审查、缺陷修复、本地迁移和真实 Provider 验收。
- 涉及 Parent、Backend `apps/myapp`、AI Orchestrator `services/myapp-ai` 和 Web `frontend/myapp-web`；Mobile 未修改。
- 当前结论：主链路已实现并通过 Backend、AI、Web 自动化门禁；本地 `localhost` 已完成备份和迁移，真实 Provider 视觉探测及三类关键图片草稿 smoke 已通过。
- 真实 smoke 只生成并丢弃 AI Draft，没有创建或修改正式 Item、Sales Order 或 Purchase Order。
- Backend、AI Orchestrator、Web 和 Parent 已分别提交并推送；Backend/AI 与 Web staging 镜像已构建并部署成功。production 未操作。

## 已实现能力

### 模型与 Runtime 治理

- 模型注册表把主要用途 `capability` 与 `supports_vision` 分开治理，并记录视觉探测时间、状态和稳定错误码。
- 可用性检查对 Chat、Function Calling 和红/蓝双图片挑战分别验证；视觉失败不会把仍可文本使用的模型整体标记为不可用。
- 图片请求只选择 `supports_vision=true` 的候选；固定纯文本模型失败关闭，不静默丢弃图片。
- 没有匹配已发布 Runtime Policy 时，system-default 也会携带显式固定模型的健康、工具和视觉元数据，避免把已验证视觉模型误判为不支持图片。

### 图片附件

- 新增私有短期 `MyApp AI Attachment`：真实解码、实际格式与声明 MIME 一致性校验、EXIF 修正、WebP 规范化、owner/有效期/SHA-256 校验、会话消息绑定和定时清理。
- 单条消息最多 4 张图；原始上传最多 20MB，传给 Orchestrator 的规范化图片最多 8MB。
- AI 证据图片最长边最多 2400 像素，只缩小、不放大小图；商品图片原有 `item-flexible-v2` 行为保持不变。
- 会话历史只返回安全元数据和私有预览 URL；base64、磁盘路径和图片正文不进入普通日志或默认 Langfuse 内容采集。

### 商品照片草稿

- 可提取名称、编码、条码、品牌、规格、包装文字、价格和图片证据。
- Backend 在当前账号权限范围内重新搜索真实商品，并区分 `unique / ambiguous / not_found`。
- 疑似重复时要求用户选择新增或完善；明确修改但未匹配时不会自动转为新增。
- 只有创建新商品且用户没有指定其他图片时，首张来源图才派生暂存封面；完善现有商品不会自动覆盖已有图片。

### 订单照片草稿

- 销售/采购图片提取订单号、往来单位、日期、商品行、数量、UOM、价格和备注；图片未出现的数据保持为空，不按合计或常识猜测。
- 图片中明确可见的行价格首次生成时按 `price_source=user` 保留，同时保存后端参考价供复核，不再被参考价静默覆盖。
- 识别为本系统订单修改时读取真实 baseline，保存 `source_order_modified`；只改备注时 `update_items_explicit=false`。
- 执行前重新检查来源订单版本；表头更新后把最新 `modified` 传给明细更新服务，阻止并发静默覆盖。

### 失败与重试

- 普通 Chat 和四类草稿均支持失败消息原位重试。
- 草稿失败时先回滚未完成写入，再标记 Run 失败、写入绑定 Run 的助手失败占位并提交；因此 `retry_run_id` 总有持久消息可绑定。
- 草稿重试恢复原问题、场景、公司、会话和附件，不重复插入用户消息，并记录 `retry_of_run_id`。

## 本地迁移与运行状态

- `localhost` 完整备份位于 `/home/frappe/frappe-bench/sites/localhost/private/backups/`：
  - `20260815_185218-localhost-database.sql.gz`
  - `20260815_185218-localhost-files.tar`
  - `20260815_185218-localhost-private-files.tar`
- `bench --site localhost migrate` 已成功执行。
- 已执行 Patch：
  - `myapp.patches.add_ai_model_multimodal_health_fields`
  - `myapp.patches.create_ai_multimodal_tables`
- `tabMyApp AI Attachment`、`supports_vision`、`last_vision_error_code` 均存在。
- `myapp.tasks.cleanup_ai_attachments` 已注册为 Hourly。
- AI Orchestrator 已重建并重启，Prompt 为 intent v4、sales/purchase v3、product v5。
- Backend、Queue、Scheduler 已重启。Backend devcontainer 主进程为 `tail -f /dev/null`；容器重启后需手工执行 `bench serve`。
- 最终健康复核：Backend `Host: localhost` 的 `/api/method/ping` 返回 `pong`；AI `/health` 返回 `status=ok`，Prompt 版本与上述版本一致。

## 真实 Provider 与多模态 smoke

本地模型注册表实测：

- `gpt-5.5`：available，tools=true，vision=true。
- `gpt-5.6-luna`：available，tools=true，vision=true。
- `erp-embedding`：available。
- 多个 opencode/kimi 别名当前返回 Provider 401/403，已标记 unavailable。

不要在文档、日志或交接中输出 Compose Service Token、LiteLLM Key 或 Provider 原始错误正文。

使用合成图片完成以下验收：

1. Attachment 生命周期：PNG 转 WebP、尺寸、SHA-256、模型 payload 和删除均正确；小图保持原尺寸，不再放大。
2. 商品照片：提取 `DEMO COFFEE BEANS`、`MM-SMOKE-001`、条码 `6901234567892`、规格 `500 g bag`，并把来源图作为新商品封面候选；草稿 ready 后已 discarded。
3. 销售订单照片：客户、仓库、SKU、数量、UOM 和图片价格正确；价格 `15.5`、`3200` 均保存为 `price_source=user`；草稿 ready 后已 discarded。
4. 修改现有订单照片：来源 `SAL-ORD-2026-02470`，`operation=update`，保存 baseline 和 `source_order_modified`；只改备注时不替换明细，构造过期版本后正确拒绝执行；草稿已 discarded。

关键 smoke 会话为 `AI-CONV-58cdc73eff17466b8097ddd718355df5`。相关 Run、discarded Draft 和 bound Attachment 属于本地审计数据；Attachment 会按 24 小时保留期清理，不要绕过生命周期直接删除审计记录。

## 自动化验证

### Backend

- Backend 全量 unit discovery：`772 tests` 通过。
- 最终定向复跑：AI Attachment、图片处理和 AI Service 共 `109 tests` 通过。
- 定向测试覆盖实际格式/MIME 一致性、小图不放大、草稿失败占位、图片价格、商品/订单草稿、订单修改和乐观并发保护。
- 测试使用 `frappe_docker-backend-1` 内 `/home/frappe/frappe-bench/env/bin/python`，没有使用宿主机 Python 冒充 Frappe 运行时。

### AI Orchestrator

- `uv run ruff check .` 通过。
- `uv run pre-commit run --all-files` 全部通过。
- `uv run pytest`：`162 tests` 通过。
- 最终定向复跑 Policy、Main、Governance、LiteLLM Client、Runtime Guard：`60 tests` 通过，只有既有 Starlette/httpx 弃用警告。
- `docker build --target test -t myapp-ai:test .` 通过。
- `docker run --rm myapp-ai:test`：容器内 `162 tests` 通过。
- `docker build --target runtime -t myapp-ai:runtime .` 通过。

### Web

- 本轮最后四项 Backend/AI 修复未修改 Web。
- 此前同一功能候选已通过 `npm run tsc`、`npm run biome:lint` 和 `44 suites / 294 tests`。
- Jest 仍有既有 open handle 提示，但退出码为 0，无失败用例。

### 最终差异检查

- Parent `git diff --check`：通过。
- Backend `git -C apps/myapp diff --check`：通过。
- AI `git -C services/myapp-ai diff --check`：通过。
- Web `git -C frontend/myapp-web diff --check`：通过。

## Staging 发布结果

### 提交与镜像

- Parent staging release：`d072d538 feat: release multimodal AI workflows`。
- Backend：`0001e0c feat: add multimodal AI product and order workflows`。
- AI Orchestrator：`0f15f02 feat: add governed multimodal AI requests`。
- Web：`4626080 feat: add multimodal AI workbench flows`。
- Backend/Worker/Frontend 镜像：`staging-20260815-d072d538`，digest `sha256:2cf9ccc013be39a6ee2f67249fb4d62c4c32686597260a55fb0b36ea944b1aed`。
- AI 镜像：`staging-20260815-d072d538`，digest `sha256:35100f3f44acf752436325138351f77e7c065c2197cd6638ba35eaf8483316f8`，Runtime revision 固定为 `0f15f02`。
- Web 镜像：`staging-20260815-4626080`，digest `sha256:a3a946c464cea0a803bdae906a148674b2b93320a53252047e9ad1896261195d`。

### GitHub Actions

| 范围                       | Run                                                                             | 结果 |
| -------------------------- | ------------------------------------------------------------------------------- | ---- |
| Backend push CI            | [31882343611](https://github.com/rgc318/myapp/actions/runs/31882343611)         | 成功 |
| AI push CI                 | [31882350624](https://github.com/rgc318/myapp-ai/actions/runs/31882350624)      | 成功 |
| AI CodeQL                  | [31882350656](https://github.com/rgc318/myapp-ai/actions/runs/31882350656)      | 成功 |
| Web push CI                | [31882360694](https://github.com/rgc318/myapp-web/actions/runs/31882360694)     | 成功 |
| Web coverage CI            | [31882360697](https://github.com/rgc318/myapp-web/actions/runs/31882360697)     | 成功 |
| Backend + AI build         | [31882464128](https://github.com/rgc318/frappe_docker/actions/runs/31882464128) | 成功 |
| Backend + AI deploy/health | [31882650200](https://github.com/rgc318/frappe_docker/actions/runs/31882650200) | 成功 |
| Web build                  | [31882466394](https://github.com/rgc318/myapp-web/actions/runs/31882466394)     | 成功 |
| Web deploy                 | [31882816673](https://github.com/rgc318/myapp-web/actions/runs/31882816673)     | 成功 |

Parent release 首次 Lint Run `31882414571` 只发现本交接文件的 Prettier 格式漂移；代码、镜像构建和部署均未失败。当前交接更新已按同一 Prettier 版本格式化，后续 handoff-only 提交用于恢复分支门禁。

### 部署后事实

- Workflow 在 `staging.example.com` 成功执行 `bench migrate`。
- Backend、Frontend、Queue、Scheduler、Websocket 均运行 `staging-20260815-d072d538`。
- AI Orchestrator 运行同标签并为 `healthy`；AI `/health` 返回 `status=ok`，LiteLLM、Runtime Governance 和 Vector Search 已配置。
- Backend 到 AI Orchestrator 内部认证通过。
- Agent Runtime Policy：`1 policies, 7 tool-ready models`。
- staging 首页和 Ping API 均返回 HTTP 200。
- Web 部署对 `/healthz`、`/user/login` 和 `/api/method/ping` 的组合检查通过。
- 仓库未配置登录态 HTTP 回归凭据，因此 `run_http_regression=false`；没有把该项冒充为已执行。
- production 未部署。

## 仓库状态与未提交范围

| 仓库            | 提交 / 发布基线                        | 当前状态                                                        |
| --------------- | -------------------------------------- | --------------------------------------------------------------- |
| Parent          | `develop` / staging release `d072d538` | 已推送并部署；本交接作为后续 docs-only 提交更新，不改变运行镜像 |
| Backend         | `develop` / `0001e0c`                  | 已推送，CI 成功，已进入 staging 镜像                            |
| AI Orchestrator | `develop` / `0f15f02`                  | 已推送，CI/CodeQL 成功，已进入 staging 镜像                     |
| Web             | `main` / `4626080`                     | 已推送，CI/coverage 成功，已部署 staging                        |
| Mobile          | 未核对                                 | 本轮未修改，保留用户既有状态                                    |

Parent 的 `AGENTS.md` 当前显示为修改状态，属于用户提供的项目指令更新，本轮不得覆盖或擅自提交。

## 剩余边界与风险

1. 尚未在 staging 使用真实浏览器、平板或摄像头验证 20MB 上传、4 图交互、私有预览 URL、刷新恢复和网络中断后的带图重试。
2. 尚未在 staging 创建或修改正式业务对象；本地 smoke 刻意停在草稿并 discard。仍应使用可回滚测试数据验证已提交订单、下游单据阻断和权限组合。
3. staging 仓库未配置登录态 HTTP 回归凭据，本次只完成公开 HTTP、服务认证、迁移和容器健康检查。
4. Provider 健康是带时间的快照。当前 401/403 alias 不应进入自动或固定选择；Provider 配置恢复后需重新探测。
5. 本次标准 Deploy Workflow 没有单独执行发布前备份。迁移已成功；后续涉及 Schema 的 staging/production 发布应先显式运行备份流程。
6. 本地 Backend devcontainer 重启后不会自动启动 `bench serve`，健康复核时需先确认进程和 HTTP Ping。

## 下一步

1. 使用可回滚数据完成 staging 浏览器上传、商品新增/完善、销售/采购创建/修改和并发冲突验收。
2. 如需自动登录态回归，为 Parent 仓库配置受控的 staging HTTP 凭据后重新运行健康门禁。
3. production 仅在业务验收完成且用户再次明确授权后部署。
