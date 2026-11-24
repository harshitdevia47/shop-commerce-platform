import 'package:flutter/widgets.dart';

import '../../../core/utils/localized.dart';

/// Wire names match the order service `OrderStatus`.
enum OrderStatus {
  placed('PLACED'),
  confirmed('CONFIRMED'),
  packed('PACKED'),
  outForDelivery('OUT_FOR_DELIVERY'),
  readyForPickup('READY_FOR_PICKUP'),
  delivered('DELIVERED'),
  pickedUp('PICKED_UP'),
  cancelled('CANCELLED'),
  rejected('REJECTED');

  const OrderStatus(this.wire);
  final String wire;

  static OrderStatus fromWire(String value) => values.firstWhere((s) => s.wire == value);

  bool get isFailed => this == cancelled || this == rejected;
  bool get isDone => isFailed || this == delivered || this == pickedUp;
}

enum Fulfillment {
  delivery('DELIVERY'),
  pickup('PICKUP');

  const Fulfillment(this.wire);
  final String wire;

  static Fulfillment fromWire(String value) => values.firstWhere((f) => f.wire == value);
}

enum PaymentMethod {
  cod('COD'),
  upi('UPI'),
  razorpay('RAZORPAY');

  const PaymentMethod(this.wire);
  final String wire;

  static PaymentMethod fromWire(String value) => values.firstWhere((m) => m.wire == value);
}

enum PaymentStatus {
  pending('PENDING'),
  submitted('SUBMITTED'),
  paid('PAID'),
  voided('VOID');

  const PaymentStatus(this.wire);
  final String wire;

  static PaymentStatus fromWire(String value) => values.firstWhere((s) => s.wire == value);
}

@immutable
class Address {
  const Address({
    required this.id,
    required this.line1,
    required this.city,
    required this.pincode,
    this.label = 'home',
    this.name,
    this.phone,
    this.line2,
    this.landmark,
    this.isDefault = false,
    this.lat,
    this.lng,
  });

  factory Address.fromJson(Map<String, dynamic> json) => Address(
    id: json['id'] as String,
    label: json['label'] as String? ?? 'home',
    name: json['name'] as String?,
    phone: json['phone'] as String?,
    line1: json['line1'] as String,
    line2: json['line2'] as String?,
    landmark: json['landmark'] as String?,
    city: json['city'] as String,
    pincode: json['pincode'] as String,
    isDefault: json['isDefault'] as bool? ?? false,
    lat: (json['lat'] as num?)?.toDouble(),
    lng: (json['lng'] as num?)?.toDouble(),
  );

  /// Map pin, when the customer set one (distance and rider ETA use it).
  final double? lat;
  final double? lng;

  final String id;
  final String label;
  final String? name;
  final String? phone;
  final String line1;
  final String? line2;
  final String? landmark;
  final String city;
  final String pincode;
  final bool isDefault;

  /// One line for lists: "12 Station Road, Near temple, Bhavnagar 364001".
  String get summary => [line1, line2, landmark, '$city $pincode'].whereType<String>().where((s) => s.isNotEmpty).join(', ');
}

/// Line of a server quote.
@immutable
class QuoteLine {
  const QuoteLine({
    required this.variantId,
    required this.productName,
    required this.label,
    required this.pricePaise,
    required this.qty,
    required this.lineTotalPaise,
    this.productNameI18n,
    this.labelI18n,
    this.mrpPaise,
    this.issue,
    this.maxQty,
  });

  factory QuoteLine.fromJson(Map<String, dynamic> json) => QuoteLine(
    variantId: json['variantId'] as String,
    productName: json['productName'] as String,
    productNameI18n: readI18n(json['productNameI18n']),
    label: json['label'] as String,
    labelI18n: readI18n(json['labelI18n']),
    pricePaise: json['pricePaise'] as int,
    mrpPaise: json['mrpPaise'] as int?,
    qty: json['qty'] as int,
    lineTotalPaise: json['lineTotalPaise'] as int,
    issue: json['issue'] as String?,
    maxQty: json['maxQty'] as int?,
  );

  final String variantId;
  final String productName;
  final Map<String, String>? productNameI18n;
  final String label;
  final Map<String, String>? labelI18n;
  final int pricePaise;
  final int? mrpPaise;
  final int qty;
  final int lineTotalPaise;

  /// `UNAVAILABLE` | `INSUFFICIENT_STOCK` | null
  final String? issue;
  final int? maxQty;
}

