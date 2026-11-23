import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/auth_models.dart';

abstract interface class AuthApi {
  Future<OtpRequestResult> requestOtp(String phone);
  Future<AuthSession> verifyOtp(String phone, String code);
  Future<AuthSession> refresh(String refreshToken);
  Future<void> logout(String refreshToken);
  Future<AppUser> me();
  Future<AppUser> updateMe({String? name, String? locale});
}

class HttpAuthApi implements AuthApi {
  /// [publicDio] has no auth interceptor (used for /auth/*, including refresh);
  /// [authedDio] attaches the access token.
  HttpAuthApi({required Dio publicDio, required Dio authedDio}) : _public = publicDio, _authed = authedDio;

  final Dio _public;
  final Dio _authed;

  @override
  Future<OtpRequestResult> requestOtp(String phone) async => OtpRequestResult.fromJson(
    await unwrap<Map<String, dynamic>>(_public.post<dynamic>('/api/v1/auth/otp/request', data: {'phone': phone})),
  );

  @override
  Future<AuthSession> verifyOtp(String phone, String code) async => AuthSession.fromJson(
    await unwrap<Map<String, dynamic>>(
      _public.post<dynamic>('/api/v1/auth/otp/verify', data: {'phone': phone, 'code': code}),
    ),
  );

  @override
  Future<AuthSession> refresh(String refreshToken) async => AuthSession.fromJson(
    await unwrap<Map<String, dynamic>>(
      _public.post<dynamic>('/api/v1/auth/refresh', data: {'refreshToken': refreshToken}),
    ),
  );

  @override
  Future<void> logout(String refreshToken) async {
    await _public.post<dynamic>('/api/v1/auth/logout', data: {'refreshToken': refreshToken});
  }

  @override
  Future<AppUser> me() async =>
      AppUser.fromJson(await unwrap<Map<String, dynamic>>(_authed.get<dynamic>('/api/v1/me')));

  @override
  Future<AppUser> updateMe({String? name, String? locale}) async => AppUser.fromJson(
    await unwrap<Map<String, dynamic>>(_authed.patch<dynamic>('/api/v1/me', data: {'name': ?name, 'locale': ?locale})),
  );
}
