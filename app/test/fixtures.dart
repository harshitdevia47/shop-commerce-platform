import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qc_app/core/config/client_config.dart';
import 'package:qc_app/core/config/env_config.dart';
import 'package:qc_app/core/config/shop_settings.dart';
import 'package:qc_app/core/config/shop_settings_repository.dart';
import 'package:qc_app/core/network/api_exception.dart';
import 'package:qc_app/features/auth/data/auth_api.dart';
import 'package:qc_app/features/auth/domain/auth_models.dart';
import 'package:qc_app/features/catalog/data/catalog_repository.dart';
import 'package:qc_app/features/catalog/domain/catalog_models.dart';

/// 360x800 dp, a typical Android phone.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

const testEnv = EnvConfig(env: 'test', apiBaseUrl: 'http://localhost');

const testClient = ClientConfig(
  shopKey: 'sharma_kirana',
  appName: 'Sharma Kirana',
  logoAsset: 'assets/missing-in-tests.png',
  primaryColor: Color(0xFF1B5E20),
  secondaryColor: Color(0xFFFFB300),
  defaultLocale: Locale('en'),
  supportedLocales: [Locale('en'), Locale('gu'), Locale('hi')],
);

/// Shape returned by GET /api/v1/shop/config (captured from the tenant service).
/// Phase 6 features (slots, list photos, prescriptions, returns) are off unless a test turns them on.
Map<String, dynamic> shopConfigJson({
  bool deliveryEnabled = true,
  bool upi = true,
  bool razorpay = false,
  Map<String, bool> features = const {},
  Map<String, dynamic>? ordering,
  Map<String, dynamic>? subscription,
}) => {
  'id': '01a206e8-75c7-71d8-b22b-d3223bce1039',
  'slug': 'sharma_kirana',
  'shop': {
    'name': 'Sharma Kirana',
    'nameI18n': {'gu': 'શર્મા કરિયાણા', 'hi': 'शर्मा किराना'},
    'businessType': 'grocery',
    'currency': 'INR',
    'timezone': 'Asia/Kolkata',
    'contact': {
      'phone': '+919876543210',
      'whatsapp': '+919876543210',
      'address': 'Station Road, Bhavnagar, Gujarat 364001',
      'lat': 21.7645,
      'lng': 72.1519,
    },
  },
  'delivery': {
    'enabled': deliveryEnabled,
    'radiusKm': 5,
    'pincodes': ['364001'],
    'minOrderPaise': 10000,
    'feePaise': 2000,
    'freeAbovePaise': 50000,
    'etaMinutes': 45,
  },
  'payments': {
    'cod': true,
    'upi': {'enabled': upi, 'vpa': 'sharmakirana@okaxis', 'payeeName': 'Sharma Kirana'},
    'razorpay': {'enabled': razorpay},
  },
  'features': {
    'deliverySlots': false,
    'storePickup': true,
    'returns': false,
    'prescriptionUpload': false,
    'orderNotes': true,
    'handwrittenListUpload': false,
    'someFutureFlag': true,
    ...features,
  },
  'returns': {'windowDays': 7, 'allowExchange': true},
  'ordering': ?ordering,
  'subscription': ?subscription,
  'catalog': {
    'variantStyle': 'units',
    'variantAxes': <String>[],
    'customFields': [
      {
        'key': 'brand',
        'type': 'text',
        'label': {'en': 'Brand', 'gu': 'બ્રાન્ડ', 'hi': 'ब्रांड'},
        'required': false,
      },
    ],
  },
};

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

// ---- Catalog ----

