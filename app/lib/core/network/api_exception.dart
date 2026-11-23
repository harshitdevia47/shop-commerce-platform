import 'package:dio/dio.dart';

/// Error from the backend (`{ "error": { "code", "message" } }`) or the network.
/// UI maps [code] to a localized message; never show [message] to customers directly.
class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.statusCode, this.details});

  factory ApiException.fromDio(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final body = data['error'] as Map;
      return ApiException(
        body['code'] as String? ?? 'UNKNOWN',
        body['message'] as String? ?? 'Unknown error',
        statusCode: error.response?.statusCode,
        details: body['details'],
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
      error.message ?? (error.error != null ? 'Request failed: ${error.error}' : 'Request failed'),
      statusCode: error.response?.statusCode,
    );
  }

  static const networkError = 'NETWORK_ERROR';

  final String code;
  final String message;
  final int? statusCode;

  /// Optional structured details, e.g. `{ "attemptsLeft": 3 }`.
  final Object? details;

  /// Reads an int from [details] when it is a map, e.g. `detailInt('attemptsLeft')`.
  int? detailInt(String key) {
    final value = details;
    return value is Map && value[key] is int ? value[key] as int : null;
  }

  bool get isNetwork => code == networkError;

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
