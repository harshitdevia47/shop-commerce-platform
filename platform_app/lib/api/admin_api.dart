import 'package:dio/dio.dart';

import 'models.dart';

/// An answer from the server that is not a success, with a message to show.
class ApiError implements Exception {
  const ApiError(this.code, this.message, {this.statusCode, this.fieldMessages = const []});

  final String code;
  final String message;
  final int? statusCode;

  /// Readable messages for wrong form values (VALIDATION_FAILED).
  final List<String> fieldMessages;

  bool get isAuth => statusCode == 401;
  bool get isNetwork => code == 'NETWORK';

  /// What to show the person.
  String get display => fieldMessages.isNotEmpty ? fieldMessages.join('\n') : message;

  @override
  String toString() => 'ApiError($code, $message)';
}

/// The platform service's admin API. Behind an interface so widget tests use a fake.
abstract interface class AdminApi {
  Future<void> requestCode(String email);
  Future<({String token, String email})> verifyCode(String email, String code);
  Future<void> logout(String token);
  Future<void> registerDevice(String token, String fcmToken);
  Future<Overview> overview(String token);
  Future<ShopDetail> shop(String token, String shopId);

  /// `action`: setup, edit, paid, extend, pause, resume, checklist.
  Future<ActionOutcome> act(String token, String shopId, String action, Map<String, Object?> body);
}

class HttpAdminApi implements AdminApi {
  HttpAdminApi(String baseUrl)
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          contentType: Headers.jsonContentType,
        ),
      );

  final Dio _dio;

  Options _auth(String token) => Options(headers: {'authorization': 'Bearer $token'});

  Future<Map<String, dynamic>> _call(Future<Response<dynamic>> request) async {
    try {
      final res = await request;
      final body = res.data;
      if (body is Map && body['data'] is Map) return (body['data'] as Map).cast<String, dynamic>();
      return const {};
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] is Map) {
        final error = (data['error'] as Map).cast<String, dynamic>();
        final details = error['details'];
        return Future.error(
          ApiError(
            error['code'] as String? ?? 'ERROR',
            error['message'] as String? ?? 'Something went wrong',
            statusCode: e.response?.statusCode,
            fieldMessages: [
              if (details is List)
                for (final d in details)
                  if (d is Map && d['message'] is String) d['message'] as String,
            ],
          ),
        );
      }
      if (e.response == null) {
        return Future.error(const ApiError('NETWORK', 'Cannot reach the server. Check the internet (or the USB cable) and try again.'));
      }
      return Future.error(ApiError('HTTP_${e.response!.statusCode}', 'The server had a problem (${e.response!.statusCode}). Try again.', statusCode: e.response!.statusCode));
    }
  }

  @override
  Future<void> requestCode(String email) => _call(_dio.post<dynamic>('/api/admin/login/code', data: {'email': email}));

  @override
  Future<({String token, String email})> verifyCode(String email, String code) async {
    final data = await _call(_dio.post<dynamic>('/api/admin/login/verify', data: {'email': email, 'code': code}));
    return (token: data['token'] as String, email: data['email'] as String);
  }

  @override
  Future<void> logout(String token) => _call(_dio.post<dynamic>('/api/admin/logout', options: _auth(token)));

  @override
  Future<void> registerDevice(String token, String fcmToken) =>
      _call(_dio.put<dynamic>('/api/admin/device', data: {'token': fcmToken, 'platform': 'android'}, options: _auth(token)));

  @override
  Future<Overview> overview(String token) async => Overview.fromJson(await _call(_dio.get<dynamic>('/api/admin/overview', options: _auth(token))));

  @override
  Future<ShopDetail> shop(String token, String shopId) async =>
      ShopDetail.fromJson(await _call(_dio.get<dynamic>('/api/admin/shops/$shopId', options: _auth(token))));

  @override
  Future<ActionOutcome> act(String token, String shopId, String action, Map<String, Object?> body) async =>
      ActionOutcome.fromJson(await _call(_dio.post<dynamic>('/api/admin/shops/$shopId/$action', data: body, options: _auth(token))));
}
