import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qc_app/app.dart';
import 'package:qc_app/core/config/shop_settings.dart';
import 'package:qc_app/core/providers.dart';
import 'package:qc_app/features/auth/data/session_store.dart';
import 'package:qc_app/features/catalog/domain/catalog_models.dart';
import 'package:qc_app/features/catalog/presentation/catalog_providers.dart';
import 'package:qc_app/features/catalog/presentation/search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures.dart';

Future<void> pumpShop(WidgetTester tester, FakeCatalogRepository catalog) async {
  usePhoneScreen(tester);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clientConfigProvider.overrideWithValue(testClient),
        envConfigProvider.overrideWithValue(testEnv),
        sharedPreferencesProvider.overrideWithValue(prefs),
        shopSettingsRepositoryProvider.overrideWithValue(FakeRepository(ShopSettings.fromJson(shopConfigJson()))),
        catalogRepositoryProvider.overrideWithValue(catalog),
        sessionStoreProvider.overrideWithValue(InMemorySessionStore()),
      ],
      child: const QcApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Product product(String id, String name, {String categoryId = 'c1', bool inStock = true}) {
  final json = productJson(id: id, name: name, nameI18n: null, inStock: inStock)..['categoryId'] = categoryId;
  return Product.fromJson(json);
}

void main() {
  testWidgets('product detail switches variants and shows details', (tester) async {
    await pumpShop(tester, FakeCatalogRepository());
    await tester.tap(find.text('Basmati Rice'));
    await tester.pumpAndSettle();

    expect(find.text('Choose an option'), findsOneWidget);
    expect(find.text('₹120'), findsOneWidget);
    expect(find.text('Brand'), findsOneWidget); // custom field label from shop config
    expect(find.text('India Gate'), findsOneWidget);
    expect(find.text('Long grain rice'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('variant-p1-v2')));
    await tester.pumpAndSettle();
    expect(find.text('₹550'), findsOneWidget);
    expect(find.text('14% off'), findsNothing); // 5 kg has no MRP
  });

  testWidgets('out of stock products are marked', (tester) async {
    await pumpShop(tester, FakeCatalogRepository(products: [product('p1', 'Sugar', inStock: false)]));
    expect(find.text('Out of stock'), findsOneWidget);
  });

  testWidgets('home grid loads the next page while scrolling', (tester) async {
    final catalog = FakeCatalogRepository(
      products: [for (var i = 0; i < 30; i++) product('p$i', 'Item $i')],
      pageSize: 10,
    );
    await pumpShop(tester, catalog);
    expect(find.text('Item 0'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Item 25'), 500, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Item 25'), findsOneWidget);
    expect(catalog.queries.length, greaterThanOrEqualTo(3));
  });

  testWidgets('search waits for typing to pause and needs 2 letters', (tester) async {
    final catalog = FakeCatalogRepository(products: [product('p1', 'Basmati Rice'), product('p2', 'Toor Dal')]);
    await pumpShop(tester, catalog);
    await tester.tap(find.byKey(const Key('searchBox')));
    await tester.pumpAndSettle();
    expect(find.text('Type at least 2 letters to search'), findsOneWidget);
    final before = catalog.queries.length;

    await tester.enterText(find.byKey(const Key('searchField')), 'd');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byKey(const Key('searchField')), 'da');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byKey(const Key('searchField')), 'dal');
    await tester.pump(SearchScreen.debounce);
    await tester.pumpAndSettle();

    expect(catalog.queries.sublist(before), ['dal']); // one request, not one per keystroke
    expect(find.text('Toor Dal'), findsOneWidget);
    expect(find.text('Basmati Rice'), findsNothing);
  });

  testWidgets('category screen filters by sub-category', (tester) async {
    final catalog = FakeCatalogRepository(
      categories: const [
        ProductCategory(id: 'c1', name: 'Staples'),
        ProductCategory(id: 'c2', name: 'Rice', parentId: 'c1'),
      ],
      products: [product('p1', 'Loose Atta'), product('p2', 'Basmati Rice', categoryId: 'c2')],
    );
    await pumpShop(tester, catalog);
    await tester.tap(find.byKey(const ValueKey('category-c1')));
    await tester.pumpAndSettle();
    expect(find.text('Loose Atta'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Rice'));
    await tester.pumpAndSettle();
    expect(find.text('Basmati Rice'), findsOneWidget);
    expect(find.text('Loose Atta'), findsNothing);
  });
}
