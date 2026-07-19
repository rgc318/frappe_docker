# Codex Project Instructions

This file is the stable entry point for Codex sessions in this repository. Keep it concise and durable. Put detailed or frequently changing notes in the indexed documents below.

## Project Structure

- Parent repository: `/home/rgc318/python-project/frappe_docker`
- Backend app repository: `apps/myapp`
- AI orchestration repository: `services/myapp-ai`
- Web frontend repository: `frontend/myapp-web`
- Mobile frontend repository: `frontend/myapp-mobile`

## Repository Boundaries

- `apps/myapp` is the main backend code repository and is tracked by the parent repository as a git submodule.
- Backend code changes should normally be made and committed inside `apps/myapp`.
- After committing backend changes in `apps/myapp`, update and commit the submodule pointer in the parent repository when the user asks for a complete backend submission.
- `services/myapp-ai` is the independent AI Orchestrator repository and is tracked by the parent repository as a git submodule. AI source, dependency lock, standalone Compose, Redis/Qdrant integration tests, service documentation, Dockerfile and repository CI/security workflows are committed there. Full ERP Compose, Dev Container, bundled Langfuse, staging/production and cross-service Secret orchestration remain in the parent repository.
- After committing AI changes in `services/myapp-ai`, push that repository first, then update and commit its submodule pointer in the parent repository.
- `frontend/myapp-web` is not tracked by the parent repository. Web commits must be made only inside `frontend/myapp-web`.
- The parent `.codex` directory is existing local untracked state. Do not commit it.
- Do not modify `apps/frappe` or `apps/erpnext` unless the user explicitly asks for framework or ERPNext source changes.

## Required Context Index

Read these documents when the task touches the matching area:

### Codex and Handoff

- Codex development rules and architecture standards: `docs/codex/DEVELOPMENT_GUIDE.zh-CN.md`
- Recurring issues and fixes: `docs/codex/KNOWN_ISSUES.zh-CN.md`
- Current project handoff: `docs/codex/CURRENT_HANDOFF.zh-CN.md`
- Handoff/status template: `docs/codex/HANDOFF_TEMPLATE.zh-CN.md`

### Parent Frappe Docker Repository

- Parent repository overview for coding agents: `CLAUDE.md`
- Parent repository README: `README.md`
- Frappe Docker development guide: `docs/05-development/01-development.md`
- Local services connection guide: `docs/05-development/03-local-services-connection.md`
- AI business workbench design: `docs/05-development/04-ai-business-workbench.zh-CN.md`
- Staging deployment notes: `STAGING_DEPLOYMENT.zh-CN.md`

### Backend: `apps/myapp`

- Backend app overview: `apps/myapp/README.zh-CN.md`
- Backend testing rules: `apps/myapp/TESTING.zh-CN.md`
- Backend API source of truth: `apps/myapp/API_GATEWAY.zh-CN.md`
- Backend auth design: `apps/myapp/JWT_AUTH.zh-CN.md`

### Backend domain designs

- Wholesale/business design baseline: `apps/myapp/WHOLESALE_TECH_DESIGN.zh-CN.md`
- Purchase flow design: `apps/myapp/PURCHASE_TECH_DESIGN.zh-CN.md`
- Reports design: `apps/myapp/REPORTS_TECH_DESIGN.zh-CN.md`
- Printing design: `apps/myapp/PRINTING_TECH_DESIGN.zh-CN.md`
- Barcode scanning design: `apps/myapp/BARCODE_SCANNING_TECH_DESIGN.zh-CN.md`
- Sales status aggregation design: `apps/myapp/SALES_STATUS_AGGREGATION.zh-CN.md`
- UOM standard catalog: `apps/myapp/UOM_STANDARD_CATALOG.zh-CN.md`

### AI Orchestrator: `services/myapp-ai`

- AI service overview and quick start: `services/myapp-ai/README.zh-CN.md`
- AI complete documentation index: `services/myapp-ai/docs/README.zh-CN.md`
- AI standalone deployment: `services/myapp-ai/docs/DEPLOYMENT.zh-CN.md`
- AI development and testing: `services/myapp-ai/docs/DEVELOPMENT.zh-CN.md`
- AI configuration and API contracts: `services/myapp-ai/docs/CONFIGURATION.zh-CN.md`, `services/myapp-ai/docs/API_CONTRACT.zh-CN.md`

### Web Frontend: `frontend/myapp-web`

- Web development rules: `frontend/myapp-web/WEB_DEVELOPMENT.zh-CN.md`
- Web development plan: `frontend/myapp-web/DEVELOPMENT_PLAN.zh-CN.md`
- AI Web frontend design: `frontend/myapp-web/AI_WEB_FRONTEND_DESIGN.zh-CN.md`
- Web request result contract: `frontend/myapp-web/REQUEST_RESULT_CONTRACT.zh-CN.md`
- Web project README: `frontend/myapp-web/README.zh-CN.md`
- Web template/development notes: `frontend/myapp-web/DEVELOPMENT.md`

### Mobile Frontend: `frontend/myapp-mobile`

