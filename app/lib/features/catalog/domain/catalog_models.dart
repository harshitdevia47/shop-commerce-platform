import 'package:flutter/widgets.dart';

import '../../../core/utils/localized.dart';

@immutable
class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.name,
    this.parentId,
    this.nameI18n,
    this.imageUrl,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) => ProductCategory(
    id: json['id'] as String,
    parentId: json['parentId'] as String?,
    name: json['name'] as String,
    nameI18n: readI18n(json['nameI18n']),
    imageUrl: json['imageUrl'] as String?,
    sortOrder: json['sortOrder'] as int? ?? 0,
    isActive: json['isActive'] as bool? ?? true,
  );

  final String id;
  final String? parentId;
  final String name;
  final Map<String, String>? nameI18n;

  /// Relative to the API base URL, e.g. `/media/<shop>/...-thumb.webp`.
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;

  bool get isTopLevel => parentId == null;
  String localizedName(Locale locale) => localized(name, nameI18n, locale);
}

@immutable
class ProductImage {
  const ProductImage({required this.mediaId, required this.url, required this.thumbUrl});

  factory ProductImage.fromJson(Map<String, dynamic> json) => ProductImage(
    mediaId: json['mediaId'] as String,
    url: json['url'] as String,
    thumbUrl: json['thumbUrl'] as String,
  );

  final String mediaId;
  final String url;
  final String thumbUrl;
}

@immutable
class Variant {
  const Variant({
    required this.id,
    required this.label,
    required this.pricePaise,
    required this.inStock,
    this.labelI18n,
    this.options = const {},
    this.mrpPaise,
    this.sku,
    this.stockQty,
    this.isAvailable = true,
  });

  factory Variant.fromJson(Map<String, dynamic> json) => Variant(
    id: json['id'] as String,
    label: json['label'] as String,
    labelI18n: readI18n(json['labelI18n']),
    options: (json['options'] as Map<String, dynamic>? ?? const {}).cast<String, String>(),
    pricePaise: json['pricePaise'] as int,
    mrpPaise: json['mrpPaise'] as int?,
    inStock: json['inStock'] as bool,
    sku: json['sku'] as String?,
    stockQty: json['stockQty'] as int?,
    isAvailable: json['isAvailable'] as bool? ?? true,
  );

  final String id;
  final String label;
  final Map<String, String>? labelI18n;

  /// Axis values for option catalogs, e.g. `{size: M, color: Blue}`.
  final Map<String, String> options;
  final int pricePaise;
  final int? mrpPaise;
  final bool inStock;

  // Admin only (null for customers).
  final String? sku;
  final int? stockQty;
  final bool isAvailable;

  String localizedLabel(Locale locale) => localized(label, labelI18n, locale);

  /// Whole-percent discount from MRP, or null when there is none.
  int? get discountPercent {
    final mrp = mrpPaise;
    if (mrp == null || mrp <= pricePaise || mrp == 0) return null;
    final percent = ((mrp - pricePaise) * 100 / mrp).floor();
    return percent > 0 ? percent : null;
  }
}

@immutable
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.variants,
    required this.inStock,
    this.categoryId,
    this.nameI18n,
    this.description,
    this.descriptionI18n,
    this.customFields = const {},
    this.tags = const [],
    this.images = const [],
    this.isActive = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    categoryId: json['categoryId'] as String?,
    name: json['name'] as String,
    nameI18n: readI18n(json['nameI18n']),
    description: json['description'] as String?,
    descriptionI18n: readI18n(json['descriptionI18n']),
    customFields: (json['customFields'] as Map<String, dynamic>? ?? const {}),
    tags: (json['tags'] as List<dynamic>? ?? const []).cast<String>(),
    images: [for (final i in json['images'] as List<dynamic>? ?? const []) ProductImage.fromJson(i as Map<String, dynamic>)],
    variants: [for (final v in json['variants'] as List<dynamic>) Variant.fromJson(v as Map<String, dynamic>)],
    inStock: json['inStock'] as bool,
    isActive: json['isActive'] as bool? ?? true,
  );

  final String id;
  final String? categoryId;
  final String name;
  final Map<String, String>? nameI18n;
  final String? description;
  final Map<String, String>? descriptionI18n;

  /// Values for the shop's custom fields (String, num or bool).
  final Map<String, dynamic> customFields;
  final List<String> tags;
  final List<ProductImage> images;
  final List<Variant> variants;
  final bool inStock;

  /// Admin only.
  final bool isActive;

  String localizedName(Locale locale) => localized(name, nameI18n, locale);

  Product copyWith({bool? isActive}) => Product(
    id: id,
    name: name,
    variants: variants,
    inStock: inStock,
    categoryId: categoryId,
    nameI18n: nameI18n,
    description: description,
    descriptionI18n: descriptionI18n,
    customFields: customFields,
    tags: tags,
    images: images,
    isActive: isActive ?? this.isActive,
  );

  String? localizedDescription(Locale locale) {
    final text = description;
    return text == null ? null : localized(text, descriptionI18n, locale);
  }

  /// The variant shown on cards: first one in stock, else the first.
  Variant get defaultVariant => variants.firstWhere((v) => v.inStock, orElse: () => variants.first);
  String? get thumbUrl => images.isEmpty ? null : images.first.thumbUrl;
}

/// One page of a cursor-paginated list.
@immutable
class PageResult<T> {
  const PageResult(this.items, this.nextCursor);

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
