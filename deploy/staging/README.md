# Staging Deployment Files

This directory contains the minimum files needed to run a production-like staging environment for `myapp`.

Files:

- `staging.env.example`
  - copy to `staging.env` and fill real values
- `apps.staging.json.example`
  - copy to `apps.staging.json` and define the apps baked into the image
- `build-staging-image.sh`
  - builds the custom image that already contains `myapp`
- `start-staging.sh`
  - starts the staging stack with HTTPS
- `deploy-staging.sh`
  - pulls the latest image, restarts the stack, and optionally runs `bench migrate`
- `init-staging-server.sh`
  - prepares the server directories and creates `staging.env` from the example
- `check-staging.sh`
  - verifies the compose services and basic HTTP endpoints after deployment
- `stop-staging.sh`
  - stops the staging stack
- `INIT_SITE.zh-CN.md`
  - first-time site creation and app installation guide

Recommended long-term path:

- do not build the staging image on the staging server
- use GitHub Actions to build and push the image to GHCR
- let the staging server only:
  - `docker pull`
  - `./deploy/staging/start-staging.sh`

Workflow:

- `/home/rgc318/python-project/frappe_docker/.github/workflows/build_myapp_staging_image.yml`
- `/home/rgc318/python-project/frappe_docker/.github/workflows/deploy_staging.yml`

Suggested image reference in `staging.env`:

```bash
CUSTOM_IMAGE=ghcr.io/<github-owner>/myapp-erpnext
CUSTOM_TAG=staging-latest
PULL_POLICY=always
```

Required GitHub secrets for SSH deploy:

- `STAGING_SSH_HOST`
- `STAGING_SSH_PORT`
- `STAGING_SSH_USER`
- `STAGING_SSH_PRIVATE_KEY`
- `GHCR_USERNAME`
- `GHCR_TOKEN`

Recommended first-time flow:

```bash
./deploy/staging/init-staging-server.sh

# edit deploy/staging/staging.env

./deploy/staging/start-staging.sh
```

After the stack is up, initialize the staging site by following:

- `/home/rgc318/python-project/frappe_docker/deploy/staging/INIT_SITE.zh-CN.md`

Common update flow after the first deployment:

```bash
SITE_NAME=staging.example.com ./deploy/staging/deploy-staging.sh
```

Common post-deploy verification:

```bash
./deploy/staging/check-staging.sh
```
