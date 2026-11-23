import 'package:dio/dio.dart';

import '../../features/auth/data/session_store.dart';
import '../../features/auth/domain/auth_models.dart';
import 'api_exception.dart';

const _authPathPrefix = '/api/v1/auth/';
const _retriedKey = 'auth_retried';

/// Attaches the access token and, on `401 TOKEN_EXPIRED`, refreshes once and
/// retries. Queued: while one request refreshes, others wait, then reuse the
/// new token instead of refreshing again (a second refresh with the rotated
/// token would be treated as theft by the backend and end the session).
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.store,
    required this.refresh,
    required this.retryDio,
    required this.onSessionRefreshed,
    required this.onSessionExpired,
  });

  final SessionStore store;

  /// Calls `/auth/refresh` (must not go through this interceptor).
  final Future<AuthSession> Function(String refreshToken) refresh;

  /// Dio without this interceptor, used to replay the failed request.
  final Dio retryDio;
  final void Function(AuthSession session) onSessionRefreshed;
  final void Function() onSessionExpired;

  static bool _isAuthPath(RequestOptions options) => options.path.startsWith(_authPathPrefix);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_isAuthPath(options)) {
      final session = await store.read();
      if (session != null) options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final apiError = err.error is ApiException ? err.error! as ApiException : ApiException.fromDio(err);
    final shouldRefresh =
        err.response?.statusCode == 401 &&
        apiError.code == 'TOKEN_EXPIRED' &&
        !_isAuthPath(options) &&
        options.extra[_retriedKey] != true;
    if (!shouldRefresh) return handler.next(err);

    final session = await store.read();
    if (session == null) return handler.next(err);

    final sentToken = (options.headers['Authorization'] as String?)?.replaceFirst('Bearer ', '');
    var current = session;
    // Only refresh if nobody else already did while this request was in flight.
    if (sentToken == session.accessToken) {
      try {
        current = await refresh(session.refreshToken);
        await store.write(current);
        onSessionRefreshed(current);
      } on DioException catch (refreshError) {
        final refreshApiError = refreshError.error is ApiException ? refreshError.error! as ApiException : null;
        if (refreshApiError?.isNetwork ?? false) return handler.next(err); // offline: keep the session
        await store.clear();
        onSessionExpired();
        return handler.next(err);
      } on ApiException catch (refreshError) {
        if (refreshError.isNetwork) return handler.next(err);
        await store.clear();
        onSessionExpired();
        return handler.next(err);
      }
    }

    try {
      options.headers['Authorization'] = 'Bearer ${current.accessToken}';
      options.extra[_retriedKey] = true;
      handler.resolve(await retryDio.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
