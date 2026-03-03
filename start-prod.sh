docker compose \
  -f compose.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.traefik.yaml \
  -f overrides/compose.https.yaml \
  up -d