import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import '../integration/compatibility_wrappers.dart';
import '../runtime/http_api_client.dart';
import 'gitvibe_repository.dart';
import 'mock_data_seed.dart';

class RemoteRepository implements GitVibeRepository {
  RemoteRepository({
    required this.preferences,
    required HttpApiClient apiClient,
    required RuntimeMode runtimeMode,
  })  : _apiClient = apiClient,
        _runtimeMode = runtimeMode;

  static const String _readNotificationsKey =
      'theme_preview.read_notifications';

  @override
  final SharedPreferences preferences;

  final HttpApiClient _apiClient;
  final RuntimeMode _runtimeMode;

  @override
  Future<List<RepositorySummary>> listRepositories() async {
    final Map<String, dynamic> payload = await _apiClient.getJson(
      '/api/repos',
      requireAuth: _runtimeMode != RuntimeMode.demo,
    );
    final List<Map<String, dynamic>> items = _objectList(
      payload['repos'],
      context: '/api/repos repos',
    );
    return items
        .map((Map<String, dynamic> item) =>
            RepositoryPayloadAdapter.fromApi(item))
        .toList(growable: false);
  }

  @override
  Future<List<PullRequestSummary>> listPullRequests(
      String repositoryKey) async {
    final ({String owner, String repo}) parsed =
        _parseRepositoryKey(repositoryKey);
    final Map<String, dynamic> payload = await _apiClient.getJson(
      '/api/repos/${Uri.encodeComponent(parsed.owner)}/${Uri.encodeComponent(parsed.repo)}/pulls',
      requireAuth: _runtimeMode != RuntimeMode.demo,
    );
    final List<Map<String, dynamic>> items = _objectList(
      payload['pull_requests'],
      context: '/api/repos/{owner}/{repo}/pulls pull_requests',
    );
    return items
        .map((Map<String, dynamic> item) =>
            PullRequestPayloadAdapter.fromApi(item))
        .toList(growable: false);
  }

  @override
  Future<List<IssueSummary>> listIssues(String repositoryKey) async {
    final ({String owner, String repo}) parsed =
        _parseRepositoryKey(repositoryKey);
    final Map<String, dynamic> payload = await _apiClient.getJson(
      '/api/repos/${Uri.encodeComponent(parsed.owner)}/${Uri.encodeComponent(parsed.repo)}/issues',
      requireAuth: _runtimeMode != RuntimeMode.demo,
    );
    final List<Map<String, dynamic>> items = _objectList(
      payload['issues'],
      context: '/api/repos/{owner}/{repo}/issues issues',
    );
    return items
        .map((Map<String, dynamic> item) => IssuePayloadAdapter.fromApi(item))
        .toList(growable: false);
  }

  @override
  Future<MergeOutcome> mergePullRequest({
    required String repositoryKey,
    required int pullNumber,
    required String method,
    required String actor,
  }) async {
    final ({String owner, String repo}) parsed =
        _parseRepositoryKey(repositoryKey);
    final Map<String, dynamic> payload = await _apiClient.postJson(
      '/api/repos/${Uri.encodeComponent(parsed.owner)}/${Uri.encodeComponent(parsed.repo)}/pulls/$pullNumber/merge',
      requireAuth: _runtimeMode != RuntimeMode.demo,
      includeCsrf: true,
      body: <String, dynamic>{
        'merge_method': method,
      },
    );
    final bool merged = payload['merged'] == true;
    final String resolvedMethod = payload['merge_method']?.toString() ?? method;
    final String message = payload['message']?.toString() ??
        payload['status']?.toString() ??
        (merged
            ? 'Merged successfully by $actor.'
            : 'Merge request completed.');
    return MergeOutcome(
      merged: merged,
      message: message,
      method: resolvedMethod,
    );
  }

  @override
  Future<AiReviewJob> startAiReview({
    required String repositoryKey,
    required int pullNumber,
    String? focus,
  }) async {
    final ({String owner, String repo}) parsed =
        _parseRepositoryKey(repositoryKey);
    final Map<String, dynamic> payload = await _apiClient.postJson(
      '/api/ai/review/jobs',
      requireAuth: _runtimeMode != RuntimeMode.demo,
      includeCsrf: true,
      body: <String, dynamic>{
        'owner': parsed.owner,
        'repo': parsed.repo,
        'pull_number': pullNumber,
        if (focus != null && focus.isNotEmpty) 'focus': focus,
      },
    );
    final Map<String, dynamic> jobPayload = _object(
      payload['job'],
      context: '/api/ai/review/jobs job',
    );
    return _toAiReviewJob(jobPayload);
  }

  @override
  Future<AiReviewJob?> getAiReviewJob(String id) async {
    final Map<String, dynamic> payload = await _apiClient.getJson(
      '/api/jobs/${Uri.encodeComponent(id)}',
      requireAuth: _runtimeMode != RuntimeMode.demo,
    );
    final dynamic rawJob = payload['job'];
    if (rawJob == null) {
      return null;
    }
    return _toAiReviewJob(_object(rawJob, context: '/api/jobs/{job_id} job'));
  }

