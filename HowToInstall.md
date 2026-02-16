# How to Deploy GitVibeDev Locally (Without `installer/` Scripts)

This guide starts GitVibeDev locally without running `installer/install.sh` or `installer/install-local.sh`.

## 1) Prerequisites

- Docker Engine
- Docker Compose plugin (`docker compose`)
- Git
- `curl`

## 2) Clone the repository

```bash
git clone https://github.com/mesubbu/gitvibeDev.git
cd gitvibeDev
```

## 3) Create your environment file

```bash
cp .env.example .env
```

## 4) Set secure values in `.env`

Open `.env` and replace these keys with strong random values:

- `SECRET_KEY`
- `APP_ENCRYPTION_KEY`
- `BOOTSTRAP_ADMIN_TOKEN`
- `POSTGRES_PASSWORD`
- `REDIS_PASSWORD`

You can generate values with:

```bash
openssl rand -hex 32
```

Repeat the command for each value you need.

## 5) Choose runtime mode

Set `APP_MODE` in `.env`:

- `APP_MODE=demo` → frontend-only mock runtime, no backend dependency
- `APP_MODE=development` → real backend API mode
- `APP_MODE=production` → production mode (demo blocked when `DEPLOY_ENV=production`)

## 6) Start the app (default local stack)

```bash
docker compose --env-file .env up -d --build
```

This starts:
- `frontend` (nginx, exposed on `http://localhost:3000`)
- `backend` (FastAPI)
- `ollama`

For a strict demo run without backend:

```bash
APP_MODE=demo docker compose --env-file .env up -d frontend
```

## 7) Verify it is running

For `APP_MODE=development` or `APP_MODE=production`:

```bash
docker compose --env-file .env ps
curl -fsS http://localhost:3000/health
curl -fsS http://localhost:3000/api/auth/status
```

For strict frontend-only demo (`APP_MODE=demo` + only `frontend` service), verify UI availability instead:

```bash
docker compose --env-file .env ps
curl -fsS http://localhost:3000/
```

## 8) Open the app

Go to:

```text
http://localhost:3000
```

## 9) (Optional) Start PostgreSQL + Redis too

```bash
docker compose --env-file .env --profile full up -d --build
```

## 10) Useful operations

```bash
# Tail logs
docker compose --env-file .env logs -f --tail=200

# Stop containers (keep volumes)
docker compose --env-file .env down

# Stop and delete volumes (clean reset)
docker compose --env-file .env down -v --remove-orphans
```
