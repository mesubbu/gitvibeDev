#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="$REPO_ROOT/.venv"
PIDS_FILE="$REPO_ROOT/.gitvibe.pids"
BACKEND_LOG="$REPO_ROOT/.gitvibe.backend.log"
FRONTEND_LOG="$REPO_ROOT/.gitvibe.frontend.log"

BACKEND_HOST="127.0.0.1"
BACKEND_PORT="8000"
FRONTEND_HOST="127.0.0.1"
FRONTEND_PORT="3000"

info() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: bash installer/install-local.sh <start|stop>
EOF
}

is_running() {
  local pid="$1"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

read_pid() {
  local key="$1"
  if [[ -f "$PIDS_FILE" ]]; then
    awk -F= -v key="$key" '$1 == key { print $2; exit }' "$PIDS_FILE"
  fi
}

write_pids() {
  local backend_pid="$1"
  local frontend_pid="$2"
  cat > "$PIDS_FILE" <<EOF
backend=$backend_pid
frontend=$frontend_pid
EOF
}

stop_pid() {
  local pid="$1"
  local expected_fragment="$2"
  local label="$3"

  if ! is_running "$pid"; then
    return
  fi

  local command_line
  command_line="$(ps -p "$pid" -o args= 2>/dev/null || true)"
  if [[ -n "$expected_fragment" && "$command_line" != *"$expected_fragment"* ]]; then
    warn "Skipping $label PID $pid; command does not match expected process."
    return
  fi

  kill "$pid" 2>/dev/null || true
  for _ in {1..20}; do
    if ! is_running "$pid"; then
      return
    fi
    sleep 0.2
  done
  kill -9 "$pid" 2>/dev/null || true
}

ensure_env_file() {
  if [[ ! -f "$REPO_ROOT/.env" ]]; then
    [[ -f "$REPO_ROOT/.env.example" ]] || die ".env.example not found."
    cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"
    info "Created .env from .env.example."
  fi
}

ensure_venv() {
  command -v python3 >/dev/null 2>&1 || die "python3 is required for local mode."
  if [[ ! -d "$VENV_DIR" ]]; then
    info "Creating Python virtual environment at $VENV_DIR..."
    python3 -m venv "$VENV_DIR"
  fi
  "$VENV_DIR/bin/python" -m ensurepip --upgrade >/dev/null 2>&1 || true
  info "Installing backend dependencies..."
  "$VENV_DIR/bin/python" -m pip install --upgrade pip >/dev/null
  "$VENV_DIR/bin/python" -m pip install -r "$REPO_ROOT/backend/requirements.txt" >/dev/null
}

start_local() {
  local existing_backend existing_frontend
  existing_backend="$(read_pid backend)"
  existing_frontend="$(read_pid frontend)"

  if is_running "$existing_backend" && is_running "$existing_frontend"; then
    info "Local services are already running at http://localhost:$FRONTEND_PORT"
    return
  fi
  if [[ -f "$PIDS_FILE" ]]; then
    warn "Detected stale PID file. Cleaning up stale processes."
    stop_local
  fi

  ensure_env_file
  ensure_venv

  info "Starting backend on http://$BACKEND_HOST:$BACKEND_PORT ..."
  (
    cd "$REPO_ROOT/backend"
    APP_MODE=demo DEMO_MODE=true FAST_BOOT=true \
      "$VENV_DIR/bin/python" -m uvicorn app.main:app --host "$BACKEND_HOST" --port "$BACKEND_PORT" \
      >"$BACKEND_LOG" 2>&1
  ) &
  local backend_pid="$!"
  sleep 1
  is_running "$backend_pid" || die "Backend failed to start. Check $BACKEND_LOG"

  info "Starting frontend local proxy on http://$FRONTEND_HOST:$FRONTEND_PORT ..."
  APP_MODE=demo DEMO_NAMESPACE=gitvibe_demo_v1 \
    "$VENV_DIR/bin/python" "$SCRIPT_DIR/local_proxy_server.py" \
    --frontend-dir "$REPO_ROOT/frontend" \
    --backend-url "http://$BACKEND_HOST:$BACKEND_PORT" \
    --host "$FRONTEND_HOST" \
    --port "$FRONTEND_PORT" \
    >"$FRONTEND_LOG" 2>&1 &
  local frontend_pid="$!"
  sleep 1
  if ! is_running "$frontend_pid"; then
    stop_pid "$backend_pid" "uvicorn app.main:app" "backend"
    die "Frontend proxy failed to start. Check $FRONTEND_LOG"
  fi

  write_pids "$backend_pid" "$frontend_pid"
  info "Local stack started."
  info "Frontend: http://localhost:$FRONTEND_PORT"
  info "Backend:  http://localhost:$BACKEND_PORT"
}

stop_local() {
  if [[ ! -f "$PIDS_FILE" ]]; then
    info "No local PID file found; nothing to stop."
    return
  fi

  local backend_pid frontend_pid
  backend_pid="$(read_pid backend)"
  frontend_pid="$(read_pid frontend)"

  stop_pid "$frontend_pid" "local_proxy_server.py" "frontend"
  stop_pid "$backend_pid" "uvicorn app.main:app" "backend"

  rm -f "$PIDS_FILE"
  info "Local stack stopped."
}

main() {
  case "${1:-}" in
    start)
      start_local
      ;;
    stop)
      stop_local
      ;;
    -h|--help)
      usage
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