  @override
  Future<List<NotificationItem>> listNotifications() async {
    final Set<String> readIds =
        (preferences.getStringList(_readNotificationsKey) ?? <String>[])
            .toSet();
    final List<Map<String, dynamic>> events = await _fetchRecentEvents();
    if (events.isEmpty) {
      return seededNotifications
          .map((NotificationItem item) =>
              item.copyWith(read: readIds.contains(item.id) || item.read))
          .toList(growable: false);
    }
    return events.reversed
        .map((Map<String, dynamic> item) =>
            _toNotification(item, readIds: readIds))
        .toList(growable: false);
  }

  @override
  Future<void> markNotificationRead(String id) async {
    final Set<String> readIds =
        (preferences.getStringList(_readNotificationsKey) ?? <String>[])
            .toSet();
    readIds.add(id);
    await preferences.setStringList(
        _readNotificationsKey, readIds.toList(growable: false));
  }

  @override
  Future<List<ActivityEvent>> listActivities() async {
    final List<Map<String, dynamic>> events = await _fetchRecentEvents();
    if (events.isEmpty) {
      return List<ActivityEvent>.from(seededActivities);
    }
    return events.reversed
        .map((Map<String, dynamic> item) => _toActivity(item))
        .toList(growable: false);
  }

  @override
  Future<AnalyticsSnapshot> getAnalytics() async {
    final List<RepositorySummary> repositories = await listRepositories();
    int openPullRequests = 0;
    int mergedToday = 0;
    int failedReviews = 0;
    int totalReviews = 0;
    final DateTime now = DateTime.now().toUtc();
    for (final RepositorySummary repository in repositories) {
      final List<PullRequestSummary> pulls =
          await listPullRequests(repository.key);
      for (final PullRequestSummary pull in pulls) {
        totalReviews += 1;
        final String checkStatus = pull.checkStatus.toLowerCase();
        if (checkStatus == 'failing' || checkStatus == 'failed') {
          failedReviews += 1;
        }
        if (pull.state.toLowerCase() == 'open' && !pull.merged) {
          openPullRequests += 1;
        }
        final DateTime? mergedAt = pull.mergedAt;
        if (pull.merged &&
            mergedAt != null &&
            mergedAt.year == now.year &&
            mergedAt.month == now.month &&
            mergedAt.day == now.day) {
          mergedToday += 1;
        }
      }
    }
    final int passingCount = totalReviews - failedReviews;
    final double automationCoverage =
        totalReviews == 0 ? 0 : (passingCount / totalReviews) * 100;
    return AnalyticsSnapshot(
      openPullRequests: openPullRequests,
      mergedToday: mergedToday,
      failedReviews: failedReviews,
      avgReviewMinutes: totalReviews == 0 ? 0 : 18,
      automationCoveragePercent: automationCoverage,
    );
  }

  @override
  List<WorkflowScenario> listWorkflowScenarios() {
    return List<WorkflowScenario>.from(seededWorkflowScenarios);
  }

  @override
  Future<HealthSnapshot> getHealth(RuntimeMode mode) async {
    final Map<String, dynamic> payload = await _apiClient.getJson('/health');
    final HealthSnapshot snapshot = HealthPayloadAdapter.fromApi(payload);
    if (snapshot.mode == mode) {
      return snapshot;
    }
    return HealthSnapshot(
      status: snapshot.status,
      mode: mode,
      services: snapshot.services,
    );
  }

  @override
  Future<AuthStatusSnapshot> getAuthStatus() async {
    final Map<String, dynamic> payload = await _apiClient.getJson(
      '/api/auth/status',
      requireAuth: false,
    );
    return AuthStatusPayloadAdapter.fromApi(payload);
  }

  Future<List<Map<String, dynamic>>> _fetchRecentEvents() async {
    final Map<String, dynamic> payload = await _apiClient.getJson(
      '/api/platform/events?limit=30',
      requireAuth: _runtimeMode != RuntimeMode.demo,
    );
    return _objectList(
      payload['recent_events'],
      context: '/api/platform/events recent_events',
    );
  }

  ({String owner, String repo}) _parseRepositoryKey(String repositoryKey) {
    final List<String> parts = repositoryKey.split('/');
    if (parts.length != 2 || parts.any((String item) => item.isEmpty)) {
      throw FormatException(
        'Invalid repository key "$repositoryKey". Expected "owner/repository".',
      );
    }
    return (owner: parts[0], repo: parts[1]);
  }

  NotificationItem _toNotification(
    Map<String, dynamic> event, {
    required Set<String> readIds,
  }) {
    final String id = event['id']?.toString() ??
        'evt-${DateTime.now().microsecondsSinceEpoch}';
    final String topic = event['topic']?.toString() ?? 'event';
    final String source = event['source']?.toString() ?? 'system';
    final Map<String, dynamic> payload = event['payload'] == null
        ? <String, dynamic>{}
        : _object(event['payload'], context: 'event payload');
    final DateTime createdAt = _parseDateTime(event['timestamp']);
    return NotificationItem(
      id: id,
      title: topic,
      message: payload.isEmpty
          ? 'Event emitted by $source.'
          : _stringifyPayload(payload),
      createdAt: createdAt,
      priority: _priorityForTopic(topic: topic, payload: payload),
      read: readIds.contains(id),
    );
  }

