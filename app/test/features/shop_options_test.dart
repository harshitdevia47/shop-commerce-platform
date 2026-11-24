import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qc_app/core/payments/online_checkout.dart';
import 'package:qc_app/features/admin_catalog/presentation/photo_picker.dart';
import 'package:qc_app/features/auth/domain/auth_models.dart';
import 'package:qc_app/features/orders/domain/order_models.dart';
import 'package:qc_app/features/private_media/data/private_media_repository.dart';
import 'package:qc_app/features/private_media/presentation/private_media.dart';

import 'ordering_test.dart' show addRiceFromHome, pumpShop, sessionFor;

/// 1x1 transparent PNG.
final _png = Uint8List.fromList(const [
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, //
  73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

class FakePrivateMedia implements PrivateMediaRepository {
  final List<(String, AttachmentKind)> uploads = [];

  @override
  Future<Attachment> upload(String filePath, AttachmentKind kind) async {
    uploads.add((filePath, kind));
    return Attachment(id: 'm${uploads.length}', kind: kind);
  }

  @override
  Future<Uint8List> bytes(String id, {bool thumb = true}) async => _png;
}

class FakeCheckout implements OnlineCheckout {
  FakeCheckout({this.succeed = true});

  bool succeed;
  final List<(String, String, int)> opened = [];

  @override
  Future<OnlinePaymentResult?> pay({
    required String keyId,
    required String orderId,
    required int amountPaise,
    required String shopName,
    String? phone,
  }) async {
    opened.add((keyId, orderId, amountPaise));
    return succeed ? OnlinePaymentResult(orderId: orderId, paymentId: 'pay_1', signature: 'sig') : null;
  }
}

void main() {
  late FakePrivateMedia media;

  List<Override> overrides() => [
    privateMediaRepositoryProvider.overrideWithValue(media),
    photoSourceProvider.overrideWithValue(({required camera}) async => '/tmp/list.jpg'),
  ];

  setUp(() => media = FakePrivateMedia());

  Future<void> pickPhoto(WidgetTester tester, String kind) async {
    await tester.tap(find.byKey(ValueKey('add-$kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
  }

  testWidgets('checkout asks for a delivery time; full windows cannot be picked', (tester) async {
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day, 23); // late today: always "Today"
    final h = await pumpShop(
      tester,
      session: sessionFor(UserRole.customer),
      features: {'deliverySlots': true},
      setup: (o) {
        o.addressList.add(const Address(id: 'a1', line1: 'Station Rd', city: 'Bhavnagar', pincode: '364001', isDefault: true));
        o.slotList = [
          DeliverySlot(start: first, end: first.add(const Duration(minutes: 59)), available: false),
          DeliverySlot(start: first.add(const Duration(days: 1)), end: first.add(const Duration(days: 1, minutes: 59)), available: true),
        ];
      },
      extraOverrides: overrides(),
    );
    await addRiceFromHome(tester);
    await tester.tap(find.byKey(const Key('cartBar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('proceedButton')));
    await tester.pumpAndSettle();

    expect(find.text('Delivery time'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);
    final place = find.byKey(const Key('placeOrderButton'));
    expect(tester.widget<FilledButton>(place).onPressed, isNull);

    final fullChip = find.byKey(ValueKey('slot-${first.toUtc().toIso8601String()}'));
    expect(tester.widget<ChoiceChip>(fullChip).onSelected, isNull);
    final open = first.add(const Duration(days: 1));
    await tester.tap(find.byKey(ValueKey('slot-${open.toUtc().toIso8601String()}')));
    await tester.pumpAndSettle();
    await tester.tap(place);
    await tester.pumpAndSettle();

    expect(h.orders.placed.single.slotStart, open);
    expect(find.byKey(const Key('orderSlot')), findsOneWidget);
  });

  testWidgets('customer orders with a photo of a list; the order waits for the shop to price it', (tester) async {
    final h = await pumpShop(
      tester,
      session: sessionFor(UserRole.customer),
      features: {'handwrittenListUpload': true},
      setup: (o) => o.addressList.add(const Address(id: 'a1', line1: 'Station Rd', city: 'Bhavnagar', pincode: '364001', isDefault: true)),
      extraOverrides: overrides(),
    );
    await tester.tap(find.byKey(const Key('listOrderButton')));
    await tester.pumpAndSettle();
    expect(find.text('Order with a list photo'), findsOneWidget);
    final send = find.byKey(const Key('placeOrderButton'));
    expect(tester.widget<FilledButton>(send).onPressed, isNull);

    await pickPhoto(tester, 'HANDWRITTEN_LIST');
    expect(media.uploads, [('/tmp/list.jpg', AttachmentKind.handwrittenList)]);
    await tester.tap(send);
    await tester.pumpAndSettle();

    final request = h.orders.placed.single;
    expect(request.items, isEmpty);
    expect(request.attachmentIds, ['m1']);
    expect(request.expectedTotalPaise, isNull);
    expect(find.byKey(const Key('awaitingPricing')), findsOneWidget);
    expect(find.text('Your photos'), findsOneWidget);
    expect(find.byKey(const Key('utrField')), findsNothing);
  });

  testWidgets('the shop sees the list photo and accepts it with an amount', (tester) async {
    final h = await pumpShop(
      tester,
      session: sessionFor(UserRole.owner),
      features: {'handwrittenListUpload': true},
      extraOverrides: overrides(),
    );
    await h.orders.place(
      const PlaceOrderRequest(
        items: [],
        fulfillment: Fulfillment.pickup,
        paymentMethod: PaymentMethod.cod,
        idempotencyKey: 'k',
        attachmentIds: ['m9'],
      ),
    );
    // As the server tells the shop: a placed order can be accepted or rejected.
    final o = h.orders.store['o1']!;
    h.orders.store['o1'] = Order(
      id: o.id,
      number: o.number,
      status: o.status,
      fulfillment: o.fulfillment,
      paymentMethod: o.paymentMethod,
      items: o.items,
      itemCount: o.itemCount,
      subtotalPaise: 0,
      deliveryFeePaise: 0,
      totalPaise: 0,
      placedAt: o.placedAt,
      customerPhone: o.customerPhone,
      attachments: o.attachments,
      needsPricing: true,
      nextStatuses: const [OrderStatus.confirmed, OrderStatus.rejected],
    );
    await tester.tap(find.byKey(const Key('adminOrdersTile')));
    await tester.pumpAndSettle();
    expect(find.textContaining('List order'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('admin-order-o1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('private-photo-m9')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nextStatusButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('listAmountField')), '456.50');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmAmountButton')));
    await tester.pumpAndSettle();
    expect(h.orders.amounts, [45650]);
  });

  testWidgets('after delivery the customer asks for a return with chosen items', (tester) async {
    final h = await pumpShop(
      tester,
      session: sessionFor(UserRole.customer),
      features: {'returns': true},
      setup: (o) => o.seed(asCustomer: true),
      extraOverrides: overrides(),
    );
    for (final s in [OrderStatus.confirmed, OrderStatus.packed, OrderStatus.outForDelivery, OrderStatus.delivered]) {
      await h.orders.setStatus('o1', s);
    }
    await tester.tap(find.byKey(const Key('myOrdersButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Order #7'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('requestReturnButton')), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.byKey(const Key('requestReturnButton')));
    await tester.pumpAndSettle();

    final send = find.byKey(const Key('sendReturnButton'));
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('return-add-p1-v1')));
    await tester.enterText(find.byKey(const Key('returnReasonField')), 'Bag was torn');
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(h.orders.returnRequests.single, {
      'orderId': 'o1',
      'type': ReturnKind.returnItems,
      'reason': 'Bag was torn',
      'items': [
        {'variantId': 'p1-v1', 'qty': 1},
      ],
      'photoIds': <String>[],
    });
    expect(find.byKey(const Key('returnRequestCard')), findsOneWidget);
    expect(find.byKey(const Key('requestReturnButton')), findsNothing);
  });

  testWidgets('the shop answers a return from the order screen', (tester) async {
    final h = await pumpShop(
      tester,
      session: sessionFor(UserRole.owner),
      features: {'returns': true},
      setup: (o) => o.seed(),
      extraOverrides: overrides(),
    );
    await h.orders.requestReturn('o1', type: ReturnKind.exchange, reason: 'Wrong size', items: [
      {'variantId': 'p1-v1', 'qty': 1},
    ]);
    await tester.tap(find.byKey(const Key('adminReturnsTile')));
    await tester.pumpAndSettle();
    expect(find.text('Order #7 · Exchange'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('return-r1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('declineReturnButton')));
    await tester.pumpAndSettle();
    final confirm = find.byKey(const Key('confirmNoteButton'));
    expect(tester.widget<TextButton>(confirm).onPressed, isNull); // declining needs a message
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('approveReturnButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('returnNoteField')), 'Bring it tomorrow');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmNoteButton')));
    await tester.pumpAndSettle();
    expect(h.orders.returnStatusCalls, [('r1', ReturnStatus.approved, 'Bring it tomorrow')]);
    expect(find.byKey(const Key('completeReturnButton')), findsOneWidget);
  });

  testWidgets('paying online opens the payment sheet after placing; a cancelled sheet can be retried', (tester) async {
    final checkout = FakeCheckout(succeed: false);
    final h = await pumpShop(
      tester,
      session: sessionFor(UserRole.customer),
      razorpay: true,
      prefsValues: {
        'cart_v1': '[{"variantId":"p1-v1","productId":"p1","name":"Basmati Rice","label":"1 kg","pricePaise":12000,"qty":1}]',
      },
      setup: (o) => o.addressList.add(const Address(id: 'a1', line1: 'Station Rd', city: 'Bhavnagar', pincode: '364001', isDefault: true)),
      extraOverrides: [...overrides(), onlineCheckoutProvider.overrideWithValue(checkout)],
    );
    await tester.tap(find.byKey(const Key('cartBar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('proceedButton')));
    await tester.pumpAndSettle();
    expect(find.text('Pay online (UPI, card, netbanking)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('method-RAZORPAY')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('placeOrderButton')));
    await tester.pumpAndSettle();

    expect(h.orders.placed.single.paymentMethod, PaymentMethod.razorpay);
    expect(checkout.opened, [('rzp_test_x', 'order_o1', h.orders.store['o1']!.totalPaise)]);
    expect(find.text('Payment was not completed. You can try again.'), findsOneWidget);
    expect(h.orders.onlineConfirmations, isEmpty);

    checkout.succeed = true;
    await tester.tap(find.byKey(const Key('payOnlineButton')));
    await tester.pumpAndSettle();
    expect(h.orders.onlineConfirmations, [('order_o1', 'pay_1', 'sig')]);
    expect(find.byKey(const Key('payOnlineButton')), findsNothing);
  });
}
