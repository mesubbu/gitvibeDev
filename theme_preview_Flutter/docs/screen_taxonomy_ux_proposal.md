# Screen Taxonomy + UX Proposal

## Canonical Screen Set (Inferred)

### Core Screens

1. **Dashboard**
2. **Repositories**
3. **Pull Requests**
4. **PR Detail / Review Workspace**
5. **Issues**

### Secondary Screens

6. **Onboarding**
7. **Notifications Inbox**
8. **Activity Timeline**
9. **Analytics Overview**

### Admin / Power Screens

10. **Advanced Settings**
11. **Moderation & Access Control**
12. **Workflow Runs & Automation Console**
13. **Plugin/Agent Catalog**

### Support / System Screens

14. **System Health & Dependencies**
15. **Audit and Security Signals**
16. **Error Recovery Center**

### Edge / Exception Screens

17. **Rate Limit / Permission Denied**
18. **Provider Misconfiguration**
19. **Offline / degraded fallback**

## Classification Matrix

| Screen | Class | Entry Point | Primary Actor |
|---|---|---|---|
| Dashboard | Core | App launch | All |
| Repositories | Core | Primary nav | Viewer/Operator |
| Pull Requests | Core | Repo drill-down | Viewer/Operator |
| PR Detail | Core | PR select | Operator |
| Issues | Core | Repo tabs | Viewer |
| Onboarding | Secondary | First-use or reset | Demo evaluator |
| Notifications | Secondary | Header badge | All |
| Activity Timeline | Secondary | Context panel | Operator/Admin |
| Analytics | Secondary | Insights nav | Operator/Admin |
| Advanced Settings | Admin/Power | Settings section | Admin |
| Moderation | Admin/Power | Admin nav | Admin |
| Workflow Console | Admin/Power | Power nav | Operator/Admin |
| System Health | Support/System | Settings | Admin |
| Audit Signals | Support/System | Security nav | Admin |
| Error Recovery | Support/System | Failure CTA | Operator/Admin |
| Permission Denied | Edge/Exception | Guarded actions | All |
| Provider Misconfiguration | Edge/Exception | Startup checks | Admin |
| Offline Fallback | Edge/Exception | Connectivity fallback | All |

## UX Restructuring Proposal

### 1) Navigation

Adopt role-aware adaptive shell:

- **Left rail**: Core flows
- **Top contextual bar**: mode, role, density, filter context
- **Right side panel**: activity + AI findings + alerts

### 2) Progressive Disclosure

- Merge actions collapsed by default; expose advanced merge methods on demand.
- Plugin/agent/workflow controls hidden for non-operator roles.
- Security controls gated behind admin-focused sections.

### 3) Contextual Actions

Within PR Detail:

- one-click AI review,
- conditional merge CTA,
- “View related issues”,
- “Replay workflow” on failed checks.

### 4) Adaptive Dashboards

Dashboard widgets adapt by role:

- Viewer: repo health, open PR inventory
- Operator: pending actions, failing reviews, queue load
- Admin: policy drift, auth anomalies, audit anomalies

### 5) Smart Defaults

- Default to review-focused layout in high PR load contexts.
- Choose compact density for large data tables.
- Auto-select theme variant by role if user has no explicit preference.

### 6) Reduced Friction Flows

- Keep keyboard-first navigation parity.
- Batch actions for collaborator management.
- Inline retry paths for failed AI jobs.

## UX Alternatives + Trade-offs

| Decision Area | Option A | Option B | Trade-off |
|---|---|---|---|
| Navigation | Role-adaptive rail | Static global nav | Adaptive improves focus; static is easier to learn initially |
| PR Workspace | Single-page dense layout | Multi-step wizard | Dense favors power users; wizard helps first-time users |
| Notifications | Global inbox | Screen-local alerts | Global improves traceability; local reduces noise |
| Analytics | Embedded widgets | Dedicated analytics app | Embedded is quick; dedicated scales better for advanced querying |
| Recovery | Inline retry banners | Dedicated recovery center | Inline is faster; center provides stronger governance trail |

## Recommended Baseline

- Role-adaptive primary nav
- Unified PR review workspace
- Notifications + activity as persistent context panel
- Dedicated Theme/UX lab for safe experimentation
- Explicit error/recovery center for operational trust
