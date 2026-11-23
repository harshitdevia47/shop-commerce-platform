import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qc_app/app.dart';
import 'package:qc_app/core/config/env_config.dart';
import 'package:qc_app/core/config/shop_settings.dart';
import 'package:qc_app/core/config/shop_settings_repository.dart';
import 'package:qc_app/core/network/api_exception.dart';
import 'package:qc_app/core/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures.dart';

class FakeRepository implements ShopSettingsRepository {
  FakeRepository(this.result);

  Object result;
  int calls = 0;

  @override
  Future<ShopSettings> load() async {
    calls++;
    final value = result;
    if (value is ShopSettings) return value;
    throw value;
  }
}

Future<void> pumpApp(WidgetTester tester, FakeRepository repository, {String? savedLocale}) async {
  SharedPreferences.setMockInitialValues({'locale': ?savedLocale});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clientConfigProvider.overrideWithValue(testClient),
        envConfigProvider.overrideWithValue(const EnvConfig(env: 'test', apiBaseUrl: 'http://localhost')),
        sharedPreferencesProvider.overrideWithValue(prefs),
        shopSettingsRepositoryProvider.overrideWithValue(repository),
      ],
      child: const QcApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows shop settings from the server', (tester) async {
    await pumpApp(tester, FakeRepository(ShopSettings.fromJson(shopConfigJson())));

    expect(find.text('Welcome to Sharma Kirana'), findsOneWidget);
    expect(find.text('Minimum order ₹100'), findsOneWidget);
    expect(find.text('Free delivery above ₹500'), findsOneWidget);
    expect(find.text('Cash on delivery'), findsOneWidget);
    expect(find.text('UPI'), findsOneWidget);
    expect(find.text('Choose a delivery time slot'), findsOneWidget);
    expect(find.text('Returns and exchange'), findsNothing);
  });

  testWidgets('hides disabled options', (tester) async {
    await pumpApp(tester, FakeRepository(ShopSettings.fromJson(shopConfigJson(deliveryEnabled: false, upi: false))));

    expect(find.text('Delivery is not available. Pick up from the store.'), findsOneWidget);
    expect(find.text('UPI'), findsNothing);
  });

  testWidgets('renders in the saved language', (tester) async {
    await pumpApp(tester, FakeRepository(ShopSettings.fromJson(shopConfigJson())), savedLocale: 'gu');

    expect(find.text('શર્મા કરિયાણા માં આપનું સ્વાગત છે'), findsOneWidget);
    expect(find.text('ડિલિવરી વખતે રોકડ'), findsOneWidget);
  });

  testWidgets('switches language from the menu', (tester) async {
    await pumpApp(tester, FakeRepository(ShopSettings.fromJson(shopConfigJson())));

    await tester.tap(find.byIcon(Icons.translate));
    await tester.pumpAndSettle();
    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();

    expect(find.text('शर्मा किराना में आपका स्वागत है'), findsOneWidget);
  });

  testWidgets('shows a localized network error and retries', (tester) async {
    final repository = FakeRepository(const ApiException(ApiException.networkError, 'offline'));
    await pumpApp(tester, repository);

    expect(find.text('No internet connection. Check your network and try again.'), findsOneWidget);

    repository.result = ShopSettings.fromJson(shopConfigJson());
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Sharma Kirana'), findsOneWidget);
  });
}
