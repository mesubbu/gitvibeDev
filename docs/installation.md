# Installation Guide

> Documentation version: **v0.2.0**

This guide gets GitVibeDev running on Linux or macOS.

## Prerequisites

- Docker Engine running
- Docker Compose plugin (`docker compose` command)
- Git
- Bash

> The installer can auto-install Docker in many cases, but you still need permission to run it.

## Quick start (recommended)

Run from repository root:

```bash
make up
```

What this does:

- Runs `installer/install.sh --skip-clone --target-dir .`
- Creates `.env` from `.env.example` if missing
- Auto-generates secure values for:
  - `SECRET_KEY`
  - `APP_ENCRYPTION_KEY`
  - `BOOTSTRAP_ADMIN_TOKEN`
  - `POSTGRES_PASSWORD`
  - `REDIS_PASSWORD`
- Starts the stack with `docker compose --env-file .env up -d --build`

## Verify installation

```bash
curl -fsS http://localhost:8080/health
curl -fsS http://localhost:8080/api/auth/status
```

## First access token (for protected API calls)

```bash
BOOTSTRAP_TOKEN=$(grep '^BOOTSTRAP_ADMIN_TOKEN=' .env | cut -d= -f2-)

curl -sS           -X POST http://localhost:8080/api/auth/token           -H 'Content-Type: application/json'           -H "x-bootstrap-token: ${BOOTSTRAP_TOKEN}"           -d '{"username":"local-admin","role":"admin"}'
```

Save `access_token`, `refresh_token`, and `csrf_token` from the response.

## Daily operations

```bash
# Stop services (keep volumes)
make down

# Tail logs
make logs

# Rebuild from scratch (removes volumes)
make reset

# Pull + rebuild
make update
```

## Manual installer options

```bash
# Use existing working directory, generate .env and secrets, but do not start services
bash installer/install.sh --skip-clone --target-dir . --skip-up

# Clone into custom path and start
bash installer/install.sh --repo-url https://github.com/your-org/gitvibedev.git --target-dir ~/gitvibedev
```

## Ports and URLs

- Frontend + API gateway: `http://localhost:${FRONTEND_PORT:-8080}`
- Backend health through gateway: `http://localhost:${FRONTEND_PORT:-8080}/health`
- API base through gateway: `http://localhost:${FRONTEND_PORT:-8080}/api`

## Optional: run backend directly (without Docker)

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

> You must still provide compatible Postgres/Redis/Ollama endpoints via environment variables.
