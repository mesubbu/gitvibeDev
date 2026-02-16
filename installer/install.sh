#!/usr/bin/env bash
set -Eeuo pipefail
trap 'printf "\n[ERROR] Installer failed at line %s while running: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

log() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
GitVibeDev one-click installer

Usage:
  bash installer/install.sh [options]

Options:
  --mode <demo|development|production>  Runtime mode (default: development)
  --full                                Start PostgreSQL + Redis profile (non-demo only)
  --repo-url <url>                      Clone URL when cloning is enabled
  --target-dir <path>                   Target directory for clone/use
  --skip-clone                          Use existing directory (default: current directory)
  --skip-up                             Prepare env only; do not start containers
  -h, --help                            Show this help
EOF
}

to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

resolve_mode() {
  local raw_mode
  raw_mode="$(to_lower "$1")"
  case "$raw_mode" in
    demo|development|production) printf '%s' "$raw_mode" ;;
    *) die "Invalid --mode value: $1 (expected demo|development|production)" ;;
  esac
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

generate_hex() {
  local bytes="${1:-32}"
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "$bytes"
    return
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$bytes" <<'PY'
import secrets
import sys
print(secrets.token_hex(int(sys.argv[1])))
PY
    return
  fi
  die "Unable to generate secrets: install openssl or python3."
}

set_env_var() {
  local key="$1"
  local value="$2"
  local file="$3"
  local temp_file
  temp_file="$(mktemp)"
  awk -v k="$key" -v v="$value" -F= '
    BEGIN { updated = 0 }
    $1 == k { print k "=" v; updated = 1; next }
    { print }
    END { if (updated == 0) print k "=" v }
  ' "$file" > "$temp_file"
  mv "$temp_file" "$file"
}

get_env_var() {
  local key="$1"
  local file="$2"
  grep -E "^${key}=" "$file" | head -n 1 | cut -d= -f2- || true
}

ensure_secret() {
  local key="$1"
  local file="$2"
  local current
  current="$(get_env_var "$key" "$file")"
  if [ -z "$current" ] || [[ "$current" == CHANGE_ME* ]] || [[ "$current" == change_me* ]]; then
    set_env_var "$key" "$(generate_hex 32)" "$file"
  fi
}

clone_or_update_repo() {
  local repo_url="$1"
  local target_dir="$2"

  require_command git
  if [ -d "$target_dir/.git" ]; then
    log "Repository exists, pulling latest changes..."
    git -C "$target_dir" pull --ff-only || die "Failed to update repository in $target_dir"
    return
  fi
  if [ -e "$target_dir" ] && [ -n "$(ls -A "$target_dir" 2>/dev/null)" ]; then
    die "Target directory is not empty: $target_dir"
  fi
  log "Cloning repository..."
  git clone "$repo_url" "$target_dir" || die "Failed to clone repository."
}

ensure_docker_ready() {
  require_command docker
  docker compose version >/dev/null 2>&1 || die "Docker Compose plugin is missing."
  docker info >/dev/null 2>&1 || die "Docker daemon is not running. Start Docker and retry."
}