@immutable
class Quote {
  const Quote({
    required this.lines,
    required this.missing,
    required this.itemCount,
    required this.subtotalPaise,
    required this.deliveryFeePaise,
    required this.totalPaise,
    required this.savingsPaise,
    required this.minOrderPaise,
    required this.canPlace,
    this.freeDeliveryGapPaise,
  });

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
    lines: [for (final l in json['lines'] as List<dynamic>) QuoteLine.fromJson(l as Map<String, dynamic>)],
    missing: (json['missing'] as List<dynamic>).cast<String>(),
    itemCount: json['itemCount'] as int,
    subtotalPaise: json['subtotalPaise'] as int,
    deliveryFeePaise: json['deliveryFeePaise'] as int,
    totalPaise: json['totalPaise'] as int,
    savingsPaise: json['savingsPaise'] as int,
    minOrderPaise: json['minOrderPaise'] as int,
    freeDeliveryGapPaise: json['freeDeliveryGapPaise'] as int?,
    canPlace: json['canPlace'] as bool,
  );

  final List<QuoteLine> lines;
  final List<String> missing;
  final int itemCount;
  final int subtotalPaise;
  final int deliveryFeePaise;
  final int totalPaise;
  final int savingsPaise;
  final int minOrderPaise;
  final int? freeDeliveryGapPaise;
  final bool canPlace;

  QuoteLine? lineFor(String variantId) => lines.where((l) => l.variantId == variantId).firstOrNull;
  bool get belowMinimum => subtotalPaise < minOrderPaise;
}

@immutable
class OrderItem {
  const OrderItem({
    required this.productName,
    required this.variantLabel,
    required this.pricePaise,
    required this.qty,
    required this.lineTotalPaise,
    this.productNameI18n,
    this.variantLabelI18n,
    this.thumbUrl,
    this.variantId,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    variantId: json['variantId'] as String?,
    productName: json['productName'] as String,
    productNameI18n: readI18n(json['productNameI18n']),
    variantLabel: json['variantLabel'] as String,
    variantLabelI18n: readI18n(json['variantLabelI18n']),
    thumbUrl: json['thumbUrl'] as String?,
    pricePaise: json['pricePaise'] as int,
    qty: json['qty'] as int,
    lineTotalPaise: json['lineTotalPaise'] as int,
  );

  final String? variantId;
  final String productName;
  final Map<String, String>? productNameI18n;
  final String variantLabel;
  final Map<String, String>? variantLabelI18n;
  final String? thumbUrl;
  final int pricePaise;
  final int qty;
  final int lineTotalPaise;

  String localizedName(Locale locale) => localized(productName, productNameI18n, locale);
  String localizedLabel(Locale locale) => localized(variantLabel, variantLabelI18n, locale);
}

@immutable
class StatusChange {
  const StatusChange({required this.status, required this.at, this.reason});

  factory StatusChange.fromJson(Map<String, dynamic> json) => StatusChange(
    status: OrderStatus.fromWire(json['status'] as String),
    at: DateTime.parse(json['at'] as String).toLocal(),
    reason: json['reason'] as String?,
  );

