import 'package:flutter/widgets.dart';

/// Shop-entered text in the user's language, falling back to the default text.
String localized(String fallback, Map<String, String>? translations, Locale locale) {
  final value = translations?[locale.languageCode];
  return value == null || value.isEmpty ? fallback : value;
}

Map<String, String>? readI18n(Object? json) =>
    json is Map ? json.map((key, value) => MapEntry(key as String, value as String)) : null;
