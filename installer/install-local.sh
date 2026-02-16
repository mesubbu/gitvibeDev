#!/usr/bin/env bash
set -eo pipefail

# GitVibeDev — Local installer (no Docker required)
# Usage: bash installer/install-local.sh [start|stop]
#
# Starts the FastAPI backend directly with a Python venv.
# Serves the frontend via Python's built-in HTTP server.

trap 'echo ""; echo "[FAIL]  Installer exited unexpectedly at line $LINENO. Re-run with: bash -x installer/install-local.sh start" >&2' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="$PROJECT_DIR/.venv"
BACKEND_DIR="$PROJECT_DIR/backend"
FRONTEND_DIR="$PROJECT_DIR/frontend"
ENV_FILE="$PROJECT_DIR/.env"
PID_FILE="$PROJECT_DIR/.gitvibe.pids"

BACKEND_PORT="${BACKEND_PORT:-8000}"
FRONTEND_PORT="${FRONTEND_PORT:-3000}"

log()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*" >&2; }
ok()   { printf '\033[1;32m[ OK ]\033[0m  %s\n' "$*"; }
die()  { printf '\033[1;31m[FAIL]\033[0m  %s\n' "$*" >&2; exit 1; }

# ── Preflight checks ─────────────────────────────────────────────────
check_python() {
  local py=""
  for cmd in python3 python; do
    if command -v "$cmd" >/dev/null 2>&1; then
      py="$cmd"
      break
    fi
  done
  [ -n "$py" ] || die "Python 3 is required but not found. Install Python 3.10+ and retry."

  local ver
  ver=$("$py" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
  local major minor
  major="${ver%%.*}"
  minor="${ver##*.}"
  if [ "$major" -lt 3 ] || { [ "$major" -eq 3 ] && [ "$minor" -lt 10 ]; }; then
    die "Python 3.10+ required, found $ver"
  fi

  ok "Python $ver ($py)"
  PYTHON="$py"
}

# ── Secret generation ─────────────────────────────────────────────────
generate_hex() {
  local bytes="${1:-32}"
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "$bytes"
  else
    "$PYTHON" -c "import secrets; print(secrets.token_hex($bytes))"
  fi
}

get_env_var() {
  local key="$1" file="$2"
  grep -E "^${key}=" "$file" 2>/dev/null | head -n 1 | cut -d= -f2- || true
}

set_env_var() {
  local key="$1" value="$2" file="$3"
  if grep -qE "^${key}=" "$file" 2>/dev/null; then
    local tmp; tmp="$(mktemp)"
    awk -v k="$key" -v v="$value" -F= '$1 == k { print k "=" v; next } { print }' "$file" > "$tmp"
    mv "$tmp" "$file"
  else
    printf '%s=%s\n' "$key" "$value" >> "$file"
  fi
}

ensure_secret() {
  local key="$1" file="$2"
  local current
  current="$(get_env_var "$key" "$file")"
  if [ -z "$current" ] || [ "$current" = "change_me" ] || [[ "$current" == CHANGE_ME* ]]; then
    set_env_var "$key" "$(generate_hex 32)" "$file"
  fi
}

setup_env() {
  if [ ! -f "$ENV_FILE" ]; then
    if [ -f "$PROJECT_DIR/.env.example" ]; then
      log "Creating .env from .env.example..."
      cp "$PROJECT_DIR/.env.example" "$ENV_FILE"
    else
      log "Creating minimal .env..."
      touch "$ENV_FILE"
    fi
  fi

  # Force local-friendly defaults
  set_env_var "DEMO_MODE"       "true"  "$ENV_FILE"
  set_env_var "FAST_BOOT"       "true"  "$ENV_FILE"
  set_env_var "FRONTEND_PORT"   "$FRONTEND_PORT" "$ENV_FILE"

  ensure_secret "SECRET_KEY"            "$ENV_FILE"
  ensure_secret "APP_ENCRYPTION_KEY"    "$ENV_FILE"
  ensure_secret "BOOTSTRAP_ADMIN_TOKEN" "$ENV_FILE"

  ok "Environment configured (.env)"
}

# ── Virtual environment ───────────────────────────────────────────────
setup_venv() {
  if [ -d "$VENV_DIR" ] && [ -f "$VENV_DIR/bin/python" ]; then
    log "Reusing existing venv at $VENV_DIR"
  else
    log "Creating virtual environment..."
    if ! "$PYTHON" -m venv --without-pip "$VENV_DIR" 2>/dev/null; then
      if ! "$PYTHON" -m venv "$VENV_DIR" 2>/dev/null; then
        die "Failed to create venv. On Ubuntu/Debian, run: sudo apt install python3-venv"
      fi
    fi
  fi

  # Ensure pip is available inside the venv
  if ! "$VENV_DIR/bin/python" -m pip --version >/dev/null 2>&1; then
    log "Bootstrapping pip inside venv..."
    local get_pip
    get_pip="$(mktemp)"
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL https://bootstrap.pypa.io/get-pip.py -o "$get_pip" \
        || die "Failed to download get-pip.py. Check your internet connection."
    elif command -v wget >/dev/null 2>&1; then
      wget -qO "$get_pip" https://bootstrap.pypa.io/get-pip.py \
        || die "Failed to download get-pip.py. Check your internet connection."
    else
      die "curl or wget is required to bootstrap pip."
    fi
    "$VENV_DIR/bin/python" "$get_pip" --quiet || die "pip bootstrap failed."
    rm -f "$get_pip"
  fi

  ok "Virtual environment ready"
}

install_deps() {
  log "Installing backend dependencies..."
  "$VENV_DIR/bin/python" -m pip install --quiet -r "$BACKEND_DIR/requirements.txt" \
    || die "Failed to install backend dependencies."
  ok "Dependencies installed"
}

# ── Export env vars from .env ─────────────────────────────────────────
load_env() {
  # Source .env safely — skip comments and tolerate empty values
  while IFS='=' read -r key value; do
    # Skip blank lines and comments
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
    # Strip leading/trailing whitespace from key
    key="$(echo "$key" | xargs)"
    [[ -z "$key" ]] && continue
    export "$key"="${value:-}"
  done < "$ENV_FILE"

  # Override for local mode
  export DEMO_MODE=true
  export FAST_BOOT=true
  # Use local data directories instead of Docker /data paths
  local data_dir="$PROJECT_DIR/.data"
  export VAULT_FILE="$data_dir/vault/secrets.enc"
  export AUDIT_LOG_FILE="$data_dir/logs/audit.log"
  mkdir -p "$data_dir/vault" "$data_dir/logs"
}

# ── Start / Stop ──────────────────────────────────────────────────────
start_backend() {
  log "Starting backend on port $BACKEND_PORT..."
  "$VENV_DIR/bin/python" -m uvicorn app.main:app \
    --host 127.0.0.1 --port "$BACKEND_PORT" \
    --log-level info \
    --app-dir "$BACKEND_DIR" &
  local pid=$!
  echo "backend=$pid" > "$PID_FILE"

  # Wait for backend to respond
  local attempt=0
  while [ "$attempt" -lt 20 ]; do
    attempt=$((attempt + 1))
    sleep 1
    # Check if process is still alive
    if ! kill -0 "$pid" 2>/dev/null; then
      die "Backend process exited. Check error output above."
    fi
    if curl -fsS "http://127.0.0.1:$BACKEND_PORT/health" >/dev/null 2>&1; then
      ok "Backend running (PID $pid)"
      return 0
    fi
  done
  warn "Backend started (PID $pid) but health check not yet passing."
}

start_frontend() {
  log "Starting frontend on port $FRONTEND_PORT..."

  # Create a tiny proxy-aware server script
  local server_script="$PROJECT_DIR/.frontend-server.py"
  cat > "$server_script" << 'PYEOF'
"""Minimal dev server: serves frontend/ static files, proxies /api and /health to backend."""
import http.server
import os
import sys
import urllib.request
import urllib.error

FRONTEND_DIR = sys.argv[1]
BACKEND_URL  = sys.argv[2]

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=FRONTEND_DIR, **kwargs)

    def do_GET(self):
        if self.path.startswith("/api/") or self.path == "/health" or self.path.startswith("/health?"):
            self._proxy("GET")
        else:
            super().do_GET()

    def do_POST(self):
        self._proxy("POST")

    def do_PUT(self):
        self._proxy("PUT")

    def do_DELETE(self):
        self._proxy("DELETE")

    def _proxy(self, method):
        url = BACKEND_URL.rstrip("/") + self.path
        content_len = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_len) if content_len > 0 else None

        headers = {}
        for key in ("Content-Type", "Authorization", "x-bootstrap-token", "x-csrf-token"):
            val = self.headers.get(key)
            if val:
                headers[key] = val

        req = urllib.request.Request(url, data=body, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                resp_body = resp.read()
                self.send_response(resp.status)
                self.send_header("Content-Type", resp.headers.get("Content-Type", "application/json"))
                self.send_header("Content-Length", str(len(resp_body)))
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(resp_body)
        except urllib.error.HTTPError as e:
            body_bytes = e.read()
            self.send_response(e.code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body_bytes)))
            self.end_headers()
            self.wfile.write(body_bytes)
        except Exception as e:
            msg = f'{{"detail":"{e}"}}'.encode()
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)

    def log_message(self, format, *args):
        pass  # suppress request logs for cleanliness

