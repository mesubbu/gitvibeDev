# Integration Guide

## Goal

Safely migrate validated preview patterns into production with minimal risk.

## Migration Playbook

### Step 1 — Contract Freeze

- Extract API contract snapshots from backend routes.
- Map production model fields to preview compatibility wrappers.
- Lock screen registry IDs as stable integration keys.

### Step 2 — Design System Adoption

- Introduce token package first (colors, type, spacing, motion, density).
- Migrate one surface at a time: PR Detail → Repositories → Settings.
- Use compatibility wrappers to avoid full model rewrites.

### Step 3 — Navigation Refactor

- Add adaptive navigation shell behind feature flag.
- Keep legacy route tree until parity tests pass.

### Step 4 — Workflow Enhancements

- Roll out contextual actions and progressive disclosure.
- Enable activity/notification panes incrementally.

### Step 5 — Governance

- Validate token version compatibility.
- Record UX deltas and release notes.

## Refactoring Roadmap

1. Baseline token and component extraction
2. Screen registry-based route normalization
3. Role-aware navigation and policy guards
4. Workflow simulation parity checks
5. UX lab experiment promotion policy

## Automated Diff Detection

Use `lib/integration/diff_detector.dart` to compare:

- inferred expected screen IDs,
- currently implemented screen IDs,
- feature map actions vs rendered CTAs,
- model compatibility mappings.

Expected output classes:

- `missing-screen`
- `extra-screen`
- `missing-action-binding`
- `model-field-drift`

## Compatibility Wrappers

`lib/integration/compatibility_wrappers.dart` includes adapters for:

- repositories (`/api/repos` style payloads),
- pull requests (`pull_requests` lists),
- issues (`issues` lists),
- auth/health status payloads.

These wrappers isolate shape drift and prevent UI components from depending on backend-specific payload details.

## Rollout Guardrails

- Never replace all production screens in a single release.
- Require feature parity tests for all migrated surfaces.
- Gate by role and environment flags.
- Keep rollback path via compatibility adapters.