  ActivityEvent _toActivity(Map<String, dynamic> event) {
    final String id = event['id']?.toString() ??
        'evt-${DateTime.now().microsecondsSinceEpoch}';
    final String topic = event['topic']?.toString() ?? 'event';
    final String source = event['source']?.toString() ?? 'system';
    final Map<String, dynamic> payload = event['payload'] == null
        ? <String, dynamic>{}
        : _object(event['payload'], context: 'event payload');
    return ActivityEvent(
      id: id,
      actor: source,
      action: topic,
      target: _resolveEventTarget(payload),
      occurredAt: _parseDateTime(event['timestamp']),
      severity: _severityForTopic(topic: topic, payload: payload),
    );
  }

  AiReviewJob _toAiReviewJob(Map<String, dynamic> payload) {
    final String id =
        payload['id']?.toString() ?? payload['job_id']?.toString() ?? '';
    if (id.isEmpty) {
      throw const FormatException('AI review job payload is missing id.');
    }
    return AiReviewJob(
      id: id,
      status: _parseJobStatus(payload['status']?.toString() ?? 'queued'),
      createdAt: _parseDateTime(payload['created_at']),
      completedAt: payload['completed_at'] == null
          ? null
          : _parseDateTime(payload['completed_at']),
      result: _parseReviewResult(payload['result']),
      error: payload['error']?.toString(),
    );
  }

  AiReviewResult? _parseReviewResult(dynamic raw) {
    if (raw == null) {
      return null;
    }
    final Map<String, dynamic> map = _object(raw, context: 'ai review result');
    final List<Map<String, dynamic>> findingsPayload = _objectList(
      map['findings'],
      context: 'ai review findings',
    );
    return AiReviewResult(
      summary: map['summary']?.toString() ?? 'Review completed.',
      findings: findingsPayload.map((Map<String, dynamic> finding) {
        return AiReviewFinding(
          severity: finding['severity']?.toString() ?? 'info',
          title: finding['title']?.toString() ?? 'Finding',
          description: finding['description']?.toString() ?? '',
          file: finding['file']?.toString() ?? 'unknown',
          line: _toOptionalInt(finding['line']),
        );
      }).toList(growable: false),
    );
  }

  DateTime _parseDateTime(dynamic value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt() * 1000,
        isUtc: true,
      );
    }
    if (value is String && value.isNotEmpty) {
      final DateTime? parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed.toUtc();
      }
    }
    return DateTime.now().toUtc();
  }

  int? _toOptionalInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  JobStatus _parseJobStatus(String raw) {
    final String normalized = raw.trim().toLowerCase();
    return JobStatus.values.firstWhere(
      (JobStatus item) => item.name == normalized,
      orElse: () => JobStatus.queued,
    );
  }

  String _priorityForTopic({
    required String topic,
    required Map<String, dynamic> payload,
  }) {
    final String normalized = topic.toLowerCase();
    final String status = payload['status']?.toString().toLowerCase() ?? '';
    if (normalized.contains('failed') || status == 'failed') {
      return 'high';
    }
    if (normalized.contains('security') ||
        normalized.contains('blocked') ||
        normalized.contains('warning')) {
      return 'medium';
    }
    return 'low';
  }

  String _severityForTopic({
    required String topic,
    required Map<String, dynamic> payload,
  }) {
    final String priority = _priorityForTopic(topic: topic, payload: payload);
    if (priority == 'high') {
      return 'high';
    }
    if (priority == 'medium') {
      return 'warning';
    }
    return 'info';
  }

  String _resolveEventTarget(Map<String, dynamic> payload) {
    if (payload['owner'] != null && payload['repo'] != null) {
      return '${payload['owner']}/${payload['repo']}';
    }
    if (payload['request_id'] != null) {
      return payload['request_id'].toString();
    }
    if (payload.isEmpty) {
      return 'system';
    }
    return _stringifyPayload(payload);
  }

  String _stringifyPayload(Map<String, dynamic> payload) {
    if (payload.isEmpty) {
      return 'no payload';
    }
    final Iterable<String> pairs = payload.entries.take(3).map(
        (MapEntry<String, dynamic> entry) => '${entry.key}=${entry.value}');
    return pairs.join(' • ');
  }

  Map<String, dynamic> _object(dynamic value, {required String context}) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic item) => MapEntry<String, dynamic>(
          key.toString(),
          item,
        ),
      );
    }
    throw FormatException('Expected JSON object for $context.');
  }

  List<Map<String, dynamic>> _objectList(dynamic value,
      {required String context}) {
    if (value == null) {
      return <Map<String, dynamic>>[];
    }
    if (value is! List) {
      throw FormatException('Expected JSON array for $context.');
    }
    return value
        .map((dynamic item) => _object(item, context: context))
        .toList(growable: false);
  }
}