ensure_env_file() {
  local target_dir="$1"
  local app_mode="$2"
  local env_file="$target_dir/.env"
  local env_example="$target_dir/.env.example"

  [ -f "$env_example" ] || die ".env.example not found in $target_dir"
  if [ ! -f "$env_file" ]; then
    log "Creating .env from .env.example..."
    cp "$env_example" "$env_file"
  fi

  set_env_var "APP_MODE" "$app_mode" "$env_file"
  if [ "$app_mode" = "production" ]; then
    set_env_var "DEPLOY_ENV" "production" "$env_file"
    set_env_var "FAST_BOOT" "false" "$env_file"
    set_env_var "DEMO_MODE" "false" "$env_file"
  elif [ "$app_mode" = "development" ]; then
    set_env_var "DEPLOY_ENV" "development" "$env_file"
    set_env_var "FAST_BOOT" "true" "$env_file"
    set_env_var "DEMO_MODE" "false" "$env_file"
  else
    set_env_var "DEPLOY_ENV" "development" "$env_file"
    set_env_var "FAST_BOOT" "true" "$env_file"
    set_env_var "DEMO_MODE" "true" "$env_file"
  fi

  if [ "$app_mode" != "demo" ]; then
    log "Ensuring secure secrets..."
    ensure_secret "SECRET_KEY" "$env_file"
    ensure_secret "APP_ENCRYPTION_KEY" "$env_file"
    ensure_secret "BOOTSTRAP_ADMIN_TOKEN" "$env_file"
    ensure_secret "POSTGRES_PASSWORD" "$env_file"
    ensure_secret "REDIS_PASSWORD" "$env_file"
  else
    log "APP_MODE=demo: skipping backend secret generation."
  fi
}

start_stack() {
  local target_dir="$1"
  local app_mode="$2"
  local full_profile="$3"

  (
    cd "$target_dir"
    if [ "$app_mode" = "demo" ]; then
      if [ "$full_profile" = "true" ]; then
        warn "--full is ignored for APP_MODE=demo."
      fi
      docker compose --env-file .env up -d frontend
      return
    fi

    if [ "$full_profile" = "true" ]; then
      docker compose --env-file .env --profile full up -d --build
      return
    fi

    docker compose --env-file .env up -d --build
  ) || die "docker compose up failed."
}

print_summary() {
  local target_dir="$1"
  local app_mode="$2"
  local env_file="$target_dir/.env"
  local frontend_port
  frontend_port="$(get_env_var FRONTEND_PORT "$env_file")"
  frontend_port="${frontend_port:-3000}"

  printf '\nGitVibeDev is up.\n'
  printf 'Mode: %s\n' "$app_mode"
  printf 'Open: http://localhost:%s\n' "$frontend_port"
  if [ "$app_mode" = "demo" ]; then
    printf 'Demo mode runs frontend-only with local mock API/auth/storage.\n\n'
    return
  fi
  printf 'Health: http://localhost:%s/health\n' "$frontend_port"
  printf 'Auth status: http://localhost:%s/api/auth/status\n\n' "$frontend_port"
}

main() {
  local repo_url="${INSTALL_REPO_URL:-https://github.com/mesubbu/gitvibeDev.git}"
  local target_dir=""
  local skip_clone="false"
  local skip_up="false"
  local full_profile="false"
  local app_mode="${APP_MODE:-development}"

  while [ $# -gt 0 ]; do
    case "$1" in
      --repo-url)
        [ $# -ge 2 ] || die "Missing value for --repo-url"
        repo_url="$2"
        shift 2
        ;;
      --target-dir)
        [ $# -ge 2 ] || die "Missing value for --target-dir"
        target_dir="$2"
        shift 2
        ;;
      --mode)
        [ $# -ge 2 ] || die "Missing value for --mode"
        app_mode="$2"
        shift 2
        ;;
      --skip-clone)
        skip_clone="true"
        shift
        ;;
      --skip-up)
        skip_up="true"
        shift
        ;;
      --full)
        full_profile="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done

  app_mode="$(resolve_mode "$app_mode")"

  if [ "$skip_clone" = "true" ]; then
    target_dir="${target_dir:-$(pwd)}"
  else
    target_dir="${target_dir:-$HOME/$(basename "${repo_url%.git}")}"
    clone_or_update_repo "$repo_url" "$target_dir"
  fi

  ensure_env_file "$target_dir" "$app_mode"

  if [ "$skip_up" = "false" ]; then
    ensure_docker_ready
    log "Starting stack..."
    start_stack "$target_dir" "$app_mode" "$full_profile"
    print_summary "$target_dir" "$app_mode"
  else
    log "Environment prepared at $target_dir/.env (skip-up enabled)."
  fi
}

main "$@"
