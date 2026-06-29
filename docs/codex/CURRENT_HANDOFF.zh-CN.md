# 当前交接状态

更新时间：2026-06-29

本文件用于跨新会话交接当前项目状态。长期规则不要写在这里，应写入 `AGENTS.md` 或 `docs/codex/DEVELOPMENT_GUIDE.zh-CN.md`。

## 当前目标

- 建立 Codex 新会话启动所需的项目规则、文档索引和交接机制。
- 已新增根级 `AGENTS.md` 和 `docs/codex/` 下的 Codex 专用文档。

## 仓库状态

- 父仓库：有新增 `AGENTS.md` 和 `docs/codex/` 文档；仍显示 `apps/myapp` 子模块指针变更；`.codex` 是既有未跟踪目录，不处理。
- 后端 `apps/myapp`：最后检查时工作区干净，但父仓库看到子模块指针变更。
- Web `frontend/myapp-web`：仍有商品模块相关未提交改动，包括文档、商品详情条码表、商品列表/导入/布局优化。

## 已完成改动

- 新增 `AGENTS.md`，记录仓库边界、后端 devcontainer 规则、Web Ant Design Pro 优先规范、企业级设计准则、验证命令和交接规则。
- 新增 `docs/codex/DEVELOPMENT_GUIDE.zh-CN.md`，记录 Codex 开发规范与架构准则。
- 新增 `docs/codex/KNOWN_ISSUES.zh-CN.md`，记录已知问题和处理方式。
- 新增 `docs/codex/HANDOFF_TEMPLATE.zh-CN.md`，提供交接文档模板。
- 新增当前文件 `docs/codex/CURRENT_HANDOFF.zh-CN.md`，作为新会话交接入口。

## 已验证

文档空白检查：

```bash
git diff --check -- AGENTS.md docs/codex/DEVELOPMENT_GUIDE.zh-CN.md docs/codex/KNOWN_ISSUES.zh-CN.md docs/codex/HANDOFF_TEMPLATE.zh-CN.md
```

结果：通过。

Web 商品模块此前已验证：

```bash
cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- --runInBand
git diff --check
```

结果：TypeScript、Biome、Jest、空白检查均通过。

## 未完成事项

- 尚未提交 `AGENTS.md` 和 `docs/codex/` 文档。
- 尚未提交 Web 商品模块改动。
- 父仓库中的 `apps/myapp` 子模块指针变更是否提交，需要按用户当前提交计划决定。

## 下一步建议

1. 检查 `AGENTS.md` 和 `docs/codex/` 内容是否符合团队习惯。
2. 若确认规则稳定，提交父仓库文档改动。
3. 再处理 Web 商品模块未提交改动，必要时先做浏览器预览确认列表布局。
