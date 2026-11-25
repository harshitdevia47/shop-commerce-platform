import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../auth/session.dart';
import '../providers.dart';
import 'push.dart';

/// While logged in: asks for notification permission, tells the server this phone's token (again
/// when it changes), and opens the shop of a tapped alert. Kept alive by [AdminApp].
final pushRegistrationProvider = Provider<void>((ref) {
  final push = ref.watch(adminPushProvider);
  final session = ref.watch(sessionProvider).value;
  final subs = <StreamSubscription<String>>[];
  ref.onDispose(() {
    for (final s in subs) {
      unawaited(s.cancel());
    }
  });

  void openShop(String shopId) {
    final router = ref.read(routerProvider);
    if (session == null) {
      ref.read(pendingRouteProvider.notifier).set('/shops/$shopId');
      router.go('/login');
    } else {
      unawaited(router.push('/shops/$shopId'));
    }
  }

  subs.add(push.taps.listen(openShop));
  unawaited(push.takeLaunchShop().then((shop) {
    if (shop != null) openShop(shop);
  }));
  if (session == null) return;

  Future<void> register(String? token) async {
    if (token == null) return;
    try {
      await ref.read(adminApiProvider).registerDevice(session.token, token);
    } on Object catch (error) {
      debugPrint('Could not register for notifications: $error');
    }
  }

  unawaited(push.requestPermission().then((_) => push.token()).then(register));
  subs.add(push.tokenRefresh.listen(register));
});
