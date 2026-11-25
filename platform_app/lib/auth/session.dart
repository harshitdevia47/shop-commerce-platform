import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../providers.dart';

/// The signed-in admin. The token lives in the phone's secure storage.
class AdminSession {
  const AdminSession({required this.token, required this.email});
  final String token;
  final String email;
}

abstract interface class SessionStore {
  Future<AdminSession?> read();
  Future<void> write(AdminSession session);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  const SecureSessionStore();
  static const _storage = FlutterSecureStorage();

  @override
  Future<AdminSession?> read() async {
    final token = await _storage.read(key: 'admin_token');
    final email = await _storage.read(key: 'admin_email');
    return token == null || email == null ? null : AdminSession(token: token, email: email);
  }

  @override
  Future<void> write(AdminSession session) async {
    await _storage.write(key: 'admin_token', value: session.token);
    await _storage.write(key: 'admin_email', value: session.email);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: 'admin_token');
    await _storage.delete(key: 'admin_email');
  }
}

class InMemorySessionStore implements SessionStore {
  InMemorySessionStore([this.session]);
  AdminSession? session;

  @override
  Future<AdminSession?> read() async => session;
  @override
  Future<void> write(AdminSession value) async => session = value;
  @override
  Future<void> clear() async => session = null;
}

final sessionStoreProvider = Provider<SessionStore>((ref) => const SecureSessionStore());

/// Null = logged out. Loading only while reading storage at start.
class SessionController extends AsyncNotifier<AdminSession?> {
  @override
  Future<AdminSession?> build() => ref.read(sessionStoreProvider).read();

  Future<void> requestCode(String email) => ref.read(adminApiProvider).requestCode(email.trim());

  Future<void> verify(String email, String code) async {
    final result = await ref.read(adminApiProvider).verifyCode(email.trim(), code.trim());
    final session = AdminSession(token: result.token, email: result.email);
    await ref.read(sessionStoreProvider).write(session);
    state = AsyncData(session);
  }

  Future<void> logout() async {
    final token = state.value?.token;
    await ref.read(sessionStoreProvider).clear();
    state = const AsyncData(null);
    if (token != null) {
      try {
        await ref.read(adminApiProvider).logout(token);
      } on Object {
        // The phone has forgotten the session already; the server expires it anyway.
      }
    }
  }

  /// The server no longer accepts the token (expired, logged out elsewhere).
  Future<void> expired() async {
    await ref.read(sessionStoreProvider).clear();
    state = const AsyncData(null);
  }
}

final sessionProvider = AsyncNotifierProvider<SessionController, AdminSession?>(SessionController.new);
