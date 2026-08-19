import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;

/// Single source of truth for API connectivity.
///
/// Resolution order for the base URL:
///   1. `API_BASE_URL` from `.env` (recommended — works for local, staging, prod)
///   2. Platform-aware localhost fallback, but ONLY in debug builds
///   3. [prodFallbackUrl] below — set this to your Heroku app URL
///
/// To point the app at your Heroku server, create a `.env` file at the
/// project root (next to pubspec.yaml) containing:
///
///   API_BASE_URL=https://<your-heroku-app-name>.herokuapp.com
///
/// Replace <your-heroku-app-name> with your actual Heroku app name.
/// This keeps the URL out of source control and lets you swap
/// local/staging/prod without touching code.
class ApiConfig {
  ApiConfig._();

  /// Hard fallback used only if no .env is present and this isn't a debug
  /// build. Update this to your real Heroku URL, e.g.
  /// 'https://healthqueue-plus.herokuapp.com'.
  static const String prodFallbackUrl = 'https://REPLACE_WITH_YOUR_HEROKU_APP.herokuapp.com';

  static const Duration requestTimeout = Duration(seconds: 30);

  /// Resolved base URL, no trailing slash, WITHOUT the `/api` prefix.
  /// (Individual endpoints below already include `/api/...` in their path,
  /// matching server.js's route mounting.)
  static String get baseUrl {
    if (dotenv.isInitialized) {
      final envUrl = dotenv.env['API_BASE_URL'];
      if (envUrl != null && envUrl.trim().isNotEmpty) {
        return envUrl.trim().replaceAll(RegExp(r'/+$'), '');
      }
    }

    if (kDebugMode) {
      // Android emulator loopback / iOS simulator loopback.
      if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:5000';
      if (!kIsWeb && Platform.isIOS) return 'http://127.0.0.1:5000';
    }

    return prodFallbackUrl;
  }

  static Uri buildUri(String path, [Map<String, dynamic>? queryParams]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final query = <String, String>{};
    queryParams?.forEach((k, v) {
      if (v != null) query[k] = v.toString();
    });
    return Uri.parse('$baseUrl$cleanPath').replace(
      queryParameters: query.isEmpty ? null : query,
    );
  }
}
