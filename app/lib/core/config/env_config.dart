import 'package:flutter/foundation.dart';

/// Deployment environment, from `config/env.<env>.json` via `--dart-define-from-file`.
@immutable
class EnvConfig {
  const EnvConfig({required this.env, required this.apiBaseUrl});

  factory EnvConfig.fromEnvironment() {
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (apiBaseUrl.isEmpty) {
      throw StateError('Missing API_BASE_URL. Build with --dart-define-from-file=config/env.dev.json');
    }
    return const EnvConfig(env: String.fromEnvironment('ENV', defaultValue: 'dev'), apiBaseUrl: apiBaseUrl);
  }

  final String env;
  final String apiBaseUrl;

  bool get isProduction => env == 'prod';
}
