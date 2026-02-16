# Architecture Overview

> Documentation version: **v0.2.0**

## High-level system

GitVibeDev is a Docker Compose stack with four data/runtime dependencies and one API service.

```text
Browser
  -> Nginx frontend (serves UI + proxies /api and /health)
  -> FastAPI backend
     -> PostgreSQL (persistence)
     -> Redis (runtime dependency checks)
     -> Ollama or OpenAI-compatible endpoint (AI review)
     -> Encrypted local vault file (/data/vault/secrets.enc)
```

## Runtime services

| Service | Purpose | Source |
|---|---|---|
| `frontend` (nginx) | Serves UI and proxies API | `frontend/index.html`, `frontend/nginx.conf` |
| `backend` (FastAPI) | Auth, GitHub integration, repo/PR/issue actions, AI review, plugin run | `backend/app/main.py` |
| `postgres` | App persistence dependency | `docker-compose.yml` |
| `redis` | Queue/runtime dependency and health dependency | `docker-compose.yml` |
| `ollama` | Local default AI inference | `docker-compose.yml` |

## Backend module map

- `app/main.py`: API routing and dependency wiring
- `app/security.py`: JWT, CSRF, RBAC, rate-limit, secure headers, audit logging
- `app/github_service.py`: GitHub OAuth + GitHub REST wrappers
- `app/ai_service.py`: AI provider abstraction (`ollama`, `openai-compatible`)
- `app/job_queue.py`: Persistent async job queue with retries (stored in encrypted vault)
- `app/vault.py`: Encrypted JSON vault using Fernet-derived key
- `app/plugin_sandbox.py`: Strict plugin execution sandbox
- `app/demo_service.py`: Demo-mode in-memory repos/PRs/issues/collaborators

## Request flow examples

### 1) Bootstrap auth flow

1. Client sends `POST /api/auth/token` with `x-bootstrap-token`.
2. Backend verifies bootstrap token from env/config.
3. `TokenService` returns access + refresh + csrf tokens.

### 2) GitHub OAuth flow

1. Client calls `GET /api/github/oauth/start`.
2. Backend creates short-lived OAuth state and authorization URL.
3. GitHub redirects to `GET /api/github/oauth/callback`.
4. Backend exchanges code for token and stores it encrypted in the vault.

### 3) AI review async flow

1. Client submits `POST /api/ai/review/jobs`.
2. Job queue persists job payload (`background_job_queue_state`) in vault.
3. Worker processes job and retries failures with backoff.
4. Client polls `GET /api/jobs/{job_id}` for status/result.

## Security model

- JWT access/refresh with rotating signing keys
- Role-based access levels: `viewer < operator < admin`
- CSRF required for mutating `/api/*` calls (except token/refresh)
- Request-size limits and IP rate limiting middleware
- Audit events written as JSON lines (`/data/logs/audit.log`)
- Vault and audit files force restrictive permissions (`0700` dir / `0600` file where possible)

## Demo mode behavior

When `DEMO_MODE=true`:

- Read endpoints can work without bearer token
- Repo/PR/issue/collaborator data comes from `DemoDataService`
- Merge and collaborator changes are simulated in-memory
- GitHub OAuth callback/start endpoints return demo-safe responses
