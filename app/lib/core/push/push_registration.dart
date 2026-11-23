import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../providers.dart';

/// While someone is signed in, keeps the server's record of this phone's push token current
/// (after login, on token rotation, when the app language changes). Kept alive by `QcApp`.
final pushRegistrationProvider = Provider<void>((ref) {
  final push = ref.watch(pushServiceProvider);
  final userId = ref.watch(authControllerProvider.select((auth) => auth.value?.id));
  final locale = ref.watch(localeProvider).languageCode;
  if (userId == null) return;
  final api = ref.read(authApiProvider);

  Future<void> register(String? token) async {
    if (token == null || !ref.mounted) return;
    try {
      await api.registerDevice(token: token, locale: locale);
    } on Object catch (error) {
      debugPrint('Push registration failed: $error'); // retried on next start or token change
    }
  }

  unawaited(() async {
    await push.requestPermission();
    await register(await push.token());
  }());
  final subscription = push.tokenRefresh.listen(register);
  ref.onDispose(subscription.cancel);
});
