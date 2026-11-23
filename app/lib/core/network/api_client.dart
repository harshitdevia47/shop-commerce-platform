import 'package:dio/dio.dart';

import '../config/client_config.dart';
import '../config/env_config.dart';
import 'api_exception.dart';

const shopKeyHeader = 'X-Shop-Key';

/// Base Dio for the gateway: shop key + error normalisation, no auth.
/// `dioProvider` adds [AuthInterceptor] on top for authenticated calls.
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
        // `next` (not `reject`) so later interceptors (auth refresh) still see the error.
        handler.next(error.error is ApiException ? error : error.copyWith(error: ApiException.fromDio(error)));
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

/// Unwraps `{ "data": [...], "nextCursor": "..." }` list responses.
Future<({List<dynamic> items, String? nextCursor})> unwrapList(Future<Response<dynamic>> request) async {
  try {
    final body = (await request).data as Map<String, dynamic>;
    return (items: body['data'] as List<dynamic>, nextCursor: body['nextCursor'] as String?);
  } on DioException catch (error) {
    final cause = error.error;
    throw cause is ApiException ? cause : ApiException.fromDio(error);
  }
}

/// Absolute URL for a server path such as `/media/...` (images are served next to the API).
String resolveServerUrl(String baseUrl, String path) =>
    path.startsWith('http') ? path : Uri.parse(baseUrl).resolve(path).toString();

/// Sends a request whose response has no body (e.g. 204 on delete); rethrows [ApiException].
Future<void> send(Future<Response<dynamic>> request) async {
  try {
    await request;
  } on DioException catch (error) {
    final cause = error.error;
    throw cause is ApiException ? cause : ApiException.fromDio(error);
  }
}
