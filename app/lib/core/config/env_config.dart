import 'package:flutter/foundation.dart';

/// Deployment environment, from `config/env.<env>.json` via `--dart-define-from-file`.
@immutable
class EnvConfig {
  const EnvConfig({required this.env, required this.apiBaseUrl, this.realtimeUrl, this.supportWhatsapp});

  factory EnvConfig.fromEnvironment() {
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (apiBaseUrl.isEmpty) {
      throw StateError('Missing API_BASE_URL. Build with --dart-define-from-file=config/env.dev.json');
    }
    const realtimeUrl = String.fromEnvironment('REALTIME_URL');
    const support = String.fromEnvironment('SUPPORT_WHATSAPP');
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
      supportWhatsapp: support == '' ? null : support,
    );
  }

  final String env;
  final String apiBaseUrl;

  /// Socket.IO endpoint for live order updates; null disables them (tests).
  final String? realtimeUrl;

  /// The platform team's WhatsApp number (`+91...`) for shop owners' "Contact support"; null hides it.
  final String? supportWhatsapp;

  bool get isProduction => env == 'prod';
}
