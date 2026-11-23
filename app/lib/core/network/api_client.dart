import 'package:dio/dio.dart';

import '../config/client_config.dart';
import '../config/env_config.dart';
import 'api_exception.dart';

const shopKeyHeader = 'X-Shop-Key';

/// Single Dio instance for the gateway. Every request carries the shop key;
/// the auth interceptor (Phase 1) adds the bearer token and refresh handling.
Dio createDio(EnvConfig env, ClientConfig client) {
  final dio = Dio(
    BaseOptions(
      baseUrl: env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {shopKeyHeader: client.shopKey, 'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (error, handler) {
        // Normalise every failure to ApiException for repositories/UI.
        handler.reject(error.copyWith(error: ApiException.fromDio(error)));
      },
    ),
  );
  return dio;
}

/// Unwraps `{ "data": ... }` responses and rethrows [ApiException].
Future<T> unwrap<T>(Future<Response<dynamic>> request) async {
  try {
    final response = await request;
    return (response.data as Map<String, dynamic>)['data'] as T;
  } on DioException catch (error) {
    final cause = error.error;
    throw cause is ApiException ? cause : ApiException.fromDio(error);
  }
}
