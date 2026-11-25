import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:platform_admin/api/admin_api.dart';
import 'package:platform_admin/api/models.dart';
import 'package:platform_admin/app.dart';
import 'package:platform_admin/auth/session.dart';
import 'package:platform_admin/config.dart';
import 'package:platform_admin/providers.dart';
import 'package:platform_admin/push/push.dart';
import 'dart:async';

const shopA = '01936a00-0000-7000-8000-00000000000a';
const shopB = '01936a00-0000-7000-8000-00000000000b';

Map<String, dynamic> shopJson(String id, String name) => {
  'id': id,
  'slug': name.toLowerCase().replaceAll(' ', '_'),
  'name': name,
  'businessType': 'grocery',
  'contact': {'phone': '+919876543210', 'address': 'Station Road'},
  'isActive': true,
};

const numbersJson = {
  'customers': {'total': 312, 'newSince': 40, 'activeSince': 120},
  'owner': {'name': 'Ramesh', 'phone': '+919876543210', 'hasLoggedIn': true},
  'products': 50,
  'month': {'orders': 87, 'salesPaise': 4500000, 'lastOrderAt': '2026-11-25T10:00:00.000Z'},
};

/// Stands in for the platform service.
class FakeAdminApi implements AdminApi {
  final calls = <(String, Map<String, Object?>)>[];
  ApiError? failNext;
  bool expired = false;
  Map<String, dynamic>? sub = {
    'feePaise': 99900,
    'dueDay': 5,
    'nextDueDate': '2026-12-05',
    'extendedUntil': null,
    'pausedAt': null,
    'logoDone': false,
    'playDone': false,
  };
  final payments = <Map<String, dynamic>>[];
  final seenForms = <String>{};

  Map<String, dynamic> detail() => {
    'shop': shopJson(shopA, 'Sharma Kirana'),
    'subscription': sub,
    'payments': payments,
    'status': sub == null ? 'not_set_up' : (sub!['pausedAt'] != null ? 'paused' : 'due'),
    'numbers': numbersJson,
    'today': '2026-11-26',
    'payTo': 'me@okaxis',
    'defaultFeeRupees': 999,
  };

  Future<void> _check() async {
    if (expired) throw const ApiError('ADMIN_AUTH_REQUIRED', 'Please log in again', statusCode: 401);
    final f = failNext;
    failNext = null;
    if (f != null) throw f;
  }

  @override
  Future<void> requestCode(String email) async => _check();

  @override
  Future<({String token, String email})> verifyCode(String email, String code) async {
    if (code != '123456') throw const ApiError('LOGIN_CODE_INVALID', 'That code is not right or has expired. Ask for a new one.', statusCode: 400);
    return (token: 'tok', email: email);
  }

  @override
  Future<void> logout(String token) async {}

  @override
  Future<void> registerDevice(String token, String fcmToken) async {}

  @override
  Future<Overview> overview(String token) async {
    await _check();
    return Overview.fromJson({
      'rows': [
        {'shop': shopJson(shopB, 'Late Shop'), 'subscription': {...sub ?? {}, 'feePaise': 50000, 'dueDay': 1, 'nextDueDate': '2026-11-01'}, 'status': 'overdue', 'numbers': numbersJson},
        {'shop': shopJson(shopA, 'Sharma Kirana'), 'subscription': sub, 'status': 'due', 'numbers': numbersJson},
      ],
      'counts': {'overdue': 1, 'paused': 0, 'due': 1, 'due_soon': 0, 'paid': 0, 'not_set_up': 0},
    });
  }

  @override
  Future<ShopDetail> shop(String token, String shopId) async {
    await _check();
    return ShopDetail.fromJson(detail());
  }

  @override
  Future<ActionOutcome> act(String token, String shopId, String action, Map<String, Object?> body) async {
    await _check();
    calls.add((action, body));
    final form = body['formId'] as String?;
    if (form != null && !seenForms.add(form)) return ActionOutcome.fromJson({'result': 'repeat', 'shop': detail()});
    switch (action) {
      case 'pause':
        sub = {...?sub, 'pausedAt': '2026-11-26T05:00:00.000Z'};
      case 'paid':
        payments.add({'id': 'p1', 'amountPaise': 99900, 'upiRef': body['upiRef'], 'paidOn': body['paidOn'], 'months': body['months'], 'note': null});
        sub = {...?sub, 'nextDueDate': '2027-01-05', 'pausedAt': null};
    }
    return ActionOutcome.fromJson({'result': 'done', 'shop': detail()});
  }
}

class FakePush implements AdminPush {
  final tapController = StreamController<String>.broadcast();
  bool asked = false;
  @override
  Future<String?> token() async => 'fcm-token-of-this-phone';
  @override
  Stream<String> get tokenRefresh => const Stream.empty();
  @override
  Stream<String> get taps => tapController.stream;
  @override
  Future<String?> takeLaunchShop() async => null;
  @override
  Future<void> requestPermission() async => asked = true;
}

class RecordingApi extends FakeAdminApi {
  final devices = <String>[];
  @override
  Future<void> registerDevice(String token, String fcmToken) async => devices.add(fcmToken);
}

