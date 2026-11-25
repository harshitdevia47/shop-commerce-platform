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
    this.returns = const ReturnsPolicy(),
    this.ordering = const OrderingState(),
    this.subscription = const SubscriptionInfo(),
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
      returns: json['returns'] == null ? const ReturnsPolicy() : ReturnsPolicy.fromJson(json['returns'] as Map<String, dynamic>),
      ordering: json['ordering'] == null ? const OrderingState() : OrderingState.fromJson(json['ordering'] as Map<String, dynamic>),
      subscription: json['subscription'] == null
          ? const SubscriptionInfo()
          : SubscriptionInfo.fromJson(json['subscription'] as Map<String, dynamic>),
    );
  }

  final String id;
  final String slug;
  final ShopInfo shop;
  final DeliveryRules delivery;
  final PaymentOptions payments;
  final Map<Feature, bool> features;
  final CatalogSettings catalog;
  final ReturnsPolicy returns;
  final OrderingState ordering;

  /// The shop's subscription to the platform (set by the platform only).
  final SubscriptionInfo subscription;

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
    this.lat,
    this.lng,
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
      lat: (contact['lat'] as num?)?.toDouble(),
      lng: (contact['lng'] as num?)?.toDouble(),
    );
  }

  final String name;
  final Map<String, String> nameI18n;
  final String businessType;
  final String currency;
  final String phone;
  final String? whatsapp;
  final String address;
  final double? lat;
  final double? lng;

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
    this.slots,
  });

  factory DeliveryRules.fromJson(Map<String, dynamic> json) => DeliveryRules(
    enabled: json['enabled'] as bool,
    radiusKm: (json['radiusKm'] as num).toDouble(),
    pincodes: (json['pincodes'] as List<dynamic>).cast<String>(),
    minOrderPaise: json['minOrderPaise'] as int,
    feePaise: json['feePaise'] as int,
    freeAbovePaise: json['freeAbovePaise'] as int?,
    etaMinutes: json['etaMinutes'] as int,
    slots: json['slots'] == null ? null : SlotSettings.fromJson(json['slots'] as Map<String, dynamic>),
  );

  final bool enabled;
  final double radiusKm;
  final List<String> pincodes;
  final int minOrderPaise;
  final int feePaise;
  final int? freeAbovePaise;
  final int etaMinutes;

  /// Delivery windows customers choose from (when [Feature.deliverySlots] is on).
  final SlotSettings? slots;
}

/// One daily delivery window, `HH:MM` in shop time.
typedef SlotWindow = ({String start, String end});

@immutable
class SlotSettings {
  const SlotSettings({required this.windows, this.daysAhead = 2, this.capacityPerSlot = 10, this.cutoffMinutes = 60});

  factory SlotSettings.fromJson(Map<String, dynamic> json) => SlotSettings(
    windows: [
      for (final w in json['windows'] as List<dynamic>)
        (start: (w as Map<String, dynamic>)['start'] as String, end: w['end'] as String),
    ],
    daysAhead: json['daysAhead'] as int? ?? 2,
    capacityPerSlot: json['capacityPerSlot'] as int? ?? 10,
    cutoffMinutes: json['cutoffMinutes'] as int? ?? 60,
  );

  final List<SlotWindow> windows;
  final int daysAhead;
  final int capacityPerSlot;
  final int cutoffMinutes;

  Map<String, dynamic> toJson() => {
    'windows': [for (final w in windows) {'start': w.start, 'end': w.end}],
    'daysAhead': daysAhead,
    'capacityPerSlot': capacityPerSlot,
    'cutoffMinutes': cutoffMinutes,
  };
}

/// Owner's "not taking orders" switch.
@immutable
class OrderingState {
  const OrderingState({this.paused = false, this.message});

  factory OrderingState.fromJson(Map<String, dynamic> json) =>
      OrderingState(paused: json['paused'] as bool? ?? false, message: json['pausedMessage'] as String?);

  final bool paused;
  final String? message;
}

enum SubscriptionState { ok, due, paused }

