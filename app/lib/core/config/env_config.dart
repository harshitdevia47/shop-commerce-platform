import 'package:flutter/foundation.dart';

/// Deployment environment, from `config/env.<env>.json` via `--dart-define-from-file`.
@immutable
class EnvConfig {
  const EnvConfig({required this.env, required this.apiBaseUrl, this.realtimeUrl});

  factory EnvConfig.fromEnvironment() {
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (apiBaseUrl.isEmpty) {
      throw StateError('Missing API_BASE_URL. Build with --dart-define-from-file=config/env.dev.json');
    }
    const realtimeUrl = String.fromEnvironment('REALTIME_URL');
    const env = String.fromEnvironment('ENV', defaultValue: 'dev');
    // Dart's HTTP client ignores Android's cleartext policy, so production enforces HTTPS here.
    if (env == 'prod' && (!apiBaseUrl.startsWith('https://') || (realtimeUrl.isNotEmpty && !realtimeUrl.startsWith('https://')))) {
      throw StateError('Production builds need https:// API_BASE_URL and REALTIME_URL');
    }
    return const EnvConfig(
      env: String.fromEnvironment('ENV', defaultValue: 'dev'),
      apiBaseUrl: apiBaseUrl,
      // Production: nginx serves /socket.io on the API host. Dev: the realtime service's own port.
      realtimeUrl: realtimeUrl == '' ? apiBaseUrl : realtimeUrl,
    );
  }

  final String env;
  final String apiBaseUrl;

  /// Socket.IO endpoint for live order updates; null disables them (tests).
  final String? realtimeUrl;

  bool get isProduction => env == 'prod';
}
