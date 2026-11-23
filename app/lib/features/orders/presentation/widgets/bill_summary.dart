import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/utils/money.dart';

/// Item total, delivery fee and amount to pay.
class BillSummary extends StatelessWidget {
  const BillSummary({
    required this.subtotalPaise,
    required this.deliveryFeePaise,
    required this.totalPaise,
    this.showDelivery = true,
    this.savingsPaise = 0,
    super.key,
  });

  final int subtotalPaise;
  final int deliveryFeePaise;
  final int totalPaise;
  final bool showDelivery;
  final int savingsPaise;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    Widget row(String label, String value, {TextStyle? style, Key? key}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, key: key, style: style),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.billDetails, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            row(l10n.itemTotal, formatPaise(subtotalPaise)),
            if (showDelivery)
              row(l10n.deliveryFeeLabel, deliveryFeePaise == 0 ? l10n.free : formatPaise(deliveryFeePaise)),
            const Divider(),
            row(
              l10n.toPay,
              formatPaise(totalPaise),
              key: const Key('billTotal'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (savingsPaise > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.youSave(formatPaise(savingsPaise)),
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