Future<(FakeAdminApi, InMemorySessionStore, List<Uri>)> pumpAdmin(WidgetTester tester, {bool loggedIn = true, FakeAdminApi? apiOverride, AdminPush push = const NoPush()}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final api = apiOverride ?? FakeAdminApi();
  final store = InMemorySessionStore(loggedIn ? const AdminSession(token: 'tok', email: 'owner@example.com') : null);
  final opened = <Uri>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig(apiUrl: 'http://test')),
        adminApiProvider.overrideWithValue(api),
        sessionStoreProvider.overrideWithValue(store),
        adminPushProvider.overrideWithValue(push),
        externalLauncherProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
      child: const AdminApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (api, store, opened);
}

Future<void> openSharma(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('shop-$shopA')));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('logs in with the emailed code and lands on the shops', (tester) async {
    final (_, store, _) = await pumpAdmin(tester, loggedIn: false);
    expect(find.text('Send me a login code'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('emailField')), 'owner@example.com');
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('codeField')), '000000');
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pumpAndSettle();
    expect(find.textContaining('not right'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('codeField')), '123456');
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pumpAndSettle();
    expect(find.text('Shops'), findsOneWidget);
    expect(store.session?.token, 'tok');
  });

  testWidgets('home shows the count tiles and overdue shops first', (tester) async {
    await pumpAdmin(tester);
    expect(find.byKey(const Key('tile-overdue')), findsOneWidget);
    final late = tester.getTopLeft(find.text('Late Shop')).dy;
    final sharma = tester.getTopLeft(find.text('Sharma Kirana')).dy;
    expect(late, lessThan(sharma));
    expect(find.textContaining('312 customers · 87 orders this month'), findsNWidgets(2));
  });

  testWidgets('shop page: details, numbers, WhatsApp reminder', (tester) async {
    final (_, _, opened) = await pumpAdmin(tester);
    await openSharma(tester);
    expect(find.text('₹999'), findsWidgets);
    expect(find.text('5 Dec 2026'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('312'), 300);
    expect(find.text('312'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('remindButton')));
    expect(opened.single.host, 'wa.me');
    expect(opened.single.queryParameters['text'], contains('me@okaxis'));
  });

  testWidgets('mark paid sends the payment once and shows the new due date', (tester) async {
    final (api, _, _) = await pumpAdmin(tester);
    await openSharma(tester);
    await tapVisible(tester, find.byKey(const Key('markPaidButton')));
    await tester.enterText(find.byKey(const Key('upiField')), '4321');
    await tester.tap(find.byKey(const Key('savePaymentButton')));
    await tester.pumpAndSettle();
    expect(api.calls.single.$1, 'paid');
    expect(api.calls.single.$2, containsPair('amountRupees', '999'));
    expect(api.calls.single.$2, containsPair('months', 1));
    expect(api.calls.single.$2, containsPair('paidOn', '2026-11-26'));
    expect(find.textContaining('Payment saved'), findsOneWidget);
    expect(find.text('5 Jan 2027', skipOffstage: false), findsOneWidget);
  });

  testWidgets('pause asks first; cancel does nothing', (tester) async {
    final (api, _, _) = await pumpAdmin(tester);
    await openSharma(tester);
    await tapVisible(tester, find.byKey(const Key('pauseButton')));
    expect(find.text('Pause online orders?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);

    await tapVisible(tester, find.byKey(const Key('pauseButton')));
    await tester.tap(find.byKey(const Key('confirmPause')));
    await tester.pumpAndSettle();
    expect(api.calls.single.$1, 'pause');
    expect(find.byKey(const Key('resumeButton')), findsOneWidget);
  });

  testWidgets('wrong values are explained and the sheet stays open', (tester) async {
    final (api, _, _) = await pumpAdmin(tester);
    await openSharma(tester);
    await tapVisible(tester, find.byKey(const Key('editButton')));
    api.failNext = const ApiError('VALIDATION_FAILED', 'Invalid request', statusCode: 400, fieldMessages: ['Due day: from 1 to 28']);
    await tester.enterText(find.byKey(const Key('dueDayField')), '31');
    await tester.tap(find.byKey(const Key('saveFeeButton')));
    await tester.pumpAndSettle();
    expect(find.text('Due day: from 1 to 28'), findsOneWidget);
    expect(find.byKey(const Key('saveFeeButton')), findsOneWidget);
  });

  testWidgets('an expired session goes back to login', (tester) async {
    final (api, store, _) = await pumpAdmin(tester);
    api.expired = true;
    await tester.fling(find.text('Late Shop'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Send me a login code'), findsOneWidget);
    expect(store.session, isNull);
  });

  testWidgets('server down: readable error with retry', (tester) async {
    final api = FakeAdminApi()..failNext = const ApiError('NETWORK', 'Cannot reach the server. Check the internet (or the USB cable) and try again.');
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(const AppConfig(apiUrl: 'http://test')),
          adminApiProvider.overrideWithValue(api),
          sessionStoreProvider.overrideWithValue(InMemorySessionStore(const AdminSession(token: 'tok', email: 'o@e.com'))),
        ],
        child: const AdminApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Cannot reach the server'), findsOneWidget);
    await tester.tap(find.byKey(const Key('retryButton')));
    await tester.pumpAndSettle();
    expect(find.text('Sharma Kirana'), findsOneWidget);
  });

  testWidgets('registers the phone for alerts; a tapped alert opens that shop', (tester) async {
    final push = FakePush();
    final api = RecordingApi();
    await pumpAdmin(tester, apiOverride: api, push: push);
    expect(push.asked, isTrue);
    expect(api.devices, ['fcm-token-of-this-phone']);
    push.tapController.add(shopA);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('markPaidButton')), findsOneWidget);
  });
}
