import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../component_gallery/component_gallery_page.dart';
import '../demos/workflow_simulator.dart';
import '../design_system/components/adaptive_card.dart';
import '../design_system/components/contextual_action_bar.dart';
import '../design_system/components/metric_tile.dart';
import '../design_system/components/status_badge.dart';
import '../design_system/theme/app_theme_extensions.dart';
import '../domain/models.dart';
import '../domain/screen_descriptor.dart';
import '../theme_lab/theme_lab_page.dart';

class InferredScreenRenderer extends StatelessWidget {
  const InferredScreenRenderer({
    super.key,
    required this.descriptor,
    required this.state,
  });

  final ScreenDescriptor descriptor;
  final PreviewAppState state;

  @override
  Widget build(BuildContext context) {
    switch (descriptor.id) {
      case 'dashboard':
        return _DashboardScreen(state: state);
      case 'repositories':
        return _RepositoriesScreen(state: state);
      case 'pull-requests':
        return _PullRequestsScreen(state: state);
      case 'pr-detail':
        return _PullRequestDetailScreen(state: state);
      case 'issues':
        return _IssuesScreen(state: state);
      case 'settings':
        return _SettingsScreen(state: state);
      case 'notifications':
        return _NotificationsScreen(state: state);
      case 'activity-log':
        return _ActivityLogScreen(state: state);
      case 'analytics':
        return _AnalyticsScreen(state: state);
      case 'system-health':
        return _SystemHealthScreen(state: state);
      case 'workflow-demos':
        return WorkflowSimulatorPage(state: state);
      case 'component-gallery':
        return ComponentGalleryPage(state: state);
      case 'theme-lab':
        return ThemeLabPage(state: state);
      default:
        return _PlaceholderScreen(descriptor: descriptor, state: state);
    }
  }
}

class _DashboardBundle {
  const _DashboardBundle({
    required this.analytics,
    required this.notifications,
    required this.activities,
    required this.health,
  });

  final AnalyticsSnapshot analytics;
  final List<NotificationItem> notifications;
  final List<ActivityEvent> activities;
  final HealthSnapshot health;
}

class _SettingsBundle {
  const _SettingsBundle({
    required this.health,
    required this.auth,
  });

  final HealthSnapshot health;
  final AuthStatusSnapshot auth;
}

class _DashboardScreen extends StatelessWidget {
  const _DashboardScreen({required this.state});

  final PreviewAppState state;