Map<String, dynamic> productJson({
  String id = 'p1',
  String name = 'Basmati Rice',
  Map<String, String>? nameI18n = const {'gu': 'બાસમતી ચોખા'},
  bool inStock = true,
  bool isActive = true,
  List<Map<String, dynamic>>? variants,
}) => {
  'id': id,
  'categoryId': 'c1',
  'name': name,
  'nameI18n': nameI18n,
  'description': 'Long grain rice',
  'descriptionI18n': null,
  'customFields': {'brand': 'India Gate'},
  'tags': ['chawal'],
  'images': <Map<String, dynamic>>[],
  'inStock': inStock,
  'isActive': isActive,
  'variants':
      variants ??
      [
        {
          'id': '$id-v1',
          'label': '1 kg',
          'labelI18n': null,
          'options': <String, String>{},
          'pricePaise': 12000,
          'mrpPaise': 14000,
          'inStock': inStock,
          'stockQty': null,
          'sku': null,
          'isAvailable': true,
        },
        {
          'id': '$id-v2',
          'label': '5 kg',
          'labelI18n': null,
          'options': <String, String>{},
          'pricePaise': 55000,
          'mrpPaise': null,
          'inStock': inStock,
          'stockQty': null,
          'sku': null,
          'isAvailable': true,
        },
      ],
};

/// In-memory catalog: pages of [pageSize]; filters by category and name.
class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository({List<ProductCategory>? categories, List<Product>? products, this.pageSize = 20})
    : categoryList = categories ?? [const ProductCategory(id: 'c1', name: 'Staples', nameI18n: {'gu': 'અનાજ'})],
      productList = products ?? [Product.fromJson(productJson())];

  final List<ProductCategory> categoryList;
  final List<Product> productList;
  final int pageSize;
  final List<String?> queries = [];

  @override
  Future<List<ProductCategory>> categories() async => categoryList;

  @override
  Future<PageResult<Product>> products({String? categoryId, String? query, String? cursor, int limit = 20}) async {
    queries.add(query);
    final matching = productList
        .where((p) => categoryId == null || p.categoryId == categoryId)
        .where((p) => query == null || p.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + pageSize).clamp(0, matching.length);
    return PageResult(matching.sublist(start, end), end < matching.length ? '$end' : null);
  }

  @override
  Future<Product> product(String id) async => productList.firstWhere(
    (p) => p.id == id,
    orElse: () => throw const ApiException('PRODUCT_NOT_FOUND', 'not found', statusCode: 404),
  );
}

// ---- Auth ----

class FakeAuthApi implements AuthApi {
  FakeAuthApi({this.role = UserRole.customer});

  UserRole role;
  String? lastPhone;
  int logouts = 0;
  String? lastLogoutDeviceToken;
  final devices = <(String, String)>[];
  AppUser? profile;

  AuthSession _session(String phone) {
    profile ??= AppUser(id: 'user-1', phone: phone, role: role);
    return AuthSession(
      accessToken: 'access',
      accessTokenExpiresAt: DateTime.utc(2030),
      refreshToken: 'refresh',
      refreshTokenExpiresAt: DateTime.utc(2030),
      user: profile!,
    );
  }

  String? lastLocale;

  @override
  Future<OtpRequestResult> requestOtp(String phone, {String? locale}) async {
    lastPhone = phone;
    lastLocale = locale;
    return const OtpRequestResult(expiresInSeconds: 300, resendAfterSeconds: 30, debugCode: '123456', viaWhatsApp: true);
  }

  @override
  Future<AuthSession> verifyOtp(String phone, String code) async {
    if (code != '123456') {
      throw const ApiException('OTP_INVALID', 'wrong', statusCode: 400, details: {'attemptsLeft': 4});
    }
    return _session(phone);
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async => _session(lastPhone ?? '+919876543210');

  @override
  Future<void> logout(String refreshToken, {String? deviceToken}) async {
    logouts++;
    lastLogoutDeviceToken = deviceToken;
  }

  @override
  Future<void> registerDevice({required String token, required String locale}) async => devices.add((token, locale));

  @override
  Future<AppUser> me() async => profile!;

  @override
  Future<AppUser> updateMe({String? name, String? locale}) async =>
      profile = AppUser(id: profile!.id, phone: profile!.phone, role: profile!.role, name: name ?? profile!.name);

  int deletions = 0;

  /// Set to make the next delete fail with this error code.
  String? deleteError;

  @override
  Future<void> deleteMe() async {
    if (deleteError case final code?) throw ApiException(code, 'refused', statusCode: 409);
    deletions++;
    profile = null;
  }
}

