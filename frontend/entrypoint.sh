#!/bin/sh
set -eu

APP_MODE_VALUE="$(printf '%s' "${APP_MODE:-development}" | tr '[:upper:]' '[:lower:]')"
case "$APP_MODE_VALUE" in
  demo|development|production) ;;
  *)
    echo "[WARN] Invalid APP_MODE='$APP_MODE_VALUE'; defaulting to development."
    APP_MODE_VALUE="development"
    ;;
esac

ALLOW_DEMO_FLAG="$(printf '%s' "${ALLOW_DEMO_ON_PUBLIC_HOST:-false}" | tr '[:upper:]' '[:lower:]')"
case "$ALLOW_DEMO_FLAG" in
  1|true|yes|on) ALLOW_DEMO_JS=true ;;
  *) ALLOW_DEMO_JS=false ;;
esac

if [ "$APP_MODE_VALUE" = "demo" ] && [ "$(printf '%s' "${DEPLOY_ENV:-}" | tr '[:upper:]' '[:lower:]')" = "production" ]; then
  echo "[ERROR] APP_MODE=demo is blocked when DEPLOY_ENV=production."
  exit 1
fi

cat > /tmp/runtime-config.js <<EOF
window.__GITVIBE_RUNTIME_CONFIG__ = Object.freeze({
  APP_MODE: "${APP_MODE_VALUE}",
  API_BASE_URL: "${API_BASE_URL:-}",
  DEMO_NAMESPACE: "${DEMO_NAMESPACE:-gitvibe_demo_v1}",
  ALLOW_DEMO_ON_PUBLIC_HOST: ${ALLOW_DEMO_JS}
});
EOF

exec nginx -g 'daemon off;'