port = int(os.environ.get("FRONTEND_PORT", 3000))
with http.server.HTTPServer(("127.0.0.1", port), Handler) as httpd:
    print(f"Frontend server: http://127.0.0.1:{port}", flush=True)
    httpd.serve_forever()
PYEOF

  "$VENV_DIR/bin/python" "$server_script" "$FRONTEND_DIR" "http://127.0.0.1:$BACKEND_PORT" &
  local pid=$!
  echo "frontend=$pid" >> "$PID_FILE"

  sleep 1
  if kill -0 "$pid" 2>/dev/null; then
    ok "Frontend running (PID $pid)"
  else
    warn "Frontend server may have failed to start."
  fi
}

stop_services() {
  if [ ! -f "$PID_FILE" ]; then
    warn "No running services found."
    return 0
  fi
  while IFS='=' read -r name pid || [ -n "$name" ]; do
    # Skip blank/malformed lines
    [[ -z "$pid" ]] && continue
    if kill -0 "$pid" 2>/dev/null; then
      log "Stopping $name (PID $pid)..."
      kill "$pid" 2>/dev/null || true
      ok "$name stopped"
    fi
  done < "$PID_FILE"
  rm -f "$PID_FILE"
  rm -f "$PROJECT_DIR/.frontend-server.py"
}

print_banner() {
  printf '\n'
  printf '\033[1;36m  🎸 GitVibe is running!\033[0m\n'
  printf '\n'
  printf '  UI:     \033[4mhttp://localhost:%s\033[0m\n' "$FRONTEND_PORT"
  printf '  API:    \033[4mhttp://localhost:%s/api\033[0m\n' "$FRONTEND_PORT"
  printf '  Health: \033[4mhttp://localhost:%s/health\033[0m\n' "$FRONTEND_PORT"
  printf '\n'
  printf '  Stop:   \033[1mbash installer/install-local.sh stop\033[0m\n'
  printf '\n'
}

# ── Main ──────────────────────────────────────────────────────────────
main() {
  local action="${1:-start}"

  case "$action" in
    stop)
      stop_services
      exit 0
      ;;
    start)
      ;;
    *)
      echo "Usage: $0 [start|stop]"
      exit 1
      ;;
  esac

  log "GitVibeDev — Local Installer (no Docker)"
  echo ""

  check_python
  setup_env
  setup_venv
  install_deps
  load_env

  # Stop any previous run
  stop_services 2>/dev/null || true

  start_backend
  start_frontend
  print_banner
}

main "$@"
