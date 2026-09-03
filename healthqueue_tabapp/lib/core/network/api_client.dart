import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import 'api_exceptions.dart';

/// The single HTTP client for the whole app. Every network call — auth,
/// queue, appointments, chatbot, etc. — goes through here so there is one
/// place that knows how to build URLs, attach auth headers, and interpret
/// server responses/errors.
class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  final http.Client _http = http.Client();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _tokenKey = 'hq_staff_jwt';

  // ─── Token Management ─────────────────────────────────────────────────
  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  Future<Map<String, String>> _headers({bool requiresAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requiresAuth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // ─── Verb helpers ──────────────────────────────────────────────────────
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool requiresAuth = true,
  }) => _send('GET', path, query: query, requiresAuth: requiresAuth);

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? query,
    dynamic body,
    bool requiresAuth = true,
  }) => _send('POST', path, query: query, body: body, requiresAuth: requiresAuth);

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? query,
    dynamic body,
    bool requiresAuth = true,
  }) => _send('PUT', path, query: query, body: body, requiresAuth: requiresAuth);

  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? query,
    bool requiresAuth = true,
  }) => _send('DELETE', path, query: query, requiresAuth: requiresAuth);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    dynamic body,
    bool requiresAuth = true,
  }) async {
    final uri = ApiConfig.buildUri(path, query);
    final headers = await _headers(requiresAuth: requiresAuth);

    try {
      final http.Response res;
      switch (method) {
        case 'GET':
          res = await _http.get(uri, headers: headers).timeout(ApiConfig.requestTimeout);
          break;
        case 'POST':
          res = await _http
              .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
              .timeout(ApiConfig.requestTimeout);
          break;
        case 'PUT':
          res = await _http
              .put(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
              .timeout(ApiConfig.requestTimeout);
          break;
        case 'DELETE':
          res = await _http.delete(uri, headers: headers).timeout(ApiConfig.requestTimeout);
          break;
        default:
          throw StateError('Unsupported HTTP method: $method');
      }
      return _processResponse(res);
    } on TimeoutException {
      throw StaffApiException(
        'Request timed out. Please check your connection and try again.',
        isNetworkError: true,
      );
    } on SocketException {
      throw StaffApiException(
        'Could not reach the server. Please check your connection.',
        isNetworkError: true,
      );
    } on http.ClientException catch (e) {
      throw StaffApiException(
        'Network error: ${e.message}',
        isNetworkError: true,
      );
    }
  }

  dynamic _processResponse(http.Response res) {
    dynamic body;
    bool parsedOk = true;
    try {
      body = res.body.isNotEmpty ? jsonDecode(res.body) : <String, dynamic>{};
    } catch (_) {
      // The server returned something that isn't JSON — almost always an
      // HTML error page (a 404 "Cannot GET ..." page when a route isn't
      // actually deployed yet, or a framework-level 500 page). This used
      // to wrap the raw HTML itself into {'message': res.body} and throw
      // that as the exception message, which meant the app would render
      // the literal HTML source on screen instead of a real error. Fall
      // back to a clean, generic message instead — the status code alone
      // is still useful for debugging.
      parsedOk = false;
      body = <String, dynamic>{};
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }

    final message = (parsedOk && body is Map && body['message'] != null)
        ? body['message'].toString()
        : 'Request failed (HTTP ${res.statusCode}). The server may need to be updated or redeployed.';
    throw StaffApiException(message, statusCode: res.statusCode);
  }

  /// Unwraps the `{ success, data }` envelope used by several endpoints
  /// (queues, appointments/today, clinics/:id, chatbot-admin/logs).
  /// Falls back to the raw body if there's no `data` key, so this is safe
  /// to call even on endpoints that respond with a flat object.
  static dynamic unwrap(dynamic json) {
    if (json is Map && json.containsKey('data')) {
      return json['data'];
    }
    return json;
  }
}
