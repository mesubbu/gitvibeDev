import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import 'gitvibe_repository.dart';
import 'mock_data_seed.dart';

class MockRepository implements GitVibeRepository {
  MockRepository._(this.preferences);

  static const String _mergedKey = 'theme_preview.merged_prs';
  static const String _readNotificationsKey =
      'theme_preview.read_notifications';

  @override
  final SharedPreferences preferences;

  late final List<RepositorySummary> _repositories;
  late final Map<String, List<PullRequestSummary>> _pullRequests;
  late final Map<String, List<IssueSummary>> _issues;
  late final List<NotificationItem> _notifications;
  late final List<ActivityEvent> _activities;
  late final AnalyticsSnapshot _analytics;
  late final List<WorkflowScenario> _scenarios;

  final Map<String, AiReviewJob> _jobs = <String, AiReviewJob>{};
  int _jobCounter = 0;

  static Future<MockRepository> create({SharedPreferences? preferences}) async {
    final SharedPreferences prefs =
        preferences ?? await SharedPreferences.getInstance();
    final MockRepository repository = MockRepository._(prefs);
    repository._hydrate();
    return repository;
  }

  void _hydrate() {
    _repositories = List<RepositorySummary>.from(seededRepositories);
    _pullRequests = seededPullRequests.map(
      (String key, List<PullRequestSummary> value) =>
          MapEntry<String, List<PullRequestSummary>>(
              key, List<PullRequestSummary>.from(value)),
    );
    _issues = seededIssues.map(
      (String key, List<IssueSummary> value) =>
          MapEntry<String, List<IssueSummary>>(
              key, List<IssueSummary>.from(value)),
    );
    _notifications = List<NotificationItem>.from(seededNotifications);
    _activities = List<ActivityEvent>.from(seededActivities);
    _analytics = seededAnalytics;
    _scenarios = List<WorkflowScenario>.from(seededWorkflowScenarios);
    _restoreMergedPullRequests();
    _restoreReadNotifications();
  }

  Future<T> _latency<T>(T Function() resolver, {int milliseconds = 220}) async {
    await Future<void>.delayed(Duration(milliseconds: milliseconds));
    return resolver();
  }

  void _restoreMergedPullRequests() {
    final Set<String> mergedIds =
        (preferences.getStringList(_mergedKey) ?? <String>[]).toSet();
    _pullRequests.forEach((String repoKey, List<PullRequestSummary> pulls) {
      for (int index = 0; index < pulls.length; index += 1) {
        final PullRequestSummary pull = pulls[index];
        final String id = '$repoKey#${pull.number}';
        if (!mergedIds.contains(id)) continue;
        pulls[index] = pull.copyWith(
          state: 'closed',
          merged: true,
          mergedAt: DateTime.now().toUtc(),
          checkStatus: 'passing',
        );
      }
    });
  }

  void _restoreReadNotifications() {
    final Set<String> readIds =
        (preferences.getStringList(_readNotificationsKey) ?? <String>[])
            .toSet();
    for (int index = 0; index < _notifications.length; index += 1) {
      final NotificationItem item = _notifications[index];
      if (!readIds.contains(item.id)) continue;
      _notifications[index] = item.copyWith(read: true);
    }
  }

  @override
  Future<List<RepositorySummary>> listRepositories() {
    return _latency<List<RepositorySummary>>(
      () => List<RepositorySummary>.from(_repositories),
    );
  }

  @override
  Future<List<PullRequestSummary>> listPullRequests(String repositoryKey) {
    return _latency<List<PullRequestSummary>>(
      () => List<PullRequestSummary>.from(
          _pullRequests[repositoryKey] ?? <PullRequestSummary>[]),
      milliseconds: 280,
    );
  }

  @override
  Future<List<IssueSummary>> listIssues(String repositoryKey) {
    return _latency<List<IssueSummary>>(
      () => List<IssueSummary>.from(_issues[repositoryKey] ?? <IssueSummary>[]),
      milliseconds: 260,
    );
  }

  @override
  Future<MergeOutcome> mergePullRequest({
    required String repositoryKey,
    required int pullNumber,
    required String method,
    required String actor,
  }) async {
    final List<PullRequestSummary> pulls =
        _pullRequests[repositoryKey] ?? <PullRequestSummary>[];
    final int index = pulls
        .indexWhere((PullRequestSummary item) => item.number == pullNumber);
    if (index == -1) {
      return const MergeOutcome(
          merged: false, message: 'Pull request not found.', method: 'none');
    }

    final PullRequestSummary target = pulls[index];
    if (target.merged) {
      return MergeOutcome(
          merged: true,
          message: 'Pull request already merged.',
          method: method);
    }

    pulls[index] = target.copyWith(
      state: 'closed',
      merged: true,
      mergedAt: DateTime.now().toUtc(),
      checkStatus: 'passing',
    );

    final Set<String> mergedIds =
        (preferences.getStringList(_mergedKey) ?? <String>[]).toSet();
    mergedIds.add('$repositoryKey#$pullNumber');
    await preferences.setStringList(_mergedKey, mergedIds.toList());

    _activities.insert(
      0,
      ActivityEvent(
        id: 'act-merge-${DateTime.now().millisecondsSinceEpoch}',
        actor: actor,
        action: 'merge($method)',
        target: '$repositoryKey#$pullNumber',
        occurredAt: DateTime.now().toUtc(),
        severity: 'info',
      ),
    );

    return MergeOutcome(
        merged: true,
        message: 'Merged successfully in simulated flow.',
        method: method);
  }