/// Platform subscription: `due` reminds the owner to pay; `paused` = the platform stopped new orders.
@immutable
class SubscriptionInfo {
  const SubscriptionInfo({this.state = SubscriptionState.ok, this.amountPaise, this.dueDate, this.payTo});

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) => SubscriptionInfo(
    // Unknown states from a newer backend count as ok (never block on a value the app does not know).
    state: SubscriptionState.values.asNameMap()[json['state']] ?? SubscriptionState.ok,
    amountPaise: (json['amountPaise'] as num?)?.toInt(),
    dueDate: json['dueDate'] == null ? null : DateTime.tryParse(json['dueDate'] as String),
    payTo: json['payTo'] as String?,
  );

  final SubscriptionState state;
  final int? amountPaise;
  final DateTime? dueDate;
  final String? payTo;
}

@immutable
class PaymentOptions {
  const PaymentOptions({required this.cod, required this.upiEnabled, this.upiVpa, this.upiPayeeName, this.razorpayEnabled = false});

  factory PaymentOptions.fromJson(Map<String, dynamic> json) {
    final upi = json['upi'] as Map<String, dynamic>;
    return PaymentOptions(
      cod: json['cod'] as bool,
      upiEnabled: upi['enabled'] as bool,
      upiVpa: upi['vpa'] as String?,
      upiPayeeName: upi['payeeName'] as String?,
      razorpayEnabled: (json['razorpay'] as Map<String, dynamic>?)?['enabled'] == true,
    );
  }

  final bool cod;
  final bool upiEnabled;
  final String? upiVpa;
  final String? upiPayeeName;

  /// Online payments through the shop's Razorpay account.
  final bool razorpayEnabled;
}

@immutable
class CatalogSettings {
  const CatalogSettings({required this.variantStyle, required this.variantAxes, this.customFields = const []});

  factory CatalogSettings.fromJson(Map<String, dynamic> json) => CatalogSettings(
    variantStyle: VariantStyle.fromWire(json['variantStyle'] as String),
    variantAxes: (json['variantAxes'] as List<dynamic>).cast<String>(),
    customFields: [
      for (final field in json['customFields'] as List<dynamic>? ?? const [])
        CustomFieldDef.fromJson(field as Map<String, dynamic>),
    ],
  );

  final VariantStyle variantStyle;

  /// Option axes for [VariantStyle.options], e.g. `size`, `color`.
  final List<String> variantAxes;
  final List<CustomFieldDef> customFields;
}

/// How a shop's products vary. Wire names match backend `VARIANT_STYLES`.
enum VariantStyle {
  /// One price per product.
  single,

  /// Pack sizes such as "500 g" and "1 kg".
  units,

  /// Combinations of axes such as size and colour.
  options;

  static VariantStyle fromWire(String value) =>
      VariantStyle.values.firstWhere((v) => v.name == value, orElse: () => VariantStyle.units);
}

enum CustomFieldType { text, number, boolean, select }

/// Extra product detail a shop collects (e.g. brand, fabric). Mirrors `customFieldSchema`.
@immutable
class CustomFieldDef {
  const CustomFieldDef({
    required this.key,
    required this.type,
    required this.label,
    this.required = false,
    this.options = const [],
  });

  factory CustomFieldDef.fromJson(Map<String, dynamic> json) => CustomFieldDef(
    key: json['key'] as String,
    type: CustomFieldType.values.firstWhere((t) => t.name == json['type'], orElse: () => CustomFieldType.text),
    label: (json['label'] as Map<String, dynamic>).cast<String, String>(),
    required: json['required'] as bool? ?? false,
    options: (json['options'] as List<dynamic>? ?? const []).cast<String>(),
  );

  final String key;
  final CustomFieldType type;

  /// `{en, gu?, hi?}`
  final Map<String, String> label;
  final bool required;
  final List<String> options;

  String localizedLabel(Locale locale) => label[locale.languageCode] ?? label['en'] ?? key;
}

/// Returns / exchanges policy (when [Feature.returns] is on).
@immutable
class ReturnsPolicy {
  const ReturnsPolicy({this.windowDays = 7, this.allowExchange = true});

  factory ReturnsPolicy.fromJson(Map<String, dynamic> json) =>
      ReturnsPolicy(windowDays: json['windowDays'] as int? ?? 7, allowExchange: json['allowExchange'] as bool? ?? true);

  final int windowDays;
  final bool allowExchange;
}
