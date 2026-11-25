import 'package:material_ui/material_ui.dart';

import '../api/models.dart';

/// Status colours with readable text (never colour alone: the label is always shown).
Color statusColor(ShopStatus status, ColorScheme scheme) => switch (status) {
  ShopStatus.overdue || ShopStatus.paused => scheme.error,
  ShopStatus.due => const Color(0xFFB26A00),
  ShopStatus.dueSoon => scheme.primary,
  ShopStatus.paid => const Color(0xFF2E7D32),
  ShopStatus.notSetUp => scheme.outline,
};

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final ShopStatus status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(999)),
      child: Text(status.label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
