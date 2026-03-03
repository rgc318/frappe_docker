#!/bin/bash



docker compose \
  -f compose.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.noproxy.yaml \
  up -d