  final OrderStatus status;
  final DateTime at;
  final String? reason;
}

@immutable
class Order {
  const Order({
    required this.id,
    required this.number,
    required this.status,
    required this.fulfillment,
    required this.paymentMethod,
    required this.items,
    required this.itemCount,
    required this.subtotalPaise,
    required this.deliveryFeePaise,
    required this.totalPaise,
    required this.placedAt,
    required this.customerPhone,
    this.customerName,
    this.address,
    this.note,
    this.cancelReason,
    this.history = const [],
    this.nextStatuses = const [],
    this.slot,
    this.attachments = const [],
    this.needsPricing = false,
    this.returnRequest,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>;
    final address = json['address'] as Map<String, dynamic>?;
    return Order(
      id: json['id'] as String,
      number: json['number'] as int,
      status: OrderStatus.fromWire(json['status'] as String),
      fulfillment: Fulfillment.fromWire(json['fulfillment'] as String),
      paymentMethod: PaymentMethod.fromWire(json['paymentMethod'] as String),
      address: address == null ? null : Address.fromJson(address),
      note: json['note'] as String?,
      customerPhone: customer['phone'] as String,
      customerName: customer['name'] as String?,
      items: [for (final i in json['items'] as List<dynamic>) OrderItem.fromJson(i as Map<String, dynamic>)],
      itemCount: json['itemCount'] as int,
      subtotalPaise: json['subtotalPaise'] as int,
      deliveryFeePaise: json['deliveryFeePaise'] as int,
      totalPaise: json['totalPaise'] as int,
      cancelReason: json['cancelReason'] as String?,
      placedAt: DateTime.parse(json['placedAt'] as String).toLocal(),
      history: [for (final h in json['history'] as List<dynamic>? ?? const []) StatusChange.fromJson(h as Map<String, dynamic>)],
      nextStatuses: [for (final s in json['nextStatuses'] as List<dynamic>? ?? const []) OrderStatus.fromWire(s as String)],
      slot: json['slot'] == null ? null : TimeWindow.fromJson(json['slot'] as Map<String, dynamic>),
      attachments: [for (final a in json['attachments'] as List<dynamic>? ?? const []) Attachment.fromJson(a as Map<String, dynamic>)],
      needsPricing: json['needsPricing'] as bool? ?? false,
      returnRequest: json['returnRequest'] == null ? null : ReturnRequest.fromJson(json['returnRequest'] as Map<String, dynamic>),
    );
  }

  /// Delivery window chosen at checkout (shops with delivery slots).
  final TimeWindow? slot;

  /// Private photos: prescription / handwritten list.
  final List<Attachment> attachments;

  /// List order: the shop sets the amount when accepting it.
  final bool needsPricing;

  final ReturnRequest? returnRequest;

  /// When the customer got it (delivered or picked up), for the return window.
  DateTime? get handedOverAt => history.where((h) => h.status == OrderStatus.delivered || h.status == OrderStatus.pickedUp).lastOrNull?.at;

  final String id;
  final int number;
  final OrderStatus status;
  final Fulfillment fulfillment;
  final PaymentMethod paymentMethod;
  final Address? address;
  final String? note;
  final String customerPhone;
  final String? customerName;
  final List<OrderItem> items;
  final int itemCount;
  final int subtotalPaise;
  final int deliveryFeePaise;
  final int totalPaise;
  final String? cancelReason;
  final DateTime placedAt;
  final List<StatusChange> history;

  /// What the current user may do next (from the server's status machine).
  final List<OrderStatus> nextStatuses;

  bool get canCancel => nextStatuses.contains(OrderStatus.cancelled);
}

@immutable
class Payment {
  const Payment({
    required this.orderId,
    required this.method,
    required this.status,
    required this.amountPaise,
    this.utr,
    this.upiUri,
    this.razorpay,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    orderId: json['orderId'] as String,
    method: PaymentMethod.fromWire(json['method'] as String),
    status: PaymentStatus.fromWire(json['status'] as String),
    amountPaise: json['amountPaise'] as int,
    utr: json['utr'] as String?,
    upiUri: json['upiUri'] as String?,
    razorpay: json['razorpay'] == null ? null : RazorpayCheckoutInfo.fromJson(json['razorpay'] as Map<String, dynamic>),
  );

  final String orderId;
  final PaymentMethod method;
  final PaymentStatus status;
  final int amountPaise;
  final String? utr;
  final String? upiUri;

  /// Online payment not done yet: what Razorpay Checkout needs.
  final RazorpayCheckoutInfo? razorpay;
}

@immutable
class RazorpayCheckoutInfo {
  const RazorpayCheckoutInfo({required this.keyId, required this.orderId, required this.amountPaise});

  factory RazorpayCheckoutInfo.fromJson(Map<String, dynamic> json) => RazorpayCheckoutInfo(
    keyId: json['keyId'] as String,
    orderId: json['orderId'] as String,
    amountPaise: json['amountPaise'] as int,
  );

  final String keyId;
  final String orderId;
  final int amountPaise;
}

/// The order flow's request; [idempotencyKey] stays the same across retries of one checkout.
@immutable
class PlaceOrderRequest {
  const PlaceOrderRequest({
    required this.items,
    required this.fulfillment,
    required this.paymentMethod,
    required this.idempotencyKey,
    this.addressId,
    this.note,
    this.expectedTotalPaise,
    this.slotStart,
    this.attachmentIds = const [],
  });

  final DateTime? slotStart;
  final List<String> attachmentIds;
  final List<Map<String, dynamic>> items;
  final Fulfillment fulfillment;
  final PaymentMethod paymentMethod;
  final String idempotencyKey;
  final String? addressId;
  final String? note;
  final int? expectedTotalPaise;

