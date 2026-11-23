import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/utils/money.dart';
import '../../domain/catalog_models.dart';

/// Price, struck-through MRP and discount badge of a variant.
class PriceTag extends StatelessWidget {
  const PriceTag(this.variant, {this.large = false, super.key});

  final Variant variant;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final discount = variant.discountPercent;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Text(
          formatPaise(variant.pricePaise),
          style: (large ? theme.textTheme.titleLarge : theme.textTheme.titleSmall)?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (discount != null) ...[
          Text(
            formatPaise(variant.mrpPaise!),
            style: theme.textTheme.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: theme.colorScheme.outline,
            ),
          ),
          Text(
            context.l10n.percentOff(discount),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }
}
