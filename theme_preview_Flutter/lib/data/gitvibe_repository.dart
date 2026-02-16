import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

abstract class GitVibeRepository {
  SharedPreferences get preferences;

  Future<List<RepositorySummary>> listRepositories();
  Future<List<PullRequestSummary>> listPullRequests(String repositoryKey);
  Future<List<IssueSummary>> listIssues(String repositoryKey);

  Future<MergeOutcome> mergePullRequest({
    required String repositoryKey,
    required int pullNumber,
    required String method,
    required String actor,
  });

  Future<AiReviewJob> startAiReview({
    required String repositoryKey,
    required int pullNumber,
    String? focus,
  });

  Future<AiReviewJob?> getAiReviewJob(String id);

  Future<List<NotificationItem>> listNotifications();
  Future<void> markNotificationRead(String id);
  Future<List<ActivityEvent>> listActivities();
  Future<AnalyticsSnapshot> getAnalytics();
  List<WorkflowScenario> listWorkflowScenarios();
  Future<HealthSnapshot> getHealth(RuntimeMode mode);
  Future<AuthStatusSnapshot> getAuthStatus();
}
