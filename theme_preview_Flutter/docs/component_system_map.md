# Component System Map

Use Case → Component → Variants → States

| Use Case | Component | Variants | States |
|---|---|---|---|
| PR and issue status communication | `StatusBadge` | neutral/info/success/warning/danger | default, emphasized |
| Structured content container | `AdaptiveCard` | standard, emphasis | loading, populated, warning |
| Operational KPI display | `MetricTile` | info/success/warning/danger semantic | normal, alerting |
| Action clustering near context | `ContextualActionBar` | primary-first, secondary-first | enabled, partial-disabled |
| Identity and policy context | `RoleTag` | viewer/operator/admin | role switch transitions |

## Component Governance Rules

1. No direct hardcoded palette values in feature widgets.
2. Components consume tokenized theme extensions.
3. New variants require documented use-case before promotion.
