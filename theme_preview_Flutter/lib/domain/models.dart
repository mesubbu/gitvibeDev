enum UserRole { viewer, operator, admin }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.viewer:
        return 'Viewer';
      case UserRole.operator:
        return 'Operator';
      case UserRole.admin:
        return 'Admin';
    }
  }
}

enum RuntimeMode { demo, development, production }

extension RuntimeModeX on RuntimeMode {
  String get label {
    switch (this) {
      case RuntimeMode.demo:
        return 'Demo';
      case RuntimeMode.development:
        return 'Development';
      case RuntimeMode.production:
        return 'Production';
    }
  }
}

enum ThemeVariant { variantA, variantB, variantC }

extension ThemeVariantX on ThemeVariant {
  String get label {
    switch (this) {
      case ThemeVariant.variantA:
        return 'Variant A';
      case ThemeVariant.variantB:
        return 'Variant B';
      case ThemeVariant.variantC:
        return 'Variant C';
    }
  }
}

enum DensityMode { compact, comfortable }

extension DensityModeX on DensityMode {
  String get label => this == DensityMode.compact ? 'Compact' : 'Comfortable';
}

enum WorkMode { focus, review }

extension WorkModeX on WorkMode {
  String get label => this == WorkMode.focus ? 'Focus' : 'Review';
}

enum DeviceType { mobile, tablet, desktop }

extension DeviceTypeX on DeviceType {
  String get label {
    switch (this) {
      case DeviceType.mobile:
        return 'Mobile';
      case DeviceType.tablet:
        return 'Tablet';
      case DeviceType.desktop:
        return 'Desktop';
    }
  }
}

enum TaskComplexity { low, medium, high }

extension TaskComplexityX on TaskComplexity {
  String get label {
    switch (this) {
      case TaskComplexity.low:
        return 'Low';
      case TaskComplexity.medium:
        return 'Medium';
      case TaskComplexity.high:
        return 'High';
    }
  }
}

class RepositorySummary {
  const RepositorySummary({
    required this.id,
    required this.owner,
    required this.name,
    required this.description,
    required this.language,
    required this.stars,
  });

  final String id;
  final String owner;
  final String name;
  final String description;
  final String language;
  final int stars;

  String get key => '$owner/$name';
}

class PullRequestSummary {
  const PullRequestSummary({
    required this.number,
    required this.title,
    required this.author,
    required this.state,
    required this.createdAt,
    required this.headBranch,
    required this.baseBranch,
    required this.body,
    required this.diff,
    this.merged = false,
    this.mergedAt,
    this.checkStatus = 'passing',
  });

  final int number;
  final String title;
  final String author;
  final String state;
  final DateTime createdAt;
  final String headBranch;
  final String baseBranch;
  final String body;
  final String diff;
  final bool merged;
  final DateTime? mergedAt;
  final String checkStatus;

  PullRequestSummary copyWith({
    String? state,
    bool? merged,
    DateTime? mergedAt,
    String? checkStatus,
  }) {
    return PullRequestSummary(
      number: number,
      title: title,
      author: author,
      state: state ?? this.state,
      createdAt: createdAt,
      headBranch: headBranch,
      baseBranch: baseBranch,
      body: body,
      diff: diff,
      merged: merged ?? this.merged,
      mergedAt: mergedAt ?? this.mergedAt,
      checkStatus: checkStatus ?? this.checkStatus,
    );
  }
}

class IssueSummary {
  const IssueSummary({
    required this.number,
    required this.title,
    required this.author,
    required this.state,
    required this.createdAt,
    required this.labels,
  });

  final int number;
  final String title;
  final String author;
  final String state;
  final DateTime createdAt;
  final List<String> labels;
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.priority,
    required this.read,
  });

  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final String priority;
  final bool read;

  NotificationItem copyWith({bool? read}) {
    return NotificationItem(
      id: id,
      title: title,
      message: message,
      createdAt: createdAt,
      priority: priority,
      read: read ?? this.read,
    );
  }
}

class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.actor,
    required this.action,
    required this.target,
    required this.occurredAt,
    required this.severity,
  });

  final String id;
  final String actor;
  final String action;
  final String target;
  final DateTime occurredAt;
  final String severity;
}

class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    required this.openPullRequests,
    required this.mergedToday,
    required this.failedReviews,
    required this.avgReviewMinutes,
    required this.automationCoveragePercent,
  });

  final int openPullRequests;
  final int mergedToday;
  final int failedReviews;
  final int avgReviewMinutes;
  final double automationCoveragePercent;
}

enum WorkflowStepState { pending, inProgress, completed, failed }

class WorkflowStep {
  const WorkflowStep({
    required this.id,
    required this.label,
    required this.description,
    required this.state,
  });

  final String id;
  final String label;
  final String description;
  final WorkflowStepState state;
}

class WorkflowScenario {
  const WorkflowScenario({
    required this.id,
    required this.name,
    required this.persona,
    required this.steps,
    required this.recoveryHint,
    required this.heavyDataPoints,
  });

  final String id;
  final String name;
  final String persona;
  final List<WorkflowStep> steps;
  final String recoveryHint;
  final int heavyDataPoints;
}

class AiReviewFinding {
  const AiReviewFinding({
    required this.severity,
    required this.title,
    required this.description,
    required this.file,
    required this.line,
  });

  final String severity;
  final String title;
  final String description;
  final String file;
  final int? line;
}

class AiReviewResult {
  const AiReviewResult({
    required this.summary,
    required this.findings,
  });

  final String summary;
  final List<AiReviewFinding> findings;
}

enum JobStatus { queued, running, completed, failed }

extension JobStatusX on JobStatus {
  String get label {
    switch (this) {
      case JobStatus.queued:
        return 'Queued';
      case JobStatus.running:
        return 'Running';
      case JobStatus.completed:
        return 'Completed';
      case JobStatus.failed:
        return 'Failed';
    }
  }
}

class AiReviewJob {
  const AiReviewJob({
    required this.id,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.result,
    this.error,
  });

  final String id;
  final JobStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final AiReviewResult? result;
  final String? error;

  AiReviewJob copyWith({
    JobStatus? status,
    DateTime? completedAt,
    AiReviewResult? result,
    String? error,
  }) {
    return AiReviewJob(
      id: id,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      result: result ?? this.result,
      error: error ?? this.error,
    );
  }
}

class MergeOutcome {
  const MergeOutcome({
    required this.merged,
    required this.message,
    required this.method,
  });

  final bool merged;
  final String message;
  final String method;
}

class HealthSnapshot {
  const HealthSnapshot({
    required this.status,
    required this.mode,
    required this.services,
  });

  final String status;
  final RuntimeMode mode;
  final Map<String, String> services;
}

class AuthStatusSnapshot {
  const AuthStatusSnapshot({
    required this.authenticated,
    required this.appMode,
    required this.mode,
    required this.githubAppReady,
    required this.rbacEnabled,
    required this.csrfProtectionEnabled,
    required this.tokenRotationEnabled,
    required this.aiProvider,
    this.user,
    this.role,
  });

  final bool authenticated;
  final RuntimeMode appMode;
  final String mode;
  final bool githubAppReady;
  final bool rbacEnabled;
  final bool csrfProtectionEnabled;
  final bool tokenRotationEnabled;
  final String aiProvider;
  final String? user;
  final String? role;
}
