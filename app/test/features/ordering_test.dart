import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qc_app/app.dart';
import 'package:qc_app/core/config/shop_settings.dart';
import 'package:qc_app/core/network/api_exception.dart';
import 'package:qc_app/core/providers.dart';
import 'package:qc_app/core/push/push_service.dart';
import 'package:qc_app/core/realtime/realtime_channel.dart';
import 'package:qc_app/core/realtime/realtime_providers.dart';
import 'package:qc_app/core/utils/launcher.dart';
import 'package:qc_app/features/auth/data/session_store.dart';
import 'package:qc_app/features/auth/domain/auth_models.dart';
import 'package:qc_app/features/auth/presentation/auth_controller.dart';
import 'package:qc_app/features/cart/presentation/cart_quote.dart';
import 'package:qc_app/features/catalog/domain/catalog_models.dart';
import 'package:qc_app/features/catalog/presentation/catalog_providers.dart';
import 'package:qc_app/features/orders/data/orders_repository.dart';
import 'package:qc_app/features/orders/domain/order_models.dart';
import 'package:qc_app/features/orders/presentation/order_detail_screen.dart';
import 'package:qc_app/features/orders/presentation/orders_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures.dart';

/// In-memory order service: prices with fixed fee rules, tracks stock limits and payments.
class FakeOrders implements OrdersRepository, AdminOrdersRepository {
  final Map<String, int> stockLimit = {};
  final List<PlaceOrderRequest> placed = [];
  final List<Address> addressList = [];
  final Map<String, Order> store = {};
  final Map<String, Payment> payments = {};
  Object? failNextPlace;
  int quotes = 0;

  static const prices = {'p1-v1': 12000, 'p1-v2': 55000};

  @override
  Future<Quote> quote(List<Map<String, dynamic>> items, Fulfillment fulfillment) async {
    quotes++;
    final lines = [
      for (final item in items)
        () {
          final id = item['variantId'] as String;
          final qty = item['qty'] as int;
          final limit = stockLimit[id];
          final short = limit != null && qty > limit;
          return QuoteLine(
            variantId: id,
            productName: 'Basmati Rice',
            label: id.endsWith('1') ? '1 kg' : '5 kg',
            pricePaise: prices[id]!,
            qty: qty,
            lineTotalPaise: prices[id]! * qty,
            issue: short ? 'INSUFFICIENT_STOCK' : null,
            maxQty: short ? limit : null,
          );
        }(),
    ];
    final subtotal = lines.where((l) => l.issue == null).fold(0, (s, l) => s + l.lineTotalPaise);
    final fee = fulfillment == Fulfillment.delivery && subtotal < 50000 ? 2000 : 0;
    return Quote(
      lines: lines,
      missing: const [],
      itemCount: lines.fold(0, (s, l) => s + l.qty),
      subtotalPaise: subtotal,
      deliveryFeePaise: fee,
      totalPaise: subtotal + fee,
      savingsPaise: 0,
      minOrderPaise: fulfillment == Fulfillment.delivery ? 10000 : 0,
      freeDeliveryGapPaise: fee > 0 ? 50000 - subtotal : null,
      canPlace: lines.every((l) => l.issue == null) && subtotal >= 10000,
    );
  }

  Order _order(String id, int number, PlaceOrderRequest r, int total, {OrderStatus status = OrderStatus.placed}) => Order(
    id: id,
    number: number,
    status: status,
    fulfillment: r.fulfillment,
    paymentMethod: r.paymentMethod,
    items: const [
      OrderItem(variantId: 'p1-v1', productName: 'Basmati Rice', variantLabel: '1 kg', pricePaise: 12000, qty: 1, lineTotalPaise: 12000),
    ],
    itemCount: 1,
    subtotalPaise: total,
    deliveryFeePaise: 0,
    totalPaise: total,
    placedAt: DateTime(2026, 11, 23, 10),
    customerPhone: '+919876543210',
    address: addressList.firstOrNull,
    history: [StatusChange(status: OrderStatus.placed, at: DateTime(2026, 11, 23, 10))],
    nextStatuses: status == OrderStatus.placed ? const [OrderStatus.cancelled] : const [],
  );

