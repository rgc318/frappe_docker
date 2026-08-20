# Staging Deployment Files

This directory contains the minimum files needed to run a production-like staging environment for `myapp`.

Files:

- `staging.env.example`
  - copy to `staging.env` and fill real values
- `apps.staging.json.example`
  - copy to `apps.staging.json` and define the apps baked into the image
- `compose.staging.yaml`
  - staging-only compose base that does not bind-mount `apps/myapp`
  - includes the AI Orchestrator, Qdrant, its one-shot volume initializer, and the dedicated `ai-vector` worker
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
  - switches `CUSTOM_TAG` to an older image tag, restarts the stack, and optionally runs the health check
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
```

The build workflow publishes the ERPNext and AI Orchestrator images with the same release tag. Deploy and rollback update both `CUSTOM_TAG` and `MYAPP_AI_TAG`; `check-staging.sh` verifies the Orchestrator health response, authenticated Backend-to-Orchestrator communication, and an effective positive-rollout staging Runtime Policy with tool-ready and vision-ready models.

Before starting staging, configure these AI values in the ignored `deploy/staging/staging.env`:

- LiteLLM base URL and API key
- a random internal service token of at least 32 characters
- Frappe site host and AI environment
- Embedding/Qdrant alias settings; keep vector search disabled until smoke tests pass
- optional external Langfuse host/public/secret key; configure all three together or leave all three empty

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
