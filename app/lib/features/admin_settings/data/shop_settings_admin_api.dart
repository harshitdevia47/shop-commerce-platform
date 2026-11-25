import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/shop_settings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';

/// Owner: changes shop settings (`PATCH /api/v1/admin/settings`, only the given sections/fields).
abstract interface class ShopSettingsAdminApi {
  Future<ShopSettings> save(Map<String, dynamic> patch);
}

class HttpShopSettingsAdminApi implements ShopSettingsAdminApi {
  HttpShopSettingsAdminApi(this._dio);

  final Dio _dio;

  @override
  Future<ShopSettings> save(Map<String, dynamic> patch) async => ShopSettings.fromJson(
    await unwrap<Map<String, dynamic>>(_dio.patch<dynamic>('/api/v1/admin/settings', data: patch)),
  );
}

final shopSettingsAdminApiProvider = Provider<ShopSettingsAdminApi>(
  (ref) => HttpShopSettingsAdminApi(ref.watch(dioProvider)),
);
