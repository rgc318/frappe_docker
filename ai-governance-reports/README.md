# AI governance release artifacts

This directory is mounted read-only into the AI Orchestrator at
`/var/lib/myapp-ai/governance-reports`.

Only redacted, immutable release-gate reports belong here. Do not store model output,
credentials, customer data, ERP records, or other sensitive source content.

Expected local filenames:

- `live-gate.json`: a passing `myapp-ai-eval-report-v1` live full-gate report whose attempts use the policy primary model alias.
- `embedding-gate.json`: a passing full-gate report for the configured Embedding alias, collection, semantic quality, permission, delete and recovery checks.
- `product-retrieval-v1-current.json`: the latest redacted 30-case Chinese retrieval diagnostic. A failed report is retained as Provider-blocking evidence but is never accepted as `embedding-gate.json`.

The JSON artifacts are intentionally ignored by Git. Copy them from a controlled evaluation
run or CI artifact store; do not edit them manually. Policy validation fails closed when the
configured report is missing, partial, failed, malformed or for a different model.
