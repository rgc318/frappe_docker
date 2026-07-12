# Frappe Docker

[![Build Stable](https://github.com/frappe/frappe_docker/actions/workflows/build_stable.yml/badge.svg)](https://github.com/frappe/frappe_docker/actions/workflows/build_stable.yml)
[![Build Develop](https://github.com/frappe/frappe_docker/actions/workflows/build_develop.yml/badge.svg)](https://github.com/frappe/frappe_docker/actions/workflows/build_develop.yml)

Docker images and orchestration for Frappe applications.

## What is this?

This repository handles the containerization of the Frappe stack, including the application server, database, Redis, and supporting services. It provides quick disposable demo setups, a development environment, production-ready Docker images and compose configurations for deploying Frappe applications including ERPNext.

## Repository Structure

```
frappe_docker/
├── docs/                 # Complete documentation
├── overrides/            # Docker Compose configurations for different scenarios
├── compose.yaml          # Base Compose File for production setups
├── pwd.yml               # Single Compose File for quick disposable demo
├── images/               # Dockerfiles for building Frappe images
├── development/          # Development environment configurations
├── devcontainer-example/ # VS Code devcontainer setup
└── resources/            # Helper scripts and configuration templates
```

> This section describes the structure of **this repository**, not the Frappe framework itself.

### Key Components

- `docs/` - Canonical documentation for all deployment and operational workflows
- `overrides/` - Opinionated Compose overrides for common deployment patterns
- `compose.yaml` - Base compose file for production setups (production)
- `pwd.yml` - Disposable demo environment (non-production)

### Local myapp Development

This workspace includes a project-specific `myapp` development setup. Use `./start-dev.sh` to start the local stack with the same compose files used by the dev workflow:

```bash
./start-dev.sh
```

The script expands to:

```bash
docker compose \
  -f compose.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.noproxy.yaml \
  up -d
```

`compose.yaml` bind-mounts `apps/myapp` and runs `./env/bin/pip install -e apps/myapp` for the backend, workers, scheduler, and configurator. This means Python dependencies declared by `apps/myapp/pyproject.toml`, including `rgc-backend-kit>=0.1.1,<0.2.0`, are installed automatically from PyPI when the app services start. Do not install `rgc-backend-kit` manually from `/tmp` or a host-local source checkout.

The local development compose file intentionally does not persist `/home/frappe/frappe-bench/env` as a Docker volume. Each container uses the virtualenv from its image and refreshes `myapp` dependencies on startup, which keeps dependency behavior closer to staging builds.

### VS Code Dev Container Notes

When the stack is started through VS Code Dev Containers, use the Dev Container compose override in `.devcontainer/docker-compose.yml`.

- Stop Dev Container services with `./stop.sh --devcontainer`.
- Do not use plain `./stop.sh` for a Dev Container session; it does not include Dev Container-only services such as `mobile-proxy`.
- `./stop.sh --devcontainer` includes `.devcontainer/docker-compose.yml` and `--remove-orphans`, which prevents stale containers from referencing deleted Docker networks.
- Do not add `-v` unless you intentionally want to delete Docker volumes.

The Dev Container `backend` service is intentionally kept idle. It installs/refreshes `myapp`, ensures `debugpy` is available for VS Code debugging, and then keeps the container alive. It does not run `bench serve` automatically. Pressing F5 in VS Code starts `bench serve --port 8000` from `.vscode/launch.json`; this avoids the `Address already in use` error caused by starting a second server on port `8000`.

`debugpy` is a development/debugging dependency. It should not be listed in `apps/myapp/pyproject.toml` under normal runtime `dependencies`, otherwise every service that runs `pip install -e apps/myapp` will try to install it on startup. Keep it in the app's dev dependency section or install it only from the Dev Container startup path.

For Chinese PDF/font rendering in local Dev Containers, install Noto CJK fonts in WSL and mount them into the container:

```bash
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y fontconfig fonts-noto-cjk
```

The Dev Container maps `/usr/share/fonts/opentype/noto` into `/home/frappe/.local/share/fonts/noto` and refreshes the font cache on start. Staging images already install `fontconfig` and `fonts-noto-cjk` in `images/custom/myapp-staging/Containerfile`, so the workflow does not need a separate change for local font mounting.

## Documentation

**The official documentation for `frappe_docker` is maintained in the `docs/` folder in this repository.**

**New to Frappe Docker?** Read the [Getting Started Guide](docs/getting-started.md) for a comprehensive overview of repository structure, development workflow, custom apps, Docker concepts, and quick start examples.

If you are already familiar with Frappe, you can jump right into the [different deployment methods](docs/01-getting-started/01-choosing-a-deployment-method.md) and select the one best suited to your use case.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose v2](https://docs.docker.com/compose/)
- [git](https://docs.github.com/en/get-started/getting-started-with-git/set-up-git)

> For Docker basics and best practices refer to Docker's [documentation](http://docs.docker.com)

## Demo setup

The fastest way to try Frappe is to play in an already set up sandbox, in your browser, click the button below:

<a href="https://labs.play-with-docker.com/?stack=https://raw.githubusercontent.com/frappe/frappe_docker/main/pwd.yml">
  <img src="https://raw.githubusercontent.com/play-with-docker/stacks/master/assets/images/button.png" alt="Try in PWD"/>
</a>

### Try on your environment

> **⚠️ Disposable demo only**
>
> **This setup is intended for quick evaluation. Expect to throw the environment away.** You will not be able to install custom apps to this setup. For production deployments, custom configurations, and detailed explanations, see the full documentation.

First clone the repo:

```sh
git clone https://github.com/frappe/frappe_docker
cd frappe_docker
```

Then run:

```sh
docker compose -f pwd.yml up -d
```

Wait for a couple of minutes for ERPNext site to be created or check `create-site` container logs before opening browser on port `8080`. (username: `Administrator`, password: `admin`)

## Documentation Links

### [myapp 项目差距与交付路线图](docs/codex/PROJECT_GAP_ROADMAP.zh-CN.md)

### [myapp 当前交接状态](docs/codex/CURRENT_HANDOFF.zh-CN.md)

### [Getting Started Guide](docs/getting-started.md)

### [Frequently Asked Questions](https://github.com/frappe/frappe_docker/wiki/Frequently-Asked-Questions)

### [Getting Started](#getting-started)

### [Deployment Methods](docs/01-getting-started/01-choosing-a-deployment-method.md)

### [ARM64](docs/01-getting-started/03-arm64.md)

### [Container Setup Overview](docs/02-setup/01-overview.md)

### [Development](docs/05-development/01-development.md)

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

This repository is only for container related stuff. You also might want to contribute to:

## Resources

- [Frappe framework](https://github.com/frappe/frappe),
- [ERPNext](https://github.com/frappe/erpnext),
- [Frappe Bench](https://github.com/frappe/bench).

## License

This repository is licensed under the MIT License. See [LICENSE](LICENSE) for details.
