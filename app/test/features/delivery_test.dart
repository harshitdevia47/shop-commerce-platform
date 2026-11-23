import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' show LocationServiceDisabledException;
import 'package:material_ui/material_ui.dart';
import 'package:qc_app/core/network/api_exception.dart';
import 'package:qc_app/features/auth/domain/auth_models.dart';
import 'package:qc_app/features/delivery/data/delivery_repository.dart';
import 'package:qc_app/features/delivery/domain/delivery_models.dart';
import 'package:qc_app/features/delivery/presentation/delivery_providers.dart';
import 'package:qc_app/features/orders/domain/order_models.dart';
import 'package:qc_app/features/rider_deliveries/presentation/location_sharing.dart';

import 'ordering_test.dart' show FakeChannel, FakeOrders, pumpShop, sessionFor;

/// In-memory delivery service for every role.
class FakeDeliveries implements CustomerDeliveryRepository, RiderRepository, TeamRepository {
  final riderList = [
    const Rider(id: 'r1', name: 'Raju', phone: '+919811100001', activeDeliveries: 0),
    const Rider(id: 'r2', name: 'Vikas', phone: '+919811100002', activeDeliveries: 2),
  ];
  final Map<String, AdminDelivery> byOrder = {};
  CustomerDelivery? customerView;
  final Map<String, RiderDelivery> jobs = {};
  final List<(String, String)> assignCalls = [];
  final List<String> otpTries = [];
  final List<TeamMember> team = [const TeamMember(id: 'o', phone: '+919876543210', role: 'OWNER', name: 'Ramesh')];

  // Customer
  @override
  Future<CustomerDelivery?> forOrder(String orderId) async =>
      customerView?.orderId == orderId ? customerView : null;

  // Shop (through _AdminView)
  Future<List<Rider>> riders() async => riderList;

  Future<AdminDelivery> assign(String orderId, String riderId) async {
    assignCalls.add((orderId, riderId));
    final rider = riderList.firstWhere((r) => r.id == riderId);
    return byOrder[orderId] = AdminDelivery(
      id: 'd-$orderId',
      orderId: orderId,
      status: DeliveryStatus.assigned,
      rider: Person(id: rider.id, name: rider.name, phone: rider.phone),
    );
  }

  Future<AdminDelivery?> adminForOrder(String orderId) async => byOrder[orderId];

  // Rider
  @override
  Future<List<RiderDelivery>> deliveries({required bool active}) async =>
      jobs.values.where((j) => j.status.isActive == active).toList();

  @override
  Future<RiderDelivery> delivery(String id) async => jobs[id]!;

  RiderDelivery _with(RiderDelivery j, DeliveryStatus status) => jobs[j.id] = RiderDelivery(
    id: j.id,
    orderId: j.orderId,
    orderNumber: j.orderNumber,
    status: status,
    customer: j.customer,
    address: j.address,
    itemCount: j.itemCount,
    totalPaise: j.totalPaise,
    codPaise: j.codPaise,
    otpAttemptsLeft: j.otpAttemptsLeft,
    note: j.note,
  );

  @override
  Future<RiderDelivery> pickUp(String id) async => _with(jobs[id]!, DeliveryStatus.pickedUp);

  @override
  Future<RiderDelivery> deliver(String id, String otp) async {
    otpTries.add(otp);
    if (otp != '4821') throw const ApiException('DELIVERY_OTP_INVALID', 'wrong', statusCode: 400, details: {'attemptsLeft': 4});
    return _with(jobs[id]!, DeliveryStatus.delivered);
  }

  // Team
  @override
  Future<List<TeamMember>> members() async => team;

  @override
  Future<TeamMember> add({required String phone, required String role, String? name}) async {
    final member = TeamMember(id: 'm${team.length}', phone: phone, role: role, name: name);
    team.add(member);
    return member;
  }

  @override
  Future<void> remove(String id) async => team.removeWhere((m) => m.id == id);

  void job({DeliveryStatus status = DeliveryStatus.assigned, int codPaise = 34000}) => jobs['d1'] = RiderDelivery(
    id: 'd1',
    orderId: 'o1',
    orderNumber: 7,
    status: status,
    customer: const Person(name: 'Meena', phone: '+919800000001'),
    address: const Address(id: 'a', line1: '12 Station Rd', landmark: 'Temple', city: 'Bhavnagar', pincode: '364001', lat: 21.77, lng: 72.15),
    note: 'Ring twice',
    itemCount: 3,
    totalPaise: 34000,
    codPaise: codPaise,
    otpAttemptsLeft: 5,
  );
}

