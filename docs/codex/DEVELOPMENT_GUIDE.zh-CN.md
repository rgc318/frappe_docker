# Codex 开发规范与架构准则

本文档记录 Codex 在本项目中执行开发任务时应遵循的长期规则。短期进度、最新提交和下一步计划不要放在这里，应放到交接文档或任务记录中。

## 1. 仓库与职责边界

- 父仓库 `/home/rgc318/python-project/frappe_docker` 主要负责 Frappe Docker 外层编排、devcontainer、部署和子模块指针。
- 后端主要开发仓库是 `apps/myapp`。
- Web 前端主要开发仓库是 `frontend/myapp-web`。
- Mobile 前端主要开发仓库是 `frontend/myapp-mobile`。
- `apps/myapp` 是父仓库子模块。后端提交完成后，如需完整提交链路，需要在父仓库提交子模块指针。
- `frontend/myapp-web` 不归父仓库跟踪，Web 改动只在 Web 仓库提交。
- 父仓库 `.codex` 是本地未跟踪目录，不要提交。

开发前先确认当前任务所属仓库，不要把后端、Web、父仓库的提交混在一起。

## 2. 后端开发规范

后端以 Frappe / ERPNext devcontainer 或 Docker 运行环境为准。`apps/myapp` 通过 bind mount 进入容器，容器内 bench 路径为：

```text
/home/frappe/frappe-bench
```

服务层、单元测试和任何需要导入 `frappe` 的测试必须使用 bench 虚拟环境 Python：

```text
/home/frappe/frappe-bench/env/bin/python
```

推荐命令形态：

```bash
docker exec frappe_docker-backend-1 bash -lc '
  cd /home/frappe/frappe-bench &&
  env/bin/python -m unittest apps.myapp.myapp.tests.unit.test_wholesale_service
'
```

不要在宿主机直接用 `python3 -m unittest` 跑需要导入 Frappe 的服务层测试。宿主机通常没有完整 Frappe bench 上下文，容易出现误导性失败。

接口和服务设计原则：

- API 契约以 `apps/myapp/API_GATEWAY.zh-CN.md` 为事实来源。
- 认证和 JWT 逻辑以 `apps/myapp/JWT_AUTH.zh-CN.md` 为事实来源。
- 测试命令、HTTP 测试和 devcontainer 细节以 `apps/myapp/TESTING.zh-CN.md` 为事实来源。
- 新增交易型写接口时优先考虑幂等 key、重复提交、部分成功、下游单据约束和回滚路径。
- 新增主数据接口时优先考虑引用保护、启停状态、批量维护、导入导出、审计和字段治理。
- 不要直接绕过 ERPNext/Frappe 的正式单据和库存逻辑去改核心账务或库存字段，除非有明确设计和测试覆盖。

## 3. Web 前端开发规范

Web 端基于 Ant Design Pro。新增或优化页面时，优先使用官方 Ant Design Pro 与 ProComponents 的结构和组件。

优先使用：

- `ProTable`：列表、筛选、列状态、批量操作、导入预览表格
- `ProCard` / `Card`：详情区块、统计区块、工作台区块
- `Modal` / `Drawer`：创建、编辑、批量操作、确认流程
- `Form` / `StepsForm`：复杂表单、分步表单
- `Upload`：文件导入、图片上传
- `Descriptions` / `Tabs` / `StatisticCard`：详情、分组信息、指标展示

可以使用自定义模板或第三方组件，但需要满足至少一个条件：

- 官方组件无法满足明确业务需求。
- 自定义方案能显著降低复杂度或提升可维护性。
- 第三方方案在功能、稳定性或用户体验上明显更适合当前任务。

页面设计取向：

- 桌面端管理系统应保持信息密度、可扫描性和批量操作效率。
- 不要机械复制移动端底部弹层、单列卡片和逐项操作流程。
- 商品、销售、采购、库存等业务页面应围绕筛选、表格、详情、批量动作和异常提示组织。
- 表格字段多时，优先使用 ProTable 的 `width`、`ellipsis`、`fixed`、`scroll.x` 和 `columnsState`，不要让字段互相挤压。
- 低频字段可以默认隐藏，但应通过列设置允许用户打开。

前端分层规则：

- 页面组件调用 `src/services/myapp/*` 下的领域 service。
- 页面组件不直接解析 Frappe 外层响应、myapp gateway envelope 或后端 snake_case 字段。
- `api-client.ts` 负责响应包络和错误处理。
- `sales.ts`、`purchase.ts`、`master-data.ts`、`reports.ts` 等领域 service 返回页面友好的 camelCase 对象。
- 使用 `@umijs/max` 的 `useRequest` 调用领域 service 时，遵守 `REQUEST_RESULT_CONTRACT.zh-CN.md`，需要时设置 `formatResult: (result) => result`。

## 4. 企业级功能设计检查

做功能设计和实现时，默认从企业级系统角度审视，不只满足页面能点通。

主数据模块重点检查：

- 批量启停、批量修改、导入、导出
- 多编码、多条码、多单位、多价格
- 引用保护和删除限制
- 资料质量检查
- 生命周期状态：新品、启用、停用、淘汰
- 审批、审计日志、变更历史
- 权限、可见范围、数据隔离

交易模块重点检查：

- 部分发货 / 收货
- 部分开票
- 部分收付款
- 退货、退款、核销
- 下游单据回退与取消
- 幂等与重复提交保护
- 业务状态聚合是否与 ERPNext 真实单据一致

报表和工作台重点检查：

- 指标口径是否清晰
- 过滤条件是否可复现
- 明细能否追溯到业务单据
- 大数据量是否需要分页、异步导出或后端聚合

## 5. 验证与提交规范

Web 常用验证：

```bash
cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- --runInBand
```

后端服务层测试示例：

```bash
docker exec frappe_docker-backend-1 bash -lc '
  cd /home/frappe/frappe-bench &&
  env/bin/python -m unittest \
    apps.myapp.myapp.tests.unit.test_wholesale_service \
    apps.myapp.myapp.tests.unit.test_gateway_wrappers \
    apps.myapp.myapp.tests.unit.test_link_options_service
'
```

提交前检查：

```bash
git diff --check
git -C apps/myapp diff --check
git -C frontend/myapp-web diff --check
```

提交规则：

- 后端提交在 `apps/myapp`。
- 后端子模块指针提交在父仓库。
- Web 提交在 `frontend/myapp-web`。
- 不要提交父仓库 `.codex`。
- 不要把未验证的大范围重构和业务功能混在一个提交里。
