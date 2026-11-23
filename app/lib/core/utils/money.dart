import 'package:intl/intl.dart';

/// Formats integer paise as rupees with Indian digit grouping: 123456 -> ₹1,234.56, 50000 -> ₹500.
/// Money is always `int` paise in the app; convert only for display.
String formatPaise(int paise) {
  final wholeRupees = paise % 100 == 0;
  final format = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: wholeRupees ? 0 : 2);
  return format.format(paise / 100);
}
