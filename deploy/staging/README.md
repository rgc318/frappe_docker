# Staging Deployment Files

This directory contains the minimum files needed to run a production-like staging environment for `myapp`.

Files:

- `staging.env.example`
  - copy to `staging.env` and fill real values
- `apps.staging.json.example`
  - copy to `apps.staging.json` and define the apps baked into the image
- `compose.staging.yaml`
  - staging-only compose base that does not bind-mount `apps/myapp`
  - includes a readiness-routed AI Orchestrator replica set, Qdrant, its one-shot volume initializer, and the dedicated `ai-vector` worker
- `haproxy.ai.cfg`
  - routes Backend/worker AI traffic across stable/candidate replica pools, removes instances that fail `/readyz`, and fails unknown release affinity closed
- `ensure-ai-router-state.sh` / `set-ai-rollout.py`
  - persist rollout and release-affinity maps, then update HAProxy through atomic Runtime API transactions
- `run-ai-progressive-rollout.sh`
  - validates a candidate and advances it through bounded traffic, canary, distribution, and SLO stages
- `finalize-ai-progressive-rollout.sh` / `complete-ai-progressive-rollout.sh`
  - enter the old-release drain window, then retire it and converge the candidate into the stable pool
- `abort-ai-progressive-rollout.sh`
  - restores fresh traffic to the previous stable release while retaining candidate affinity until its reverse drain completes
- `compose.mariadb.staging.yaml`
  - staging-only MariaDB override that does not publish database ports to the host
- `build-staging-image.sh`
  - builds both the custom image containing `myapp` and the AI Orchestrator image
  - accepts `BUILD_HTTP_PROXY`, `BUILD_HTTPS_PROXY`, and `BUILD_NO_PROXY` as explicit build-only proxy overrides
  - accepts `BUILD_NETWORK` (default: `default`); use `host` on Linux when a build must reach a proxy bound to host loopback
  - the ERP image retries `bench init` up to three times after transient Git/Python dependency download failures
  - BuildKit caches uv and Yarn downloads across local rebuilds; build logs stay concise enough to preserve the real failure reason
  - asset compilation runs only after the build-time site config is cleared, so image creation never depends on a runtime Redis service
  - Frappe v16 asset compilation uses a loopback-only, non-persistent Redis process inside the builder stage; it is stopped before the layer completes and is absent from the runtime image
  - one cached uv resolution reconciles Frappe, ERPNext, and myapp together after `bench init`; imports plus `pip check` remain the release gate
- `validate-staging-env.sh`
  - fails closed on missing AI images, provider configuration, short service tokens, placeholders, incomplete vector settings, or partial Langfuse credentials
- `start-staging.sh`
  - starts the staging stack
- `deploy-staging.sh`
  - pulls the latest image, restarts the stack, and optionally runs `bench migrate`
- `init-staging-server.sh`
  - prepares the server directories and creates `staging.env` from the example
- `init-site.sh`
  - creates the first staging site, installs apps, runs migrate, and optionally sets the default site
- `rollback-staging.sh`
  - verifies an older tag against its previously qualified Backend/AI release-pair manifest, switches both tags, restarts the stack, and optionally runs the health check
- `run-ai-canary.py` / `run-ai-canary.sh`
  - run bounded, non-executing readiness, intent, chat, and structured-draft scenarios; write a machine-readable `passed / partial / failed` report
- `record-staging-release-pair.sh` / `verify-staging-release-pair.sh`
  - bind a passed canary to exact Backend/AI revisions, image IDs/digests, and one release ID; reject tag drift before rollback
- `verify-ai-replica-set.py` / `verify-ai-replica-set.sh`
  - fail closed unless every expected replica is healthy and all images, release IDs, revisions, protocols, and manifest hashes agree with the router
- `evaluate-ai-slo.py` / `run-ai-slo-gate.sh`
  - combine canary and optional load reports into a machine-readable SLO/alert state; never report a small sample as a pass
- `backup-staging.sh`
  - runs `bench backup --with-files`, packages the generated site backups, and copies the archive to the host
