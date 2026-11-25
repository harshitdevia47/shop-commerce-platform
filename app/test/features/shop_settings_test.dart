import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qc_app/core/config/shop_settings.dart';
import 'package:qc_app/features/admin_settings/data/shop_settings_admin_api.dart';
import 'package:qc_app/features/auth/domain/auth_models.dart';

import '../fixtures.dart';
import 'ordering_test.dart' show pumpShop, sessionFor;

/// Stands in for the tenant service: keeps the patch and serves the result on the next load.
class FakeSettingsAdminApi implements ShopSettingsAdminApi {
  FakeSettingsAdminApi(this.repository);

  final FakeRepository repository;
  final List<Map<String, dynamic>> saved = [];

  @override
  Future<ShopSettings> save(Map<String, dynamic> patch) async {
    saved.add(patch);
    final json = shopConfigJson(ordering: Map<String, dynamic>.from(patch['ordering'] as Map));
    json['delivery'] = {...json['delivery'] as Map<String, dynamic>, ...patch['delivery'] as Map<String, dynamic>};
    final result = ShopSettings.fromJson(json);
    repository.result = result;
    return result;
  }
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('adminSettingsTile')));
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, String key, {bool up = false}) async {
  await tester.scrollUntilVisible(find.byKey(Key(key)), up ? -200 : 200, scrollable: find.byType(Scrollable).last);
  await tester.pumpAndSettle();
}

void main() {
  late FakeRepository repository;
  late FakeSettingsAdminApi api;
  setUp(() {
    repository = FakeRepository(ShopSettings.fromJson(shopConfigJson()));
    api = FakeSettingsAdminApi(repository);
  });

  testWidgets('owner closes the shop for a day and changes the delivery fee', (tester) async {
    await pumpShop(
      tester,
      session: sessionFor(UserRole.owner),
      settings: repository,
      extraOverrides: [shopSettingsAdminApiProvider.overrideWithValue(api)],
    );
    await openSettings(tester);

    expect(find.text('Customers can place orders now'), findsOneWidget);
    await tester.tap(find.byKey(const Key('acceptingOrdersSwitch')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pausedMessageField')), 'Closed for Diwali');
    await tester.enterText(find.byKey(const Key('feeField')), '15');
    await tester.tap(find.byKey(const Key('saveSettingsButton')));
    await tester.pumpAndSettle();

    final patch = api.saved.single;
    expect(patch['ordering'], {'paused': true, 'pausedMessage': 'Closed for Diwali'});
    expect((patch['delivery'] as Map)['feePaise'], 1500);
    expect((patch['delivery'] as Map)['freeAbovePaise'], 50000);
    expect((patch['contact'] as Map)['phone'], '+919876543210');
    expect(find.text('Settings saved. Customers see them now.'), findsOneWidget);

    // Back on the dashboard the owner is reminded the shop is closed.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pausedNotice')), findsOneWidget);
  });

  testWidgets('wrong values are shown next to the field and nothing is saved', (tester) async {
    await pumpShop(
      tester,
      session: sessionFor(UserRole.owner),
      settings: repository,
      extraOverrides: [shopSettingsAdminApiProvider.overrideWithValue(api)],
    );
    await openSettings(tester);

    await tester.enterText(find.byKey(const Key('feeField')), '12.345');
    await scrollTo(tester, 'pincodesField');
    await tester.enterText(find.byKey(const Key('pincodesField')), '36400');
    await tester.tap(find.byKey(const Key('saveSettingsButton')));
    await tester.pumpAndSettle();
    expect(find.text('Each pincode has 6 digits'), findsOneWidget);
    expect(find.text('Please fix the highlighted fields'), findsOneWidget);
    expect(api.saved, isEmpty);

    // Delivery and pickup both off: customers could not order at all.
    await tester.enterText(find.byKey(const Key('pincodesField')), '');
    await scrollTo(tester, 'feeField', up: true);
    await tester.enterText(find.byKey(const Key('feeField')), '20');
    await scrollTo(tester, 'deliverySwitch', up: true);
    await tester.tap(find.byKey(const Key('deliverySwitch')));
    await tester.pumpAndSettle();
    await scrollTo(tester, 'pickupSwitch');
    await tester.tap(find.byKey(const Key('pickupSwitch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveSettingsButton')));
    await tester.pumpAndSettle();
    expect(find.text('Turn on home delivery or pickup, otherwise customers cannot order'), findsOneWidget);
    expect(api.saved, isEmpty);
  });

  testWidgets('staff do not get the settings tile', (tester) async {
    await pumpShop(tester, session: sessionFor(UserRole.staff));
    expect(find.byKey(const Key('adminSettingsTile')), findsNothing);
  });

  testWidgets('customers see when the shop is closed, with the owner message', (tester) async {
    await pumpShop(
      tester,
      settings: FakeRepository(
        ShopSettings.fromJson(shopConfigJson(ordering: {'paused': true, 'pausedMessage': 'Closed for Diwali'})),
      ),
    );
    expect(find.text('The shop is not taking orders right now'), findsOneWidget);
    expect(find.text('Closed for Diwali'), findsOneWidget);
  });
}
