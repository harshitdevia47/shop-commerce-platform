import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'shop_settings.dart';

abstract interface class ShopSettingsRepository {
  /// Fresh settings from the server; falls back to the last cached copy when offline.
  Future<ShopSettings> load();
}

class HttpShopSettingsRepository implements ShopSettingsRepository {
  HttpShopSettingsRepository(this._dio, this._prefs);

  static const _cacheKey = 'shop_settings_cache_v1';

  final Dio _dio;
  final SharedPreferences _prefs;

  @override
  Future<ShopSettings> load() async {
    try {
      final json = await unwrap<Map<String, dynamic>>(_dio.get<dynamic>('/api/v1/shop/config'));
      final settings = ShopSettings.fromJson(json);
      await _prefs.setString(_cacheKey, jsonEncode(json));
      return settings;
    } on ApiException catch (error) {
      final cached = _prefs.getString(_cacheKey);
      if (error.isNetwork && cached != null) {
        return ShopSettings.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      }
      rethrow;
    }
  }
}
