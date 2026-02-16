import '../domain/models.dart';

class RepositoryPayloadAdapter {
  static RepositorySummary fromApi(Map<String, dynamic> payload) {
    final String owner = payload['owner']?.toString() ??
        _ownerFromFullName(payload['full_name']?.toString());
    final String name = payload['name']?.toString() ??
        _nameFromFullName(payload['full_name']?.toString());
    return RepositorySummary(
      id: payload['id']?.toString() ?? '$owner/$name',
      owner: owner,
      name: name,
      description: payload['description']?.toString() ?? 'No description',
      language: payload['language']?.toString() ?? 'Unknown',
      stars: (payload['stars'] as num?)?.toInt() ??
          (payload['stargazers_count'] as num?)?.toInt() ??
          0,
    );
  }

  static String _ownerFromFullName(String? fullName) =>
      (fullName ?? 'demo/unknown').split('/').first;
  static String _nameFromFullName(String? fullName) {
    final List<String> parts = (fullName ?? 'demo/unknown').split('/');
    return parts.length > 1 ? parts[1] : 'unknown';
  }
}

class PullRequestPayloadAdapter {
  static PullRequestSummary fromApi(Map<String, dynamic> payload) {
    return PullRequestSummary(
      number: (payload['number'] as num?)?.toInt() ?? -1,
      title: payload['title']?.toString() ?? 'Untitled PR',
      author: payload['author']?.toString() ??
          payload['user']?.toString() ??
          'unknown',
      state: payload['state']?.toString() ?? 'open',
      createdAt: DateTime.tryParse(payload['created_at']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      headBranch: payload['head_branch']?.toString() ??
          payload['head']?.toString() ??
          'feature/unknown',
      baseBranch: payload['base_branch']?.toString() ??
          payload['base']?.toString() ??
          'main',
      body: payload['body']?.toString() ?? '',
      diff: payload['diff']?.toString() ?? '',
      merged: payload['merged'] == true || payload['merged_at'] != null,
      mergedAt: payload['merged_at'] == null
          ? null
          : DateTime.tryParse(payload['merged_at'].toString()),
      checkStatus: payload['checks']?.toString() ??
          payload['check_status']?.toString() ??
          'unknown',
    );
  }
}

class IssuePayloadAdapter {
  static IssueSummary fromApi(Map<String, dynamic> payload) {
    return IssueSummary(
      number: (payload['number'] as num?)?.toInt() ?? -1,
      title: payload['title']?.toString() ?? 'Untitled Issue',
      author: payload['author']?.toString() ??
          payload['user']?.toString() ??
          'unknown',
      state: payload['state']?.toString() ?? 'open',
      createdAt: DateTime.tryParse(payload['created_at']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      labels: (payload['labels'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(),
    );
  }
}

class HealthPayloadAdapter {
  static HealthSnapshot fromApi(Map<String, dynamic> payload) {
    final RuntimeMode mode = _parseMode(
      payload['app_mode']?.toString() ?? payload['mode']?.toString(),
    );

    final Map<String, dynamic> servicesRaw =
        payload['services'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final Map<String, String> services = servicesRaw.map(
      (String key, dynamic value) => MapEntry<String, String>(
          key,
          value is Map<String, dynamic>
              ? value['detail']?.toString() ?? 'ok'
              : value.toString()),
    );

    return HealthSnapshot(
      status: payload['status']?.toString() ?? 'unknown',
      mode: mode,
      services: services,
    );
  }
}

class AuthStatusPayloadAdapter {
  static AuthStatusSnapshot fromApi(Map<String, dynamic> payload) {
    return AuthStatusSnapshot(
      authenticated: _parseBool(payload['authenticated']),
      appMode: _parseMode(
        payload['app_mode']?.toString() ?? payload['mode']?.toString(),
      ),
      mode: payload['mode']?.toString() ?? 'unknown',
      githubAppReady: _parseBool(payload['github_app_ready']),
      rbacEnabled: _parseBool(payload['rbac_enabled']),
      csrfProtectionEnabled: _parseBool(payload['csrf_protection_enabled']),
      tokenRotationEnabled: _parseBool(payload['token_rotation_enabled']),
      aiProvider: payload['ai_provider']?.toString() ?? 'unknown',
      user: payload['user']?.toString(),
      role: payload['role']?.toString(),
    );
  }
}

RuntimeMode _parseMode(String? modeRaw) {
  final String normalized = modeRaw?.trim().toLowerCase() ?? '';
  return RuntimeMode.values.firstWhere(
    (RuntimeMode item) => item.name == normalized,
    orElse: () => RuntimeMode.development,
  );
}

bool _parseBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final String normalized = value.trim().toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'on';
  }
  return false;
}