  @override
  Future<(Order, Payment?)> place(PlaceOrderRequest request) async {
    placed.add(request);
    if (request.fulfillment == Fulfillment.delivery && request.addressId == null) {
      throw const ApiException('ADDRESS_REQUIRED', 'Choose a delivery address', statusCode: 400);
    }
    if (failNextPlace case final error?) {
      failNextPlace = null;
      throw error;
    }
    final id = 'o${store.length + 1}';
    final list = request.items.isEmpty;
    final base = _order(id, store.length + 1, request, request.expectedTotalPaise ?? 0);
    final order = Order(
      id: base.id,
      number: base.number,
      status: base.status,
      fulfillment: base.fulfillment,
      paymentMethod: base.paymentMethod,
      items: list ? const [] : base.items,
      itemCount: list ? 0 : base.itemCount,
      subtotalPaise: base.subtotalPaise,
      deliveryFeePaise: 0,
      totalPaise: base.totalPaise,
      placedAt: base.placedAt,
      customerPhone: base.customerPhone,
      address: base.address,
      history: base.history,
      nextStatuses: base.nextStatuses,
      needsPricing: list,
      slot: request.slotStart == null
          ? null
          : TimeWindow(start: request.slotStart!, end: request.slotStart!.add(const Duration(hours: 4))),
      attachments: [for (final a in request.attachmentIds) Attachment(id: a, kind: AttachmentKind.handwrittenList)],
    );
    store[id] = order;
    if (list) return (order, null);
    payments[id] = Payment(
      orderId: id,
      method: request.paymentMethod,
      status: PaymentStatus.pending,
      amountPaise: order.totalPaise,
      upiUri: request.paymentMethod == PaymentMethod.upi ? 'upi://pay?pa=shop@okaxis&am=120.00' : null,
    );
    return (order, payments[id]);
  }

  @override
  Future<PageResult<Order>> myOrders({String? cursor}) async => PageResult(store.values.toList().reversed.toList(), null);

  int orderFetches = 0;

  @override
  Future<Order> order(String id) async {
    orderFetches++;
    return store[id]!;
  }

  @override
  Future<Order> cancel(String id, {String? reason}) async {
    final o = store[id]!;
    return store[id] = Order(
      id: id,
      number: o.number,
      status: OrderStatus.cancelled,
      fulfillment: o.fulfillment,
      paymentMethod: o.paymentMethod,
      items: o.items,
      itemCount: o.itemCount,
      subtotalPaise: o.subtotalPaise,
      deliveryFeePaise: o.deliveryFeePaise,
      totalPaise: o.totalPaise,
      placedAt: o.placedAt,
      customerPhone: o.customerPhone,
      address: o.address,
      slot: o.slot,
      attachments: o.attachments,
      returnRequest: o.returnRequest,
      history: [...o.history, StatusChange(status: OrderStatus.cancelled, at: DateTime(2026, 11, 23, 11))],
    );
  }

  @override
  Future<Payment> payment(String orderId) async => payments[orderId]!;

  @override
  Future<Payment> submitUtr(String orderId, String utr) async {
    final p = payments[orderId]!;
    return payments[orderId] = Payment(
      orderId: orderId,
      method: p.method,
      status: PaymentStatus.submitted,
      amountPaise: p.amountPaise,
      utr: utr,
      upiUri: p.upiUri,
    );
  }

  @override
  Future<List<Address>> addresses() async => addressList;

  @override
  Future<Address> addAddress(Map<String, dynamic> address) async {
    final saved = Address(
      id: 'a${addressList.length + 1}',
      line1: address['line1'] as String,
      city: address['city'] as String,
      pincode: address['pincode'] as String,
      isDefault: addressList.isEmpty,
    );
    addressList.add(saved);
    return saved;
  }

  @override
  Future<void> deleteAddress(String id) async => addressList.removeWhere((a) => a.id == id);

  // ---- Slots and returns ----
  List<DeliverySlot> slotList = [];
  final List<Map<String, Object?>> returnRequests = [];
  final List<(String, ReturnStatus, String?)> returnStatusCalls = [];

  @override
  Future<List<DeliverySlot>> slots() async => slotList;

