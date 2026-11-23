import 'package:flutter/widgets.dart';

import '../../../core/utils/localized.dart';
import '../../catalog/domain/catalog_models.dart';

/// One cart line. Keeps a display snapshot so the cart renders instantly and offline;
/// the server quote is the source of truth for prices and stock.
@immutable
class CartLine {
  const CartLine({
    required this.variantId,
    required this.productId,
    required this.name,
    required this.label,
    required this.pricePaise,
    required this.qty,
    this.nameI18n,
    this.labelI18n,
    this.mrpPaise,
    this.thumbUrl,
  });

  factory CartLine.of(Product product, Variant variant, int qty) => CartLine(
    variantId: variant.id,
    productId: product.id,
    name: product.name,
    nameI18n: product.nameI18n,
    label: variant.label,
    labelI18n: variant.labelI18n,
    pricePaise: variant.pricePaise,
    mrpPaise: variant.mrpPaise,
    thumbUrl: product.thumbUrl,
    qty: qty,
  );

  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
    variantId: json['variantId'] as String,
    productId: json['productId'] as String,
    name: json['name'] as String,
    nameI18n: readI18n(json['nameI18n']),
    label: json['label'] as String,
    labelI18n: readI18n(json['labelI18n']),
    pricePaise: json['pricePaise'] as int,
    mrpPaise: json['mrpPaise'] as int?,
    thumbUrl: json['thumbUrl'] as String?,
    qty: json['qty'] as int,
  );

  final String variantId;
  final String productId;
  final String name;
  final Map<String, String>? nameI18n;
  final String label;
  final Map<String, String>? labelI18n;
  final int pricePaise;
  final int? mrpPaise;
  final String? thumbUrl;
  final int qty;

  int get lineTotalPaise => pricePaise * qty;
  String localizedName(Locale locale) => localized(name, nameI18n, locale);
  String localizedLabel(Locale locale) => localized(label, labelI18n, locale);

  CartLine withQty(int qty) => CartLine(
    variantId: variantId,
    productId: productId,
    name: name,
    nameI18n: nameI18n,
    label: label,
    labelI18n: labelI18n,
    pricePaise: pricePaise,
    mrpPaise: mrpPaise,
    thumbUrl: thumbUrl,
    qty: qty,
  );

  Map<String, dynamic> toJson() => {
    'variantId': variantId,
    'productId': productId,
    'name': name,
    'nameI18n': nameI18n,
    'label': label,
    'labelI18n': labelI18n,
    'pricePaise': pricePaise,
    'mrpPaise': mrpPaise,
    'thumbUrl': thumbUrl,
    'qty': qty,
  };
}

@immutable
class Cart {
  const Cart([this.lines = const []]);

  /// Per-line limit; the server accepts up to 99.
  static const maxQty = 20;

  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;
  int get itemCount => lines.fold(0, (sum, l) => sum + l.qty);

  /// Local estimate from the snapshot; shown until the server quote arrives.
  int get estimatedTotalPaise => lines.fold(0, (sum, l) => sum + l.lineTotalPaise);

  int qtyOf(String variantId) => lines.where((l) => l.variantId == variantId).firstOrNull?.qty ?? 0;

  /// Total quantity of a product across its variants (for cards showing the default variant).
  int qtyOfProduct(String productId) =>
      lines.where((l) => l.productId == productId).fold(0, (sum, l) => sum + l.qty);

  List<Map<String, dynamic>> toRequestItems() => [
    for (final l in lines) {'variantId': l.variantId, 'qty': l.qty},
  ];
}
