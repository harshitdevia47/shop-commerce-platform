import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/client_config.dart';
import 'config/env_config.dart';
import 'config/shop_settings.dart';
import 'config/shop_settings_repository.dart';
import 'network/api_client.dart';

// ---- Overridden in main() / tests ----

final clientConfigProvider = Provider<ClientConfig>((ref) => throw UnimplementedError('override in main'));
final envConfigProvider = Provider<EnvConfig>((ref) => throw UnimplementedError('override in main'));
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('override in main'));

// ---- Infrastructure ----

final dioProvider = Provider<Dio>((ref) => createDio(ref.watch(envConfigProvider), ref.watch(clientConfigProvider)));

final shopSettingsRepositoryProvider = Provider<ShopSettingsRepository>(
  (ref) => HttpShopSettingsRepository(ref.watch(dioProvider), ref.watch(sharedPreferencesProvider)),
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
