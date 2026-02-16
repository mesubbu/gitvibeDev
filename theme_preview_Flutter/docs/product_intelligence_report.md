# Product Intelligence Report

## Scope and Method

This report reverse-engineers GitVibeDev behavior from:

- Frontend navigation/state (`frontend/app.js`)
- Backend route/model surface (`backend/app/main.py`)
- Security and RBAC (`backend/app/security.py`)
- Demo provider behavior (`backend/app/demo_service.py`)
- Runtime feature flags (`APP_MODE`, `DEMO_MODE`, `FAST_BOOT`)

## Product Thesis

GitVibeDev is an AI-assisted pull request operations console with extensibility primitives (plugins, agents, workflows). It is optimized for:

1. fast review loops,
2. secure/self-hosted deployment,
3. progressive automation.

## Inferred User Types

| User Type | Primary Goal | Access Envelope |
|---|---|---|
| Viewer | Observe repo/PR/issue health | Read-only screens and status views |
| Operator | Execute delivery actions | Merge PRs, run workflows/agents |
| Admin | Govern security + automation | Collaborator control, plugin execution, key rotation |
| Demo Evaluator | Product trial without infra | Frontend-only mock runtime (`APP_MODE=demo`) |

RBAC is explicit: `viewer < operator < admin`.

## Feature Flags and Runtime Modes

| Flag | Effect |
|---|---|
| `APP_MODE=demo` | Frontend-only runtime, mock API/auth, local persistence |
| `APP_MODE=development` | Real backend API and auth stack |
| `APP_MODE=production` | Hardened runtime; demo blocked with `DEPLOY_ENV=production` |
| `FAST_BOOT=true` | Skips optional external dependency checks |
| `DEMO_MODE` | Legacy backend fallback when `APP_MODE` is unset |

## Feature Map

```text
User Type → Features → Screens → Actions → Data Flow
```

| User Type | Features | Screens | Actions | Data Flow |
|---|---|---|---|---|
| Viewer | Repo visibility, PR triage, issue browsing | Repositories, Pull Requests, Issues | Select repo, inspect PR/issue | `/api/repos` → `/pulls`/`/issues` → UI state store |
| Operator | Merge + AI review orchestration | PR Detail, Workflow Demos | Merge (merge/squash/rebase), start AI review | `/api/repos/.../merge`, `/api/ai/review/jobs`, `/api/jobs/{id}` polling |
| Admin | Security and collaboration governance | Settings, Advanced Settings (inferred), Moderation (inferred) | Rotate signing keys, collaborator upsert/remove, plugin execution | `/api/auth/rotate-signing-key`, `/api/repos/.../collaborators`, `/api/plugins/{name}/run` |
| Demo Evaluator | Zero-backend product trial | Dashboard, Onboarding, Theme Lab | Simulate workflows, toggle variants, inspect outcomes | Mock repository + IndexedDB/local prefs |

## Existing Screen and Navigation Intelligence

Implemented frontend screens:

- Repositories
- Pull Requests
- Issues
- PR Detail
- Settings

Navigation is state-machine driven (`state.view`) with keyboard accelerators (`r`, `s`, `t`, `Esc`).

## Core Backend Workflow Patterns

1. **AI Review Sync + Async Paths**
   - Immediate review endpoint and queued job endpoint.
   - Job polling from frontend.

2. **Provider Abstraction**
   - Git provider router (GitHub/GitLab/Demo).
   - AI provider abstraction (Ollama/OpenAI-compatible).

3. **Automation Platform Skeleton**
   - Plugin framework, agent framework, workflow engine, event bus.

4. **Security-first Pipeline**
   - JWT/refresh rotation, CSRF policy, rate limiting, audit logs.

## Business Logic and Engagement Mechanics (Inferred)

No payment/subscription mechanics are present. Engagement mechanics are product-driven:

- low-friction demo mode,
- “one-click AI review” interaction loop,
- keyboard-first review workflow,
- extensibility hooks that increase retention for power teams.

## Missing / Fragmented UX Flows

1. No explicit onboarding and role-based setup wizard.
2. No notification center despite async jobs/events.
3. No activity timeline for merge/plugin/workflow audit events in UI.
4. No analytics workspace for review throughput and quality trends.
5. No progressive disclosure for advanced operations (plugins/workflows) in current shell.
6. No recovery UX for failed job retries and rollback guidance.

## Redundancies and Consolidation Opportunities

- Settings currently combines health/auth/theme; split into:
  - Runtime status,
  - Security/auth,
  - Preferences.
- PR detail can absorb issue context and recent activity to reduce context switching.
- Merge action cluster should be contextual with policy-aware defaults (e.g., squash for selected repos).

## Unimplemented but Implied Features

Inferred from existing backend/platform primitives:

- workflow run history and replay,
- event stream observability,
- plugin permission audit viewer,
- environment policy management,
- role-scoped analytics dashboards.

## Assumptions

- Frontend and backend remain decoupled through API contracts.
- Demo-mode parity should mirror real workflow semantics, not static placeholders.
- Extensibility endpoints represent near-term product roadmap, not dead code.