  Map<String, dynamic> toJson() => {
    'items': items,
    'fulfillment': fulfillment.wire,
    'paymentMethod': paymentMethod.wire,
    'idempotencyKey': idempotencyKey,
    'addressId': ?addressId,
    if (note != null && note!.isNotEmpty) 'note': note,
    'expectedTotalPaise': ?expectedTotalPaise,
    if (slotStart != null) 'slotStart': slotStart!.toUtc().toIso8601String(),
    if (attachmentIds.isNotEmpty) 'attachmentIds': attachmentIds,
  };
}

@immutable
class TimeWindow {
  const TimeWindow({required this.start, required this.end});

  factory TimeWindow.fromJson(Map<String, dynamic> json) =>
      TimeWindow(start: DateTime.parse(json['start'] as String).toLocal(), end: DateTime.parse(json['end'] as String).toLocal());

  final DateTime start;
  final DateTime end;
}

/// A delivery window offered at checkout.
@immutable
class DeliverySlot extends TimeWindow {
  const DeliverySlot({required super.start, required super.end, required this.available});

  factory DeliverySlot.fromJson(Map<String, dynamic> json) => DeliverySlot(
    start: DateTime.parse(json['start'] as String).toLocal(),
    end: DateTime.parse(json['end'] as String).toLocal(),
    available: json['available'] as bool,
  );

  final bool available;
}

/// Private photo kinds (wire names match the media service).
enum AttachmentKind {
  prescription('PRESCRIPTION'),
  handwrittenList('HANDWRITTEN_LIST'),
  returnPhoto('RETURN_PHOTO');

  const AttachmentKind(this.wire);
  final String wire;

  static AttachmentKind fromWire(String value) => values.firstWhere((k) => k.wire == value, orElse: () => handwrittenList);
}

@immutable
class Attachment {
  const Attachment({required this.id, required this.kind});

  factory Attachment.fromJson(Map<String, dynamic> json) =>
      Attachment(id: json['id'] as String, kind: AttachmentKind.fromWire(json['kind'] as String));

  final String id;
  final AttachmentKind kind;
}

enum ReturnKind {
  returnItems('RETURN'),
  exchange('EXCHANGE');

  const ReturnKind(this.wire);
  final String wire;
}

enum ReturnStatus {
  requested('REQUESTED'),
  approved('APPROVED'),
  rejected('REJECTED'),
  completed('COMPLETED');

  const ReturnStatus(this.wire);
  final String wire;

  static ReturnStatus fromWire(String value) => values.firstWhere((s) => s.wire == value, orElse: () => requested);
}

@immutable
class ReturnLine {
  const ReturnLine({required this.variantId, required this.productName, required this.variantLabel, required this.qty});

  factory ReturnLine.fromJson(Map<String, dynamic> json) => ReturnLine(
    variantId: json['variantId'] as String,
    productName: json['productName'] as String,
    variantLabel: json['variantLabel'] as String,
    qty: json['qty'] as int,
  );

  final String variantId;
  final String productName;
  final String variantLabel;
  final int qty;
}

@immutable
class ReturnRequest {
  const ReturnRequest({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.type,
    required this.status,
    required this.reason,
    required this.items,
    required this.createdAt,
    this.photos = const [],
    this.shopNote,
  });

  factory ReturnRequest.fromJson(Map<String, dynamic> json) => ReturnRequest(
    id: json['id'] as String,
    orderId: json['orderId'] as String,
    orderNumber: json['orderNumber'] as int,
    type: json['type'] == 'EXCHANGE' ? ReturnKind.exchange : ReturnKind.returnItems,
    status: ReturnStatus.fromWire(json['status'] as String),
    reason: json['reason'] as String,
    items: [for (final i in json['items'] as List<dynamic>) ReturnLine.fromJson(i as Map<String, dynamic>)],
    photos: [for (final p in json['photos'] as List<dynamic>? ?? const []) Attachment.fromJson(p as Map<String, dynamic>)],
    shopNote: json['shopNote'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  final String id;
  final String orderId;
  final int orderNumber;
  final ReturnKind type;
  final ReturnStatus status;
  final String reason;
  final List<ReturnLine> items;
  final List<Attachment> photos;
  final String? shopNote;
  final DateTime createdAt;
}
