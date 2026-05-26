# Staging Deployment Files

This directory contains the minimum files needed to run a production-like staging environment for `myapp`.

Files:

- `staging.env.example`
  - copy to `staging.env` and fill real values
- `apps.staging.json.example`
  - copy to `apps.staging.json` and define the apps baked into the image
- `compose.staging.yaml`
  - staging-only compose base that does not bind-mount `apps/myapp`
- `compose.mariadb.staging.yaml`
  - staging-only MariaDB override that does not publish database ports to the host
- `build-staging-image.sh`
  - builds the custom image that already contains `myapp`
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

Workflow:

- `/home/rgc318/python-project/frappe_docker/.github/workflows/build_myapp_staging_image.yml`
- `/home/rgc318/python-project/frappe_docker/.github/workflows/deploy_staging.yml`
- `/home/rgc318/python-project/frappe_docker/.github/workflows/init_staging_site.yml`

Suggested image reference in `staging.env`:

```bash
CUSTOM_IMAGE=ghcr.io/<github-owner>/myapp-erpnext
CUSTOM_TAG=staging-latest
PULL_POLICY=always
```

For release verification, prefer a unique `CUSTOM_TAG` such as `staging-20260526-bff502e`.
The staging compose file intentionally persists only `sites`; the Python virtualenv comes
from the image and is not mounted as a long-lived Docker volume.
Shared host runtime constraints, such as Frappe's supported `PyJWT` range and `XlsxWriter`,
belong in `deploy/staging/requirements.staging.txt` and are installed during image build.

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

For local cleaned-data migration into staging, follow:

- `/home/rgc318/python-project/frappe_docker/deploy/staging/DATA_MIGRATION.zh-CN.md`
