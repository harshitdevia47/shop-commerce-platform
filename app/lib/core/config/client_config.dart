import 'package:flutter/widgets.dart';

/// Build-time client configuration, generated per client by `tool/gen_flavors.dart`
/// into `config/clients/<slug>.json` and passed with `--dart-define-from-file`.
///
/// Runtime settings (features, delivery, payments) come from the server instead:
/// see `ShopSettings`.
@immutable
class ClientConfig {
  const ClientConfig({
    required this.shopKey,
    required this.appName,
    required this.logoAsset,
    required this.primaryColor,
    required this.secondaryColor,
    required this.defaultLocale,
    required this.supportedLocales,
    this.surfaceColor,
    this.firebase,
  });

  /// Reads the compile-time defines. Throws if the app was built without a client file.
  factory ClientConfig.fromEnvironment() {
    return ClientConfig.fromMap(const {
      'SHOP_KEY': String.fromEnvironment('SHOP_KEY'),
      'APP_NAME': String.fromEnvironment('APP_NAME'),
      'LOGO_ASSET': String.fromEnvironment('LOGO_ASSET'),
      'COLOR_PRIMARY': String.fromEnvironment('COLOR_PRIMARY'),
      'COLOR_SECONDARY': String.fromEnvironment('COLOR_SECONDARY'),
      'COLOR_SURFACE': String.fromEnvironment('COLOR_SURFACE'),
      'DEFAULT_LOCALE': String.fromEnvironment('DEFAULT_LOCALE'),
      'SUPPORTED_LOCALES': String.fromEnvironment('SUPPORTED_LOCALES'),
      'FIREBASE_API_KEY': String.fromEnvironment('FIREBASE_API_KEY'),
      'FIREBASE_APP_ID': String.fromEnvironment('FIREBASE_APP_ID'),
      'FIREBASE_SENDER_ID': String.fromEnvironment('FIREBASE_SENDER_ID'),
      'FIREBASE_PROJECT_ID': String.fromEnvironment('FIREBASE_PROJECT_ID'),
    });
  }

  factory ClientConfig.fromMap(Map<String, String> values) {
    String require(String key) {
      final value = values[key] ?? '';
      if (value.isEmpty) {
        throw StateError(
          'Missing build define $key. Build with '
          '--dart-define-from-file=config/clients/<slug>.json (run tool/gen_flavors.dart first).',
        );
      }
      return value;
    }

    final surface = values['COLOR_SURFACE'] ?? '';
    final supported = require('SUPPORTED_LOCALES').split(',').map((code) => Locale(code.trim())).toList();
    final defaultLocale = Locale(require('DEFAULT_LOCALE'));
    if (!supported.contains(defaultLocale)) {
      throw StateError('DEFAULT_LOCALE must be one of SUPPORTED_LOCALES');
    }

    return ClientConfig(
      shopKey: require('SHOP_KEY'),
      appName: require('APP_NAME'),
      logoAsset: require('LOGO_ASSET'),
      primaryColor: parseHexColor(require('COLOR_PRIMARY')),
      secondaryColor: parseHexColor(require('COLOR_SECONDARY')),
      surfaceColor: surface.isEmpty ? null : parseHexColor(surface),
      defaultLocale: defaultLocale,
      supportedLocales: supported,
      firebase: FirebaseConfig.fromMap(values),
    );
  }

  /// Sent as `X-Shop-Key` on every request; equals the client slug.
  final String shopKey;
  final String appName;
  final String logoAsset;
  final Color primaryColor;
  final Color secondaryColor;
  final Color? surfaceColor;
  final Locale defaultLocale;
  final List<Locale> supportedLocales;

  /// Push notifications (FCM). Null when the client folder has no google-services.json.
  final FirebaseConfig? firebase;
}

/// Values from the client's google-services.json (written by gen_flavors). Not secrets:
/// they identify the app to Firebase; sending pushes needs the server's service account.
@immutable
class FirebaseConfig {
  const FirebaseConfig({required this.apiKey, required this.appId, required this.senderId, required this.projectId});

  static FirebaseConfig? fromMap(Map<String, String> values) {
    final apiKey = values['FIREBASE_API_KEY'] ?? '';
    final appId = values['FIREBASE_APP_ID'] ?? '';
    final senderId = values['FIREBASE_SENDER_ID'] ?? '';
    final projectId = values['FIREBASE_PROJECT_ID'] ?? '';
    if ([apiKey, appId, senderId, projectId].any((v) => v.isEmpty)) return null;
    return FirebaseConfig(apiKey: apiKey, appId: appId, senderId: senderId, projectId: projectId);
  }

  final String apiKey;
  final String appId;
  final String senderId;
  final String projectId;
}

/// Parses `#RRGGBB`.
Color parseHexColor(String hex) {
  final match = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(hex);
  if (match == null) throw FormatException('Expected a colour like #1B5E20', hex);
  return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
}
