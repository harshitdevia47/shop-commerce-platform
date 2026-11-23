import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/client_config.dart';
import 'config/env_config.dart';
import 'config/shop_settings.dart';
import 'config/shop_settings_repository.dart';
import '../features/auth/data/session_store.dart';
import '../features/auth/data/auth_api.dart';
import '../features/auth/presentation/auth_controller.dart';
import 'network/api_client.dart';
import 'network/auth_interceptor.dart';
import 'push/push_service.dart';

// ---- Overridden in main() / tests ----

final clientConfigProvider = Provider<ClientConfig>((ref) => throw UnimplementedError('override in main'));
final envConfigProvider = Provider<EnvConfig>((ref) => throw UnimplementedError('override in main'));
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('override in main'));

/// Push notifications; `main()` overrides it with Firebase when the client has a Firebase app.
final pushServiceProvider = Provider<PushService>((ref) => const NoPushService());

// ---- Infrastructure ----

final sessionStoreProvider = Provider<SessionStore>((ref) => SecureSessionStore());

/// No auth: shop config, /auth/* (including token refresh).
final publicDioProvider = Provider<Dio>((ref) {
  final dio = createDio(ref.watch(envConfigProvider), ref.watch(clientConfigProvider));
  final adapter = ref.watch(httpAdapterProvider);
  if (adapter != null) dio.httpClientAdapter = adapter;
  return dio;
});

/// Tests replace the network with a fake server here; null = real HTTP.
final httpAdapterProvider = Provider<HttpClientAdapter?>((ref) => null);

/// Authenticated calls: attaches the access token and refreshes it transparently.
///
/// The interceptor must not read [authApiProvider]: that provider depends on this one, and
/// Riverpod rejects the cycle at refresh time (every request then fails once the token expires).
final Provider<Dio> dioProvider = Provider<Dio>((ref) {
  final dio = createDio(ref.watch(envConfigProvider), ref.watch(clientConfigProvider));
  final adapter = ref.watch(httpAdapterProvider);
  if (adapter != null) dio.httpClientAdapter = adapter;
  final publicDio = ref.watch(publicDioProvider);
  dio.interceptors.add(
    AuthInterceptor(
      store: ref.watch(sessionStoreProvider),
      refresh: (token) => refreshSession(publicDio, token),
      retryDio: publicDio,
      onSessionRefreshed: (session) => ref.read(authControllerProvider.notifier).sessionRefreshed(session),
      onSessionExpired: () => ref.read(authControllerProvider.notifier).sessionExpired(),
    ),
  );
  return dio;
});

final shopSettingsRepositoryProvider = Provider<ShopSettingsRepository>(
  (ref) => HttpShopSettingsRepository(ref.watch(publicDioProvider), ref.watch(sharedPreferencesProvider)),
);

// ---- Runtime shop settings ----

class ShopSettingsNotifier extends AsyncNotifier<ShopSettings> {
  @override
  Future<ShopSettings> build() => ref.watch(shopSettingsRepositoryProvider).load();

  /// Reloads; the previous value stays visible while loading.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Object {
      // Surfaced through `state` (AsyncError); callers render it.
    }
  }
}

final shopSettingsProvider = AsyncNotifierProvider<ShopSettingsNotifier, ShopSettings>(ShopSettingsNotifier.new);

/// `ref.watch(featureProvider(Feature.storePickup))` — false until settings load.
final featureProvider = Provider.family<bool, Feature>(
  (ref, feature) => ref.watch(shopSettingsProvider).value?.isEnabled(feature) ?? false,
);

// ---- Locale ----

class LocaleController extends Notifier<Locale> {
  static const _key = 'locale';

  @override
  Locale build() {
    final client = ref.watch(clientConfigProvider);
    final saved = ref.watch(sharedPreferencesProvider).getString(_key);
    final savedLocale = saved == null ? null : Locale(saved);
    return client.supportedLocales.contains(savedLocale) ? savedLocale! : client.defaultLocale;
  }

  Future<void> set(Locale locale) async {
    if (!ref.read(clientConfigProvider).supportedLocales.contains(locale)) return;
    state = locale;
    await ref.read(sharedPreferencesProvider).setString(_key, locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);