  @override
  Future<ReturnRequest> requestReturn(
    String orderId, {
    required ReturnKind type,
    required String reason,
    required List<Map<String, dynamic>> items,
    List<String> photoIds = const [],
  }) async {
    returnRequests.add({'orderId': orderId, 'type': type, 'reason': reason, 'items': items, 'photoIds': photoIds});
    final request = ReturnRequest(
      id: 'r1',
      orderId: orderId,
      orderNumber: store[orderId]!.number,
      type: type,
      status: ReturnStatus.requested,
      reason: reason,
      items: [for (final i in items) ReturnLine(variantId: i['variantId'] as String, productName: 'Basmati Rice', variantLabel: '1 kg', qty: i['qty'] as int)],
      createdAt: DateTime(2026, 11, 24),
    );
    _withReturn(orderId, request);
    return request;
  }

  void _withReturn(String orderId, ReturnRequest? request) {
    final o = store[orderId]!;
    store[orderId] = Order(
      id: o.id,
      number: o.number,
      status: o.status,
      fulfillment: o.fulfillment,
      paymentMethod: o.paymentMethod,
      items: o.items,
      itemCount: o.itemCount,
      subtotalPaise: o.subtotalPaise,
      deliveryFeePaise: o.deliveryFeePaise,
      totalPaise: o.totalPaise,
      placedAt: o.placedAt,
      customerPhone: o.customerPhone,
      address: o.address,
      history: o.history,
      nextStatuses: o.nextStatuses,
      slot: o.slot,
      attachments: o.attachments,
      needsPricing: o.needsPricing,
      returnRequest: request,
    );
  }

  @override
  Future<List<ReturnRequest>> returns({ReturnStatus? status}) async => [
    for (final o in store.values)
      if (o.returnRequest case final r? when status == null || r.status == status) r,
  ];

  @override
  Future<ReturnRequest> setReturnStatus(String id, ReturnStatus status, {String? note}) async {
    returnStatusCalls.add((id, status, note));
    final order = store.values.firstWhere((o) => o.returnRequest?.id == id);
    final r = order.returnRequest!;
    final updated = ReturnRequest(
      id: r.id,
      orderId: r.orderId,
      orderNumber: r.orderNumber,
      type: r.type,
      status: status,
      reason: r.reason,
      items: r.items,
      createdAt: r.createdAt,
      shopNote: note ?? r.shopNote,
    );
    _withReturn(order.id, updated);
    return updated;
  }

  // ---- Admin ----
  final List<(String, OrderStatus, String?)> statusCalls = [];
  final List<String> markedPaid = [];

  @override
  Future<PageResult<Order>> orders({required String group, String? cursor}) async => PageResult(
    store.values.where((o) => switch (group) {
      'new' => o.status == OrderStatus.placed,
      'done' => o.status.isDone,
      _ => !o.status.isDone && o.status != OrderStatus.placed,
    }).toList(),
    null,
  );

  final List<int?> amounts = [];

  @override
  Future<Order> setStatus(String id, OrderStatus status, {String? reason, int? amountPaise}) async {
    statusCalls.add((id, status, reason));
    amounts.add(amountPaise);
    final o = store[id]!;
    final next = switch (status) {
      OrderStatus.confirmed => const [OrderStatus.packed, OrderStatus.rejected],
      _ => const <OrderStatus>[],
    };
    return store[id] = Order(
      id: id,
      number: o.number,
      status: status,
      fulfillment: o.fulfillment,
      paymentMethod: o.paymentMethod,
      items: o.items,
      itemCount: o.itemCount,
      subtotalPaise: amountPaise ?? o.subtotalPaise,
      deliveryFeePaise: o.deliveryFeePaise,
      totalPaise: amountPaise ?? o.totalPaise,
      needsPricing: amountPaise == null && o.needsPricing,
      placedAt: o.placedAt,
      customerPhone: o.customerPhone,
      address: o.address,
      slot: o.slot,
      attachments: o.attachments,
      returnRequest: o.returnRequest,
      cancelReason: reason,
      history: [...o.history, StatusChange(status: status, at: DateTime.now())],
      nextStatuses: next,
    );
  }

