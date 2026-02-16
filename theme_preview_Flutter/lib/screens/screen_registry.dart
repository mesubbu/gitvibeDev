import '../domain/models.dart';
import '../domain/screen_descriptor.dart';

class ScreenRegistry {
  static final List<ScreenDescriptor> canonical = <ScreenDescriptor>[
    ScreenDescriptor(
      id: 'dashboard',
      title: 'Dashboard',
      summary:
          'Adaptive operational summary with role-prioritized metrics and action queues.',
      classification: ScreenClass.core,
      roles: UserRole.values.toSet(),
      actions: <String>['inspect-metrics', 'jump-to-pr', 'jump-to-alert'],
      dataFlow: <String>[
        'analytics snapshot',
        'notifications feed',
        'activity stream'
      ],
      tags: <String>['adaptive', 'entrypoint'],
    ),
    ScreenDescriptor(
      id: 'repositories',
      title: 'Repositories',
      summary: 'Repository inventory with risk and throughput indicators.',
      classification: ScreenClass.core,
      roles: UserRole.values.toSet(),
      actions: <String>['open-repository', 'filter', 'sort'],
      dataFlow: <String>['/api/repos', 'mock repositories'],
    ),
    ScreenDescriptor(
      id: 'pull-requests',
      title: 'Pull Requests',
      summary: 'PR queue with status, checks, and triage operations.',
      classification: ScreenClass.core,
      roles: UserRole.values.toSet(),
      actions: <String>['open-pr', 'run-ai-review', 'merge-shortcut'],
      dataFlow: <String>['/api/repos/{owner}/{repo}/pulls'],
    ),
    ScreenDescriptor(
      id: 'pr-detail',
      title: 'PR Detail',
      summary: 'Focused review workspace with diff context and merge outcomes.',
      classification: ScreenClass.core,
      roles: UserRole.values.toSet(),
      actions: <String>['merge', 'run-ai-review', 'inspect-findings'],
      dataFlow: <String>['pull detail payload', 'ai review job stream'],
    ),
    ScreenDescriptor(
      id: 'issues',
      title: 'Issues',
      summary: 'Issue context for linked work and defect tracking.',
      classification: ScreenClass.core,
      roles: UserRole.values.toSet(),
      actions: <String>['inspect-issue', 'link-pr', 'prioritize'],
      dataFlow: <String>['/api/repos/{owner}/{repo}/issues'],
    ),
    ScreenDescriptor(
      id: 'settings',
      title: 'Settings',
      summary:
          'Runtime, auth, health, and theme diagnostics for parity workflows.',
      classification: ScreenClass.core,
      roles: UserRole.values.toSet(),
      actions: <String>[
        'inspect-runtime',
        'inspect-auth-status',
        'toggle-theme'
      ],
      dataFlow: <String>['/health', '/api/auth/status', 'local preferences'],
    ),
    ScreenDescriptor(
      id: 'onboarding',
      title: 'Onboarding',
      summary: 'Guided setup for role-aware first run experiences.',
      classification: ScreenClass.secondary,
      roles: UserRole.values.toSet(),
      actions: <String>['setup-mode', 'select-role', 'run-first-scenario'],
      dataFlow: <String>['runtime preferences', 'demo seed status'],
    ),
    ScreenDescriptor(
      id: 'notifications',
      title: 'Notifications',
      summary:
          'Priority inbox for job failures, policy alerts, and workflow updates.',
      classification: ScreenClass.secondary,
      roles: UserRole.values.toSet(),
      actions: <String>['mark-read', 'open-context', 'bulk-clear'],
      dataFlow: <String>['event bus projections', 'notification feed'],
    ),
    ScreenDescriptor(
      id: 'activity-log',
      title: 'Activity Log',
      summary: 'Timeline of merge, review, and governance events.',
      classification: ScreenClass.secondary,
      roles: UserRole.values.toSet(),
      actions: <String>['inspect-event', 'filter-severity', 'pivot-by-actor'],
      dataFlow: <String>['audit log feed', 'workflow/job events'],
    ),
    ScreenDescriptor(
      id: 'analytics',
      title: 'Analytics',
      summary:
          'Operational trends for review throughput and automation quality.',
      classification: ScreenClass.secondary,
      roles: <UserRole>{UserRole.operator, UserRole.admin},
      actions: <String>['compare-periods', 'drilldown', 'export-view'],
      dataFlow: <String>['derived metrics', 'review outcomes'],
    ),
    ScreenDescriptor(
      id: 'workflow-console',
      title: 'Workflow Console',
      summary: 'Power-user orchestration for agents, plugins, and workflows.',
      classification: ScreenClass.adminPower,
      roles: <UserRole>{UserRole.operator, UserRole.admin},
      actions: <String>['run-workflow', 'replay-run', 'inspect-step'],
      dataFlow: <String>['/api/workflows', '/api/agents'],
    ),
    ScreenDescriptor(
      id: 'advanced-settings',
      title: 'Advanced Settings',
      summary:
          'Security, policy, and execution controls for governed environments.',
      classification: ScreenClass.adminPower,
      roles: <UserRole>{UserRole.admin},
      actions: <String>['rotate-key', 'set-policy', 'approve-mode-switch'],
      dataFlow: <String>['/api/auth/*', 'security config'],
    ),
    ScreenDescriptor(
      id: 'moderation',
      title: 'Moderation',
      summary: 'Collaborator and access governance workspace.',
      classification: ScreenClass.adminPower,
      roles: <UserRole>{UserRole.admin},
      actions: <String>[
        'upsert-collaborator',
        'remove-collaborator',
        'audit-access'
      ],
      dataFlow: <String>['/api/repos/.../collaborators'],
    ),
    ScreenDescriptor(
      id: 'system-health',
      title: 'System Health',
      summary: 'Dependency and service status across runtime modes.',
      classification: ScreenClass.supportSystem,
      roles: <UserRole>{UserRole.operator, UserRole.admin},
      actions: <String>['inspect-service', 'check-mode-health'],
      dataFlow: <String>['/health', 'runtime mode status'],
    ),
    ScreenDescriptor(
      id: 'audit-signals',
      title: 'Audit Signals',
      summary: 'Security-relevant telemetry with severity prioritization.',
      classification: ScreenClass.supportSystem,
      roles: <UserRole>{UserRole.admin},
      actions: <String>['inspect-anomaly', 'acknowledge', 'escalate'],
      dataFlow: <String>['audit events', 'security middleware traces'],
    ),
    ScreenDescriptor(
      id: 'recovery-center',
      title: 'Recovery Center',
      summary: 'Guided failure recovery and retry orchestration.',
      classification: ScreenClass.edgeException,
      roles: <UserRole>{UserRole.operator, UserRole.admin},
      actions: <String>['retry-job', 'fallback-provider', 'open-postmortem'],
      dataFlow: <String>['failed jobs', 'error envelopes'],
    ),
    ScreenDescriptor(
      id: 'permission-denied',
      title: 'Permission Denied',
      summary: 'Explains blocked actions and required access level.',
      classification: ScreenClass.edgeException,
      roles: UserRole.values.toSet(),
      actions: <String>['request-access', 'switch-role-preview'],
      dataFlow: <String>['rbac policy state'],
    ),
    ScreenDescriptor(
      id: 'provider-misconfig',
      title: 'Provider Misconfiguration',
      summary: 'Diagnoses AI/Git provider setup drift and remediation steps.',
      classification: ScreenClass.edgeException,
      roles: <UserRole>{UserRole.operator, UserRole.admin},
      actions: <String>['run-diagnostics', 'apply-defaults', 'view-docs'],
      dataFlow: <String>['provider config', 'health responses'],
    ),
    ScreenDescriptor(
      id: 'offline-fallback',
      title: 'Offline Fallback',
      summary: 'Keeps critical workflows available in degraded connectivity.',
      classification: ScreenClass.edgeException,
      roles: UserRole.values.toSet(),
      actions: <String>['retry-sync', 'view-cached-data', 'reconcile'],
      dataFlow: <String>['local cache', 'offline queue'],
    ),
    ScreenDescriptor(
      id: 'workflow-demos',
      title: 'Workflow Demos',
      summary: 'End-to-end journey simulator with edge-case coverage.',
      classification: ScreenClass.lab,
      roles: UserRole.values.toSet(),
      actions: <String>[
        'run-scenario',
        'simulate-failure',
        'measure-density-impact'
      ],
      dataFlow: <String>['scenario fixtures', 'mock workflow traces'],
    ),
    ScreenDescriptor(
      id: 'component-gallery',
      title: 'Component Gallery',
      summary: 'Contextual component compositions from real product use-cases.',
      classification: ScreenClass.lab,
      roles: UserRole.values.toSet(),
      actions: <String>['inspect-variant', 'toggle-state', 'view-usecase-map'],
      dataFlow: <String>['design tokens', 'component variants'],
    ),
    ScreenDescriptor(
      id: 'theme-lab',
      title: 'Theme Lab',
      summary: 'Theme tuning, A/B evaluation, and UX experiment controls.',
      classification: ScreenClass.lab,
      roles: UserRole.values.toSet(),
      actions: <String>['switch-variant', 'toggle-density', 'simulate-heatmap'],
      dataFlow: <String>['theme engine', 'preference persistence'],
    ),
  ];

  static List<ScreenDescriptor> visibleFor(UserRole role) {
    return canonical
        .where((ScreenDescriptor descriptor) => descriptor.visibleTo(role))
        .toList();
  }

  static Set<String> get expectedScreenIds {
    return canonical
        .map((ScreenDescriptor descriptor) => descriptor.id)
        .toSet();
  }
}
