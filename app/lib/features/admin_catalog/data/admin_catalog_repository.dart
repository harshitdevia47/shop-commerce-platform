import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../catalog/domain/catalog_models.dart';

enum ProductStatus { all, active, inactive }

/// Uploaded image, ready to attach to a product or category.
@immutable
class UploadedImage {
  const UploadedImage({required this.id, required this.url, required this.thumbUrl});

  factory UploadedImage.fromJson(Map<String, dynamic> json) =>
      UploadedImage(id: json['id'] as String, url: json['url'] as String, thumbUrl: json['thumbUrl'] as String);

  final String id;
  final String url;
  final String thumbUrl;
}

@immutable
class CategoryDraft {
  const CategoryDraft({
    required this.name,
    this.nameI18n = const {},
    this.parentId,
    this.imageMediaId,
    this.isActive = true,
  });

  final String name;
  final Map<String, String> nameI18n;
  final String? parentId;
  final String? imageMediaId;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'name': name,
    'nameI18n': nameI18n.isEmpty ? null : nameI18n,
    'parentId': parentId,
    'imageMediaId': ?imageMediaId,
    'isActive': isActive,
  };
}

@immutable
class VariantDraft {
  const VariantDraft({
    required this.pricePaise,
    this.id,
    this.label = '',
    this.options = const {},
    this.mrpPaise,
    this.stockQty,
    this.isAvailable = true,
  });

  final String? id;
  final String label;
  final Map<String, String> options;
  final int pricePaise;
  final int? mrpPaise;
  final int? stockQty;
  final bool isAvailable;

  Map<String, dynamic> toJson() => {
    'id': ?id,
    if (label.isNotEmpty) 'label': label,
    if (options.isNotEmpty) 'options': options,
    'pricePaise': pricePaise,
    'mrpPaise': mrpPaise,
    'stockQty': stockQty,
    'isAvailable': isAvailable,
  };
}

/// The whole product form; saved with POST (new) or PUT (replace).
@immutable
class ProductDraft {
  const ProductDraft({
    required this.name,
    required this.variants,
    this.nameI18n = const {},
    this.description,
    this.categoryId,
    this.customFields = const {},
    this.tags = const [],
    this.imageMediaIds = const [],
    this.isActive = true,
  });

  final String name;
  final Map<String, String> nameI18n;
  final String? description;
  final String? categoryId;
  final Map<String, Object> customFields;
  final List<String> tags;
  final List<String> imageMediaIds;
  final bool isActive;
  final List<VariantDraft> variants;

  Map<String, dynamic> toJson() => {
    'name': name,
    'nameI18n': nameI18n.isEmpty ? null : nameI18n,
    'description': description == null || description!.isEmpty ? null : description,
    'categoryId': categoryId,
    'customFields': customFields,
    'tags': tags,
    'imageMediaIds': imageMediaIds,
    'isActive': isActive,
    'variants': [for (final v in variants) v.toJson()],
  };
}

/// Shop admin (OWNER/STAFF) catalog management.
abstract interface class AdminCatalogRepository {
  Future<List<ProductCategory>> categories();
  Future<ProductCategory> createCategory(CategoryDraft draft);
  Future<ProductCategory> updateCategory(String id, CategoryDraft draft);
  Future<void> deleteCategory(String id);

  Future<PageResult<Product>> products({String? query, ProductStatus status = ProductStatus.all, String? cursor});
  Future<Product> product(String id);
  Future<Product> createProduct(ProductDraft draft);
  Future<Product> replaceProduct(String id, ProductDraft draft);
  Future<Product> setProductActive(String id, {required bool isActive});
  Future<void> deleteProduct(String id);

  Future<UploadedImage> uploadImage(String filePath, {String kind = 'PRODUCT_IMAGE'});
}

class HttpAdminCatalogRepository implements AdminCatalogRepository {
  HttpAdminCatalogRepository(this._dio);

  final Dio _dio;
  static const _base = '/api/v1/admin/catalog';

  Future<Product> _product(Future<Response<dynamic>> request) async =>
      Product.fromJson(await unwrap<Map<String, dynamic>>(request));

  Future<ProductCategory> _category(Future<Response<dynamic>> request) async =>
      ProductCategory.fromJson(await unwrap<Map<String, dynamic>>(request));

  @override
  Future<List<ProductCategory>> categories() async {
    final data = await unwrap<List<dynamic>>(_dio.get<dynamic>('$_base/categories'));
    return [for (final c in data) ProductCategory.fromJson(c as Map<String, dynamic>)];
  }

  @override
  Future<ProductCategory> createCategory(CategoryDraft draft) =>
      _category(_dio.post<dynamic>('$_base/categories', data: draft.toJson()));

  @override
  Future<ProductCategory> updateCategory(String id, CategoryDraft draft) =>
      _category(_dio.patch<dynamic>('$_base/categories/$id', data: draft.toJson()));

  @override
  Future<void> deleteCategory(String id) => send(_dio.delete<dynamic>('$_base/categories/$id'));

  @override
  Future<PageResult<Product>> products({String? query, ProductStatus status = ProductStatus.all, String? cursor}) async {
    final page = await unwrapList(
      _dio.get<dynamic>(
        '$_base/products',
        queryParameters: {
          'status': status.name,
          'limit': 30,
          if (query != null && query.isNotEmpty) 'q': query,
          'cursor': ?cursor,
        },
      ),
    );
    return PageResult([for (final p in page.items) Product.fromJson(p as Map<String, dynamic>)], page.nextCursor);
  }

  @override
  Future<Product> product(String id) => _product(_dio.get<dynamic>('$_base/products/$id'));

  @override
  Future<Product> createProduct(ProductDraft draft) => _product(_dio.post<dynamic>('$_base/products', data: draft.toJson()));

  @override
  Future<Product> replaceProduct(String id, ProductDraft draft) =>
      _product(_dio.put<dynamic>('$_base/products/$id', data: draft.toJson()));

  @override
  Future<Product> setProductActive(String id, {required bool isActive}) =>
      _product(_dio.patch<dynamic>('$_base/products/$id', data: {'isActive': isActive}));

  @override
  Future<void> deleteProduct(String id) => send(_dio.delete<dynamic>('$_base/products/$id'));

  @override
  Future<UploadedImage> uploadImage(String filePath, {String kind = 'PRODUCT_IMAGE'}) async {
    final form = FormData.fromMap({'kind': kind, 'file': await MultipartFile.fromFile(filePath)});
    return UploadedImage.fromJson(
      await unwrap<Map<String, dynamic>>(
        _dio.post<dynamic>('/api/v1/admin/media', data: form, options: Options(sendTimeout: const Duration(seconds: 60))),
      ),
    );
  }
}