  @override
  Future<Payment> markPaid(String orderId) async {
    markedPaid.add(orderId);
    final p = payments[orderId]!;
    return payments[orderId] = Payment(orderId: orderId, method: p.method, status: PaymentStatus.paid, amountPaise: p.amountPaise);
  }

  /// Seeds a placed order. The server tells each viewer what they may do next.
  void seed({bool asCustomer = false}) {
    const request = PlaceOrderRequest(
      items: [],
      fulfillment: Fulfillment.delivery,
      paymentMethod: PaymentMethod.cod,
      idempotencyKey: 'k',
      expectedTotalPaise: 24000,
    );
    final o = _order('o1', 7, request, 24000);
    store['o1'] = Order(
      id: o.id,
      number: o.number,
      status: o.status,
      fulfillment: o.fulfillment,
      paymentMethod: o.paymentMethod,
      items: o.items,
      itemCount: o.itemCount,
      subtotalPaise: o.subtotalPaise,
      deliveryFeePaise: o.deliveryFeePaise,
      totalPaise: o.totalPaise,
      placedAt: o.placedAt,
      customerPhone: o.customerPhone,
      address: o.address,
      slot: o.slot,
      attachments: o.attachments,
      returnRequest: o.returnRequest,
      customerName: 'Meena',
      history: o.history,
      nextStatuses: asCustomer ? const [OrderStatus.cancelled] : const [OrderStatus.confirmed, OrderStatus.rejected],
    );
    payments['o1'] = const Payment(orderId: 'o1', method: PaymentMethod.cod, status: PaymentStatus.pending, amountPaise: 24000);
  }
}

AuthSession sessionFor(UserRole role) => AuthSession(
  accessToken: 'a',
  accessTokenExpiresAt: DateTime.utc(2030),
  refreshToken: 'r',
  refreshTokenExpiresAt: DateTime.utc(2030),
  user: AppUser(id: 'u', phone: '+919876543210', role: role, name: role == UserRole.owner ? 'Ramesh' : null),
);

class FakeChannel implements RealtimeChannel {
  final _events = StreamController<RealtimeEvent>.broadcast();
  final _connection = StreamController<bool>.broadcast();
  Future<String?> Function()? token;
  bool closed = false;
  final List<(double, double)> sentLocations = [];

  @override
  Future<int> sendLocation({required double lat, required double lng, double? accuracy}) async {
    sentLocations.add((lat, lng));
    return 1;
  }

  void emitData(String type, Map<String, Object?> data) =>
      _events.add(RealtimeEvent(type: type, orderId: data['orderId']! as String, status: data['status'] as String?, data: data));

  void connect() => _connection.add(true);
  void emit(String type, String orderId, [String? status]) =>
      _events.add(RealtimeEvent(type: type, orderId: orderId, status: status));

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  @override
  Stream<bool> get connection => _connection.stream;

  @override
  void close() => closed = true;
}

class FakePush implements PushService {
  FakePush({this.launchRoute});

  String? launchRoute;
  int permissionRequests = 0;
  final _taps = StreamController<String>.broadcast();

  void tap(String route) => _taps.add(route);

  @override
  Future<String?> token() async => 'fcm-token-1';

  @override
  Stream<String> get tokenRefresh => const Stream.empty();

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> takeLaunchRoute() async {
    final route = launchRoute;
    launchRoute = null;
    return route;
  }

  @override
  Future<void> requestPermission() async => permissionRequests++;
}

class Harness {
  Harness(this.orders, this.launched, this.prefs);
  final FakeOrders orders;
  final List<Uri> launched;
  final SharedPreferences prefs;
}