- Mobile project README: `frontend/myapp-mobile/README.md`
- Mobile development notes: `frontend/myapp-mobile/DEVELOPMENT.md`
- Mobile deployment notes: `frontend/myapp-mobile/DEPLOYMENT.zh-CN.md`
- Mobile Web deployment notes: `frontend/myapp-mobile/WEB_DEPLOYMENT.zh-CN.md`
- Mobile Web preview deployment notes: `frontend/myapp-mobile/WEB_PREVIEW_DEPLOYMENT.zh-CN.md`

## Backend Development

- The backend runs in the Frappe/ERPNext devcontainer or Docker environment.
- Do not treat host Python as the backend runtime for Frappe service tests.
- Service/unit tests that import `frappe` must run in the backend container with bench virtualenv Python:

```bash
docker exec frappe_docker-backend-1 bash -lc '
  cd /home/frappe/frappe-bench &&
  env/bin/python -m unittest apps.myapp.myapp.tests.unit.test_wholesale_service
'
```

- Bench path: `/home/frappe/frappe-bench`
- Bench Python: `/home/frappe/frappe-bench/env/bin/python`
- Backend container: `frappe_docker-backend-1`
- Local site directory currently includes `localhost`.

## Web Frontend Development

- Web work happens in `frontend/myapp-web`.
- The Web app is based on Ant Design Pro and ProComponents.
- Prefer official Ant Design Pro structure and Ant Design/ProComponents components such as `ProTable`, `ProCard`, `Modal`, `Form`, `Upload`, `Descriptions`, `Tabs`, `StatisticCard`, and official dashboard/table/detail patterns.
- Use custom components, custom layout, or third-party templates only when the official pattern cannot satisfy a clear business or UX requirement, or when the alternative is demonstrably better for this task.
- Keep desktop workflows dense, scannable, and operational. Do not copy mobile interaction patterns mechanically.

## Architecture Standards

- Think from an enterprise system perspective: correctness, auditability, permission boundaries, idempotency, data consistency, lifecycle state, and operational recovery matter more than fast local-only shortcuts.
- Preserve domain boundaries. Page components should call domain services, not parse raw backend envelopes or snake_case fields directly.
- Prefer extending existing service/domain layers before adding page-local business logic.
- For master data features, consider bulk operations, import/export, governance, lifecycle, audit trail, and validation quality checks.
- For transaction features, consider partial fulfillment, partial billing, partial payment, returns, refunds, rollback/cancel paths, and idempotency.
- Unit display, unit selection, unit conversion, stock quantity conversion, line amount calculation, and any quantity-with-unit presentation are shared domain concerns. Do not hand-roll UOM labels, conversion math, stock-unit estimates, or amount formulas in page components or one-off services.
- Backend code that handles product, order, inventory, return, invoice, receipt, delivery, or print data must use `myapp.utils.uom` and `myapp.utils.uom_display` for UOM conversion and display mapping.
- Frontend code that displays or edits UOM values, quantity labels, stock-unit estimates, or transaction line amounts must use shared helpers/components such as `src/utils/display-uom.ts`, `src/utils/uom-conversion.ts`, order editor utilities, and `UomSelect`.
- New product, order, inventory, return, printing, or reporting work must verify that `uom`, `uom_display`, `all_uoms`, and `conversion_factor` are carried through the API and UI where relevant.

## Verification

For Web changes, run from `frontend/myapp-web` when relevant:

```bash
npm run tsc
npm run biome:lint
npm test -- --runInBand
```

For backend unit/service changes, run targeted tests in the backend container with bench Python. For HTTP gateway behavior, follow `apps/myapp/TESTING.zh-CN.md`.

For AI Orchestrator changes, run from `services/myapp-ai` when relevant:

```bash
uv sync --extra test --extra dev --frozen
uv run ruff check .
uv run pre-commit run --all-files
docker build --target test -t myapp-ai:test .
docker run --rm myapp-ai:test
docker build --target runtime -t myapp-ai:runtime .
# When Compose/runtime integration changes:
make integration
```

Before finishing code changes, run whitespace checks where relevant:

```bash
git diff --check
git -C frontend/myapp-web diff --check
git -C apps/myapp diff --check
git -C services/myapp-ai diff --check
```

## Working Rules

- Check `git status` in the relevant repository before editing or committing.
- Do not revert user changes or unrelated dirty work.
- Keep commits scoped to the repository that owns the change.
- Update documentation when behavior, contracts, verification commands, or operational assumptions change.

## Handoff Rules

- Use `docs/codex/CURRENT_HANDOFF.zh-CN.md` as the current cross-repository handoff file.
- Update the handoff before opening a new session, after substantial multi-step work, or before pausing with uncommitted changes.
- The handoff should record current status, repository dirtiness, latest verified commands, uncommitted work, risks, and concrete next steps.
- Do not put long-term rules in the handoff. Long-term rules belong in `AGENTS.md` or `docs/codex/DEVELOPMENT_GUIDE.zh-CN.md`.
- Do not put quickly changing progress, latest commit hashes, or temporary blockers in `AGENTS.md`. Put them in the handoff.
