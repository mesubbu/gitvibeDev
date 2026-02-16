# Troubleshooting Guide

> Documentation version: **v0.2.0**

## Quick diagnostics

```bash
make logs
curl -sS http://localhost:3000/health
curl -sS http://localhost:3000/api/auth/status
```

## Installer says Docker is not running

Symptom:

- `Docker daemon is not running. Start Docker and rerun the installer.`

Fix:

- Start Docker Desktop / daemon
- Re-run `make up`

## `docker compose` command missing

Symptom:

- `Docker Compose plugin is missing.`

Fix:

- Install Docker Compose plugin
- Verify with:

```bash
docker compose version
```

## `/health` returns `degraded`

Check service details:

```bash
curl -sS http://localhost:3000/health
```

Then inspect service logs:

```bash
docker compose --env-file .env logs backend
docker compose --env-file .env logs postgres
docker compose --env-file .env logs redis
docker compose --env-file .env logs ollama
```

## `401 Invalid bootstrap token`

Ensure header value comes from `.env`:

```bash
grep '^BOOTSTRAP_ADMIN_TOKEN=' .env
```

## `403 CSRF token is missing or invalid`

For mutating `/api/*` endpoints, send:

- `Authorization: Bearer <access_token>`
- `x-csrf-token: <csrf_token from token issuance>`

## GitHub OAuth issues

### `GitHub OAuth is not configured`

Set these in `.env`:

```bash
GITHUB_APP_CLIENT_ID=...
GITHUB_APP_CLIENT_SECRET=...
GITHUB_OAUTH_REDIRECT_URI=http://localhost:3000/api/github/oauth/callback
```

### `OAuth redirect URI mismatch`

Ensure the redirect URI in GitHub App settings and request query exactly match.

## AI provider errors

### Ollama not reachable

- Check `OLLAMA_BASE_URL`
- Verify Ollama service is running

### OpenAI-compatible key missing

Symptom includes:

- `OPENAI_API_KEY is required for OpenAI-compatible provider.`

Fix:

```bash
AI_PROVIDER=openai-compatible
OPENAI_API_KEY=YOUR_KEY
```

Restart services after changing `.env`.

## Plugin execution blocked

Common causes:

- `PLUGIN_SANDBOX_ENABLED=false`
- plugin not in `PLUGIN_ALLOWLIST`
- plugin file not executable
- plugin path outside `/app/plugins`

## Job stuck in queue or repeatedly failing

Inspect job status:

```bash
curl -sS http://localhost:3000/api/jobs/<job_id> -H "Authorization: Bearer ${ACCESS_TOKEN}"
```

Check `last_error` in response and backend logs:

```bash
docker compose --env-file .env logs backend
```

Tune retries/polling if needed:

```bash
JOB_QUEUE_POLL_SECONDS=1
JOB_RETRY_BASE_SECONDS=2
```

## Hard reset local environment

```bash
make reset
```

This removes containers and volumes, then rebuilds.