Future<Harness> pumpShop(
  WidgetTester tester, {
  AuthSession? session,
  FakeAuthApi? auth,
  Map<String, Object> prefsValues = const {},
  FakeChannel? channel,
  PushService? push,
  void Function(FakeOrders orders)? setup,
  List<Override> extraOverrides = const [],
  Map<String, bool> features = const {},
}) async {
  usePhoneScreen(tester);
  quoteDebounce = Duration.zero;
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  final orders = FakeOrders();
  setup?.call(orders);
  final launched = <Uri>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clientConfigProvider.overrideWithValue(testClient),
        envConfigProvider.overrideWithValue(testEnv),
        sharedPreferencesProvider.overrideWithValue(prefs),
        shopSettingsRepositoryProvider.overrideWithValue(FakeRepository(ShopSettings.fromJson(shopConfigJson(features: features)))),
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        ordersRepositoryProvider.overrideWithValue(orders),
        adminOrdersRepositoryProvider.overrideWithValue(orders),
        sessionStoreProvider.overrideWithValue(InMemorySessionStore(session)),
        authApiProvider.overrideWithValue(auth ?? FakeAuthApi()),
        externalLauncherProvider.overrideWithValue((uri) async {
          launched.add(uri);
          return true;
        }),
        if (channel != null)
          realtimeConnectorProvider.overrideWithValue((token) {
            channel.token = token;
            return channel;
          }),
        if (push != null) pushServiceProvider.overrideWithValue(push),
        ...extraOverrides,
      ],
      child: const QcApp(),
    ),
  );
  await tester.pumpAndSettle();
  return Harness(orders, launched, prefs);
}

