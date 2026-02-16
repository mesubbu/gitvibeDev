#!/usr/bin/env bash
set -euo pipefail

DEFAULT_REPO_URL="https://github.com/mesubbu/gitvibeDev.git"
REPO_URL="$DEFAULT_REPO_URL"
TARGET_DIR="gitvibeDev"
TARGET_DIR_SET=false
SKIP_CLONE=false
SKIP_UP=false
FULL_PROFILE=false
MODE="development"
OS_FAMILY=""

usage() {
  cat <<'EOF'
Usage: bash installer/install.sh [options]

Options:
  --repo-url <url>      Repository URL to clone (default: upstream GitVibeDev repo)
  --target-dir <path>   Target directory (default: ./gitvibeDev, or . with --skip-clone)
  --mode <mode>         Runtime mode: demo | development | production (default: development)
  --skip-clone          Use existing directory instead of cloning
  --skip-up             Prepare .env and secrets, but do not run docker compose
  --full                Start docker compose with the "full" profile (postgres + redis)
  -h, --help            Show this help text
EOF
}

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

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

run_with_privileges() {
  if has_cmd sudo; then
    sudo "$@"
    return
  fi
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
    return
  fi
  die "Root privileges are required for this step. Re-run with sudo."
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo-url)
        [[ $# -ge 2 ]] || die "Missing value for --repo-url"
        REPO_URL="$2"
        shift 2
        ;;
      --target-dir)
        [[ $# -ge 2 ]] || die "Missing value for --target-dir"
        TARGET_DIR="$2"
        TARGET_DIR_SET=true
        shift 2
        ;;
      --mode)
        [[ $# -ge 2 ]] || die "Missing value for --mode"
        MODE="$2"
        shift 2
        ;;
      --skip-clone)
        SKIP_CLONE=true
        shift
        ;;
      --skip-up)
        SKIP_UP=true
        shift
        ;;
      --full)
        FULL_PROFILE=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1 (use --help)"
        ;;
    esac
  done
}

normalize_mode() {
  MODE="$(printf '%s' "$MODE" | tr '[:upper:]' '[:lower:]')"
  case "$MODE" in
    demo|development|production) ;;
    *)
      die "Invalid --mode '$MODE'. Valid values: demo, development, production."
      ;;
  esac
}

detect_os() {
  local raw_os
  raw_os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  case "$raw_os" in
    linux*) OS_FAMILY="linux" ;;
    darwin*) OS_FAMILY="macos" ;;
    *)
      die "Unsupported operating system: $(uname -s). Supported: Linux, macOS."
      ;;
  esac
}

install_docker_if_missing() {
  if has_cmd docker; then
    return
  fi

  warn "Docker is not installed. Attempting automatic installation."
  case "$OS_FAMILY" in
    linux)
      has_cmd curl || die "curl is required to install Docker automatically."
      run_with_privileges sh -c "curl -fsSL https://get.docker.com | sh"
      ;;
    macos)
      if ! has_cmd brew; then
        die "Docker is missing. Install Docker Desktop manually or install Homebrew first."
      fi
      brew install --cask docker
      if has_cmd open; then
        open -a Docker || true
      fi
      ;;
  esac

  has_cmd docker || die "Docker installation did not complete successfully."
}

ensure_docker_running() {
  if docker info >/dev/null 2>&1; then
    return
  fi

  if [[ "$OS_FAMILY" == "linux" ]] && has_cmd systemctl; then
    warn "Docker daemon is not running; attempting to start it."
    if has_cmd sudo; then
      sudo systemctl start docker || true
    else
      systemctl start docker || true
    fi
  fi

  docker info >/dev/null 2>&1 || die "Docker daemon is not running. Start Docker and rerun the installer."
}

ensure_compose_plugin() {
  docker compose version >/dev/null 2>&1 || die "Docker Compose plugin is missing."
}