- `restore-staging.sh`
  - restores a site from backup files already uploaded to the staging server, with a safety backup before overwrite
- `check-staging.sh`
  - verifies the compose services and basic HTTP endpoints after deployment
- `stop-staging.sh`
  - stops the staging stack
- `INIT_SITE.zh-CN.md`
  - first-time site creation and app installation guide
- `DATA_MIGRATION.zh-CN.md`
  - local-to-staging data migration and restore guide

Recommended long-term path:

- do not build the staging image on the staging server
- use GitHub Actions to build and push the image to GHCR
- let the staging server only:
  - `docker pull`
  - `./deploy/staging/start-staging.sh`

Local build proxy examples:

```bash
# Ignore inherited host proxy variables for this build.
BUILD_HTTP_PROXY= BUILD_HTTPS_PROXY= \
  ./deploy/staging/build-staging-image.sh

# Linux only: let BuildKit reach a proxy listening on host 127.0.0.1.
BUILD_NETWORK=host \
BUILD_HTTP_PROXY=http://127.0.0.1:10808 \
BUILD_HTTPS_PROXY=http://127.0.0.1:10808 \
  ./deploy/staging/build-staging-image.sh
```

Do not put proxy credentials in tracked files or command logs. CI should normally build without a workstation proxy.

Workflow:

- `/home/rgc318/python-project/frappe_docker/.github/workflows/build_myapp_staging_image.yml`
- `/home/rgc318/python-project/frappe_docker/.github/workflows/deploy_staging.yml`
- `/home/rgc318/python-project/frappe_docker/.github/workflows/init_staging_site.yml`

Suggested image reference in `staging.env`:

```bash
CUSTOM_IMAGE=ghcr.io/<github-owner>/myapp-erpnext
CUSTOM_TAG=staging-latest
MYAPP_AI_IMAGE=ghcr.io/<github-owner>/myapp-ai
MYAPP_AI_TAG=staging-latest
PULL_POLICY=always
STAGING_REQUIRE_PAIRED_RELEASE=1
```

The build workflow publishes the ERPNext and AI Orchestrator images with the same release tag. It resolves the exact Backend revision before the build and verifies the cloned source still matches it, so a moving branch cannot silently produce mislabeled code. Deploy and rollback update both `CUSTOM_TAG` and `MYAPP_AI_TAG`; `check-staging.sh` verifies the Orchestrator health response, authenticated Backend-to-Orchestrator communication, runtime compatibility, and an effective positive-rollout staging Runtime Policy with tool-ready and vision-ready models.

Before starting staging, configure these AI values in the ignored `deploy/staging/staging.env`:

- LiteLLM base URL and API key
- a random internal service token of at least 32 characters
- Frappe site host and AI environment
- Embedding/Qdrant alias settings; keep vector search disabled until smoke tests pass
- optional external Langfuse host/public/secret key; configure all three together or leave all three empty
- `MYAPP_AI_ORCHESTRATOR_REPLICAS=2` for a two-instance staging pool; Backend and workers should keep `MYAPP_AI_ORCHESTRATOR_URL=http://ai-router:4010`

The staging Backend and workers receive only Gateway-safe values. LiteLLM and Langfuse provider credentials are injected only into `ai-orchestrator`. The bundled local Langfuse Compose stack is not used for staging; connect staging to a separately governed Langfuse deployment when observability is required.

The full development/staging/production AI deployment and secret-boundary contract is documented in `docs/codex/AI_DEPLOYMENT_ENVIRONMENTS.zh-CN.md`.

For release verification, prefer a unique `CUSTOM_TAG` such as `staging-20260526-bff502e`.
The staging compose file intentionally persists only `sites`; the Python virtualenv comes
from the image and is not mounted as a long-lived Docker volume.
Frappe and ERPNext are pinned to release tags for staging builds. Do not use the floating
`version-16` branch for staging release verification.

Mode switch:

- `STAGING_MODE=internal`
  - use `compose.noproxy.yaml`
  - recommended for first-time LAN testing
- `STAGING_MODE=https`
  - use `compose.https.yaml`
  - switch to this after the domain and certificate path are ready

Required GitHub secrets for SSH deploy:

- `STAGING_SSH_HOST`
- `STAGING_SSH_PORT`
- `STAGING_SSH_USER`
- `STAGING_SSH_PRIVATE_KEY`
- `GHCR_USERNAME`
- `GHCR_TOKEN`
- `STAGING_SITE_ADMIN_PASSWORD`

Recommended first-time flow:

```bash
./deploy/staging/init-staging-server.sh

# edit deploy/staging/staging.env

./deploy/staging/start-staging.sh

SITE_NAME=staging.example.com ADMIN_PASSWORD='<admin-password>' ./deploy/staging/init-site.sh
```

If the site is already initialized but direct IP access still returns `404`, add this to `deploy/staging/staging.env`:

```bash
FRAPPE_SITE_NAME_HEADER=staging.example.com
```

Then restart staging:

```bash
./deploy/staging/stop-staging.sh
./deploy/staging/start-staging.sh
```

This makes the staging frontend route LAN/IP requests to the intended single site during the internal testing phase.

After the stack is up, initialize the staging site by following:

- `/home/rgc318/python-project/frappe_docker/deploy/staging/INIT_SITE.zh-CN.md`

Common update flow after the first deployment:

```bash
SITE_NAME=staging.example.com ./deploy/staging/deploy-staging.sh
```

PDF note:

- if printed PDFs must render Simplified Chinese correctly, keep a CJK font package in the image
- the current bench image installs `fonts-noto-cjk`
- the staging runtime image also needs the same package in:
  - `/home/rgc318/python-project/frappe_docker/images/custom/myapp-staging/Containerfile`
- this dependency was manually verified in the local development backend container:
  - before installing `fonts-noto-cjk`, generated PDFs could show garbled Chinese
  - after installing `fonts-noto-cjk`, Simplified Chinese PDF rendering worked correctly
- when PDF Chinese output becomes garbled again after rebuilding containers, first confirm the running container still contains:
  - `fonts-noto-cjk`
  - visible CJK families from `fc-list :lang=zh`
- after changing PDF/font dependencies in `images/bench/Dockerfile`, rebuild the staging image first and then deploy

Common rollback flow:

```bash
ROLLBACK_TAG=staging-20260409-abc123 SITE_NAME=staging.example.com ./deploy/staging/rollback-staging.sh
```

Rollback is fail-closed by default. The target tag must have a manifest under
`artifacts/staging/ai-releases/` from a previously passed canary, and the currently
resolved images must match the recorded image IDs/digests and revisions. For a
documented break-glass recovery only, `ALLOW_UNQUALIFIED_ROLLBACK=1` bypasses this
preflight and prints a warning.

Common backup flow:

```bash
SITE_NAME=all ./deploy/staging/backup-staging.sh
```

Common restore flow:

```bash
SITE_NAME=staging.example.com \
RESTORE_DIR=/srv/frappe_docker/tmp/restore-localhost-20260409 \
./deploy/staging/restore-staging.sh
```

By default, backup archives are written to:

```bash
./backups/staging/
```

Common post-deploy verification:

```bash
./deploy/staging/check-staging.sh
```

Enable the bounded AI scenario canary explicitly when running the script by hand:

```bash
RUN_AI_STAGING_CANARY=1 ./deploy/staging/check-staging.sh
```

The deployment workflow enables this gate by default. The default canary calls
`/readyz`, intent parsing, ordinary read-only chat, and product draft generation.
It never confirms a draft or writes an ERP business document. Set
`AI_CANARY_SCENARIOS=readiness,intent_parse,chat,sales_order_draft,purchase_order_draft,inventory_adjustment_draft,product_setup_draft`
to cover all structured draft families. A transient Provider timeout, 429, or 5xx
gets at most one retry on the same artifacts and remains `partial`; deterministic
contract, authentication, capability, Schema, or Provider 4xx failures are `failed`
and stop the workflow. Set `AI_CANARY_REQUIRE_PASS=1` for a final release candidate.

