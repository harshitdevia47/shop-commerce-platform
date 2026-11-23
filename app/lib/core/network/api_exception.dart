import 'package:dio/dio.dart';

/// Error from the backend (`{ "error": { "code", "message" } }`) or the network.
/// UI maps [code] to a localized message; never show [message] to customers directly.
class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.statusCode});

  factory ApiException.fromDio(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final body = data['error'] as Map;
      return ApiException(
        body['code'] as String? ?? 'UNKNOWN',
        body['message'] as String? ?? 'Unknown error',
        statusCode: error.response?.statusCode,
      );
    }
    final isNetwork = switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => true,
      _ => false,
    };
    return ApiException(
      isNetwork ? networkError : 'UNKNOWN',
      error.message ?? 'Request failed',
      statusCode: error.response?.statusCode,
    );
  }

  static const networkError = 'NETWORK_ERROR';

  final String code;
  final String message;
  final int? statusCode;

  bool get isNetwork => code == networkError;

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
