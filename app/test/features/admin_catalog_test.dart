import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qc_app/features/admin_dashboard/presentation/setup_checklist.dart';
import 'package:qc_app/app.dart';
import 'package:qc_app/core/config/env_config.dart';
import 'package:qc_app/core/config/shop_settings.dart';
import 'package:qc_app/core/network/api_exception.dart';
import 'package:qc_app/core/providers.dart';
import 'package:qc_app/features/admin_catalog/data/admin_catalog_repository.dart';
import 'package:qc_app/features/admin_catalog/presentation/admin_catalog_providers.dart';
import 'package:qc_app/features/admin_catalog/presentation/photo_picker.dart';
import 'package:qc_app/features/auth/data/session_store.dart';
import 'package:qc_app/features/auth/domain/auth_models.dart';
import 'package:qc_app/features/catalog/domain/catalog_models.dart';
import 'package:qc_app/features/catalog/presentation/catalog_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures.dart';

class FakeAdminCatalog implements AdminCatalogRepository {
  final store = <Product>[Product.fromJson(productJson())];
  final categoryList = <ProductCategory>[const ProductCategory(id: 'c1', name: 'Staples')];
  ProductDraft? created;
  (String, ProductDraft)? replaced;
  CategoryDraft? createdCategory;
  final uploads = <String>[];
  Object? failActiveToggle;

  Product _fromDraft(String id, ProductDraft d) => Product(
    id: id,
    name: d.name,
    isActive: d.isActive,
    inStock: true,
    variants: [
      for (final (i, v) in d.variants.indexed)
        Variant(id: v.id ?? '$id-new$i', label: v.label, pricePaise: v.pricePaise, mrpPaise: v.mrpPaise, inStock: true),
    ],
  );

  @override
  Future<List<ProductCategory>> categories() async => categoryList;

  @override
  Future<ProductCategory> createCategory(CategoryDraft draft) async {
    createdCategory = draft;
    final category = ProductCategory(id: 'c${categoryList.length + 1}', name: draft.name, parentId: draft.parentId);
    categoryList.add(category);
    return category;
  }

  @override
  Future<ProductCategory> updateCategory(String id, CategoryDraft draft) async => throw UnimplementedError();

  @override
  Future<void> deleteCategory(String id) async => throw const ApiException('CATEGORY_NOT_EMPTY', 'x', statusCode: 409);

  @override
  Future<PageResult<Product>> products({String? query, ProductStatus status = ProductStatus.all, String? cursor}) async {
    final list = store.where(
      (p) => switch (status) {
        ProductStatus.all => true,
        ProductStatus.active => p.isActive,
        ProductStatus.inactive => !p.isActive,
      },
    );
    return PageResult(list.toList(), null);
  }

  @override
  Future<Product> product(String id) async => store.firstWhere((p) => p.id == id);

  @override
  Future<Product> createProduct(ProductDraft draft) async {
    created = draft;
    final product = _fromDraft('new', draft);
    store.add(product);
    return product;
  }

  @override
  Future<Product> replaceProduct(String id, ProductDraft draft) async {
    replaced = (id, draft);
    return _fromDraft(id, draft);
  }

  @override
  Future<Product> setProductActive(String id, {required bool isActive}) async {
    if (failActiveToggle case final error?) throw error;
    final index = store.indexWhere((p) => p.id == id);
    return store[index] = store[index].copyWith(isActive: isActive);
  }

  @override
  Future<void> deleteProduct(String id) async => store.removeWhere((p) => p.id == id);

  @override
  Future<UploadedImage> uploadImage(String filePath, {String kind = 'PRODUCT_IMAGE'}) async {
    uploads.add(filePath);
    return UploadedImage(id: 'm${uploads.length}', url: '/media/full.webp', thumbUrl: '/media/thumb.webp');
  }
}

final owner = AuthSession(
  accessToken: 'a',
  accessTokenExpiresAt: DateTime.utc(2030),
  refreshToken: 'r',
  refreshTokenExpiresAt: DateTime.utc(2030),
  user: const AppUser(id: 'o', phone: '+919876543210', role: UserRole.owner, name: 'Ramesh'),
);

Future<FakeAdminCatalog> pumpAdmin(
  WidgetTester tester, {
  Map<String, dynamic>? config,
  List<Override> extraOverrides = const [],
  bool setupChecklist = false,
  EnvConfig? env,
}) async {
  usePhoneScreen(tester);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final admin = FakeAdminCatalog();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clientConfigProvider.overrideWithValue(testClient),
        envConfigProvider.overrideWithValue(env ?? testEnv),
        sharedPreferencesProvider.overrideWithValue(prefs),
        shopSettingsRepositoryProvider.overrideWithValue(FakeRepository(ShopSettings.fromJson(config ?? shopConfigJson()))),
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        adminCatalogRepositoryProvider.overrideWithValue(admin),
        sessionStoreProvider.overrideWithValue(InMemorySessionStore(owner)),
        photoSourceProvider.overrideWithValue(({required camera}) async => '/tmp/photo.jpg'),
        if (!setupChecklist)
          setupChecklistProvider.overrideWith((ref) async => const SetupProgress(steps: {}, hidden: true)),
        ...extraOverrides,
      ],
      child: const QcApp(),
    ),
  );
  await tester.pumpAndSettle();
  return admin;
}