prepare_workspace() {
  if [[ "$SKIP_CLONE" == true && "$TARGET_DIR_SET" == false ]]; then
    TARGET_DIR="."
  fi

  if [[ "$SKIP_CLONE" == false ]]; then
    has_cmd git || die "git is required when clone is enabled."
    if [[ -e "$TARGET_DIR" ]] && [[ -n "$(ls -A "$TARGET_DIR" 2>/dev/null || true)" ]]; then
      die "Target directory '$TARGET_DIR' already exists and is not empty."
    fi
    info "Cloning repository into '$TARGET_DIR'..."
    git clone "$REPO_URL" "$TARGET_DIR"
  fi

  [[ -d "$TARGET_DIR" ]] || die "Target directory '$TARGET_DIR' does not exist."
  cd "$TARGET_DIR"
  [[ -f docker-compose.yml ]] || die "docker-compose.yml was not found in '$PWD'."
}

set_env_value() {
  local key="$1"
  local value="$2"
  local tmp_file
  tmp_file="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    BEGIN { updated = 0 }
    $0 ~ ("^" key "=") {
      print key "=" value
      updated = 1
      next
    }
    { print }
    END {
      if (!updated) {
        print key "=" value
      }
    }
  ' .env > "$tmp_file"
  mv "$tmp_file" .env
}

get_env_value() {
  local key="$1"
  awk -v key="$key" '
    $0 ~ ("^" key "=") {
      sub("^[^=]*=", "", $0)
      print $0
      exit
    }
  ' .env
}

is_placeholder_value() {
  case "$1" in
    ""|CHANGE_ME*|change_me|postgres_change_me|redis_change_me)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

generate_secret() {
  if has_cmd openssl; then
    openssl rand -hex 32
    return
  fi
  if has_cmd python3; then
    python3 - <<'PY'
import secrets
print(secrets.token_hex(32))
PY
    return
  fi
  od -An -N32 -tx1 /dev/urandom | tr -d ' \n'
  printf '\n'
}

ensure_secret_value() {
  local key="$1"
  local current_value
  current_value="$(get_env_value "$key")"
  if is_placeholder_value "$current_value"; then
    set_env_value "$key" "$(generate_secret)"
    info "Generated secure value for $key."
  fi
}

prepare_env() {
  if [[ ! -f .env ]]; then
    [[ -f .env.example ]] || die ".env.example not found."
    cp .env.example .env
    info "Created .env from .env.example."
  fi

  set_env_value "APP_MODE" "$MODE"
  if [[ "$MODE" == "demo" ]]; then
    set_env_value "DEMO_MODE" "true"
  fi

  ensure_secret_value "SECRET_KEY"
  ensure_secret_value "APP_ENCRYPTION_KEY"
  ensure_secret_value "BOOTSTRAP_ADMIN_TOKEN"
  ensure_secret_value "POSTGRES_PASSWORD"
  ensure_secret_value "REDIS_PASSWORD"
}

start_stack() {
  if [[ "$SKIP_UP" == true ]]; then
    info "Skipping docker compose startup (--skip-up)."
    return
  fi

  if [[ "$MODE" == "demo" && "$FULL_PROFILE" == true ]]; then
    warn "--full is ignored in demo mode."
    FULL_PROFILE=false
  fi

  local -a compose_cmd
  compose_cmd=(docker compose --env-file .env)
  if [[ "$FULL_PROFILE" == true ]]; then
    compose_cmd+=(--profile full)
  fi
  compose_cmd+=(up -d --build)
  if [[ "$MODE" == "demo" ]]; then
    compose_cmd+=(frontend)
  fi

  info "Starting services via docker compose..."
  "${compose_cmd[@]}"
}

print_summary() {
  local frontend_port
  frontend_port="$(get_env_value FRONTEND_PORT)"
  if [[ -z "$frontend_port" ]]; then
    frontend_port="3000"
  fi
  info "Installation complete."
  info "Open: http://localhost:${frontend_port}"
}

main() {
  parse_args "$@"
  normalize_mode
  detect_os
  install_docker_if_missing
  ensure_docker_running
  ensure_compose_plugin
  prepare_workspace
  prepare_env
  start_stack
  print_summary
}

main "$@"
