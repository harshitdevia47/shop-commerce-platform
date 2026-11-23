import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/client_config.dart';
import 'core/config/env_config.dart';
import 'core/providers.dart';

/// Build/run with a client flavor and an environment file, e.g.
///   flutter run --flavor sharma_kirana \
///     --dart-define-from-file=config/clients/sharma_kirana.json \
///     --dart-define-from-file=config/env.dev.json
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        clientConfigProvider.overrideWithValue(ClientConfig.fromEnvironment()),
        envConfigProvider.overrideWithValue(EnvConfig.fromEnvironment()),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const QcApp(),
    ),
  );
}
