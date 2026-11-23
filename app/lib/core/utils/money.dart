import 'package:intl/intl.dart';

/// Formats integer paise as rupees with Indian digit grouping: 123456 -> ₹1,234.56, 50000 -> ₹500.
/// Money is always `int` paise in the app; convert only for display.
String formatPaise(int paise) {
  final wholeRupees = paise % 100 == 0;
  final format = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: wholeRupees ? 0 : 2);
  return format.format(paise / 100);
}

/// Parses rupees typed by a shop owner ("120", "120.5", "1,200.50") into paise. Null when invalid.
int? parseRupees(String input) {
  final text = input.replaceAll(',', '').trim();
  final match = RegExp(r'^(\d{1,7})(?:\.(\d{1,2}))?$').firstMatch(text);
  if (match == null) return null;
  final rupees = int.parse(match.group(1)!);
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  return rupees * 100 + int.parse(fraction);
}

/// Paise as an editable rupee string: 12000 -> "120", 12050 -> "120.50".
String paiseToInput(int paise) =>
    paise % 100 == 0 ? '${paise ~/ 100}' : '${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';