  @override
  Future<AiReviewJob> startAiReview({
    required String repositoryKey,
    required int pullNumber,
    String? focus,
  }) async {
    _jobCounter += 1;
    final String id = 'demo-job-$_jobCounter';
    final DateTime createdAt = DateTime.now().toUtc();
    final AiReviewJob queued =
        AiReviewJob(id: id, status: JobStatus.queued, createdAt: createdAt);
    _jobs[id] = queued;

    Future<void>(() async {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      _jobs[id] = queued.copyWith(status: JobStatus.running);

      await Future<void>.delayed(const Duration(milliseconds: 850));
      final bool isFailure =
          repositoryKey.contains('automation') && pullNumber == 7;
      if (isFailure) {
        _jobs[id] = _jobs[id]!.copyWith(
          status: JobStatus.failed,
          completedAt: DateTime.now().toUtc(),
          error: 'Mock model timeout. Retry with focus scope.',
        );
        _activities.insert(
          0,
          ActivityEvent(
            id: 'act-review-failure-$id',
            actor: 'ai-service',
            action: 'review-failed',
            target: '$repositoryKey#$pullNumber',
            occurredAt: DateTime.now().toUtc(),
            severity: 'high',
          ),
        );
        return;
      }

      final AiReviewResult result = AiReviewResult(
        summary:
            'Review complete for $repositoryKey#$pullNumber. 2 findings identified.',
        findings: <AiReviewFinding>[
          const AiReviewFinding(
            severity: 'medium',
            title: 'Pending TODO in changed code',
            description: 'Replace TODO markers with concrete validation logic.',
            file: 'app/main.py',
            line: 15,
          ),
          AiReviewFinding(
            severity: focus == null ? 'low' : 'info',
            title:
                focus == null ? 'Add regression tests' : 'Focus acknowledged',
            description: focus == null
                ? 'Add coverage for merge edge cases and failed job retries.'
                : 'Review focus applied to: $focus',
            file: 'backend/tests',
            line: null,
          ),
        ],
      );

      _jobs[id] = _jobs[id]!.copyWith(
        status: JobStatus.completed,
        completedAt: DateTime.now().toUtc(),
        result: result,
      );
      _activities.insert(
        0,
        ActivityEvent(
          id: 'act-review-success-$id',
          actor: 'ai-service',
          action: 'review-completed',
          target: '$repositoryKey#$pullNumber',
          occurredAt: DateTime.now().toUtc(),
          severity: 'info',
        ),
      );
    });

    return _latency<AiReviewJob>(() => queued, milliseconds: 140);
  }

  @override
  Future<AiReviewJob?> getAiReviewJob(String id) {
    return _latency<AiReviewJob?>(() => _jobs[id], milliseconds: 120);
  }

  @override
  Future<List<NotificationItem>> listNotifications() {
    return _latency<List<NotificationItem>>(
      () => List<NotificationItem>.from(_notifications),
      milliseconds: 160,
    );
  }

  @override
  Future<void> markNotificationRead(String id) async {
    final int index =
        _notifications.indexWhere((NotificationItem item) => item.id == id);
    if (index == -1) return;
    _notifications[index] = _notifications[index].copyWith(read: true);
    final Set<String> readIds =
        (preferences.getStringList(_readNotificationsKey) ?? <String>[])
            .toSet();
    readIds.add(id);
    await preferences.setStringList(_readNotificationsKey, readIds.toList());
  }

  @override
  Future<List<ActivityEvent>> listActivities() {
    return _latency<List<ActivityEvent>>(
      () => List<ActivityEvent>.from(_activities.take(30)),
      milliseconds: 150,
    );
  }

  @override
  Future<AnalyticsSnapshot> getAnalytics() {
    return _latency<AnalyticsSnapshot>(() => _analytics, milliseconds: 120);
  }

  @override
  List<WorkflowScenario> listWorkflowScenarios() {
    return List<WorkflowScenario>.from(_scenarios);
  }

  @override
  Future<HealthSnapshot> getHealth(RuntimeMode mode) {
    final Map<String, String> services = <String, String>{
      'frontend': 'ok',
      if (mode != RuntimeMode.demo) 'backend': 'ok',
      if (mode == RuntimeMode.development || mode == RuntimeMode.production)
        'ollama': 'ok',
      if (mode == RuntimeMode.production) 'postgres': 'degraded',
      if (mode == RuntimeMode.production) 'redis': 'ok',
    };
    final String status =
        services.containsValue('degraded') ? 'degraded' : 'ok';
    return _latency<HealthSnapshot>(
      () => HealthSnapshot(status: status, mode: mode, services: services),
      milliseconds: 100,
    );
  }

  @override
  Future<AuthStatusSnapshot> getAuthStatus() {
    return _latency<AuthStatusSnapshot>(
      () => const AuthStatusSnapshot(
        authenticated: true,
        appMode: RuntimeMode.demo,
        mode: 'demo',
        githubAppReady: false,
        rbacEnabled: false,
        csrfProtectionEnabled: false,
        tokenRotationEnabled: false,
        aiProvider: 'mock-ai',
        user: 'demo-admin',
        role: 'admin',
      ),
      milliseconds: 90,
    );
  }
}