  Future<_DashboardBundle> _load() async {
    final AnalyticsSnapshot analytics = await state.repository.getAnalytics();
    final List<NotificationItem> notifications =
        await state.repository.listNotifications();
    final List<ActivityEvent> activities =
        await state.repository.listActivities();
    final HealthSnapshot health =
        await state.repository.getHealth(state.runtimeMode);
    return _DashboardBundle(
      analytics: analytics,
      notifications: notifications,
      activities: activities,
      health: health,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardBundle>(
      future: _load(),
      builder:
          (BuildContext context, AsyncSnapshot<_DashboardBundle> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AsyncErrorState(
            title: 'Dashboard load failed',
            error: snapshot.error,
            state: state,
            retryScreenId: 'dashboard',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('No dashboard data available.'));
        }
        final _DashboardBundle data = snapshot.data!;
        final int unread = data.notifications
            .where((NotificationItem item) => !item.read)
            .length;
        final int highSeverityEvents = data.activities
            .where((ActivityEvent item) => item.severity == 'high')
            .length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            AdaptiveCard(
              title: 'Operational Dashboard',
              subtitle:
                  'Role-aware summary for ${state.role.label} users in ${state.runtimeMode.label} mode.',
              trailing: StatusBadge(
                label: data.health.status.toUpperCase(),
                tone: data.health.status == 'ok'
                    ? StatusTone.success
                    : StatusTone.warning,
              ),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.8,
                children: <Widget>[
                  MetricTile(
                    label: 'Open PRs',
                    value: data.analytics.openPullRequests.toString(),
                    delta: '+${data.analytics.mergedToday} merged today',
                  ),
                  MetricTile(
                    label: 'Failed Reviews',
                    value: data.analytics.failedReviews.toString(),
                    semantic: data.analytics.failedReviews > 0
                        ? 'warning'
                        : 'success',
                  ),
                  MetricTile(
                    label: 'Automation Coverage',
                    value:
                        '${data.analytics.automationCoveragePercent.toStringAsFixed(1)}%',
                    delta:
                        '${data.analytics.avgReviewMinutes}m avg review time',
                    semantic: 'success',
                  ),
                  MetricTile(
                      label: 'Unread Alerts',
                      value: unread.toString(),
                      semantic: unread > 0 ? 'warning' : 'success'),
                  MetricTile(
                    label: 'High Severity Events',
                    value: highSeverityEvents.toString(),
                    semantic: highSeverityEvents > 0 ? 'danger' : 'success',
                  ),
                  MetricTile(
                      label: 'Services',
                      value: '${data.health.services.length}',
                      semantic: 'info'),
                ],
              ),
            ),
            AdaptiveCard(
              title: 'Suggested Next Actions',
              subtitle:
                  'Adaptive defaults based on role and current system state.',
              child: ContextualActionBar(
                actions: <Widget>[
                  FilledButton.icon(
                    onPressed: () => state.setActiveScreen('pull-requests'),
                    icon: const Icon(Icons.rate_review),
                    label: const Text('Review pending PRs'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => state.setActiveScreen('notifications'),
                    icon: const Icon(Icons.notifications_active),
                    label: Text('Open Alerts ($unread)'),
                  ),
                  if (state.role != UserRole.viewer)
                    OutlinedButton.icon(
                      onPressed: () => state.setActiveScreen('workflow-demos'),
                      icon: const Icon(Icons.auto_mode),
                      label: const Text('Run workflow simulation'),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RepositoriesScreen extends StatelessWidget {
  const _RepositoriesScreen({required this.state});

  final PreviewAppState state;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RepositorySummary>>(
      future: state.repository.listRepositories(),
      builder: (BuildContext context,
          AsyncSnapshot<List<RepositorySummary>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AsyncErrorState(
            title: 'Repositories unavailable',
            error: snapshot.error,
            state: state,
            retryScreenId: 'repositories',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('No repositories available.'));
        }
        final List<RepositorySummary> repos = snapshot.data!;
        if (repos.isEmpty) {
          return _EmptyStateCard(
            title: 'No repositories found',
            subtitle: 'No repositories were returned by the current runtime.',
            actionLabel: 'Open Settings',
            onAction: () => state.setActiveScreen('settings'),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            AdaptiveCard(
              title: 'Repositories',
              subtitle: 'Select a repository to open PR and issue workflows.',
              child: Column(
                children: repos.map((RepositorySummary repo) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                    title: Text(repo.key),
                    subtitle: Text(
                        '${repo.description}\n${repo.language} • ⭐ ${repo.stars}'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      state.selectRepository(repo.key);
                      state.setActiveScreen('pull-requests');
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PullRequestsScreen extends StatelessWidget {
  const _PullRequestsScreen({required this.state});

  final PreviewAppState state;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RepositorySummary>>(
      future: state.repository.listRepositories(),
      builder: (BuildContext context,
          AsyncSnapshot<List<RepositorySummary>> repoSnapshot) {
        if (repoSnapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (repoSnapshot.hasError) {
          return _AsyncErrorState(
            title: 'Pull request sources unavailable',
            error: repoSnapshot.error,
            state: state,
            retryScreenId: 'pull-requests',
          );
        }
        if (!repoSnapshot.hasData || repoSnapshot.data!.isEmpty) {
          return _EmptyStateCard(
            title: 'No repositories available',
            subtitle:
                'Select runtime diagnostics to resolve repository access.',
            actionLabel: 'Open Settings',
            onAction: () => state.setActiveScreen('settings'),
          );
        }

        final List<RepositorySummary> repos = repoSnapshot.data!;
        final String selectedRepo =
            state.selectedRepositoryKey ?? repos.first.key;

        return FutureBuilder<List<PullRequestSummary>>(
          future: state.repository.listPullRequests(selectedRepo),
          builder: (BuildContext context,
              AsyncSnapshot<List<PullRequestSummary>> pullSnapshot) {
            if (pullSnapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (pullSnapshot.hasError) {
              return _AsyncErrorState(
                title: 'Pull requests unavailable',
                error: pullSnapshot.error,
                state: state,
                retryScreenId: 'pull-requests',
              );
            }
            if (!pullSnapshot.hasData) {
              return const Center(
                  child: Text('No pull request data available.'));
            }
            final List<PullRequestSummary> pulls = pullSnapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                AdaptiveCard(
                  title: 'Pull Request Queue',
                  subtitle:
                      'Repository-scoped review queue with merge and AI actions.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      DropdownButton<String>(
                        value: selectedRepo,
                        onChanged: (String? value) {
                          if (value == null) return;
                          state.selectRepository(value);
                        },
                        items: repos
                            .map((RepositorySummary item) =>
                                DropdownMenuItem<String>(
                                  value: item.key,
                                  child: Text(item.key),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      if (pulls.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No pull requests found for the selected repository.',
                          ),
                        ),
                      ...pulls.map((PullRequestSummary pull) {
                        final bool blocked = pull.checkStatus == 'failing';
                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 6),
                          title: Text('#${pull.number} ${pull.title}'),
                          subtitle: Text(
                              '${pull.author} • ${pull.headBranch} → ${pull.baseBranch}'),
                          trailing: Wrap(
                            spacing: 6,
                            children: <Widget>[
                              StatusBadge(
                                label: pull.merged
                                    ? 'MERGED'
                                    : pull.state.toUpperCase(),
                                tone: pull.merged
                                    ? StatusTone.success
                                    : StatusTone.info,
                              ),
                              StatusBadge(
                                label: pull.checkStatus.toUpperCase(),
                                tone: blocked
                                    ? StatusTone.warning
                                    : StatusTone.success,
                              ),
                            ],
                          ),
                          onTap: () {
                            state.selectRepository(selectedRepo);
                            state.selectPullRequest(pull.number);
                            state.setActiveScreen('pr-detail');
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PullRequestDetailScreen extends StatefulWidget {
  const _PullRequestDetailScreen({required this.state});

  final PreviewAppState state;

  @override
  State<_PullRequestDetailScreen> createState() =>
      _PullRequestDetailScreenState();
}

class _PullRequestDetailScreenState extends State<_PullRequestDetailScreen> {
  AiReviewJob? _job;
  Timer? _timer;
  String? _message;
  bool _loading = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? repoKey = widget.state.selectedRepositoryKey;
    final int? pullNumber = widget.state.selectedPullNumber;
    if (repoKey == null || pullNumber == null) {
      return const Center(
          child: Text('Select a repository and pull request first.'));
    }

    return FutureBuilder<List<PullRequestSummary>>(
      future: widget.state.repository.listPullRequests(repoKey),
      builder: (BuildContext context,
          AsyncSnapshot<List<PullRequestSummary>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AsyncErrorState(
            title: 'PR detail unavailable',
            error: snapshot.error,
            state: widget.state,
            retryScreenId: 'pr-detail',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('No pull request data available.'));
        }

        final Iterable<PullRequestSummary> matches = snapshot.data!
            .where((PullRequestSummary item) => item.number == pullNumber);
        final PullRequestSummary? pull = matches.firstOrNull;
        if (pull == null) {
          return const Center(
              child: Text('Selected pull request no longer exists.'));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            AdaptiveCard(
              title: '#${pull.number} ${pull.title}',
              subtitle:
                  '$repoKey • ${pull.author} • ${pull.headBranch} → ${pull.baseBranch}',
              trailing: StatusBadge(
                label: pull.merged ? 'MERGED' : pull.state.toUpperCase(),
                tone: pull.merged ? StatusTone.success : StatusTone.info,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(pull.body),
                  const SizedBox(height: 12),
                  ContextualActionBar(
                    actions: <Widget>[
                      FilledButton(
                        onPressed: pull.merged ||
                                widget.state.role == UserRole.viewer ||
                                _loading
                            ? null
                            : () => _merge(repoKey, pull.number, 'merge'),
                        child: const Text('Merge'),
                      ),
                      OutlinedButton(
                        onPressed: pull.merged ||
                                widget.state.role == UserRole.viewer ||
                                _loading
                            ? null
                            : () => _merge(repoKey, pull.number, 'squash'),
                        child: const Text('Squash'),
                      ),
                      OutlinedButton(
                        onPressed: pull.merged ||
                                widget.state.role == UserRole.viewer ||
                                _loading
                            ? null
                            : () => _merge(repoKey, pull.number, 'rebase'),
                        child: const Text('Rebase'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _startAiReview(repoKey, pull.number),
                        icon: const Icon(Icons.smart_toy),
                        label: const Text('Run AI Review'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AdaptiveCard(
              title: 'Diff Preview',
              subtitle: 'Focused code context for review decisions.',
              child: Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: context.appColors.surfaceAlt,
                ),
                padding: const EdgeInsets.all(10),
                child: SingleChildScrollView(
                  child: SelectableText(
                    pull.diff,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
            if (_message != null)
              AdaptiveCard(
                title: 'Latest Action',
                child: Text(_message!),
              ),
            if (_job != null)
              AdaptiveCard(
                title: 'AI Review Job ${_job!.id}',
                subtitle: 'Status: ${_job!.status.label}',
                child: _job!.status == JobStatus.completed &&
                        _job!.result != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(_job!.result!.summary),
                          const SizedBox(height: 8),
                          ..._job!.result!.findings
                              .map((AiReviewFinding finding) {
                            final StatusTone tone = switch (finding.severity) {
                              'high' => StatusTone.danger,
                              'medium' => StatusTone.warning,
                              'low' => StatusTone.success,
                              _ => StatusTone.info,
                            };
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  StatusBadge(
                                      label: finding.severity.toUpperCase(),
                                      tone: tone),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${finding.title}\n${finding.description}\n${finding.file}${finding.line == null ? '' : ':${finding.line}'}',
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      )
                    : Text(_job!.error ?? 'Review in progress...'),
              ),
          ],
        );
      },
    );
  }

  Future<void> _merge(String repoKey, int pullNumber, String method) async {
    setState(() => _loading = true);
    try {
      final MergeOutcome result =
          await widget.state.repository.mergePullRequest(
        repositoryKey: repoKey,
        pullNumber: pullNumber,
        method: method,
        actor: widget.state.role.label.toLowerCase(),
      );
      setState(() {
        _loading = false;
        _message = result.message;
      });
    } catch (error) {
      setState(() {
        _loading = false;
        _message = 'Merge failed: $error';
      });
    }
  }

  Future<void> _startAiReview(String repoKey, int pullNumber) async {
    setState(() => _loading = true);
    try {
      final AiReviewJob created = await widget.state.repository.startAiReview(
        repositoryKey: repoKey,
        pullNumber: pullNumber,
        focus: widget.state.workMode == WorkMode.focus
            ? 'security-hardening'
            : null,
      );
      setState(() {
        _loading = false;
        _job = created;
        _message = 'Started AI review job ${created.id}';
      });

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 800),
          (Timer timer) async {
        try {
          final AiReviewJob? polled =
              await widget.state.repository.getAiReviewJob(created.id);
          if (!mounted || polled == null) return;
          setState(() => _job = polled);
          if (polled.status == JobStatus.completed ||
              polled.status == JobStatus.failed) {
            timer.cancel();
          }
        } catch (error) {
          if (!mounted) return;
          setState(() {
            _job = _job?.copyWith(
              status: JobStatus.failed,
              error: 'Polling failed: $error',
            );
            _message = 'AI review polling failed: $error';
          });
          timer.cancel();
        }
      });
    } catch (error) {
      setState(() {
        _loading = false;
        _message = 'AI review request failed: $error';
      });
    }
  }
}

class _IssuesScreen extends StatelessWidget {
  const _IssuesScreen({required this.state});

  final PreviewAppState state;

  @override
  Widget build(BuildContext context) {
    final String? repoKey = state.selectedRepositoryKey;
    if (repoKey == null) {
      return const Center(
          child: Text('Select a repository from Repositories first.'));
    }

    return FutureBuilder<List<IssueSummary>>(
      future: state.repository.listIssues(repoKey),
      builder:
          (BuildContext context, AsyncSnapshot<List<IssueSummary>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AsyncErrorState(
            title: 'Issues unavailable',
            error: snapshot.error,
            state: state,
            retryScreenId: 'issues',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('No issue data available.'));
        }

        final List<IssueSummary> issues = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            AdaptiveCard(
              title: 'Issues for $repoKey',
              subtitle: 'Track linked defects and delivery blockers.',
              child: Column(
                children: <Widget>[
                  if (issues.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child:
                          Text('No issues found for the selected repository.'),
                    ),
                  ...issues.map((IssueSummary issue) {
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                      title: Text('#${issue.number} ${issue.title}'),
                      subtitle:
                          Text('${issue.author} • ${issue.labels.join(', ')}'),
                      trailing: StatusBadge(
                        label: issue.state.toUpperCase(),
                        tone: issue.state == 'open'
                            ? StatusTone.info
                            : StatusTone.neutral,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen({required this.state});

  final PreviewAppState state;

  Future<_SettingsBundle> _load() async {
    final HealthSnapshot health =
        await state.repository.getHealth(state.runtimeMode);
    final AuthStatusSnapshot auth = await state.repository.getAuthStatus();
    return _SettingsBundle(health: health, auth: auth);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SettingsBundle>(
      future: _load(),
      builder: (BuildContext context, AsyncSnapshot<_SettingsBundle> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AsyncErrorState(
            title: 'Settings diagnostics unavailable',
            error: snapshot.error,
            state: state,
            retryScreenId: 'settings',
          );
        }
        if (!snapshot.hasData) {
          return const Center(
              child: Text('No settings diagnostics available.'));
        }
        final _SettingsBundle data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            AdaptiveCard(
              title: 'Runtime Settings',
              subtitle:
                  'Mode and UX controls aligned with frontend parity behavior.',
              trailing: StatusBadge(
                label: state.runtimeMode.label.toUpperCase(),
                tone: state.runtimeMode == RuntimeMode.demo
                    ? StatusTone.info
                    : StatusTone.success,
              ),
              child: Column(
                children: <Widget>[
                  _SettingRow(
                      label: 'Configured mode',
                      value: state.configuredRuntimeMode.label),
                  _SettingRow(
                      label: 'Active mode', value: state.runtimeMode.label),
                  _SettingRow(label: 'Preview role', value: state.role.label),
                  _SettingRow(
                    label: 'Theme',
                    value: state.themeMode == ThemeMode.dark ? 'Dark' : 'Light',
                    trailing: OutlinedButton.icon(
                      onPressed: () {
                        state.setThemeMode(
                          state.themeMode == ThemeMode.dark
                              ? ThemeMode.light
                              : ThemeMode.dark,
                        );
                      },
                      icon: const Icon(Icons.brightness_6),
                      label: const Text('Toggle'),
                    ),
                  ),
                ],
              ),
            ),
            AdaptiveCard(
              title: 'Authentication Diagnostics',
              subtitle: 'Parity mapping for `/api/auth/status` payload.',
              child: Column(
                children: <Widget>[
                  _SettingRow(
                    label: 'Authenticated',
                    value: data.auth.authenticated ? 'Yes' : 'No',
                    trailing: StatusBadge(
                      label: data.auth.authenticated ? 'AUTH' : 'GUEST',
                      tone: data.auth.authenticated
                          ? StatusTone.success
                          : StatusTone.warning,
                    ),
                  ),
                  _SettingRow(label: 'Auth mode', value: data.auth.mode),
                  _SettingRow(
                      label: 'App mode', value: data.auth.appMode.label),
                  _SettingRow(
                      label: 'GitHub app ready',
                      value: data.auth.githubAppReady ? 'Yes' : 'No'),
                  _SettingRow(
                      label: 'RBAC enabled',
                      value: data.auth.rbacEnabled ? 'Yes' : 'No'),
                  _SettingRow(
                      label: 'CSRF protection',
                      value: data.auth.csrfProtectionEnabled
                          ? 'Enabled'
                          : 'Disabled'),
                  _SettingRow(
                      label: 'Token rotation',
                      value: data.auth.tokenRotationEnabled
                          ? 'Enabled'
                          : 'Disabled'),
                  _SettingRow(
                      label: 'AI provider', value: data.auth.aiProvider),
                  if (data.auth.user != null)
                    _SettingRow(label: 'User', value: data.auth.user!),
                  if (data.auth.role != null)
                    _SettingRow(label: 'Token role', value: data.auth.role!),
                ],
              ),
            ),
            AdaptiveCard(
              title: 'System Health',
              subtitle: 'Parity mapping for `/health` service status.',
              trailing: StatusBadge(
                label: data.health.status.toUpperCase(),
                tone: data.health.status == 'ok'
                    ? StatusTone.success
                    : StatusTone.warning,
              ),
              child: Column(
                children: data.health.services.entries
                    .map((MapEntry<String, String> service) {
                  final bool healthy = service.value.toLowerCase() == 'ok';
                  return _SettingRow(
                    label: service.key,
                    value: service.value,
                    trailing: StatusBadge(
                      label: healthy ? 'OK' : 'CHECK',
                      tone: healthy ? StatusTone.success : StatusTone.warning,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.right,
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _NotificationsScreen extends StatefulWidget {
  const _NotificationsScreen({required this.state});

  final PreviewAppState state;

  @override
  State<_NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<_NotificationsScreen> {
  late Future<List<NotificationItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.state.repository.listNotifications();
  }

  Future<void> _refresh() async {
    setState(() => _future = widget.state.repository.listNotifications());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NotificationItem>>(
      future: _future,
      builder: (BuildContext context,
          AsyncSnapshot<List<NotificationItem>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AsyncErrorState(
            title: 'Notifications unavailable',
            error: snapshot.error,
            state: widget.state,
            retryScreenId: 'notifications',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('No notifications available.'));
        }
        final List<NotificationItem> items = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            AdaptiveCard(
              title: 'Notifications Inbox',
              subtitle:
                  'Prioritized operational signals and remediation context.',
              trailing: OutlinedButton(
                onPressed: _refresh,
                child: const Text('Refresh'),
              ),
              child: Column(
                children: items.map((NotificationItem item) {
                  final StatusTone tone = switch (item.priority) {
                    'high' => StatusTone.danger,
                    'medium' => StatusTone.warning,
                    _ => StatusTone.info,
                  };
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                    title: Text(item.title),
                    subtitle: Text(item.message),
                    trailing: Wrap(
                      spacing: 8,
                      children: <Widget>[
                        StatusBadge(
                            label: item.priority.toUpperCase(), tone: tone),
                        if (!item.read)
                          TextButton(
                            onPressed: () async {
                              await widget.state.repository
                                  .markNotificationRead(item.id);
                              await _refresh();
                            },
                            child: const Text('Mark read'),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ActivityLogScreen extends StatelessWidget {
  const _ActivityLogScreen({required this.state});

  final PreviewAppState state;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ActivityEvent>>(
      future: state.repository.listActivities(),
      builder:
          (BuildContext context, AsyncSnapshot<List<ActivityEvent>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AsyncErrorState(
            title: 'Activity timeline unavailable',
            error: snapshot.error,
            state: state,
            retryScreenId: 'activity-log',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('No activity events available.'));
        }
        final List<ActivityEvent> events = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            AdaptiveCard(
              title: 'Activity Timeline',
              subtitle:
                  'Merged events from review, governance, and automation systems.',
              child: Column(
                children: events.map((ActivityEvent event) {
                  final StatusTone tone = switch (event.severity) {
                    'high' => StatusTone.danger,
                    'warning' => StatusTone.warning,
                    _ => StatusTone.info,
                  };
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                    title: Text('${event.actor} • ${event.action}'),
                    subtitle: Text(
                        '${event.target}\n${event.occurredAt.toIso8601String()}'),
                    isThreeLine: true,
                    trailing: StatusBadge(
                        label: event.severity.toUpperCase(), tone: tone),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AnalyticsScreen extends StatelessWidget {
  const _AnalyticsScreen({required this.state});

  final PreviewAppState state;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AnalyticsSnapshot>(
      future: state.repository.getAnalytics(),
      builder:
          (BuildContext context, AsyncSnapshot<AnalyticsSnapshot> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AsyncErrorState(
            title: 'Analytics unavailable',
            error: snapshot.error,
            state: state,
            retryScreenId: 'analytics',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('No analytics data available.'));
        }
        final AnalyticsSnapshot data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            AdaptiveCard(
              title: 'Analytics Overview',
              subtitle: 'Operational trends and quality throughput indicators.',
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2,
                children: <Widget>[
                  MetricTile(
                      label: 'Open Pull Requests',
                      value: '${data.openPullRequests}',
                      semantic: 'info'),
                  MetricTile(
                      label: 'Merged Today',
                      value: '${data.mergedToday}',
                      semantic: 'success'),
                  MetricTile(
                      label: 'Failed Reviews',
                      value: '${data.failedReviews}',
                      semantic: 'warning'),
                  MetricTile(
                      label: 'Avg Review Time',
                      value: '${data.avgReviewMinutes}m',
                      semantic: 'info'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SystemHealthScreen extends StatelessWidget {
  const _SystemHealthScreen({required this.state});

  final PreviewAppState state;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HealthSnapshot>(
      future: state.repository.getHealth(state.runtimeMode),
      builder: (BuildContext context, AsyncSnapshot<HealthSnapshot> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AsyncErrorState(
            title: 'System health unavailable',
            error: snapshot.error,
            state: state,
            retryScreenId: 'system-health',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('No health data available.'));
        }
        final HealthSnapshot health = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            AdaptiveCard(
              title: 'System Health',
              subtitle: 'Runtime mode: ${health.mode.label}',
              trailing: StatusBadge(
                label: health.status.toUpperCase(),
                tone: health.status == 'ok'
                    ? StatusTone.success
                    : StatusTone.warning,
              ),
              child: Column(
                children: health.services.entries
                    .map((MapEntry<String, String> entry) {
                  return ListTile(
                    title: Text(entry.key),
                    subtitle: Text(entry.value),
                    trailing: StatusBadge(
                      label: entry.value.toUpperCase(),
                      tone: entry.value == 'ok'
                          ? StatusTone.success
                          : StatusTone.warning,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AsyncErrorState extends StatelessWidget {
  const _AsyncErrorState({
    required this.title,
    required this.error,
    required this.state,
    required this.retryScreenId,
  });

  final String title;
  final Object? error;
  final PreviewAppState state;
  final String retryScreenId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        AdaptiveCard(
          title: title,
          subtitle: 'The requested data could not be loaded.',
          trailing: const StatusBadge(label: 'ERROR', tone: StatusTone.danger),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                error?.toString() ?? 'Unknown error',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => state.setActiveScreen(retryScreenId),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        AdaptiveCard(
          title: title,
          subtitle: subtitle,
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.descriptor, required this.state});

  final ScreenDescriptor descriptor;
  final PreviewAppState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        AdaptiveCard(
          title: descriptor.title,
          subtitle: descriptor.summary,
          trailing: StatusBadge(
              label: descriptor.classification.label.toUpperCase(),
              tone: StatusTone.info),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Actions', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: descriptor.actions
                    .map((String action) =>
                        StatusBadge(label: action, tone: StatusTone.neutral))
                    .toList(),
              ),
              const SizedBox(height: 14),
              Text('Data flow', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...descriptor.dataFlow.map((String flow) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $flow'),
                  )),
              const SizedBox(height: 12),
              Text(
                'This inferred screen is intentionally isolated in preview mode and can be promoted '
                'to production through the migration playbook.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.appColors.foregroundMuted,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
