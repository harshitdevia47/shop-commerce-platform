import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qc_app/core/config/shop_settings.dart';
import 'package:qc_app/core/utils/launcher.dart';
import 'package:qc_app/features/auth/domain/auth_models.dart';

import '../fixtures.dart';
import 'admin_catalog_test.dart' show pumpAdmin;
import 'ordering_test.dart' show pumpShop, sessionFor;

const due = {'state': 'due', 'amountPaise': 99900, 'dueDate': '2026-12-05', 'payTo': 'platform@okaxis'};
const paused = {'state': 'paused', 'amountPaise': 99900, 'dueDate': '2026-12-05', 'payTo': 'platform@okaxis'};

void main() {
  testWidgets('owner sees the due subscription and pays by UPI', (tester) async {
    final opened = <Uri>[];
    await pumpAdmin(
      tester,
      config: shopConfigJson(subscription: due),
      extraOverrides: [
        externalLauncherProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
    );
    expect(find.byKey(const Key('subscriptionCard')), findsOneWidget);
    expect(find.text('App subscription due: ₹999 since 5 Dec 2026'), findsOneWidget);
    expect(find.text('Please pay by UPI to platform@okaxis.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('subscriptionPayButton')));
    await tester.pumpAndSettle();
    final uri = opened.single;
    expect(uri.scheme, 'upi');
    expect(uri.queryParameters, containsPair('pa', 'platform@okaxis'));
    expect(uri.queryParameters, containsPair('am', '999.00'));
    expect(uri.queryParameters, containsPair('cu', 'INR'));
  });

  testWidgets('paused: the owner is told why orders stopped', (tester) async {
    await pumpAdmin(tester, config: shopConfigJson(subscription: paused));
    expect(find.text('Online orders are paused: subscription unpaid'), findsOneWidget);
    expect(find.text('Pay ₹999 to turn orders back on. Customers can still see your shop.'), findsOneWidget);
  });

  testWidgets('ok: nothing is shown', (tester) async {
    await pumpAdmin(tester, config: shopConfigJson(subscription: {'state': 'ok'}));
    expect(find.byKey(const Key('subscriptionCard')), findsNothing);
  });

  testWidgets('staff see the paused notice but not the due reminder', (tester) async {
    await pumpShop(tester, session: sessionFor(UserRole.staff), settings: FakeRepository(ShopSettings.fromJson(shopConfigJson(subscription: due))));
    expect(find.byKey(const Key('subscriptionCard')), findsNothing);
  });

  testWidgets('customers of a paused shop are asked to call the shop', (tester) async {
    await pumpShop(tester, settings: FakeRepository(ShopSettings.fromJson(shopConfigJson(subscription: paused))));
    expect(find.byKey(const Key('shopSuspendedBanner')), findsOneWidget);
    expect(find.text('This shop is not taking online orders right now. Please call the shop.'), findsOneWidget);
    expect(find.byKey(const Key('shopPausedBanner')), findsNothing);
  });

  testWidgets('customers see nothing while the subscription is only due', (tester) async {
    await pumpShop(tester, settings: FakeRepository(ShopSettings.fromJson(shopConfigJson(subscription: due))));
    expect(find.byKey(const Key('shopSuspendedBanner')), findsNothing);
  });
}
