import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_session_store.dart';

class ApiClientException implements Exception {
  const ApiClientException({
    required this.statusCode,
    required this.message,
  });

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiClientException($statusCode): $message';
}

class HttpApiClient {
  HttpApiClient({
    required AuthSessionStore authSession,
    String baseUrl = '',
    http.Client? httpClient,
  })  : _authSession = authSession,
        _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
        _httpClient = httpClient ?? http.Client();

  static const Set<String> _csrfExemptPaths = <String>{
    '/api/auth/token',
    '/api/auth/refresh',
  };

  final AuthSessionStore _authSession;
  final String _baseUrl;
  final http.Client _httpClient;

  Future<Map<String, dynamic>> getJson(
    String path, {
    bool requireAuth = false,
  }) async {
    final Uri uri = _resolveUri(path);
    final http.Response response = await _httpClient.get(
      uri,
      headers: _buildHeaders(
        path: uri.path,
        mutating: false,
        requireAuth: requireAuth,
      ),
    );
    return _decodeJsonObject(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
    bool includeCsrf = true,
    Map<String, String>? extraHeaders,
  }) async {
    final Uri uri = _resolveUri(path);
    final Map<String, String> headers = _buildHeaders(
      path: uri.path,
      mutating: true,
      requireAuth: requireAuth,
      includeCsrf: includeCsrf,
    );
    headers['Content-Type'] = 'application/json';
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    final http.Response response = await _httpClient.post(
      uri,
      headers: headers,
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _decodeJsonObject(response);
  }

  Uri _resolveUri(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    final String normalizedPath = path.startsWith('/') ? path : '/$path';
    if (_baseUrl.isEmpty) {
      return Uri.parse(normalizedPath);
    }
    return Uri.parse('$_baseUrl$normalizedPath');
  }

  Map<String, String> _buildHeaders({
    required String path,
    required bool mutating,
    required bool requireAuth,
    bool includeCsrf = true,
  }) {
    if (requireAuth && !_authSession.hasAccessToken) {
      throw StateError('Missing access token for request to $path.');
    }
    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json',
    };
    if (_authSession.hasAccessToken) {
      headers['Authorization'] = 'Bearer ${_authSession.accessToken}';
    }
    final bool csrfRequired = mutating &&
        includeCsrf &&
        path.startsWith('/api/') &&
        !_csrfExemptPaths.contains(path);
    if (csrfRequired) {
      if (_authSession.csrfToken.isEmpty) {
        throw StateError('Missing CSRF token for mutating request to $path.');
      }
      headers['x-csrf-token'] = _authSession.csrfToken;
    }
    return headers;
  }

  Map<String, dynamic> _decodeJsonObject(http.Response response) {
    dynamic decoded = <String, dynamic>{};
    if (response.body.isNotEmpty) {
      decoded = jsonDecode(response.body);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiClientException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(decoded, response.statusCode),
      );
    }
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map(
        (dynamic key, dynamic value) => MapEntry<String, dynamic>(
          key.toString(),
          value,
        ),
      );
    }
    throw FormatException(
        'Expected JSON object response but got ${decoded.runtimeType}.');
  }

  String _extractErrorMessage(dynamic decoded, int statusCode) {
    if (decoded is Map && decoded['detail'] != null) {
      return decoded['detail'].toString();
    }
    if (decoded is String && decoded.isNotEmpty) {
      return decoded;
    }
    return 'HTTP $statusCode';
  }
}
