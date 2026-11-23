import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/cart.dart';

/// Keeps the cart across app restarts. Each shop is its own app, so one key is enough.
class CartStore {
  CartStore(this._prefs);

  static const _key = 'cart_v1';
  final SharedPreferences _prefs;

  Cart read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const Cart();
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return Cart([for (final item in list) CartLine.fromJson(item as Map<String, dynamic>)]);
    } on Object {
      return const Cart(); // corrupt or old format: start fresh rather than crash
    }
  }

  Future<void> write(Cart cart) => cart.isEmpty
      ? _prefs.remove(_key)
      : _prefs.setString(_key, jsonEncode([for (final l in cart.lines) l.toJson()]));
}