Future<void> openProducts(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('adminProductsTile')));
  await tester.pumpAndSettle();
}

/// The product form's vertical list (the photo strip is a horizontal Scrollable too).
final formScroll = find.descendant(of: find.byType(Form), matching: find.byType(Scrollable)).first;

Future<void> tapSave(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('saveProductButton')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('owner adds a grocery product with two pack sizes and a photo', (tester) async {
    final admin = await pumpAdmin(tester);
    await openProducts(tester);
    expect(find.text('Basmati Rice'), findsOneWidget);

    await tester.tap(find.byKey(const Key('addProductButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addPhotoButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    expect(admin.uploads, ['/tmp/photo.jpg']);

    await tester.enterText(find.byKey(const Key('productNameField')), 'Toor Dal');
    await tester.enterText(find.byKey(const Key('variantLabel-0')), '500 g');
    await tester.enterText(find.byKey(const Key('variantPrice-0')), '85.50');
    await tester.dragUntilVisible(find.byKey(const Key('addVariantButton')), formScroll, const Offset(0, -150));
    await tester.drag(formScroll, const Offset(0, -150)); // clear of the save bar
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addVariantButton')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('variantPrice-1')), 200, scrollable: formScroll);
    await tester.enterText(find.byKey(const Key('variantLabel-1')), '1 kg');
    await tester.enterText(find.byKey(const Key('variantPrice-1')), '165');
    await tapSave(tester);

    final draft = admin.created!;
    expect(draft.name, 'Toor Dal');
    expect(draft.imageMediaIds, ['m1']);
    expect([for (final v in draft.variants) (v.label, v.pricePaise)], [('500 g', 8550), ('1 kg', 16500)]);
    // Back on the list, which reloaded.
    expect(find.text('Toor Dal'), findsOneWidget);
  });

  testWidgets('form validation: name, unit, price and MRP', (tester) async {
    final admin = await pumpAdmin(tester);
    await openProducts(tester);
    await tester.tap(find.byKey(const Key('addProductButton')));
    await tester.pumpAndSettle();

    await tapSave(tester);
    expect(find.text('Required'), findsNWidgets(2)); // name + unit
    expect(find.text('Enter a valid amount'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('productNameField')), 'Ghee');
    await tester.enterText(find.byKey(const Key('variantLabel-0')), '1 l');
    await tester.enterText(find.byKey(const Key('variantPrice-0')), '600');
    await tester.enterText(find.widgetWithText(TextFormField, 'MRP ₹'), '550');
    await tapSave(tester);
    expect(find.text('MRP cannot be less than price'), findsOneWidget);
    expect(admin.created, isNull);
  });

  testWidgets('editing keeps variant ids so the server updates instead of re-creating', (tester) async {
    final admin = await pumpAdmin(tester);
    await openProducts(tester);
    await tester.tap(find.text('Basmati Rice'));
    await tester.pumpAndSettle();

    expect(find.text('Edit product'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('variantPrice-0')), '125');
    await tapSave(tester);

    final (id, draft) = admin.replaced!;
    expect(id, 'p1');
    expect([for (final v in draft.variants) (v.id, v.pricePaise, v.mrpPaise)], [
      ('p1-v1', 12500, 14000),
      ('p1-v2', 55000, null),
    ]);
    expect(draft.customFields, {'brand': 'India Gate'});
  });

  testWidgets('clothing shop gets size and colour inputs; labels come from options', (tester) async {
    final config = shopConfigJson()
      ..['catalog'] = {
        'variantStyle': 'options',
        'variantAxes': ['size', 'color'],
        'customFields': [
          {
            'key': 'gender',
            'type': 'select',
            'label': {'en': 'For'},
            'required': false,
            'options': ['men', 'women'],
          },
        ],
      };
    final admin = await pumpAdmin(tester, config: config);
    await openProducts(tester);
    await tester.tap(find.byKey(const Key('addProductButton')));
    await tester.pumpAndSettle();

    expect(find.text('Options and prices'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('productNameField')), 'Kurti');
    await tester.enterText(find.byKey(const Key('variantOption-0-size')), 'M');
    await tester.enterText(find.byKey(const Key('variantOption-0-color')), 'Red');
    await tester.enterText(find.byKey(const Key('variantPrice-0')), '599');
    await tapSave(tester);

    expect(admin.created!.variants.single.options, {'size': 'M', 'color': 'Red'});
    expect(admin.created!.variants.single.label, '');
  });

  testWidgets('hide toggle is optimistic and reverts on failure', (tester) async {
    final admin = await pumpAdmin(tester);
    await openProducts(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(admin.store.single.isActive, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    admin.failActiveToggle = const ApiException(ApiException.networkError, 'offline');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.text('No internet connection. Check your network and try again.'), findsOneWidget);
  });

  testWidgets('owner adds a sub-category and sees a clear error on blocked delete', (tester) async {
    final admin = await pumpAdmin(tester);
    await tester.tap(find.byKey(const Key('adminCategoriesTile')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addCategoryButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('categoryNameField')), 'Rice');
    await tester.tap(find.text('Top level'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Staples').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveCategoryButton')));
    await tester.pumpAndSettle();

    expect(admin.createdCategory!.parentId, 'c1');
    expect(find.text('Rice'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('admin-category-c1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Move or delete its products and sub-categories first.'), findsOneWidget);
  });
}
