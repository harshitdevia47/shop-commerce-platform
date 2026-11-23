import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qc_app/app.dart';
import 'package:qc_app/core/config/shop_settings.dart';
import 'package:qc_app/core/network/api_exception.dart';
import 'package:qc_app/core/providers.dart';
import 'package:qc_app/features/catalog/presentation/catalog_providers.dart';
import 'package:qc_app/features/auth/data/auth_api.dart';
import 'package:qc_app/features/auth/data/session_store.dart';
import 'package:qc_app/features/auth/domain/auth_models.dart';
import 'package:qc_app/features/auth/presentation/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures.dart';

class FakeAuthApi implements AuthApi {
  FakeAuthApi({this.role = UserRole.customer});

  UserRole role;
  String? lastPhone;
  int logouts = 0;
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

  @override
  Future<OtpRequestResult> requestOtp(String phone) async {
    lastPhone = phone;
    return const OtpRequestResult(expiresInSeconds: 300, resendAfterSeconds: 30, debugCode: '123456');
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
  Future<void> logout(String refreshToken) async => logouts++;

  @override
  Future<AppUser> me() async => profile!;

  @override
  Future<AppUser> updateMe({String? name, String? locale}) async =>
      profile = AppUser(id: profile!.id, phone: profile!.phone, role: profile!.role, name: name ?? profile!.name);
}

Future<void> pumpApp(WidgetTester tester, {required FakeAuthApi api, SessionStore? store}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clientConfigProvider.overrideWithValue(testClient),
        envConfigProvider.overrideWithValue(testEnv),
        sharedPreferencesProvider.overrideWithValue(prefs),
        shopSettingsRepositoryProvider.overrideWithValue(FakeRepository(ShopSettings.fromJson(shopConfigJson()))),
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        sessionStoreProvider.overrideWithValue(store ?? InMemorySessionStore()),
        authApiProvider.overrideWithValue(api),
      ],
      child: const QcApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> loginWithPhone(WidgetTester tester, {String code = '123456'}) async {
  await tester.tap(find.byKey(const Key('accountButton')));
  await tester.pumpAndSettle();
  expect(find.text('Log in to continue'), findsOneWidget);

  await tester.enterText(find.byKey(const Key('phoneField')), '9876543210');
  await tester.pump();
  await tester.tap(find.byKey(const Key('sendOtpButton')));
  await tester.pumpAndSettle();
  expect(find.text('Sent to +919876543210'), findsOneWidget);

  await tester.enterText(find.byKey(const Key('otpField')), code);
  await tester.pumpAndSettle();
  if (find.byKey(const Key('verifyButton')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('verifyButton')));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('guest logs in as a customer and returns home', (tester) async {
    final api = FakeAuthApi();
    await pumpApp(tester, api: api);

    await loginWithPhone(tester);

    expect(api.lastPhone, '+919876543210');
    expect(find.text('Welcome to Sharma Kirana'), findsOneWidget);
    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
  });

  testWidgets('dev builds prefill the echoed code', (tester) async {
    await pumpApp(tester, api: FakeAuthApi());
    await tester.tap(find.byKey(const Key('accountButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('phoneField')), '9876543210');
    await tester.pump();
    await tester.tap(find.byKey(const Key('sendOtpButton')));
    await tester.pumpAndSettle();

    expect(find.text('Dev code: 123456'), findsOneWidget);
    expect(find.text('123456'), findsWidgets);
  });

  testWidgets('wrong code shows attempts left', (tester) async {
    await pumpApp(tester, api: FakeAuthApi());
    await loginWithPhone(tester, code: '000000');

    expect(find.text('Incorrect code. 4 attempts left.'), findsOneWidget);
  });

  testWidgets('send button stays disabled for invalid numbers', (tester) async {
    await pumpApp(tester, api: FakeAuthApi());
    await tester.tap(find.byKey(const Key('accountButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('phoneField')), '12345');
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byKey(const Key('sendOtpButton')));
    expect(button.onPressed, isNull);
  });

  testWidgets('owner lands on the shop dashboard', (tester) async {
    await pumpApp(tester, api: FakeAuthApi(role: UserRole.owner));
    await loginWithPhone(tester);

    expect(find.text('Shop dashboard'), findsOneWidget);
    expect(find.text('Hello, +919876543210'), findsOneWidget);
  });

  testWidgets('session expiry while on account returns to guest home', (tester) async {
    final store = InMemorySessionStore();
    await pumpApp(tester, api: FakeAuthApi(), store: store);
    await loginWithPhone(tester);
    await tester.tap(find.byKey(const Key('accountButton')));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    container.read(authControllerProvider.notifier).sessionExpired();
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Sharma Kirana'), findsOneWidget);
  });

  testWidgets('restores a saved session at startup', (tester) async {
    final store = InMemorySessionStore(
      AuthSession(
        accessToken: 'a',
        accessTokenExpiresAt: DateTime.utc(2030),
        refreshToken: 'r',
        refreshTokenExpiresAt: DateTime.utc(2030),
        user: const AppUser(id: 'u', phone: '+919811111111', role: UserRole.rider),
      ),
    );
    await pumpApp(tester, api: FakeAuthApi(), store: store);

    expect(find.text('Deliveries'), findsOneWidget);
  });

  testWidgets('expired saved session starts signed out', (tester) async {
    final store = InMemorySessionStore(
      AuthSession(
        accessToken: 'a',
        accessTokenExpiresAt: DateTime.utc(2020),
        refreshToken: 'r',
        refreshTokenExpiresAt: DateTime.utc(2020),
        user: const AppUser(id: 'u', phone: '+919811111111', role: UserRole.owner),
      ),
    );
    await pumpApp(tester, api: FakeAuthApi(), store: store);

    expect(find.text('Welcome to Sharma Kirana'), findsOneWidget);
    expect(store.session, isNull);
  });

  testWidgets('profile update and logout', (tester) async {
    final api = FakeAuthApi();
    final store = InMemorySessionStore();
    await pumpApp(tester, api: api, store: store);
    await loginWithPhone(tester);

    await tester.tap(find.byKey(const Key('accountButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nameField')), 'Ramesh');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    expect(store.session!.user.name, 'Ramesh');

    await tester.tap(find.byKey(const Key('logoutButton')));
    await tester.pumpAndSettle();

    expect(api.logouts, 1);
    expect(store.session, isNull);
    expect(find.text('Welcome to Sharma Kirana'), findsOneWidget); // back to browsing as a guest
    expect(find.byIcon(Icons.login), findsOneWidget);
  });
}
