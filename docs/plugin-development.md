# Plugin Development Guide

> Documentation version: **v0.2.0**

This guide explains how to build executable plugins for `POST /api/plugins/{plugin_name}/run`.

## How plugin execution works

Plugins run through `PluginSandbox` (`backend/app/plugin_sandbox.py`) with strict validation:

- Sandbox is disabled by default
- Plugin must be explicitly allowlisted
- Name must match regex: `^[a-zA-Z0-9._-]+$`
- Plugin file must exist under `/app/plugins`
- Plugin file must be executable
- Args cannot contain newlines
- Runtime limits:
  - CPU: 2 seconds
  - Memory: 256 MB
  - File size: 10 MB
  - Open files: 64
  - Processes: 32

## Enable plugin execution

In `.env`:

```bash
PLUGIN_SANDBOX_ENABLED=true
PLUGIN_ALLOWLIST=echo-plugin
PLUGIN_TIMEOUT_SECONDS=5
```

Restart backend:

```bash
make down
make up
```

## Create a sample plugin

```bash
mkdir -p plugins

cat > plugins/echo-plugin <<'EOF_PLUGIN'
#!/usr/bin/env bash
set -euo pipefail
printf 'plugin=echo-plugin\n'
printf 'args=%s\n' "$*"
EOF_PLUGIN

chmod +x plugins/echo-plugin
```

## Mount local plugin directory into backend container

Add this backend volume entry in `docker-compose.yml` (development only):

```yaml
- ./plugins:/app/plugins:ro
```

Then restart:

```bash
make down
make up
```

## Run the plugin via API

```bash
curl -sS -X POST http://localhost:3000/api/plugins/echo-plugin/run \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "x-csrf-token: ${CSRF_TOKEN}" \
  -d '{"args":["hello","world"]}'
```

## Production notes

- Keep plugins small and deterministic.
- Prefer read-only plugin mounts.
- Do not pass secrets as command-line args.
- Use audit logs (`AUDIT_LOG_FILE`) to track plugin actions.
