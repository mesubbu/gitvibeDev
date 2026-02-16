import 'package:shared_preferences/shared_preferences.dart';

import '../data/gitvibe_repository.dart';
import '../data/mock_repository.dart';
import '../data/remote_repository.dart';
import '../domain/models.dart';
import 'auth_session_store.dart';
import 'http_api_client.dart';
import 'runtime_config.dart';

class RuntimeContext {
  const RuntimeContext({
    required this.config,
    required this.repository,
    required this.authSession,
  });

  final RuntimeConfig config;
  final GitVibeRepository repository;
  final AuthSessionStore authSession;
}

class RuntimeFactory {
  static const Set<String> _localHosts = <String>{
    '',
    'localhost',
    '127.0.0.1',
    '::1',
  };

  static Future<RuntimeContext> create() async {
    final RuntimeConfig config = RuntimeConfig.fromEnvironment();
    _enforceDemoModeSafety(config);

    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final AuthSessionStore authSession = AuthSessionStore(preferences);
    await authSession.load();

    if (config.appMode == RuntimeMode.demo) {
      final MockRepository repository = await MockRepository.create(
        preferences: preferences,
      );
      return RuntimeContext(
        config: config,
        repository: repository,
        authSession: authSession,
      );
    }

    final HttpApiClient apiClient = HttpApiClient(
      authSession: authSession,
      baseUrl: config.apiBaseUrl,
    );
    await _ensureBootstrapSession(
      config: config,
      authSession: authSession,
      apiClient: apiClient,
    );
    final RemoteRepository repository = RemoteRepository(
      preferences: preferences,
      apiClient: apiClient,
      runtimeMode: config.appMode,
    );
    return RuntimeContext(
      config: config,
      repository: repository,
      authSession: authSession,
    );
  }

  static void _enforceDemoModeSafety(RuntimeConfig config) {
    if (config.appMode != RuntimeMode.demo || config.allowDemoOnPublicHost) {
      return;
    }
    final String hostname = Uri.base.host.toLowerCase();
    if (_localHosts.contains(hostname)) {
      return;
    }
    throw StateError(
      'APP_MODE=demo is blocked on non-local hosts. Set ALLOW_DEMO_ON_PUBLIC_HOST=true for controlled demos.',
    );
  }

  static Future<void> _ensureBootstrapSession({
    required RuntimeConfig config,
    required AuthSessionStore authSession,
    required HttpApiClient apiClient,
  }) async {
    if (authSession.hasAccessToken || config.bootstrapAdminToken.isEmpty) {
      return;
    }
    final Map<String, dynamic> tokenPayload = await apiClient.postJson(
      '/api/auth/token',
      requireAuth: false,
      includeCsrf: false,
      extraHeaders: <String, String>{
        'x-bootstrap-token': config.bootstrapAdminToken,
      },
      body: <String, dynamic>{
        'username': config.bootstrapUsername,
        'role': config.bootstrapRole,
      },
    );
    await authSession.writeFromTokenPayload(
      tokenPayload,
      username: config.bootstrapUsername,
    );
  }
}
