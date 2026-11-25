/// Build-time settings (`--dart-define-from-file=config/env.<name>.json`).
class AppConfig {
  const AppConfig({required this.apiUrl, this.env = 'dev'});

  factory AppConfig.fromEnvironment() {
    const apiUrl = String.fromEnvironment('ADMIN_API_URL');
    const env = String.fromEnvironment('ENV', defaultValue: 'dev');
    if (apiUrl.isEmpty) throw StateError('Missing ADMIN_API_URL. Build with --dart-define-from-file=config/env.dev.json');
    if (env == 'prod' && !apiUrl.startsWith('https://')) throw StateError('Production builds need an https:// ADMIN_API_URL');
    return const AppConfig(apiUrl: apiUrl, env: env);
  }

  final String apiUrl;
  final String env;
}
