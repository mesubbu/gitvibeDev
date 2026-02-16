# API Documentation

> Documentation version: **v0.2.0**

Base URL (through nginx gateway):

```text
http://localhost:3000
```

API prefix:

```text
/api
```

## Authentication headers

Protected endpoints require:

```http
Authorization: Bearer <access_token>
```

Mutating endpoints (`POST`, `PUT`, `DELETE`) under `/api/` also require:

```http
x-csrf-token: <csrf_token>
```

CSRF exemptions:

- `POST /api/auth/token`
- `POST /api/auth/refresh`

## Health and status

### `GET /health`
Returns health for Postgres, Redis, and configured AI provider.

### `GET /api/auth/status`
Returns auth mode and feature readiness flags.

## Auth endpoints

### `POST /api/auth/token`

Issue access + refresh tokens using bootstrap header.

```bash
BOOTSTRAP_TOKEN=$(grep '^BOOTSTRAP_ADMIN_TOKEN=' .env | cut -d= -f2-)

curl -sS -X POST http://localhost:3000/api/auth/token           -H 'Content-Type: application/json'           -H "x-bootstrap-token: ${BOOTSTRAP_TOKEN}"           -d '{"username":"alice","role":"admin"}'
```

### `POST /api/auth/refresh`

```bash
curl -sS -X POST http://localhost:3000/api/auth/refresh           -H 'Content-Type: application/json'           -d '{"refresh_token":"<refresh_token>"}'
```

### `POST /api/auth/rotate-signing-key` (admin)

## GitHub OAuth endpoints

### `GET /api/github/oauth/start`

Query params:

- `owner_hint` (optional if authenticated)
- `scope` (default `repo read:org`)
- `redirect_uri` (optional; falls back to configured default)

Example:

```bash
curl -sS "http://localhost:3000/api/github/oauth/start?owner_hint=alice"
```

### `GET /api/github/oauth/callback`

Query params:

- `code` (required)
- `state` (required)
- `redirect_uri` (optional)

### `GET /api/github/oauth/{owner}` (viewer)

Returns stored token metadata (not raw token).

## Repo and collaboration endpoints

### `GET /api/repos`

Query params:

- `limit` (`1..100`, default `50`)
- `oauth_owner` (required outside demo mode unless token subject matches desired owner)
- `git_provider` (`github` default; `demo` available in demo mode)

### `GET /api/repos/{owner}/{repo_name}/pulls`

Query params:

- `state` = `open|closed|all`
- `limit` (`1..100`)
- `oauth_owner` (non-demo)
- `git_provider` (`github` default)

Legacy route still supported:

- `GET /api/repos/{repo_name}/pulls?owner=<org_or_user>`

### `GET /api/repos/{owner}/{repo_name}/issues`

Query params:

- `state` = `open|closed|all`
- `limit` (`1..100`)
- `oauth_owner` (non-demo)
- `git_provider` (`github` default)

### `POST /api/repos/{owner}/{repo_name}/pulls/{pull_number}/merge`

Body:

```json
{
  "merge_method": "squash",
  "commit_title": "optional custom title"
}
```

- Requires `operator` role in non-demo mode
- Supports `git_provider` query param (`github` default)

### `GET /api/repos/{owner}/{repo_name}/collaborators`

Query params: `limit`, `oauth_owner`, `git_provider`

### `PUT /api/repos/{owner}/{repo_name}/collaborators/{username}`

Body:

```json
{ "permission": "push" }
```

- Requires `admin` role in non-demo mode
- Supports `git_provider` query param (`github` default)

### `DELETE /api/repos/{owner}/{repo_name}/collaborators/{username}`

- Requires `admin` role in non-demo mode
- Supports `git_provider` query param (`github` default)

## AI endpoints

### `GET /api/ai/status`

Provider and model health status.

### `POST /api/ai/review`

Synchronous review.

```bash
curl -sS -X POST http://localhost:3000/api/ai/review           -H 'Content-Type: application/json'           -H "Authorization: Bearer ${ACCESS_TOKEN}"           -H "x-csrf-token: ${CSRF_TOKEN}"           -d '{
    "owner":"demo-org",
    "repo":"platform-api",
    "pull_number":42,
    "focus":"security and correctness"
  }'
```

### `POST /api/ai/review/jobs`

Queue async review job.

```bash
curl -sS -X POST http://localhost:3000/api/ai/review/jobs           -H 'Content-Type: application/json'           -H "Authorization: Bearer ${ACCESS_TOKEN}"           -H "x-csrf-token: ${CSRF_TOKEN}"           -d '{
    "owner":"demo-org",
    "repo":"platform-api",
    "pull_number":42,
    "focus":"security and maintainability",
    "max_retries":2
  }'
```

### `GET /api/jobs/{job_id}`

Poll async job status (`queued`, `running`, `completed`, `failed`).

## Platform and framework endpoints

### `GET /api/git/providers`

Lists configured git providers and capabilities.

### `GET /api/platform/service-boundaries`

Returns service boundary ownership and dependencies.

### `GET /api/platform/events`

Returns known event topics and recent event envelopes.

### `GET /api/plugins`

Returns plugin manifests (name, version, permissions, runtime, extension points).

### `GET /api/plugins/extension-points`

Lists available plugin/workflow extension points.

### `GET /api/plugins/{plugin_name}`

Returns a single plugin manifest.

### `GET /api/agents`

Lists registered agents with capabilities and versions.

### `POST /api/agents/{agent_name}/run`

Runs an agent with payload:

```json
{
  "payload": {},
  "oauth_owner": "optional-owner",
  "git_provider": "github"
}
```

### `GET /api/workflows`

Lists registered workflow definitions.

### `POST /api/workflows/{workflow_name}/run`

Runs a workflow with payload:

```json
{
  "payload": {},
  "oauth_owner": "optional-owner",
  "git_provider": "github"
}
```

## Plugin endpoint

### `POST /api/plugins/{plugin_name}/run` (admin)

Body:

```json
{ "args": ["arg1", "arg2"] }
```

Returns sandboxed process output:

- `status`
- `return_code`
- `stdout`
- `stderr`

## Demo mode differences

With `DEMO_MODE=true`:

- Most read operations work without bearer token.
- GitHub OAuth endpoints return demo responses.
- Repo/PR/issue/collaborator actions are simulated in-memory.
