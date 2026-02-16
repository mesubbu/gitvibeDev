import 'package:shared_preferences/shared_preferences.dart';

class AuthSessionStore {
  AuthSessionStore(this._preferences);

  static const String _accessTokenKey = 'theme_preview.auth.access_token';
  static const String _refreshTokenKey = 'theme_preview.auth.refresh_token';
  static const String _csrfTokenKey = 'theme_preview.auth.csrf_token';
  static const String _roleKey = 'theme_preview.auth.role';
  static const String _usernameKey = 'theme_preview.auth.username';

  final SharedPreferences _preferences;

  String _accessToken = '';
  String _refreshToken = '';
  String _csrfToken = '';
  String _role = '';
  String _username = '';

  String get accessToken => _accessToken;
  String get refreshToken => _refreshToken;
  String get csrfToken => _csrfToken;
  String get role => _role;
  String get username => _username;
  bool get hasAccessToken => _accessToken.isNotEmpty;

  Future<void> load() async {
    _accessToken = _preferences.getString(_accessTokenKey) ?? '';
    _refreshToken = _preferences.getString(_refreshTokenKey) ?? '';
    _csrfToken = _preferences.getString(_csrfTokenKey) ?? '';
    _role = _preferences.getString(_roleKey) ?? '';
    _username = _preferences.getString(_usernameKey) ?? '';
  }

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required String csrfToken,
    required String role,
    required String username,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _csrfToken = csrfToken;
    _role = role;
    _username = username;
    await _preferences.setString(_accessTokenKey, _accessToken);
    await _preferences.setString(_refreshTokenKey, _refreshToken);
    await _preferences.setString(_csrfTokenKey, _csrfToken);
    await _preferences.setString(_roleKey, _role);
    await _preferences.setString(_usernameKey, _username);
  }

  Future<void> clear() async {
    _accessToken = '';
    _refreshToken = '';
    _csrfToken = '';
    _role = '';
    _username = '';
    await _preferences.remove(_accessTokenKey);
    await _preferences.remove(_refreshTokenKey);
    await _preferences.remove(_csrfTokenKey);
    await _preferences.remove(_roleKey);
    await _preferences.remove(_usernameKey);
  }

  Future<void> writeFromTokenPayload(
    Map<String, dynamic> payload, {
    required String username,
  }) async {
    final String accessToken = payload['access_token']?.toString() ?? '';
    final String refreshToken = payload['refresh_token']?.toString() ?? '';
    final String csrfToken = payload['csrf_token']?.toString() ?? '';
    final String role = payload['role']?.toString() ?? '';
    if (accessToken.isEmpty ||
        refreshToken.isEmpty ||
        csrfToken.isEmpty ||
        role.isEmpty) {
      throw const FormatException(
        'Token payload is missing access_token, refresh_token, csrf_token, or role.',
      );
    }
    await save(
      accessToken: accessToken,
      refreshToken: refreshToken,
      csrfToken: csrfToken,
      role: role,
      username: username,
    );
  }
}
