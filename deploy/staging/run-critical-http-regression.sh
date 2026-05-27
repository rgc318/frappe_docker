#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"
STAGING_MODE="${STAGING_MODE:-${DEPLOY_MODE:-internal}}"
COMPOSE_BASE="${ROOT_DIR}/deploy/staging/compose.staging.yaml"
PROXY_OVERRIDE="${ROOT_DIR}/overrides/compose.noproxy.yaml"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}"
  exit 1
fi

if [[ "${STAGING_MODE}" == "https" ]]; then
  PROXY_OVERRIDE="${ROOT_DIR}/overrides/compose.https.yaml"
fi

compose() {
  docker compose \
    --env-file "${ENV_FILE}" \
    -f "${COMPOSE_BASE}" \
    -f "${ROOT_DIR}/overrides/compose.redis.yaml" \
    -f "${ROOT_DIR}/deploy/staging/compose.mariadb.staging.yaml" \
    -f "${PROXY_OVERRIDE}" \
    "$@"
}

MYAPP_HTTP_BASE_URL="${MYAPP_HTTP_BASE_URL:-http://localhost:8000}"
MYAPP_HTTP_TIMEOUT="${MYAPP_HTTP_TIMEOUT:-90}"
MYAPP_HTTP_PRINT_RESPONSES="${MYAPP_HTTP_PRINT_RESPONSES:-0}"
MYAPP_HTTP_SAVE_RESPONSES="${MYAPP_HTTP_SAVE_RESPONSES:-0}"
MYAPP_HTTP_USERNAME="${MYAPP_HTTP_USERNAME:-${STAGING_HTTP_USERNAME:-}}"
MYAPP_HTTP_PASSWORD="${MYAPP_HTTP_PASSWORD:-${STAGING_HTTP_PASSWORD:-}}"
MYAPP_HTTP_API_KEY="${MYAPP_HTTP_API_KEY:-${STAGING_HTTP_API_KEY:-}}"
MYAPP_HTTP_API_SECRET="${MYAPP_HTTP_API_SECRET:-${STAGING_HTTP_API_SECRET:-}}"
MYAPP_HTTP_BEARER_TOKEN="${MYAPP_HTTP_BEARER_TOKEN:-${STAGING_HTTP_BEARER_TOKEN:-}}"

if [[ -z "${MYAPP_HTTP_BEARER_TOKEN}" ]]; then
  if [[ -z "${MYAPP_HTTP_API_KEY}" || -z "${MYAPP_HTTP_API_SECRET}" ]]; then
    if [[ -z "${MYAPP_HTTP_USERNAME}" || -z "${MYAPP_HTTP_PASSWORD}" ]]; then
      echo "Missing staging HTTP test credentials."
      echo "Set STAGING_HTTP_BEARER_TOKEN, or STAGING_HTTP_API_KEY/STAGING_HTTP_API_SECRET, or STAGING_HTTP_USERNAME/STAGING_HTTP_PASSWORD."
      exit 1
    fi
  fi
fi

echo "== Critical HTTP regression =="
echo "Base URL inside backend: ${MYAPP_HTTP_BASE_URL}"

compose exec -T \
  -e MYAPP_HTTP_BASE_URL="${MYAPP_HTTP_BASE_URL}" \
  -e MYAPP_HTTP_TIMEOUT="${MYAPP_HTTP_TIMEOUT}" \
  -e MYAPP_HTTP_PRINT_RESPONSES="${MYAPP_HTTP_PRINT_RESPONSES}" \
  -e MYAPP_HTTP_SAVE_RESPONSES="${MYAPP_HTTP_SAVE_RESPONSES}" \
  -e MYAPP_HTTP_USERNAME="${MYAPP_HTTP_USERNAME}" \
  -e MYAPP_HTTP_PASSWORD="${MYAPP_HTTP_PASSWORD}" \
  -e MYAPP_HTTP_API_KEY="${MYAPP_HTTP_API_KEY}" \
  -e MYAPP_HTTP_API_SECRET="${MYAPP_HTTP_API_SECRET}" \
  -e MYAPP_HTTP_BEARER_TOKEN="${MYAPP_HTTP_BEARER_TOKEN}" \
  backend bash -lc '
    set -euo pipefail
    cd /home/frappe/frappe-bench
    ./env/bin/python -m unittest \
      apps.myapp.myapp.tests.http.test_jwt_token_http.JwtTokenHttpTestCase \
      apps.myapp.myapp.tests.http.test_gateway_http.GatewayHttpTestCase.test_create_order_idempotent_replay \
      apps.myapp.myapp.tests.http.test_gateway_http.GatewayHttpTestCase.test_create_order_same_request_id_with_different_data_returns_conflict \
      apps.myapp.myapp.tests.http.test_gateway_http.GatewayHttpTestCase.test_create_order_concurrent_same_request_id_returns_single_order \
      apps.myapp.myapp.tests.http.test_gateway_http.GatewayHttpTestCase.test_create_purchase_order_idempotent_replay \
      apps.myapp.myapp.tests.http.test_gateway_http.GatewayHttpTestCase.test_create_purchase_order_same_request_id_with_different_data_returns_conflict \
      apps.myapp.myapp.tests.http.test_gateway_http.GatewayHttpTestCase.test_create_purchase_order_concurrent_same_request_id_returns_single_order \
      apps.myapp.myapp.tests.http.test_gateway_v2_http.GatewayV2HttpTestCase.test_create_product_and_stock_idempotent_replay \
      apps.myapp.myapp.tests.http.test_gateway_v2_http.GatewayV2HttpTestCase.test_create_product_and_stock_same_request_id_with_different_data_returns_conflict \
      apps.myapp.myapp.tests.http.test_gateway_v2_http.GatewayV2HttpTestCase.test_create_product_and_stock_concurrent_same_request_id_returns_single_item \
      apps.myapp.myapp.tests.http.test_purchase_quick_http.PurchaseQuickHttpTestCase.test_record_supplier_payment_idempotent_replay_returns_same_payment \
      apps.myapp.myapp.tests.http.test_purchase_quick_http.PurchaseQuickHttpTestCase.test_record_supplier_payment_concurrent_same_request_id_returns_single_payment
  '

echo "Critical HTTP regression completed."
