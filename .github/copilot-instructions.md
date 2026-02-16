# Copilot Instructions for GitVibeDev

## Build, test, and lint commands

### Build / run
- Start the full stack: `make up`
  - This delegates to `installer/install.sh --skip-clone --target-dir .`, which ensures Docker is ready, creates `.env` from `.env.example` when missing, generates required secrets, and runs `docker compose --env-file .env up -d --build`.
- Stop services: `make down`
- Recreate containers and volumes: `make reset`
- Update code/images and restart: `make update`
- Stream logs: `make logs`

### Test
- There is currently no committed automated test suite or CI test workflow.
- Full stack smoke test: `curl -fsS http://localhost:${FRONTEND_PORT:-8080}/health`
- Single endpoint smoke test: `curl -fsS http://localhost:${FRONTEND_PORT:-8080}/api/auth/status`

### Lint
- There is currently no committed lint/format command configuration in this repository.

## High-level architecture

- Runtime is Docker Compose based (`docker-compose.yml`) with five services: `frontend` (nginx), `backend` (FastAPI), `postgres`, `redis`, and `ollama`.
- `frontend/nginx.conf` serves `frontend/index.html`, proxies `/api/*` to `backend:8000/api/*`, and proxies `/health` to backend health.
- `backend/app/main.py` exposes API/auth/health endpoints and performs dependency checks for Postgres, Redis, and Ollama in `/health`.
- Security/auth stack is centralized in `backend/app/security.py`: JWT issuing/verification/rotation, CSRF validation, RBAC, request-size limits, rate limiting, secure headers, and audit logging middleware.
- Sensitive token/security state is persisted in encrypted local storage (`backend/app/vault.py`, default `/data/vault/secrets.enc`), while audit events are written as JSON-lines (default `/data/logs/audit.log`).
- Local setup flow is installer-first (`installer/install.sh`), and `Makefile` is a thin wrapper around installer/compose commands.

## Key conventions in this codebase

- Environment-first configuration: defaults and operational toggles come from `.env` / env vars (see `.env.example` and `SecurityConfig.from_env()`).
- Demo behavior is explicit and default-on (`DEMO_MODE=true`): demo repo/PR endpoints return in-memory data from `DemoDataService`; when demo mode is off, those endpoints require OAuth-backed auth.
- Role checks use `Depends(require_role(...))` with fixed role levels (`viewer` < `operator` < `admin`); follow this pattern for new protected routes.
- Mutating `/api/*` routes require CSRF (`x-csrf-token`) tied to the access token, except explicitly exempt auth paths in `CSRF_EXEMPT_PATHS`.
- OAuth and token metadata are stored in the encrypted vault (key pattern: `oauth::{provider}::{owner}`), not in plaintext files or hardcoded constants.
- Security-relevant actions should emit structured audit events through `AuditLogger.security(...)`; request auditing is handled globally by middleware.
- Plugin execution is deny-by-default: sandbox is disabled unless enabled, plugin names are validated, and execution requires explicit allowlisting (`PLUGIN_ALLOWLIST`).
