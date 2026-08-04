# 交接文档模板

交接文档用于记录当前短期状态，不应替代 `AGENTS.md` 或长期设计文档。建议按任务或阶段复制本模板，放到 `docs/` 或相关仓库内。

## 当前目标

- 本轮正在解决什么问题：
- 业务模块：
- 涉及仓库：

## 仓库状态

- 父仓库状态：
- `apps/myapp` 状态：
- `services/myapp-ai` 状态：
- `frontend/myapp-web` 状态：
- `frontend/myapp-mobile` 状态：
- 是否存在不应提交的本地文件：

## 已完成改动

- 后端：
- Web：
- Mobile：
- 文档：

## 已验证

Web：

```bash
cd /home/rgc318/python-project/frappe_docker/frontend/myapp-web
npm run tsc
npm run biome:lint
npm test -- --runInBand
```

后端：

```bash
docker exec frappe_docker-backend-1 bash -lc '
  cd /home/frappe/frappe-bench &&
  env/bin/python -m unittest <test.module>
'
```

AI Orchestrator：

```bash
cd /home/rgc318/python-project/frappe_docker/services/myapp-ai
uv run ruff check .
uv run pre-commit run --all-files
docker build --target test -t myapp-ai:test .
docker run --rm myapp-ai:test
```

空白检查：

```bash
git diff --check
git -C apps/myapp diff --check
git -C services/myapp-ai diff --check
git -C frontend/myapp-web diff --check
```

## 未完成事项

- 功能缺口：
- 测试缺口：
- 文档缺口：
- 需要用户确认的问题：

## 当前风险

- 数据兼容风险：
- 权限或安全风险：
- 性能风险：
- 发布或迁移风险：

## 下一步建议

1.
2.
3.

## 最新提交

后端 `apps/myapp`：

- `<hash> <message>`

AI Orchestrator `services/myapp-ai`：

- `<hash> <message>`

Web `frontend/myapp-web`：

- `<hash> <message>`

父仓库：

- `<hash> <message>`
