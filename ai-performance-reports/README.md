# AI performance evidence

This directory stores redacted, reproducible AI concurrency baselines.

- Reports must use synthetic prompts and master data only.
- Never store service tokens, provider keys, raw model output, customer data, ERP records,
  hostnames that identify a production environment, or unredacted trace payloads.
- A synthetic-provider report proves the Orchestrator connection-pool, semaphore, SSE and
  Qdrant paths. It does not prove external model-provider capacity.
- A live-provider report must be explicitly labelled and should use the minimum paid sample
  count needed to calibrate end-to-end SLOs.

Run the load generator from the project network with
`services/myapp-ai/scripts/ai_load_test.py`. Candidate Qdrant collections use the
`myapp-products-loadtest-*` prefix and are deleted after the run.
