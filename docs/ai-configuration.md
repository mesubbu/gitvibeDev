# AI Configuration Guide

> Documentation version: **v0.2.0**

GitVibeDev uses a provider abstraction in `backend/app/ai_service.py`.

Supported providers:

- `ollama` (default)
- `openai-compatible` (also accepts `openai` / `openai_compatible`)

## Configure Ollama (default)

In `.env`:

```bash
AI_PROVIDER=ollama
OLLAMA_BASE_URL=http://ollama:11434
OLLAMA_MODEL=llama3.2
```

Start stack and check health:

```bash
make up
curl -fsS http://localhost:8080/api/ai/status
```

## Configure OpenAI-compatible API

In `.env`:

```bash
AI_PROVIDER=openai-compatible
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_API_KEY=YOUR_API_KEY
OPENAI_MODEL=gpt-4o-mini
```

Restart services:

```bash
make down
make up
```

## Run synchronous AI review

```bash
curl -sS -X POST http://localhost:8080/api/ai/review           -H 'Content-Type: application/json'           -H "Authorization: Bearer ${ACCESS_TOKEN}"           -H "x-csrf-token: ${CSRF_TOKEN}"           -d '{
    "owner":"demo-org",
    "repo":"platform-api",
    "pull_number":42,
    "focus":"security only"
  }'
```

## Run asynchronous AI review job with retries

```bash
RESPONSE=$(curl -sS -X POST http://localhost:8080/api/ai/review/jobs           -H 'Content-Type: application/json'           -H "Authorization: Bearer ${ACCESS_TOKEN}"           -H "x-csrf-token: ${CSRF_TOKEN}"           -d '{
    "owner":"demo-org",
    "repo":"platform-api",
    "pull_number":42,
    "focus":"correctness and edge cases",
    "max_retries":3
  }')

echo "$RESPONSE"
```

Poll job status:

```bash
JOB_ID=<paste_job_id>
curl -sS "http://localhost:8080/api/jobs/${JOB_ID}"           -H "Authorization: Bearer ${ACCESS_TOKEN}"
```

## Queue tuning

In `.env`:

```bash
JOB_QUEUE_POLL_SECONDS=1
JOB_RETRY_BASE_SECONDS=2
```

Retry delay formula:

```text
delay = JOB_RETRY_BASE_SECONDS * attempt_number
```

## Prompt behavior

AI reviews are built from:

- repository + PR metadata
- PR body
- unified diff (clipped at 30,000 chars)
- optional `focus` text

System prompt asks for markdown with:

- Summary
- Critical Issues
- Improvements
