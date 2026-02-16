import '../domain/models.dart';

class RuntimeConfig {
  const RuntimeConfig({
    required this.appMode,
    required this.apiBaseUrl,
    required this.demoNamespace,
    required this.allowDemoOnPublicHost,
    required this.bootstrapAdminToken,
    required this.bootstrapUsername,
    required this.bootstrapRole,
  });

  final RuntimeMode appMode;
  final String apiBaseUrl;
  final String demoNamespace;
  final bool allowDemoOnPublicHost;
  final String bootstrapAdminToken;
  final String bootstrapUsername;
  final String bootstrapRole;

  factory RuntimeConfig.fromEnvironment() {
    final RuntimeMode mode = _parseMode(const String.fromEnvironment(
      'APP_MODE',
      defaultValue: 'demo',
    ));
    final String roleCandidate = const String.fromEnvironment(
      'BOOTSTRAP_ROLE',
      defaultValue: 'admin',
    ).trim().toLowerCase();
    final String role = UserRole.values
            .map((UserRole item) => item.name)
            .contains(roleCandidate)
        ? roleCandidate
        : UserRole.admin.name;
    return RuntimeConfig(
      appMode: mode,
      apiBaseUrl:
          const String.fromEnvironment('API_BASE_URL', defaultValue: ''),
      demoNamespace: const String.fromEnvironment(
        'DEMO_NAMESPACE',
        defaultValue: 'gitvibe_demo_v1',
      ),
      allowDemoOnPublicHost: _parseBool(
        const String.fromEnvironment('ALLOW_DEMO_ON_PUBLIC_HOST',
            defaultValue: 'false'),
        fallback: false,
      ),
      bootstrapAdminToken: const String.fromEnvironment(
        'BOOTSTRAP_ADMIN_TOKEN',
        defaultValue: '',
      ),
      bootstrapUsername: const String.fromEnvironment(
        'BOOTSTRAP_USERNAME',
        defaultValue: 'flutter-operator',
      ),
      bootstrapRole: role,
    );
  }

  static RuntimeMode _parseMode(String raw) {
    final String normalized = raw.trim().toLowerCase();
    return RuntimeMode.values.firstWhere(
      (RuntimeMode item) => item.name == normalized,
      orElse: () => RuntimeMode.demo,
    );
  }

  static bool _parseBool(String raw, {required bool fallback}) {
    final String normalized = raw.trim().toLowerCase();
    if (normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'on') {
      return true;
    }
    if (normalized == '0' ||
        normalized == 'false' ||
        normalized == 'no' ||
        normalized == 'off') {
      return false;
    }
    return fallback;
  }
}