The generic canary intentionally does not mint a business-user Agent capability
token. Agent/tool acceptance must use a dedicated least-privilege staging user and
the authenticated HTTP scenario suite, so a release script cannot accidentally
gain broad ERP read permissions.

Each canary also feeds the SLO gate. Defaults are 99.5% success, at least 20
samples, p95 at or below 30 seconds, and zero contract mismatches. A normal small
canary therefore produces a warning, not a false SLO pass. Provide an existing
`myapp-ai-load-report-v1` through `AI_SLO_LOAD_REPORT_PATH` to reach the sample
threshold, and set `AI_SLO_REQUIRE_PASS=1` for a final candidate. Alerts are always
persisted under `artifacts/staging/ai-slo/`; no external webhook is called unless
`AI_SLO_ALERT_WEBHOOK_URL` is explicitly configured.

Progressive AI rollout is enabled with the `progressive_ai_rollout` workflow input
or manually with:

```bash
AI_ROLLOUT_CANDIDATE_TAG=<immutable-release-tag> \
  ./deploy/staging/run-ai-progressive-rollout.sh
```

The default stages are `5,25,50,100`. Fresh-request buckets are persisted in
`artifacts/staging/ai-router/rollout.map`; exact Agent resume routes are persisted
in `release-affinity.map`. The Backend sends `X-MyApp-AI-Release-Affinity` from the
Run's recorded release ID, and the router returns 503 for unknown or retired IDs.
Candidate readiness fallback protects fresh traffic, but a configured candidate
that receives no sampled traffic fails the stage gate.

After the paired Backend/AI candidate is deployed, finalization enters a drain
window instead of stopping the old stable pool. The default is 24 hours:

```bash
AI_ROLLOUT_DRAIN_SECONDS=86400 ./deploy/staging/finalize-ai-progressive-rollout.sh
```

After the recorded deadline, run:

```bash
./deploy/staging/complete-ai-progressive-rollout.sh
```

The completion step first removes old-release affinity, keeps fresh traffic on the
candidate while stable converges to the new image, then resets rollout to stable
100% and stops candidate. A failed or manually aborted rollout uses the same drain
mechanism in reverse: fresh traffic returns to the old stable immediately, while
candidate remains only for its existing release-affined resumes. Use
`AI_ROLLOUT_FORCE_COMPLETE=1` only for a documented emergency retirement.

Critical HTTP regression can be enabled after the basic health check:

```bash
RUN_STAGING_HTTP_REGRESSION=1 ./deploy/staging/check-staging.sh
```

It runs `deploy/staging/run-critical-http-regression.sh` inside the staging backend container and covers JWT lifecycle plus the most important idempotency replay, conflict, and concurrent same-key cases.

This is a post-deploy acceptance check. GitHub Actions does not start a separate full stack on the runner for this step. Instead, the workflow SSHs into the staging server after deployment and runs the HTTP tests against the freshly deployed staging services, database, and image.

Configure one authentication method before enabling it:

- `STAGING_HTTP_BEARER_TOKEN`
- or `STAGING_HTTP_API_KEY` + `STAGING_HTTP_API_SECRET`
- or `STAGING_HTTP_USERNAME` + `STAGING_HTTP_PASSWORD`

The `Deploy staging stack` GitHub Actions workflow exposes the same behavior through the `run_http_regression` input. Add the chosen credentials as GitHub Actions secrets, then enable the input for release verification. Keep it disabled for lightweight deploy checks.

The critical regression suite is intentionally smaller than the full HTTP suite because it creates real staging business documents. Use it to catch high-risk deployment regressions; run the full local/devcontainer HTTP suite when validating broader business behavior.

For local cleaned-data migration into staging, follow:

- `/home/rgc318/python-project/frappe_docker/deploy/staging/DATA_MIGRATION.zh-CN.md`