Future<void> addRiceFromHome(WidgetTester tester, {String variant = '1 kg'}) async {
  await tester.tap(find.byKey(const ValueKey('add-p1')));
  await tester.pumpAndSettle();
  // Two variants: a picker opens.
  final row = find.ancestor(of: find.text(variant).last, matching: find.byType(Row)).first;
  await tester.tap(find.descendant(of: row, matching: find.byKey(const ValueKey('add-p1'))));
  await tester.pumpAndSettle();
  await tester.tapAt(const Offset(10, 10)); // close the sheet
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('add from the product card, cart bar shows count and total, cart survives restart', (tester) async {
    final h = await pumpShop(tester);
    await addRiceFromHome(tester);

    expect(find.byKey(const Key('cartBar')), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
    expect(find.text('₹120'), findsWidgets);
    expect(h.prefs.getString('cart_v1'), contains('p1-v1'));

    // Card now shows the total qty for the product.
    expect(find.byKey(const ValueKey('qty-p1')), findsOneWidget);
  });

  testWidgets('cart shows server bill; short stock offers a fix', (tester) async {
    final h = await pumpShop(tester, prefsValues: {
      'cart_v1':
          '[{"variantId":"p1-v1","productId":"p1","name":"Basmati Rice","label":"1 kg","pricePaise":12000,"qty":3}]',
    });
    h.orders.stockLimit['p1-v1'] = 2;
    await tester.tap(find.byKey(const Key('cartBar')));
    await tester.pumpAndSettle();

    expect(find.text('Only 2 left'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('loginToOrderButton'))).onPressed, isNotNull);

    await tester.tap(find.text('Change to 2'));
    await tester.pumpAndSettle();
    expect(find.text('Only 2 left'), findsNothing);
    expect(find.byKey(const Key('billTotal')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('billTotal'))).data, '₹260'); // 2 × 120 + 20 delivery
    expect(find.text('Add ₹260 more for free delivery'), findsOneWidget);
  });

  testWidgets('guest logs in from the cart and lands on checkout', (tester) async {
    await pumpShop(tester, prefsValues: {
      'cart_v1': '[{"variantId":"p1-v1","productId":"p1","name":"Basmati Rice","label":"1 kg","pricePaise":12000,"qty":1}]',
    });
    await tester.tap(find.byKey(const Key('cartBar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('loginToOrderButton')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('phoneField')), '9876543210');
    await tester.pump();
    await tester.tap(find.byKey(const Key('sendOtpButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('verifyButton'))); // dev code is prefilled
    await tester.pumpAndSettle();

    expect(find.text('Checkout'), findsOneWidget);
  });

  testWidgets('checkout: add address, pay by UPI, order placed, cart cleared, UPI app opened, UTR sent', (tester) async {
    final h = await pumpShop(
      tester,
      session: sessionFor(UserRole.customer),
      prefsValues: {
        'cart_v1': '[{"variantId":"p1-v1","productId":"p1","name":"Basmati Rice","label":"1 kg","pricePaise":12000,"qty":1}]',
      },
    );
    await tester.tap(find.byKey(const Key('cartBar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('proceedButton')));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(find.byKey(const Key('placeOrderButton'))).onPressed, isNull); // no address yet
    await tester.tap(find.byKey(const Key('addAddressButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('addressLine1')), '12 Station Road');
    await tester.enterText(find.byKey(const Key('addressCity')), 'Bhavnagar');
    await tester.enterText(find.byKey(const Key('addressPincode')), '364001');
    await tester.tap(find.byKey(const Key('saveAddressButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('method-UPI')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('noteField')), 'Ring the bell');
    await tester.tap(find.byKey(const Key('placeOrderButton')));
    await tester.pumpAndSettle();

    final request = h.orders.placed.single;
    expect(request.paymentMethod, PaymentMethod.upi);
    expect(request.addressId, 'a1');
    expect(request.note, 'Ring the bell');
    expect(request.expectedTotalPaise, 14000);
    expect(find.text('Order placed!'), findsOneWidget);
    expect(h.prefs.getString('cart_v1'), isNull);

    await tester.scrollUntilVisible(find.byKey(const Key('payUpiButton')), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('payUpiButton')));
    await tester.pumpAndSettle();
    expect(h.launched.single.scheme, 'upi');

    await tester.scrollUntilVisible(find.byKey(const Key('utrField')), 200, scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byKey(const Key('utrField')), '412345678901');
    await tester.tap(find.byKey(const Key('submitUtrButton')));
    await tester.pumpAndSettle();
    expect(find.text('Payment being verified'), findsOneWidget);

    // Back goes to the shop, not to an empty checkout.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Sharma Kirana'), findsOneWidget);
  });

  testWidgets('a failed attempt is retried with the same idempotency key', (tester) async {
    final h = await pumpShop(
      tester,
      session: sessionFor(UserRole.customer),
      prefsValues: {
        'cart_v1': '[{"variantId":"p1-v1","productId":"p1","name":"Basmati Rice","label":"1 kg","pricePaise":12000,"qty":1}]',
      },
    );
    h.orders.addressList.add(const Address(id: 'a1', line1: 'x', city: 'y', pincode: '364001', isDefault: true));
    h.orders.failNextPlace = const ApiException(ApiException.networkError, 'timeout');
    await tester.tap(find.byKey(const Key('cartBar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('proceedButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('placeOrderButton')));
    await tester.pumpAndSettle();
    expect(find.text('No internet connection. Check your network and try again.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('placeOrderButton')));
    await tester.pumpAndSettle();

    expect(h.orders.placed, hasLength(2));
    expect(h.orders.placed[0].idempotencyKey, h.orders.placed[1].idempotencyKey);
    expect(h.orders.placed[1].addressId, 'a1'); // the pre-selected default address is sent
    expect(find.text('Order placed!'), findsOneWidget);
  });

  testWidgets('customer cancels a placed order from My orders', (tester) async {
    final h = await pumpShop(tester, session: sessionFor(UserRole.customer));
    h.orders.seed(asCustomer: true);
    await tester.tap(find.byKey(const Key('myOrdersButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Order #7'));
    await tester.pumpAndSettle();

    final detail = find.descendant(of: find.byType(OrderDetailScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byKey(const Key('cancelOrderButton')), 200, scrollable: detail);
    await tester.tap(find.byKey(const Key('cancelOrderButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmCancelButton')));
    await tester.pumpAndSettle();

    expect(h.orders.store['o1']!.status, OrderStatus.cancelled);
    await tester.scrollUntilVisible(find.text('Cancelled'), -200, scrollable: detail);
    expect(find.text('Cancelled'), findsWidgets);
    expect(find.byKey(const Key('cancelOrderButton')), findsNothing);
  });

  testWidgets('owner accepts, rejects with a reason, and marks paid', (tester) async {
    final h = await pumpShop(tester, session: sessionFor(UserRole.owner));
    h.orders.seed();
    await tester.tap(find.byKey(const Key('adminOrdersTile')));
    await tester.pumpAndSettle();
    expect(find.text('New (1)'), findsOneWidget);
    expect(find.textContaining('Meena'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('admin-order-o1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('markPaidButton')));
    await tester.pumpAndSettle();
    expect(h.orders.markedPaid, ['o1']);

    expect(find.text('Accept order'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nextStatusButton')));
    await tester.pumpAndSettle();
    expect(h.orders.statusCalls.last, ('o1', OrderStatus.confirmed, null));
    expect(find.text('Mark packed'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rejectButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmRejectButton'))); // empty reason: stays open
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rejectReasonField')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('rejectReasonField')), 'Out of rice');
    await tester.tap(find.byKey(const Key('confirmRejectButton')));
    await tester.pumpAndSettle();
    expect(h.orders.statusCalls.last, ('o1', OrderStatus.rejected, 'Out of rice'));
  });

  group('live updates', () {
    testWidgets("the customer's open order changes as soon as the shop accepts it", (tester) async {
      final channel = FakeChannel();
      final h = await pumpShop(tester, session: sessionFor(UserRole.customer), channel: channel);
      h.orders.seed(asCustomer: true);
      channel.connect();
      await tester.tap(find.byKey(const Key('myOrdersButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Order #7'));
      await tester.pumpAndSettle();
      expect(await channel.token!(), 'a');
      final cancel = find.byKey(const Key('cancelOrderButton'), skipOffstage: false);
      expect(cancel, findsOneWidget);
      final fetchesBefore = h.orders.orderFetches;

      await h.orders.setStatus('o1', OrderStatus.confirmed);
      channel.emit('order.updated', 'o1', 'CONFIRMED');
      await tester.pumpAndSettle();

      expect(h.orders.orderFetches, greaterThan(fetchesBefore));
      expect(cancel, findsNothing); // accepted orders can no longer be cancelled by the customer
    });

    testWidgets("a new order appears in the owner's inbox without refreshing", (tester) async {
      final channel = FakeChannel();
      final h = await pumpShop(tester, session: sessionFor(UserRole.owner), channel: channel);
      await tester.tap(find.byKey(const Key('adminOrdersTile')));
      await tester.pumpAndSettle();
      expect(find.text('New (1)'), findsNothing);

      h.orders.seed();
      channel.emit('order.updated', 'o1', 'PLACED');
      await tester.pumpAndSettle();

      expect(find.text('New (1)'), findsOneWidget);
    });

    testWidgets('the channel closes on logout', (tester) async {
      final channel = FakeChannel();
      await pumpShop(tester, session: sessionFor(UserRole.customer), channel: channel);
      await tester.tap(find.byKey(const Key('accountButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('logoutButton')));
      await tester.pumpAndSettle();
      expect(channel.closed, isTrue);
    });
  });

  group('push notifications', () {
    testWidgets('registers the phone after login, opens tapped orders, and unregisters on logout', (tester) async {
      final auth = FakeAuthApi();
      final push = FakePush();
      await pumpShop(tester, session: sessionFor(UserRole.customer), auth: auth, push: push, setup: (o) => o.seed(asCustomer: true));
      expect(push.permissionRequests, 1);
      expect(auth.devices, [('fcm-token-1', 'en')]);

      push.tap('/admin/orders/o1'); // not a customer page: ignored
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailScreen), findsNothing);

      push.tap('/orders/o1');
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailScreen), findsOneWidget);
      expect(find.text('Order #7'), findsWidgets);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('accountButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('logoutButton')));
      await tester.pumpAndSettle();
      expect(auth.lastLogoutDeviceToken, 'fcm-token-1');
    });

    testWidgets('a notification that launched the app opens its order', (tester) async {
      await pumpShop(
        tester,
        session: sessionFor(UserRole.owner),
        push: FakePush(launchRoute: '/admin/orders/o1'),
        setup: (o) => o.seed(),
      );
      expect(find.text('Accept order'), findsOneWidget);
    });

    testWidgets('guests get no registration', (tester) async {
      final auth = FakeAuthApi();
      final push = FakePush();
      await pumpShop(tester, auth: auth, push: push);
      expect(auth.devices, isEmpty);
      expect(push.permissionRequests, 0);
    });
  });
}
