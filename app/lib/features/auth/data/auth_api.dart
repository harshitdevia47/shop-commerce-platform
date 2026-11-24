import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/auth_models.dart';

abstract interface class AuthApi {
  /// [locale]: language of the WhatsApp/SMS message.
  Future<OtpRequestResult> requestOtp(String phone, {String? locale});
  Future<AuthSession> verifyOtp(String phone, String code);
  Future<AuthSession> refresh(String refreshToken);
  /// [deviceToken]: stop push notifications to this phone for the account.
  Future<void> logout(String refreshToken, {String? deviceToken});
  Future<AppUser> me();

  /// Registers this phone's push token (notifications are written in [locale]).
  Future<void> registerDevice({required String token, required String locale});
  Future<AppUser> updateMe({String? name, String? locale});
}

/// `POST /auth/refresh` on a Dio without the auth interceptor. Top-level so the authenticated
/// Dio's interceptor can call it without depending on [AuthApi] (which depends on that Dio).
Future<AuthSession> refreshSession(Dio publicDio, String refreshToken) async => AuthSession.fromJson(
  await unwrap<Map<String, dynamic>>(publicDio.post<dynamic>('/api/v1/auth/refresh', data: {'refreshToken': refreshToken})),
);

class HttpAuthApi implements AuthApi {
  /// [publicDio] has no auth interceptor (used for /auth/*, including refresh);
  /// [authedDio] attaches the access token.
  HttpAuthApi({required Dio publicDio, required Dio authedDio}) : _public = publicDio, _authed = authedDio;

  final Dio _public;
  final Dio _authed;

  @override
  Future<OtpRequestResult> requestOtp(String phone, {String? locale}) async => OtpRequestResult.fromJson(
    await unwrap<Map<String, dynamic>>(
      _public.post<dynamic>('/api/v1/auth/otp/request', data: {'phone': phone, 'locale': ?locale}),
    ),
  );

  @override
  Future<AuthSession> verifyOtp(String phone, String code) async => AuthSession.fromJson(
    await unwrap<Map<String, dynamic>>(
      _public.post<dynamic>('/api/v1/auth/otp/verify', data: {'phone': phone, 'code': code}),
    ),
  );

  @override
  Future<AuthSession> refresh(String refreshToken) => refreshSession(_public, refreshToken);

  @override
  Future<void> logout(String refreshToken, {String? deviceToken}) async {
    await _public.post<dynamic>('/api/v1/auth/logout', data: {'refreshToken': refreshToken, 'deviceToken': ?deviceToken});
  }

  @override
  Future<void> registerDevice({required String token, required String locale}) async {
    await _authed.put<dynamic>('/api/v1/me/devices', data: {'token': token, 'platform': 'android', 'locale': locale});
  }

  @override
  Future<AppUser> me() async =>
      AppUser.fromJson(await unwrap<Map<String, dynamic>>(_authed.get<dynamic>('/api/v1/me')));

  @override
  Future<AppUser> updateMe({String? name, String? locale}) async => AppUser.fromJson(
    await unwrap<Map<String, dynamic>>(_authed.patch<dynamic>('/api/v1/me', data: {'name': ?name, 'locale': ?locale})),
  );
}
