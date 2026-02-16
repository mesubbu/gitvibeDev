#!/usr/bin/env bash
set -euo pipefail

# One-command bootstrap:
# curl -fsSL https://example.com/install.sh | bash

log() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

run_privileged() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    die "This step requires elevated privileges and sudo is not available."
  fi
}

detect_os() {
  case "$(uname -s)" in
    Linux) echo "linux" ;;
    Darwin) echo "macos" ;;
    *) die "Unsupported OS. This installer supports Linux and macOS only." ;;
  esac
}

install_docker_linux() {
  log "Installing Docker Engine..."
  local script_file
  script_file="$(mktemp)"
  curl -fsSL https://get.docker.com -o "$script_file" || die "Unable to download Docker installer."
  run_privileged sh "$script_file" || die "Docker installation failed."
  rm -f "$script_file"
  if command -v systemctl >/dev/null 2>&1; then
    run_privileged systemctl enable --now docker >/dev/null 2>&1 || warn "Could not enable Docker service automatically."
  fi
}

install_docker_macos() {
  if ! command -v brew >/dev/null 2>&1; then
    die "Homebrew is required to install Docker on macOS. Install Homebrew first: https://brew.sh"
  fi
  log "Installing Docker Desktop via Homebrew..."
  brew install --cask docker || die "Docker Desktop installation failed."
  open -a Docker >/dev/null 2>&1 || warn "Could not auto-open Docker Desktop. Please launch it manually."
}

ensure_docker() {
  local os
  local attempt
  os="$(detect_os)"
  if ! command -v docker >/dev/null 2>&1; then
    case "$os" in
      linux) install_docker_linux ;;
      macos) install_docker_macos ;;
    esac
  fi

  if ! docker info >/dev/null 2>&1; then
    if [ "$os" = "linux" ] && command -v systemctl >/dev/null 2>&1; then
      run_privileged systemctl start docker >/dev/null 2>&1 || true
    fi
  fi

  if ! docker info >/dev/null 2>&1; then
    log "Waiting for Docker daemon to become available..."
    for attempt in $(seq 1 30); do
      if docker info >/dev/null 2>&1; then
        break
      fi
      sleep 2
    done
  fi

  if ! docker info >/dev/null 2>&1; then
    die "Docker daemon is not running. Start Docker and rerun the installer."
  fi

  if ! docker compose version >/dev/null 2>&1; then
    die "Docker Compose plugin is missing. Install Docker Compose and rerun."
  fi
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
  die "Unable to generate secrets: neither openssl nor python3 is available."
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
  if [ -z "$current" ] || [[ "$current" == CHANGE_ME* ]]; then
    set_env_var "$key" "$(generate_hex 32)" "$file"
  fi
}

ensure_env() {
  local target_dir="$1"
  local env_example="$target_dir/.env.example"
  local env_file="$target_dir/.env"

  [ -f "$env_example" ] || die ".env.example not found in $target_dir"

  if [ ! -f "$env_file" ]; then
    log "Creating .env from .env.example..."
    cp "$env_example" "$env_file"
  fi

  log "Generating secure secrets..."
  ensure_secret "SECRET_KEY" "$env_file"
  ensure_secret "APP_ENCRYPTION_KEY" "$env_file"
  ensure_secret "BOOTSTRAP_ADMIN_TOKEN" "$env_file"
  ensure_secret "POSTGRES_PASSWORD" "$env_file"
  ensure_secret "REDIS_PASSWORD" "$env_file"
}

clone_or_update_repo() {
  local repo_url="$1"
  local target_dir="$2"

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

start_stack() {
  local target_dir="$1"
  log "Starting platform stack..."
  (
    cd "$target_dir"
    docker compose --env-file .env up -d --build
  ) || die "docker compose up failed."
}

print_summary() {
  local env_file="$1"
  local frontend_port
  frontend_port="$(get_env_var FRONTEND_PORT "$env_file")"
  frontend_port="${frontend_port:-3000}"
  printf '\nGitVibeDev is up.\n'
  printf 'Open: http://localhost:%s\n' "$frontend_port"
  printf 'Backend health: http://localhost:%s/health\n\n' "$frontend_port"
}

main() {
  local repo_url="${INSTALL_REPO_URL:-https://github.com/AnshumanAtrey/GitVibeDev.git}"
  local skip_clone="false"
  local skip_up="false"
  local target_dir=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --repo-url)
        repo_url="$2"
        shift 2
        ;;
      --target-dir)
        target_dir="$2"
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
      *)
        die "Unknown option: $1"
        ;;
    esac
  done

  ensure_docker

  if [ "$skip_clone" = "true" ]; then
    target_dir="${target_dir:-$(pwd)}"
  else
    target_dir="${target_dir:-$HOME/$(basename "${repo_url%.git}")}"
    clone_or_update_repo "$repo_url" "$target_dir"
  fi

  ensure_env "$target_dir"

  if [ "$skip_up" = "false" ]; then
    start_stack "$target_dir"
    print_summary "$target_dir/.env"
  fi
}

main "$@"
