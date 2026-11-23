import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qc_app/core/providers.dart';
import 'package:qc_app/core/realtime/realtime_providers.dart';
import 'package:qc_app/features/auth/data/session_store.dart';
import 'package:qc_app/features/auth/domain/auth_models.dart';
import 'package:qc_app/features/auth/presentation/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures.dart';

/// Fake gateway: `/me` accepts only the refreshed token; `/auth/refresh` rotates once.
class FakeServer implements HttpClientAdapter {
  final List<String> calls = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls.add('${options.method} ${options.path} ${options.headers['Authorization'] ?? '-'}');
    if (options.path == '/api/v1/auth/refresh') {
      return _json(200, {
        'data': {
          'accessToken': 'fresh',
          'accessTokenExpiresAt': '2030-01-01T00:00:00Z',
          'refreshToken': 'r2',
          'refreshTokenExpiresAt': '2030-02-01T00:00:00Z',
          'user': {'id': 'u1', 'phone': '+919876543210', 'role': 'CUSTOMER'},
        },
      });
    }
    if (options.headers['Authorization'] == 'Bearer fresh') {
      return _json(200, {
        'data': {'id': 'u1', 'phone': '+919876543210', 'role': 'CUSTOMER'},
      });
    }
    return _json(401, {
      'error': {'code': 'TOKEN_EXPIRED', 'message': 'expired'},
    });
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

/// Uses the real provider graph (real AuthApi, real Dio wiring); only HTTP is faked.
/// Guards against provider cycles that unit tests with a fake AuthApi cannot see.
void main() {
  late FakeServer server;
  late InMemorySessionStore store;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    server = FakeServer();
    store = InMemorySessionStore(
      AuthSession(
        accessToken: 'stale',
        accessTokenExpiresAt: DateTime.utc(2020),
        refreshToken: 'r1',
        refreshTokenExpiresAt: DateTime.utc(2030),
        user: const AppUser(id: 'u1', phone: '+919876543210', role: UserRole.customer),
      ),
    );
    container = ProviderContainer(
      overrides: [
        clientConfigProvider.overrideWithValue(testClient),
        envConfigProvider.overrideWithValue(testEnv),
        sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
        sessionStoreProvider.overrideWithValue(store),
        httpAdapterProvider.overrideWithValue(server),
      ],
    );
    await container.read(authControllerProvider.future);
  });

  tearDown(() => container.dispose());

  test('an expired access token is refreshed and the request retried', () async {
    final me = await container.read(authApiProvider).me();
    expect(me.id, 'u1');
    expect(server.calls, ['GET /api/v1/me Bearer stale', 'POST /api/v1/auth/refresh -', 'GET /api/v1/me Bearer fresh']);
    expect((await store.read())!.refreshToken, 'r2');
  });

  test('the live socket gets a refreshed token', () async {
    expect(await container.read(socketTokenProvider)(), 'fresh');
  });
}
