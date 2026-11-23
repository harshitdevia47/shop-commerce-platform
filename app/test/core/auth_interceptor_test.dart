import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qc_app/core/network/api_client.dart';
import 'package:qc_app/core/network/api_exception.dart';
import 'package:qc_app/core/network/auth_interceptor.dart';
import 'package:qc_app/features/auth/data/session_store.dart';
import 'package:qc_app/features/auth/domain/auth_models.dart';

import '../fixtures.dart';

/// Fake gateway: `/api/v1/me` accepts only [validToken]; records Authorization headers.
class FakeGateway implements HttpClientAdapter {
  FakeGateway(this.validToken);

  String validToken;
  final List<String?> seenTokens = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final auth = options.headers['Authorization'] as String?;
    seenTokens.add(auth);
    if (auth == 'Bearer $validToken') {
      return _json(200, {
        'data': {'ok': true},
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

AuthSession session(String access, String refresh) => AuthSession(
  accessToken: access,
  accessTokenExpiresAt: DateTime.utc(2026, 11, 23, 10, 15),
  refreshToken: refresh,
  refreshTokenExpiresAt: DateTime.utc(2026, 12, 23),
  user: const AppUser(id: 'u1', phone: '+919876543210', role: UserRole.customer),
);

void main() {
  late FakeGateway gateway;
  late InMemorySessionStore store;
  late Dio dio;
  late int refreshCalls;
  late int expiredCalls;
  late Future<AuthSession> Function(String) refreshImpl;

  setUp(() {
    gateway = FakeGateway('new-access');
    store = InMemorySessionStore(session('old-access', 'refresh-1'));
    refreshCalls = 0;
    expiredCalls = 0;
    refreshImpl = (token) async {
      expect(token, 'refresh-1');
      return session('new-access', 'refresh-2');
    };

    final retryDio = createDio(testEnv, testClient)..httpClientAdapter = gateway;
    dio = createDio(testEnv, testClient)..httpClientAdapter = gateway;
    dio.interceptors.add(
      AuthInterceptor(
        store: store,
        refresh: (token) {
          refreshCalls++;
          return refreshImpl(token);
        },
        retryDio: retryDio,
        onSessionRefreshed: (_) {},
        onSessionExpired: () => expiredCalls++,
      ),
    );
  });

  test('refreshes an expired access token once and retries', () async {
    final response = await dio.get<dynamic>('/api/v1/me');
    expect(response.statusCode, 200);
    expect(refreshCalls, 1);
    expect(gateway.seenTokens, ['Bearer old-access', 'Bearer new-access']);
    expect((await store.read())!.refreshToken, 'refresh-2');
  });

  test('parallel requests share one refresh (no rotated-token replay)', () async {
    final results = await Future.wait([
      dio.get<dynamic>('/api/v1/me'),
      dio.get<dynamic>('/api/v1/me'),
      dio.get<dynamic>('/api/v1/me'),
    ]);
    expect(results.every((r) => r.statusCode == 200), isTrue);
    expect(refreshCalls, 1);
  });

  test('ends the session when refresh is rejected', () async {
    refreshImpl = (_) async => throw const ApiException('REFRESH_TOKEN_REUSED', 'reused', statusCode: 401);
    await expectLater(dio.get<dynamic>('/api/v1/me'), throwsA(isA<DioException>()));
    expect(expiredCalls, 1);
    expect(await store.read(), isNull);
  });

  test('keeps the session when refresh fails because the phone is offline', () async {
    refreshImpl = (_) async => throw const ApiException(ApiException.networkError, 'offline');
    await expectLater(dio.get<dynamic>('/api/v1/me'), throwsA(isA<DioException>()));
    expect(expiredCalls, 0);
    expect(await store.read(), isNotNull);
  });

  test('never sends tokens to /auth endpoints', () async {
    await expectLater(dio.post<dynamic>('/api/v1/auth/otp/request'), throwsA(isA<DioException>()));
    expect(gateway.seenTokens, [null]);
    expect(refreshCalls, 0);
  });

  test('guests send no Authorization header', () async {
    await store.clear();
    await expectLater(dio.get<dynamic>('/api/v1/me'), throwsA(isA<DioException>()));
    expect(gateway.seenTokens, [null]);
    expect(refreshCalls, 0);
  });
}
