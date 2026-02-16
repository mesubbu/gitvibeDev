# GitVibeDev Flutter Adaptation Plan

## Objective
Adapt GitVibeDev from the current vanilla-JS SPA to a Flutter application by integrating the standalone theme/design system from `theme_preview_Flutter` while preserving backend contracts and runtime behavior.

## Status
- [x] Phase 1 - Contract freeze and target architecture
- [x] Phase 2 - Theme system extraction and integration
- [x] Phase 3 - Runtime and data boundary
- [x] Phase 4 - Feature migration in parity order
- [x] Phase 5 - Validation and rollout

## Workplan
- [x] **Phase 1 - Contract freeze and target architecture**
  - [x] Snapshot API contracts used by the current SPA.
  - [x] Finalize Flutter app module layout and deployment target order.
  - [x] Define route/state parity matrix for `repos`, `pulls`, `issues`, `pr-detail`, `settings`.
- [x] **Phase 2 - Theme system extraction and integration**
  - [x] Make `theme_preview_Flutter/lib/design_system/*` canonical for the product app.
  - [x] Reuse `AppThemeEngine` and core design-system components in the new app shell.
  - [x] Port runtime theme controls (theme mode, variant, density, work mode, role context).
- [x] **Phase 3 - Runtime and data boundary**
  - [x] Implement Flutter runtime composer equivalent to JS `createRuntime()`.
  - [x] Reuse compatibility wrappers for API payload normalization.
  - [x] Add bearer + CSRF-aware request pipeline for mutating `/api/*` operations.
- [x] **Phase 4 - Feature migration in parity order**
  - [x] Repositories list and repo context navigation.
  - [x] Pull request queue and PR detail workspace (merge + AI review polling).
  - [x] Issues and Settings/Health/Auth surfaces.
- [x] **Phase 5 - Validation and rollout**
  - [x] Run parity checks for actions, role guards, and error states.
  - [x] Run structural diff checks for screens/actions/model drift.
  - [x] Prepare rollout gate/checklist command set for Flutter-web cutover.

## Phase 1 Outputs

### 1) Contract snapshot for Flutter client

Security baseline:
- Protected endpoints require `Authorization: Bearer <access_token>`.
- Mutating `/api/*` endpoints require `x-csrf-token` except:
  - `POST /api/auth/token`
  - `POST /api/auth/refresh`
- In demo mode, read flows are available without bearer for primary repo/PR/issue surfaces.

| Endpoint | Purpose | Request shape | Response shape (frozen keys used by UI) |
|---|---|---|---|
| `GET /health` | runtime health banner | none | `status`, `app_mode`, `ai_provider`, `demo_mode`, `services: {name: {ok, detail}}` |
| `GET /api/auth/status` | mode/auth status | none | `authenticated`, `app_mode`, `mode`, `github_app_ready`, `rbac_enabled`, `csrf_protection_enabled`, `token_rotation_enabled`, `ai_provider` |
| `GET /api/repos` | repositories list | query: `limit`, `oauth_owner`, `git_provider` | `provider`, optional `owner`, `repos[]` |
| `GET /api/repos/{owner}/{repo}/pulls` | PR queue | query: `state`, `limit`, `oauth_owner`, `git_provider` | `provider`, `owner`, `repo`, `pull_requests[]` |
| `GET /api/repos/{owner}/{repo}/issues` | issue list | query: `state`, `limit`, `oauth_owner`, `git_provider` | `provider`, `owner`, `repo`, `issues[]` |
| `POST /api/repos/{owner}/{repo}/pulls/{pull_number}/merge` | merge action | body: `merge_method`, optional `commit_title` | provider-specific merge outcome; UI expects `merged` and message/status fields |
| `POST /api/ai/review/jobs` | async AI review | body: `owner`, `repo`, `pull_number`, optional `focus`, optional `oauth_owner`, `git_provider`, `max_retries` | `job` object with queued metadata (`id`, `status`, timestamps) |
| `GET /api/jobs/{job_id}` | poll async AI job | path: `job_id` | `job` object with `status` and optional `result`/`error` |

Normalization rule:
- Preserve wrapper behavior from `theme_preview_Flutter/lib/integration/compatibility_wrappers.dart` so UI can handle minor shape drift (for example `stars` vs `stargazers_count`, `author` vs `user`).

