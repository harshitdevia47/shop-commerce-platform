import 'package:flutter/widgets.dart';

/// Per-shop feature flags. Wire names match backend `FEATURE_KEYS`.
enum Feature { deliverySlots, storePickup, returns, prescriptionUpload, orderNotes, handwrittenListUpload }

/// Runtime shop configuration served by `GET /api/v1/shop/config`.
/// Mirrors `RuntimeConfig` in backend/packages/config-schema.
@immutable
class ShopSettings {
  const ShopSettings({
    required this.id,
    required this.slug,
    required this.shop,
    required this.delivery,
    required this.payments,
    required this.features,
    required this.catalog,
  });

  factory ShopSettings.fromJson(Map<String, dynamic> json) {
    final features = json['features'] as Map<String, dynamic>;
    return ShopSettings(
      id: json['id'] as String,
      slug: json['slug'] as String,
      shop: ShopInfo.fromJson(json['shop'] as Map<String, dynamic>),
      delivery: DeliveryRules.fromJson(json['delivery'] as Map<String, dynamic>),
      payments: PaymentOptions.fromJson(json['payments'] as Map<String, dynamic>),
      // Unknown flags from a newer backend are ignored; missing ones default to off.
      features: {for (final f in Feature.values) f: features[f.name] == true},
      catalog: CatalogSettings.fromJson(json['catalog'] as Map<String, dynamic>),
    );
  }

  final String id;
  final String slug;
  final ShopInfo shop;
  final DeliveryRules delivery;
  final PaymentOptions payments;
  final Map<Feature, bool> features;
  final CatalogSettings catalog;

  bool isEnabled(Feature feature) => features[feature] ?? false;
}

@immutable
class ShopInfo {
  const ShopInfo({
    required this.name,
    required this.nameI18n,
    required this.businessType,
    required this.currency,
    required this.phone,
    required this.address,
    this.whatsapp,
  });

  factory ShopInfo.fromJson(Map<String, dynamic> json) {
    final contact = json['contact'] as Map<String, dynamic>;
    return ShopInfo(
      name: json['name'] as String,
      nameI18n: (json['nameI18n'] as Map<String, dynamic>? ?? const {}).cast<String, String>(),
      businessType: json['businessType'] as String,
      currency: json['currency'] as String,
      phone: contact['phone'] as String,
      whatsapp: contact['whatsapp'] as String?,
      address: contact['address'] as String,
    );
  }

  final String name;
  final Map<String, String> nameI18n;
  final String businessType;
  final String currency;
  final String phone;
  final String? whatsapp;
  final String address;

  String localizedName(Locale locale) => nameI18n[locale.languageCode] ?? name;
}

@immutable
class DeliveryRules {
  const DeliveryRules({
    required this.enabled,
    required this.radiusKm,
    required this.pincodes,
    required this.minOrderPaise,
    required this.feePaise,
    required this.freeAbovePaise,
    required this.etaMinutes,
  });

  factory DeliveryRules.fromJson(Map<String, dynamic> json) => DeliveryRules(
    enabled: json['enabled'] as bool,
    radiusKm: (json['radiusKm'] as num).toDouble(),
    pincodes: (json['pincodes'] as List<dynamic>).cast<String>(),
    minOrderPaise: json['minOrderPaise'] as int,
    feePaise: json['feePaise'] as int,
    freeAbovePaise: json['freeAbovePaise'] as int?,
    etaMinutes: json['etaMinutes'] as int,
  );

  final bool enabled;
  final double radiusKm;
  final List<String> pincodes;
  final int minOrderPaise;
  final int feePaise;
  final int? freeAbovePaise;
  final int etaMinutes;
}

@immutable
class PaymentOptions {
  const PaymentOptions({required this.cod, required this.upiEnabled, this.upiVpa, this.upiPayeeName});

  factory PaymentOptions.fromJson(Map<String, dynamic> json) {
    final upi = json['upi'] as Map<String, dynamic>;
    return PaymentOptions(
      cod: json['cod'] as bool,
      upiEnabled: upi['enabled'] as bool,
      upiVpa: upi['vpa'] as String?,
      upiPayeeName: upi['payeeName'] as String?,
    );
  }

  final bool cod;
  final bool upiEnabled;
  final String? upiVpa;
  final String? upiPayeeName;
}

@immutable
class CatalogSettings {
  const CatalogSettings({required this.variantStyle, required this.variantAxes});

  factory CatalogSettings.fromJson(Map<String, dynamic> json) => CatalogSettings(
    variantStyle: json['variantStyle'] as String,
    variantAxes: (json['variantAxes'] as List<dynamic>).cast<String>(),
  );

  /// `single` | `units` | `options`
  final String variantStyle;
  final List<String> variantAxes;
}
