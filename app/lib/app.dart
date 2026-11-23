import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/push/push_registration.dart';
import 'features/orders/presentation/order_live_updates.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';

class QcApp extends ConsumerWidget {
  const QcApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientConfigProvider);
    // Background work tied to the signed-in user: live order updates and push registration.
    ref
      ..watch(orderLiveUpdatesProvider)
      ..watch(pushRegistrationProvider);
    return MaterialApp.router(
      title: client.appName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(client),
      locale: ref.watch(localeProvider),
      supportedLocales: client.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}
