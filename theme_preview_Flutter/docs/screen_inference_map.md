# Screen Inference Map

This map links inferred domain capabilities to UI surfaces and flows used in the workspace.

| Domain Capability | Inferred APIs / Models | Canonical Screens | Key Interactions |
|---|---|---|---|
| Repo discovery | `/api/repos`, `RepositorySummary` | Dashboard, Repositories | list/filter/select repository |
| PR operations | `/api/repos/{owner}/{repo}/pulls`, `PullRequestSummary` | Pull Requests, PR Detail | triage, inspect diff, merge |
| Issue context | `/issues`, `IssueSummary` | Issues, PR Detail | inspect linked work, prioritize |
| AI review orchestration | `/api/ai/review/jobs`, `/api/jobs/{id}`, `AiReviewJob` | PR Detail, Recovery Center | start review, poll status, fallback |
| Runtime health | `/health`, `HealthSnapshot` | Dashboard, System Health | inspect dependencies, mode health |
| Security and governance | RBAC + auth endpoints | Advanced Settings, Moderation, Audit Signals | rotate keys, manage access, inspect policy drift |
| Automation | workflows/agents/plugins surfaces | Workflow Console, Workflow Demos | run/replay workflows, inspect steps |
| Engagement context | notifications + activity streams | Notifications, Activity Log | acknowledge alerts, follow event trail |
| UX experimentation | theme/runtime preference models | Theme Lab, Component Gallery | A/B variants, density tuning, role simulation |

## Generated Screen Classes

- Core: `dashboard`, `repositories`, `pull-requests`, `pr-detail`, `issues`
- Secondary: `onboarding`, `notifications`, `activity-log`, `analytics`
- Admin/Power: `workflow-console`, `advanced-settings`, `moderation`
- Support/System: `system-health`, `audit-signals`
- Edge/Exception: `recovery-center`, `permission-denied`, `provider-misconfig`, `offline-fallback`
- Lab: `workflow-demos`, `component-gallery`, `theme-lab`
