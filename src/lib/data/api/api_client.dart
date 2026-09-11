import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config.dart';
import 'api_exception.dart';
import 'token_store.dart';

/// The single HTTP entry point. Handles auth headers, the error envelope,
/// timeouts, and one silent token refresh per 401.
class ApiClient {
  ApiClient({http.Client? inner, TokenStore? tokens})
      : _http = inner ?? http.Client(),
        tokens = tokens ?? TokenStore();

  final http.Client _http;
  final TokenStore tokens;

  /// Called when refresh fails and the session is unrecoverable, so the app
  /// can bounce to the login screen from anywhere.
  void Function()? onSessionExpired;

  Future<void> init() => tokens.load();

  Map<String, String> _headers({bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        'Accept': 'application/json',
        if ((tokens.accessToken ?? '').isNotEmpty)
          'Authorization': 'Bearer ${tokens.accessToken}',
      };

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _http.get(AppConfig.uri(path, query), headers: _headers()));

  /// Un-prefixed endpoints such as /readyz. Uses the cold-start budget because
  /// this is the call that wakes an idle instance.
  Future<dynamic> getRoot(String path) => _send(
        () => _http.get(AppConfig.rootUri(path), headers: _headers()),
        authenticated: false,
        timeout: AppConfig.coldStartTimeout,
      );

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) =>
      _send(() => _http.post(
            AppConfig.uri(path, query),
            headers: _headers(),
            body: body == null ? null : jsonEncode(body),
          ));

  /// Multipart upload for evidence photos. [fields] are sent alongside.
  Future<dynamic> postFile(
    String path, {
    required File file,
    required String fieldName,
    Map<String, String> fields = const {},
    Map<String, dynamic>? query,
  }) async {
    Future<http.Response> build() async {
      final request = http.MultipartRequest('POST', AppConfig.uri(path, query))
        ..headers.addAll(_headers(json: false))
        ..fields.addAll(fields)
        ..files.add(await http.MultipartFile.fromPath(fieldName, file.path));
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    }

    return _send(build);
  }

  Future<dynamic> _send(
    Future<http.Response> Function() send, {
    bool authenticated = true,
    bool isRetry = false,
    Duration? timeout,
  }) async {
    http.Response response;
    try {
      response = await send().timeout(timeout ?? AppConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException.timeout();
    } on SocketException catch (e) {
      throw ApiException.network(e);
    } on http.ClientException catch (e) {
      throw ApiException.network(e);
    }

    // One refresh attempt, then give up and surface the session as expired.
    if (response.statusCode == 401 && authenticated && !isRetry) {
      if (await _refresh()) {
        return _send(send,
            authenticated: authenticated, isRetry: true, timeout: timeout);
      }
      await tokens.clear();
      onSessionExpired?.call();
    }

    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (response.body.isEmpty) {
      if (ok) return null;
      throw ApiException.fromResponse(response.statusCode, null);
    }

    dynamic body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      if (ok) return null;
      throw ApiException.fromResponse(response.statusCode, null);
    }

    if (!ok) throw ApiException.fromResponse(response.statusCode, body);
    return body;
  }

  Future<bool> _refresh() async {
    final refresh = tokens.refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final response = await _http
          .post(
            AppConfig.uri('/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refresh}),
          )
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      await tokens.save(
        access: '${data['access_token']}',
        refresh: '${data['refresh_token']}',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void close() => _http.close();
}
