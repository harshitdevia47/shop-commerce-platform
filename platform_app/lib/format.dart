import 'package:intl/intl.dart';

/// 99900 → ₹999, 149950 → ₹1,499.50 (Indian grouping).
String rupees(int paise) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: paise % 100 == 0 ? 0 : 2).format(paise / 100);

/// "2026-12-05" → "5 Dec 2026".
String niceDate(String? day) {
  if (day == null || day.length < 10) return '—';
  final date = DateTime.tryParse(day.substring(0, 10));
  return date == null ? day : DateFormat('d MMM y').format(date);
}

String count(int? n) => n == null ? '—' : NumberFormat.decimalPattern('en_IN').format(n);

/// Today in India as YYYY-MM-DD.
String istToday([DateTime? now]) =>
    DateFormat('yyyy-MM-dd').format((now ?? DateTime.now()).toUtc().add(const Duration(hours: 5, minutes: 30)));