class _AdminView implements AdminDeliveryRepository {
  _AdminView(this.fake);
  final FakeDeliveries fake;
  @override
  Future<List<Rider>> riders() => fake.riders();
  @override
  Future<AdminDelivery> assign(String orderId, String riderId) => fake.assign(orderId, riderId);
  @override
  Future<AdminDelivery?> forOrder(String orderId) => fake.adminForOrder(orderId);
}

class FakeLocation implements LocationSource {
  LocationAccess access = LocationAccess.granted;
  final fixes = StreamController<GeoFix>.broadcast();
  int watching = 0;

  @override
  Future<LocationAccess> ensureAccess() async => access;

  @override
  Stream<GeoFix> watch({required String notificationTitle, required String notificationText}) {
    watching++;
    return fixes.stream;
  }
}

Future<void> confirmSeeded(FakeOrders orders) async {
  orders.addressList.add(
    const Address(id: 'a1', line1: '12 Station Rd', city: 'Bhavnagar', pincode: '364001', isDefault: true, lat: 21.77, lng: 72.15),
  );
}

void main() {
  late FakeDeliveries deliveries;
  late FakeLocation location;

  List<Override> overrides() => [
    customerDeliveryRepositoryProvider.overrideWithValue(deliveries),
    adminDeliveryRepositoryProvider.overrideWithValue(_AdminView(deliveries)),
    riderRepositoryProvider.overrideWithValue(deliveries),
    teamRepositoryProvider.overrideWithValue(deliveries),
    locationSourceProvider.overrideWithValue(location),
  ];

  setUp(() {
    deliveries = FakeDeliveries();
    location = FakeLocation();
  });

  testWidgets('owner assigns a rider to an accepted delivery order', (tester) async {
    final h = await pumpShop(
      tester,
      session: sessionFor(UserRole.owner),
      setup: (o) {
        confirmSeeded(o);
        o.seed();
      },
      extraOverrides: overrides(),
    );
    await h.orders.setStatus('o1', OrderStatus.confirmed);
    await tester.tap(find.byKey(const Key('adminOrdersTile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In progress'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-order-o1')));
    await tester.pumpAndSettle();

    expect(find.text('No rider assigned yet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('assignRiderButton')));
    await tester.pumpAndSettle();
    expect(find.text('+919811100002 · 2 active'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rider-r1')));
    await tester.pumpAndSettle();

    expect(deliveries.assignCalls, [('o1', 'r1')]);
    expect(find.text('Raju'), findsOneWidget);
    expect(find.text('Rider assigned'), findsOneWidget);
    expect(find.text('Change rider'), findsOneWidget);
  });

  testWidgets('customer sees the rider, the door code, and how far the rider is', (tester) async {
    final channel = FakeChannel();
    final h = await pumpShop(
      tester,
      session: sessionFor(UserRole.customer),
      channel: channel,
      setup: (o) {
        confirmSeeded(o);
        o.seed(asCustomer: true);
      },
      extraOverrides: overrides(),
    );
    await h.orders.setStatus('o1', OrderStatus.confirmed);
    await h.orders.setStatus('o1', OrderStatus.packed);
    await h.orders.setStatus('o1', OrderStatus.outForDelivery);
    deliveries.customerView = const CustomerDelivery(
      orderId: 'o1',
      status: DeliveryStatus.pickedUp,
      rider: Person(name: 'Raju', phone: '+919811100001'),
      otp: '4821',
    );
    await tester.tap(find.byKey(const Key('myOrdersButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Order #7'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('deliveryOtp')), findsOneWidget);
    expect(find.text('4821'), findsOneWidget);
    expect(find.text('On the way to you'), findsOneWidget);

    // About 1.1 km straight line south of the address.
    channel.emitData('rider.location', {'orderId': 'o1', 'lat': 21.76, 'lng': 72.15, 'accuracy': 10, 'at': '2026-11-23T10:00:00Z'});
    await tester.pumpAndSettle();
    expect(find.text('1.1 km away · about 5 min'), findsOneWidget);
    expect(find.byKey(const Key('trackOnMapButton')), findsOneWidget);
  });

  testWidgets('rider picks up, gets the code wrong once, then delivers', (tester) async {
    deliveries.job();
    await pumpShop(tester, session: sessionFor(UserRole.rider), extraOverrides: overrides());
    expect(find.text('Active (1)'), findsOneWidget);
    expect(find.text('Collect ₹340 in cash'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('job-d1')));
    await tester.pumpAndSettle();
    expect(find.text('Note: Ring twice'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pickUpButton')));
    await tester.pumpAndSettle();
    expect(deliveries.jobs['d1']!.status, DeliveryStatus.pickedUp);

    Future<void> enter(String code) async {
      await tester.tap(find.byKey(const Key('deliverButton')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('deliveryOtpField')), code);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmOtpButton')));
      await tester.pumpAndSettle();
    }

    await enter('1111');
    expect(find.text('Wrong code. 4 attempts left.'), findsOneWidget);
    await enter('4821');
    expect(deliveries.otpTries, ['1111', '4821']);
    expect(deliveries.jobs['d1']!.status, DeliveryStatus.delivered);
    expect(find.byKey(const Key('deliverButton')), findsNothing);
  });

  testWidgets('a rider on the way shares location at most every 10 s; not before pickup', (tester) async {
    final channel = FakeChannel();
    deliveries.job();
    await pumpShop(tester, session: sessionFor(UserRole.rider), channel: channel, extraOverrides: overrides());
    expect(location.watching, 0);

    await tester.tap(find.byKey(const ValueKey('job-d1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pickUpButton')));
    await tester.pumpAndSettle();
    expect(location.watching, 1);
    expect(find.byKey(const Key('sharingBanner')), findsOneWidget);

    location.fixes
      ..add(const GeoFix(21.76, 72.15, 8))
      ..add(const GeoFix(21.761, 72.151, 8));
    await tester.pump();
    expect(channel.sentLocations, [(21.76, 72.15)]);
  });

  testWidgets('GPS switched off while on the way shows the fix-it banner', (tester) async {
    deliveries.job(status: DeliveryStatus.pickedUp);
    await pumpShop(tester, session: sessionFor(UserRole.rider), extraOverrides: overrides());
    expect(find.byKey(const Key('sharingBanner')), findsOneWidget);
    location.fixes.addError(const LocationServiceDisabledException());
    await tester.pumpAndSettle();
    expect(find.text('Turn on GPS so the customer can track you'), findsOneWidget);
  });

  testWidgets('without location permission the rider is told how to fix it', (tester) async {
    location.access = LocationAccess.denied;
    deliveries.job(status: DeliveryStatus.pickedUp);
    await pumpShop(tester, session: sessionFor(UserRole.rider), extraOverrides: overrides());
    expect(find.byKey(const Key('sharingProblemBanner')), findsOneWidget);
    expect(location.watching, 0);
  });

  testWidgets('owner adds a rider from Team; staff do not see Team', (tester) async {
    await pumpShop(tester, session: sessionFor(UserRole.owner), extraOverrides: overrides());
    await tester.tap(find.byKey(const Key('adminTeamTile')));
    await tester.pumpAndSettle();
    expect(find.text('No riders or staff yet.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('addMemberButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('memberPhoneField')), '9811100001');
    await tester.enterText(find.byKey(const Key('memberNameField')), 'Raju');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveMemberButton')));
    await tester.pumpAndSettle();

    expect(deliveries.team.last.phone, '+919811100001');
    expect(deliveries.team.last.role, 'RIDER');
    expect(find.text('+919811100001 · Rider'), findsOneWidget);
  });

  testWidgets('staff do not see the team tile', (tester) async {
    await pumpShop(tester, session: sessionFor(UserRole.staff), extraOverrides: overrides());
    expect(find.byKey(const Key('adminTeamTile')), findsNothing);
  });

  test('distance and ETA are rough but sane', () {
    final km = haversineKm(21.77, 72.15, 21.76, 72.15);
    expect(km, closeTo(1.11, 0.01));
    expect(etaMinutes(km), 5);
    expect(etaMinutes(0.01), 1);
    expect(mapsUri(lat: 21.7, lng: 72.1).toString(), 'https://www.google.com/maps/dir/?api=1&destination=21.7,72.1');
  });
}
