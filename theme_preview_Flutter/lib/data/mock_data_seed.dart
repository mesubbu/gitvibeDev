import '../domain/models.dart';

final List<RepositorySummary> seededRepositories = <RepositorySummary>[
  const RepositorySummary(
    id: 'repo-101',
    owner: 'demo-org',
    name: 'platform-api',
    description: 'Backend APIs, auth policies, and workflow orchestration.',
    language: 'Python',
    stars: 245,
  ),
  const RepositorySummary(
    id: 'repo-102',
    owner: 'demo-org',
    name: 'platform-web',
    description: 'Frontend shell for PR operations and developer productivity.',
    language: 'JavaScript',
    stars: 173,
  ),
  const RepositorySummary(
    id: 'repo-103',
    owner: 'demo-org',
    name: 'automation-kits',
    description: 'Plugin and workflow bundles for release engineering.',
    language: 'TypeScript',
    stars: 98,
  ),
];

final Map<String, List<PullRequestSummary>> seededPullRequests = <String, List<PullRequestSummary>>{
  'demo-org/platform-api': <PullRequestSummary>[
    PullRequestSummary(
      number: 42,
      title: 'feat: add AI repo insights endpoint',
      author: 'copilot-bot',
      state: 'open',
      createdAt: DateTime.utc(2026, 2, 12, 9, 12),
      headBranch: 'feature/ai-insights',
      baseBranch: 'main',
      body: 'Adds repository risk profiling and review latency metrics endpoint.',
      diff: 'diff --git a/app/main.py b/app/main.py\n'
          '@@ -12,6 +12,11 @@\n'
          '+@app.get("/api/repos/{repo}/insights")\n'
          '+async def repo_insights(repo: str):\n'
          '+    # TODO: add pagination guards\n'
          '+    return {"repo": repo}\n',
      checkStatus: 'passing',
    ),
    PullRequestSummary(
      number: 44,
      title: 'fix: tighten webhook signature validation',
      author: 'security-maintainer',
      state: 'open',
      createdAt: DateTime.utc(2026, 2, 13, 14, 33),
      headBranch: 'fix/webhook-hardening',
      baseBranch: 'main',
      body: 'Requires timestamp enforcement and strict signature handling.',
      diff: 'diff --git a/app/auth.py b/app/auth.py\n'
          '@@ -20,7 +20,8 @@\n'
          '-if not signature:\n'
          '+if not signature or not timestamp:\n'
          '     raise HTTPException(status_code=401)\n',
      checkStatus: 'pending',
    ),
  ],
  'demo-org/platform-web': <PullRequestSummary>[
    PullRequestSummary(
      number: 13,
      title: 'chore: improve dashboard loading states',
      author: 'frontend-dev',
      state: 'open',
      createdAt: DateTime.utc(2026, 2, 11, 18, 20),
      headBranch: 'chore/loading-state',
      baseBranch: 'main',
      body: 'Improves perceived responsiveness with staged skeleton loading.',
      diff: 'diff --git a/src/components/dashboard.tsx b/src/components/dashboard.tsx\n'
          '@@ -1,4 +1,6 @@\n'
          '+const LoadingState = () => <Spinner />\n'
          ' export default function Dashboard() { ... }\n',
      checkStatus: 'passing',
    ),
  ],
  'demo-org/automation-kits': <PullRequestSummary>[
    PullRequestSummary(
      number: 7,
      title: 'feat: add release freeze workflow template',
      author: 'release-ops',
      state: 'open',
      createdAt: DateTime.utc(2026, 2, 10, 10, 5),
      headBranch: 'feat/release-freeze-template',
      baseBranch: 'main',
      body: 'Adds reusable workflow for controlled release windows.',
      diff: 'diff --git a/workflows/release.yaml b/workflows/release.yaml\n'
          '@@ -4,6 +4,10 @@\n'
          '+  - name: freeze-window\n'
          '+    action: plugin:freeze-release\n',
      checkStatus: 'failing',
    ),
  ],
};

final Map<String, List<IssueSummary>> seededIssues = <String, List<IssueSummary>>{
  'demo-org/platform-api': <IssueSummary>[
    IssueSummary(
      number: 8,
      title: 'api: harden OAuth callback validation',
      author: 'security-maintainer',
      state: 'open',
      createdAt: DateTime.utc(2026, 2, 10, 10),
      labels: <String>['security'],
    ),
    IssueSummary(
      number: 9,
      title: 'api: add queue retries for review jobs',
      author: 'backend-dev',
      state: 'open',
      createdAt: DateTime.utc(2026, 2, 9, 13),
      labels: <String>['backend', 'reliability'],
    ),
  ],
  'demo-org/platform-web': <IssueSummary>[
    IssueSummary(
      number: 3,
      title: 'web: improve merge action feedback',
      author: 'frontend-dev',
      state: 'open',
      createdAt: DateTime.utc(2026, 2, 8, 8, 45),
      labels: <String>['ux'],
    ),
  ],
  'demo-org/automation-kits': <IssueSummary>[
    IssueSummary(
      number: 11,
      title: 'workflow: add rollback fallback for failed deployments',
      author: 'release-ops',
      state: 'open',
      createdAt: DateTime.utc(2026, 2, 7, 16, 30),
      labels: <String>['workflow', 'safety'],
    ),
  ],
};

