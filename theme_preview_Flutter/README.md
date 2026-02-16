# Theme Preview Workspace

`theme_preview_Flutter/` is the Flutter adaptation workspace for GitVibeDev UX/theme experimentation and runtime migration.

## Purpose

- Reverse-engineered UI model based on repository features and API surfaces.
- Runtime composer supporting demo and backend-connected modes.
- Reusable design system with tokenized theming and component contracts.
- UX lab for A/B variants, role-based density, and workflow simulation.

## Quick Start

```bash
cd theme_preview_Flutter
flutter pub get
flutter run
```

To run against the backend instead of demo mocks, pass runtime defines:

```bash
flutter run \
  --dart-define=APP_MODE=development \
  --dart-define=API_BASE_URL=http://localhost:3000 \
  --dart-define=BOOTSTRAP_ADMIN_TOKEN=change_me \
  --dart-define=BOOTSTRAP_USERNAME=flutter-operator \
  --dart-define=BOOTSTRAP_ROLE=admin
```

## Workspace Map

- `lib/design_system/` – tokens, theme engine, reusable components
- `lib/runtime/` – mode-aware runtime config, auth session store, HTTP client, runtime factory
- `lib/data/` – repository contract + demo and remote repository implementations
- `lib/screens/` – inferred canonical screens + taxonomy renderer
- `lib/demos/` – scenario-based workflow simulations
- `lib/component_gallery/` – contextual component gallery
- `lib/theme_lab/` – theme tuning, A/B comparison, UX experiments
- `lib/integration/` – compatibility wrappers and diff intelligence
- `docs/` – intelligence reports, UX rationale, governance, migration guide

## Runtime Behavior

- `APP_MODE=demo` uses in-app demo repository and local persistence.
- `APP_MODE=development|production` uses backend APIs with bearer+CSRF request handling.
- Design system remains shared across both runtime paths.
- Theme and UX preferences persist locally (SharedPreferences).

## Phase 4/5 Validation Commands

```bash
cd theme_preview_Flutter
flutter analyze --no-fatal-infos
dart run tool/diff_detector.dart
dart run tool/parity_check.dart
```
