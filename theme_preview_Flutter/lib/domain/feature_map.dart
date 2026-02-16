class FeatureMapRow {
  const FeatureMapRow({
    required this.userType,
    required this.features,
    required this.screens,
    required this.actions,
    required this.dataFlow,
  });

  final String userType;
  final List<String> features;
  final List<String> screens;
  final List<String> actions;
  final List<String> dataFlow;
}

const List<FeatureMapRow> inferredFeatureMap = <FeatureMapRow>[
  FeatureMapRow(
    userType: 'Viewer',
    features: <String>[
      'Repository visibility',
      'PR discovery',
      'Issue visibility',
      'Runtime diagnostics',
    ],
    screens: <String>[
      'Dashboard',
      'Repositories',
      'Pull Requests',
      'Issues',
      'Settings',
    ],
    actions: <String>[
      'Browse repos',
      'Inspect PR metadata',
      'Track issue state',
      'Inspect health/auth status',
    ],
    dataFlow: <String>[
      '/api/repos',
      '/api/repos/{owner}/{repo}/pulls',
      '/api/repos/{owner}/{repo}/issues',
      '/health',
      '/api/auth/status',
    ],
  ),
  FeatureMapRow(
    userType: 'Operator',
    features: <String>[
      'Merge orchestration',
      'AI review',
      'Workflow execution'
    ],
    screens: <String>['PR Detail', 'Workflow Console', 'Notifications'],
    actions: <String>['Merge PR', 'Run AI review jobs', 'Replay failed flows'],
    dataFlow: <String>[
      '/api/repos/.../merge',
      '/api/ai/review/jobs',
      '/api/jobs/{id}'
    ],
  ),
  FeatureMapRow(
    userType: 'Admin',
    features: <String>[
      'Security governance',
      'Collaboration control',
      'Plugin execution'
    ],
    screens: <String>['Advanced Settings', 'Moderation', 'Audit Signals'],
    actions: <String>[
      'Rotate signing key',
      'Manage collaborators',
      'Run plugins'
    ],
    dataFlow: <String>[
      '/api/auth/rotate-signing-key',
      '/api/repos/.../collaborators',
      '/api/plugins/{name}/run'
    ],
  ),
  FeatureMapRow(
    userType: 'Demo Evaluator',
    features: <String>[
      'Offline trial',
      'Theme experimentation',
      'Scenario playback'
    ],
    screens: <String>[
      'Onboarding',
      'Theme Lab',
      'Workflow Demos',
      'Component Gallery'
    ],
    actions: <String>[
      'Simulate journeys',
      'A/B theme tuning',
      'Stress test dense screens',
      'Inspect components'
    ],
    dataFlow: <String>[
      'Mock repository',
      'IndexedDB/local preferences',
      'Scenario simulator',
      'Design token variants'
    ],
  ),
  FeatureMapRow(
    userType: 'Ops Support',
    features: <String>[
      'Service reliability',
      'Failure recovery',
      'Operational timeline',
      'Throughput analytics',
    ],
    screens: <String>[
      'Activity Timeline',
      'System Health',
      'Recovery Center',
      'Analytics Overview',
    ],
    actions: <String>[
      'Inspect events',
      'Diagnose services',
      'Retry recovery flows',
      'Review throughput trends',
    ],
    dataFlow: <String>[
      '/api/platform/events',
      '/health',
      '/api/jobs/{id}',
      'Derived review metrics',
    ],
  ),
  FeatureMapRow(
    userType: 'Security Governance',
    features: <String>['Audit triage', 'Guarded access', 'Provider resilience'],
    screens: <String>[
      'Audit Signals',
      'Permission Denied',
      'Provider Misconfiguration',
      'Offline Fallback'
    ],
    actions: <String>[
      'Acknowledge alerts',
      'Request role elevation',
      'Run diagnostics',
      'Retry sync'
    ],
    dataFlow: <String>[
      'Audit log feed',
      'RBAC policy state',
      'Provider health responses',
      'Local cache'
    ],
  ),
];