final List<NotificationItem> seededNotifications = <NotificationItem>[
  NotificationItem(
    id: 'notif-001',
    title: 'AI review failed for PR #7',
    message: 'Fallback model timed out. Recovery path available.',
    createdAt: DateTime.utc(2026, 2, 16, 8, 10),
    priority: 'high',
    read: false,
  ),
  NotificationItem(
    id: 'notif-002',
    title: 'Security policy drift detected',
    message: 'One repository still allows direct pushes to main.',
    createdAt: DateTime.utc(2026, 2, 16, 7, 42),
    priority: 'medium',
    read: false,
  ),
  NotificationItem(
    id: 'notif-003',
    title: 'Workflow template updated',
    message: 'Release freeze workflow promoted to v1.3.',
    createdAt: DateTime.utc(2026, 2, 15, 18, 22),
    priority: 'low',
    read: true,
  ),
];

final List<ActivityEvent> seededActivities = <ActivityEvent>[
  ActivityEvent(
    id: 'act-001',
    actor: 'operator-amy',
    action: 'merge',
    target: 'demo-org/platform-api#39',
    occurredAt: DateTime.utc(2026, 2, 16, 8, 15),
    severity: 'info',
  ),
  ActivityEvent(
    id: 'act-002',
    actor: 'admin-ryan',
    action: 'rotate-signing-key',
    target: 'security-token-service',
    occurredAt: DateTime.utc(2026, 2, 16, 7, 20),
    severity: 'warning',
  ),
  ActivityEvent(
    id: 'act-003',
    actor: 'system',
    action: 'workflow-failed',
    target: 'release-freeze-pipeline#2319',
    occurredAt: DateTime.utc(2026, 2, 16, 6, 55),
    severity: 'high',
  ),
];

const AnalyticsSnapshot seededAnalytics = AnalyticsSnapshot(
  openPullRequests: 4,
  mergedToday: 6,
  failedReviews: 2,
  avgReviewMinutes: 18,
  automationCoveragePercent: 73.5,
);

final List<WorkflowScenario> seededWorkflowScenarios = <WorkflowScenario>[
  WorkflowScenario(
    id: 'scenario-pr-happy-path',
    name: 'PR Happy Path',
    persona: 'Operator',
    recoveryHint: 'No recovery required; all checks pass.',
    heavyDataPoints: 120,
    steps: <WorkflowStep>[
      WorkflowStep(
        id: 's1',
        label: 'Select repository',
        description: 'Choose repository and open PR backlog.',
        state: WorkflowStepState.completed,
      ),
      WorkflowStep(
        id: 's2',
        label: 'Run AI review',
        description: 'Trigger async AI review job with focus hints.',
        state: WorkflowStepState.completed,
      ),
      WorkflowStep(
        id: 's3',
        label: 'Merge pull request',
        description: 'Apply squash merge after checks complete.',
        state: WorkflowStepState.inProgress,
      ),
    ],
  ),
  WorkflowScenario(
    id: 'scenario-review-recovery',
    name: 'AI Review Recovery',
    persona: 'Operator',
    recoveryHint: 'Retry with fallback model and reduced diff scope.',
    heavyDataPoints: 540,
    steps: <WorkflowStep>[
      WorkflowStep(
        id: 's1',
        label: 'Start review job',
        description: 'Queue review for high-risk PR.',
        state: WorkflowStepState.completed,
      ),
      WorkflowStep(
        id: 's2',
        label: 'Detect timeout',
        description: 'Primary model response exceeds timeout window.',
        state: WorkflowStepState.failed,
      ),
      WorkflowStep(
        id: 's3',
        label: 'Fallback execution',
        description: 'Retry with fallback provider and focused prompt.',
        state: WorkflowStepState.pending,
      ),
    ],
  ),
  WorkflowScenario(
    id: 'scenario-admin-incident',
    name: 'Policy Incident Response',
    persona: 'Admin',
    recoveryHint: 'Lock plugin execution and rotate signing keys.',
    heavyDataPoints: 860,
    steps: <WorkflowStep>[
      WorkflowStep(
        id: 's1',
        label: 'Alert triage',
        description: 'Inspect audit events and identify anomaly.',
        state: WorkflowStepState.completed,
      ),
      WorkflowStep(
        id: 's2',
        label: 'Containment',
        description: 'Disable risky plugin via allowlist policy.',
        state: WorkflowStepState.inProgress,
      ),
      WorkflowStep(
        id: 's3',
        label: 'Post-incident review',
        description: 'Publish remediation and update workflows.',
        state: WorkflowStepState.pending,
      ),
    ],
  ),
];
