/// What the platform service's /api/admin answers. Money is int paise; days are `YYYY-MM-DD` (IST).
library;

enum ShopStatus {
  overdue('Overdue'),
  paused('Paused'),
  due('Due'),
  dueSoon('Due soon'),
  paid('Paid'),
  notSetUp('Not set up');

  const ShopStatus(this.label);
  final String label;

  static ShopStatus parse(String value) => switch (value) {
    'overdue' => overdue,
    'paused' => paused,
    'due' => due,
    'due_soon' => dueSoon,
    'paid' => paid,
    _ => notSetUp,
  };

  String get key => switch (this) {
    dueSoon => 'due_soon',
    notSetUp => 'not_set_up',
    _ => name,
  };
}

Map<String, dynamic> _map(Object? v) => (v as Map).cast<String, dynamic>();
int? _int(Object? v) => (v as num?)?.toInt();

class ShopInfo {
  const ShopInfo({required this.id, required this.slug, required this.name, required this.businessType, required this.phone, this.whatsapp, required this.address, required this.isActive});

  factory ShopInfo.fromJson(Map<String, dynamic> j) {
    final contact = _map(j['contact']);
    return ShopInfo(
      id: j['id'] as String,
      slug: j['slug'] as String,
      name: j['name'] as String,
      businessType: j['businessType'] as String,
      phone: contact['phone'] as String,
      whatsapp: contact['whatsapp'] as String?,
      address: contact['address'] as String? ?? '',
      isActive: j['isActive'] as bool? ?? true,
    );
  }

  final String id;
  final String slug;
  final String name;
  final String businessType;
  final String phone;
  final String? whatsapp;
  final String address;
  final bool isActive;
}

class Subscription {
  const Subscription({required this.feePaise, required this.dueDay, required this.nextDueDate, this.extendedUntil, this.pausedAt, this.logoDone = false, this.playDone = false});

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
    feePaise: _int(j['feePaise'])!,
    dueDay: _int(j['dueDay'])!,
    nextDueDate: j['nextDueDate'] as String,
    extendedUntil: j['extendedUntil'] as String?,
    pausedAt: j['pausedAt'] as String?,
    logoDone: j['logoDone'] as bool? ?? false,
    playDone: j['playDone'] as bool? ?? false,
  );

  final int feePaise;
  final int dueDay;
  final String nextDueDate;
  final String? extendedUntil;
  final String? pausedAt;
  final bool logoDone;
  final bool playDone;
}

class Payment {
  const Payment({required this.id, required this.amountPaise, this.upiRef, required this.paidOn, required this.months, this.note});

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
    id: j['id'] as String,
    amountPaise: _int(j['amountPaise'])!,
    upiRef: j['upiRef'] as String?,
    paidOn: j['paidOn'] as String,
    months: _int(j['months']) ?? 1,
    note: j['note'] as String?,
  );

  final String id;
  final int amountPaise;
  final String? upiRef;
  final String paidOn;
  final int months;
  final String? note;
}

/// Numbers from the shop's app; a part is null when that service did not answer.
class ShopNumbers {
  const ShopNumbers({this.customers, this.newCustomers, this.activeCustomers, this.ownerName, this.ownerPhone, this.ownerLoggedIn = false, this.products, this.orders, this.salesPaise, this.lastOrderAt});

  factory ShopNumbers.fromJson(Map<String, dynamic> j) {
    final customers = j['customers'] == null ? null : _map(j['customers']);
    final owner = j['owner'] == null ? null : _map(j['owner']);
    final month = j['month'] == null ? null : _map(j['month']);
    return ShopNumbers(
      customers: _int(customers?['total']),
      newCustomers: _int(customers?['newSince']),
      activeCustomers: _int(customers?['activeSince']),
      ownerName: owner?['name'] as String?,
      ownerPhone: owner?['phone'] as String?,
      ownerLoggedIn: owner?['hasLoggedIn'] as bool? ?? false,
      products: _int(j['products']),
      orders: _int(month?['orders']),
      salesPaise: _int(month?['salesPaise']),
      lastOrderAt: month?['lastOrderAt'] as String?,
    );
  }

  final int? customers;
  final int? newCustomers;
  final int? activeCustomers;
  final String? ownerName;
  final String? ownerPhone;
  final bool ownerLoggedIn;
  final int? products;
  final int? orders;
  final int? salesPaise;
  final String? lastOrderAt;
}

class OverviewRow {
  const OverviewRow({required this.shop, this.subscription, required this.status, required this.numbers});

  factory OverviewRow.fromJson(Map<String, dynamic> j) => OverviewRow(
    shop: ShopInfo.fromJson(_map(j['shop'])),
    subscription: j['subscription'] == null ? null : Subscription.fromJson(_map(j['subscription'])),
    status: ShopStatus.parse(j['status'] as String),
    numbers: ShopNumbers.fromJson(_map(j['numbers'])),
  );

  final ShopInfo shop;
  final Subscription? subscription;
  final ShopStatus status;
  final ShopNumbers numbers;
}

class Overview {
  const Overview({required this.rows, required this.counts});

  factory Overview.fromJson(Map<String, dynamic> j) => Overview(
    rows: [for (final r in j['rows'] as List) OverviewRow.fromJson(_map(r))],
    counts: {for (final e in _map(j['counts']).entries) ShopStatus.parse(e.key): _int(e.value) ?? 0},
  );

  final List<OverviewRow> rows;
  final Map<ShopStatus, int> counts;
}

class ShopDetail {
  const ShopDetail({required this.shop, this.subscription, required this.payments, required this.status, required this.numbers, required this.today, this.payTo, this.defaultFeeRupees});

  factory ShopDetail.fromJson(Map<String, dynamic> j) => ShopDetail(
    shop: ShopInfo.fromJson(_map(j['shop'])),
    subscription: j['subscription'] == null ? null : Subscription.fromJson(_map(j['subscription'])),
    payments: [for (final p in j['payments'] as List) Payment.fromJson(_map(p))],
    status: ShopStatus.parse(j['status'] as String),
    numbers: ShopNumbers.fromJson(_map(j['numbers'])),
    today: j['today'] as String,
    payTo: j['payTo'] as String?,
    defaultFeeRupees: _int(j['defaultFeeRupees']),
  );

  final ShopInfo shop;
  final Subscription? subscription;
  final List<Payment> payments;
  final ShopStatus status;
  final ShopNumbers numbers;
  final String today;
  final String? payTo;
  final int? defaultFeeRupees;
}

/// Result of an action: `repeat` = the same form was already sent, nothing changed.
class ActionOutcome {
  const ActionOutcome({required this.repeat, required this.shop});

  factory ActionOutcome.fromJson(Map<String, dynamic> j) =>
      ActionOutcome(repeat: j['result'] == 'repeat', shop: ShopDetail.fromJson(_map(j['shop'])));

  final bool repeat;
  final ShopDetail shop;
}
