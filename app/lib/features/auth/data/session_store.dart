import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/auth_models.dart';

/// Where the signed-in session (tokens + user) lives between app launches.
abstract interface class SessionStore {
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> clear();
}

/// Android Keystore / iOS Keychain backed storage.
class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth_session_v1';
  final FlutterSecureStorage _storage;

  /// Cached so every request does not hit the keystore.
  AuthSession? _cache;
  bool _loaded = false;

  @override
  Future<AuthSession?> read() async {
    if (_loaded) return _cache;
    try {
      final raw = await _storage.read(key: _key);
      _cache = raw == null ? null : AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      // Corrupt or undecryptable (e.g. restored backup): start signed out.
      await _storage.delete(key: _key);
      _cache = null;
    }
    _loaded = true;
    return _cache;
  }

  @override
  Future<void> write(AuthSession session) async {
    _cache = session;
    _loaded = true;
    await _storage.write(key: _key, value: jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() async {
    _cache = null;
    _loaded = true;
    await _storage.delete(key: _key);
  }
}

/// For tests.
class InMemorySessionStore implements SessionStore {
  InMemorySessionStore([this.session]);

  AuthSession? session;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession session) async => this.session = session;

  @override
  Future<void> clear() async => session = null;
}
