import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/auth_api.dart';
import '../domain/auth_models.dart';

final Provider<AuthApi> authApiProvider = Provider<AuthApi>(
  (ref) => HttpAuthApi(publicDio: ref.watch(publicDioProvider), authedDio: ref.watch(dioProvider)),
);

/// Injectable clock (tests).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Signed-in user, or null for guests. Loading only while reading secure storage at startup.
class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    final store = ref.read(sessionStoreProvider);
    final session = await store.read();
    if (session == null) return null;
    if (session.isRefreshExpired(ref.read(clockProvider)())) {
      await store.clear();
      return null;
    }
    return session.user;
  }

  AppUser? get user => state.value;

  Future<OtpRequestResult> requestOtp(String phone) => ref.read(authApiProvider).requestOtp(phone);

  /// Throws [ApiException] on a wrong/expired code; state is unchanged then.
  Future<AppUser> verifyOtp(String phone, String code) async {
    final session = await ref.read(authApiProvider).verifyOtp(phone, code);
    await ref.read(sessionStoreProvider).write(session);
    state = AsyncData(session.user);
    return session.user;
  }

  Future<AppUser> updateProfile({String? name, String? locale}) async {
    final updated = await ref.read(authApiProvider).updateMe(name: name, locale: locale);
    final store = ref.read(sessionStoreProvider);
    final session = await store.read();
    if (session != null) await store.write(session.withUser(updated));
    state = AsyncData(updated);
    return updated;
  }

  Future<void> logout() async {
    final store = ref.read(sessionStoreProvider);
    final session = await store.read();
    await store.clear();
    state = const AsyncData(null);
    if (session != null) {
      try {
        await ref.read(authApiProvider).logout(session.refreshToken);
      } on Object {
        // Best effort: the local session is already gone.
      }
    }
  }

  /// Called by [AuthInterceptor] after a silent refresh (role may have changed).
  void sessionRefreshed(AuthSession session) {
    if (state.value != session.user) state = AsyncData(session.user);
  }

  /// Called by [AuthInterceptor] when the refresh token is rejected.
  void sessionExpired() => state = const AsyncData(null);
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);