### 2) Target Flutter app module layout (Phase 1 architecture)

Recommended new app root: `frontend_flutter/`

```text
frontend_flutter/
  lib/
    app/
      bootstrap.dart
      app_shell.dart
      router.dart
      app_state.dart
    runtime/
      runtime_config.dart
      runtime_factory.dart
      auth_provider.dart
    data/
      api/
        http_api_client.dart
      demo/
        demo_repository.dart
      adapters/
        compatibility_wrappers.dart
      repositories/
        gitvibe_repository.dart
    features/
      repositories/
      pull_requests/
      issues/
      pr_detail/
      settings/
    design_system/   (ported from theme_preview_Flutter/lib/design_system)
    shared/
      models/
      widgets/
      utils/
  web/
  test/
```

Deployment target order:
1. Flutter Web first (matches current browser + Nginx deployment path).
2. Keep JS SPA as fallback during parity rollout.
3. Add mobile shells after web parity is complete.

### 3) Route/state parity matrix from current SPA

| Existing SPA view/state | Current JS behavior | Required frozen state | Flutter parity target |
|---|---|---|---|
| `repos` | loads repos via `GET /api/repos` | `repos`, `loading.repos`, `error` | `RepositoriesPage` + repository list state |
| `pulls` | loads pulls for selected repo | `selectedRepo`, `pulls`, `loading.pulls`, `error` | `PullRequestsPage` scoped by selected repo |
| `issues` | loads issues for selected repo | `selectedRepo`, `issues`, `loading.issues`, `error` | `IssuesPage` scoped by selected repo |
| `pr-detail` | merge actions + AI review/polling | `selectedRepo`, `selectedPR`, `aiJobId`, `aiReview` | `PrDetailPage` with merge and async AI review workflow |
| `settings` | runtime mode/health/auth/theme | `health`, `authStatus`, `theme`, `appMode` | `SettingsPage` with runtime diagnostics and theme controls |

Global parity state to preserve:
- `appMode`, `theme`, `health`, `authStatus`, shared error/loading flags.
- keyboard-first productivity shortcuts can be added after route parity is stable.

## Phase 2 Outputs

- Added canonical design-system barrel export at `theme_preview_Flutter/lib/design_system/design_system.dart`.
- Kept app shell/theme bootstrap bound to `AppThemeEngine` and design-system components.
- Retained persisted runtime theme controls in app state (`themeMode`, `variant`, `density`, `workMode`, `role`, `deviceType`, `complexity`).

## Phase 3 Outputs

- Added runtime config and factory:
  - `theme_preview_Flutter/lib/runtime/runtime_config.dart`
  - `theme_preview_Flutter/lib/runtime/runtime_factory.dart`
- Added auth/token persistence and HTTP client with bearer + CSRF handling:
  - `theme_preview_Flutter/lib/runtime/auth_session_store.dart`
  - `theme_preview_Flutter/lib/runtime/http_api_client.dart`
- Added repository abstraction and remote API-backed implementation:
  - `theme_preview_Flutter/lib/data/gitvibe_repository.dart`
  - `theme_preview_Flutter/lib/data/remote_repository.dart`
- Wired app bootstrap/state to runtime composition so demo and backend modes can share the same themed UI shell.

## Phase 4 Outputs

- Completed parity surfaces in Flutter renderer:
  - repositories
  - pull requests
  - pr detail
  - issues
  - settings/auth diagnostics
- Added explicit settings diagnostics screen to map parity state for:
  - `/health`
  - `/api/auth/status`
  - local runtime/theme controls
- Hardened core screen async behavior with user-visible error states and retry paths for:
  - dashboard/repositories/pulls/pr-detail/issues/settings/system-health
  - merge and AI-review actions now surface failures instead of silent async crashes.

## Phase 5 Outputs

- Added structural+parity automation command:
  - `theme_preview_Flutter/tool/parity_check.dart`
- Extended feature-map coverage and diff normalization so structural checks track:
  - support/system screens
  - edge/exception screens
  - component gallery + settings parity
- Updated validation runbook:
  - `flutter analyze --no-fatal-infos`
  - `dart run tool/diff_detector.dart`
  - `dart run tool/parity_check.dart`

## Rollout Note

Flutter Web cutover remains intentionally gated behind parity-check pass criteria and deployment decision in the primary frontend pipeline.
