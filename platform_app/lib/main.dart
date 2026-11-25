import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'config.dart';
import 'providers.dart';
import 'push/push.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebase = FirebaseValues.fromEnvironment();
  final push = firebase == null ? const NoPush() : await FirebaseAdminPush.start(firebase);
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(AppConfig.fromEnvironment()),
        adminPushProvider.overrideWithValue(push),
      ],
      child: const AdminApp(),
    ),
  );
}
