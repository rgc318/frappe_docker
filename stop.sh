#!/usr/bin/env bash

set -e

# 默认参数
REMOVE_VOLUMES=false
REMOVE_ORPHANS=false
DEVCONTAINER=false

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
  -v)
    REMOVE_VOLUMES=true
    shift
    ;;
  -r)
    REMOVE_ORPHANS=true
    shift
    ;;
  --devcontainer)
    DEVCONTAINER=true
    shift
    ;;
  *)
    echo "Unknown option: $1"
    echo "Usage: ./stop.sh [-v] [-r] [--devcontainer]"
    exit 1
    ;;
  esac
done

# compose 文件（和你启动时保持一致）
COMPOSE_FILES=(
  -f compose.yaml
  -f overrides/compose.redis.yaml
  -f overrides/compose.mariadb.yaml
  -f overrides/compose.noproxy.yaml
)

if [ "$DEVCONTAINER" = true ]; then
  COMPOSE_FILES+=(-f .devcontainer/docker-compose.yml)
  REMOVE_ORPHANS=true
fi

# 构建命令
CMD=(docker compose "${COMPOSE_FILES[@]}" down)

if [ "$REMOVE_VOLUMES" = true ]; then
  CMD+=(-v)
fi

if [ "$REMOVE_ORPHANS" = true ]; then
  CMD+=(--remove-orphans)
fi

echo "Running: ${CMD[*]}"
"${CMD[@]}"
