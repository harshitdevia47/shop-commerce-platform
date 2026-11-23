import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/client_config.dart';
import 'core/config/env_config.dart';
import 'core/providers.dart';
import 'core/push/push_service.dart';
import 'l10n/app_localizations.dart';

/// Build/run with a client flavor and an environment file, e.g.
///   flutter run --flavor sharma_kirana \
///     --dart-define-from-file=config/clients/sharma_kirana.json \
///     --dart-define-from-file=config/env.dev.json
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final client = ClientConfig.fromEnvironment();

  // Push only for clients with a Firebase app (google-services.json in clients/<slug>/).
  final firebase = client.firebase;
  final push = firebase == null
      ? const NoPushService()
      : await FirebasePushService.start(
          firebase,
          channelName: lookupAppLocalizations(_startupLocale(client, prefs)).notificationChannelOrders,
        );

  runApp(
    ProviderScope(
      overrides: [
        clientConfigProvider.overrideWithValue(client),
        envConfigProvider.overrideWithValue(EnvConfig.fromEnvironment()),
        sharedPreferencesProvider.overrideWithValue(prefs),
        pushServiceProvider.overrideWithValue(push),
      ],
      child: const QcApp(),
    ),
  );
}

/// The language the app will open in (same rule as `LocaleController`).
Locale _startupLocale(ClientConfig client, SharedPreferences prefs) {
  final saved = prefs.getString('locale');
  final locale = saved == null ? null : Locale(saved);
  return client.supportedLocales.contains(locale) ? locale! : client.defaultLocale;
}
