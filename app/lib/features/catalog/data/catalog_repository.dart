import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/catalog_models.dart';

/// Customer browsing. Works for guests (the gateway route is public).
abstract interface class CatalogRepository {
  Future<List<ProductCategory>> categories();
  Future<PageResult<Product>> products({String? categoryId, String? query, String? cursor, int limit = 20});
  Future<Product> product(String id);
}

class HttpCatalogRepository implements CatalogRepository {
  HttpCatalogRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<ProductCategory>> categories() async {
    final data = await unwrap<List<dynamic>>(_dio.get<dynamic>('/api/v1/catalog/categories'));
    return [for (final c in data) ProductCategory.fromJson(c as Map<String, dynamic>)];
  }

  @override
  Future<PageResult<Product>> products({String? categoryId, String? query, String? cursor, int limit = 20}) async {
    final page = await unwrapList(
      _dio.get<dynamic>(
        '/api/v1/catalog/products',
        queryParameters: {
          'limit': limit,
          'categoryId': ?categoryId,
          if (query != null && query.isNotEmpty) 'q': query,
          'cursor': ?cursor,
        },
      ),
    );
    return PageResult([for (final p in page.items) Product.fromJson(p as Map<String, dynamic>)], page.nextCursor);
  }

  @override
  Future<Product> product(String id) async =>
      Product.fromJson(await unwrap<Map<String, dynamic>>(_dio.get<dynamic>('/api/v1/catalog/products/$id')));
}
