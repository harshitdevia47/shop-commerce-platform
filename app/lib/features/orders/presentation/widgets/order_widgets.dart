import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/providers.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/server_image.dart';
import '../../domain/order_models.dart';

String formatOrderTime(BuildContext context, DateTime at) =>
    DateFormat('d MMM, h:mm a', Localizations.localeOf(context).languageCode).format(at);

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip(this.status, {super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      _ when status.isFailed => (scheme.errorContainer, scheme.onErrorContainer),
      OrderStatus.delivered || OrderStatus.pickedUp => (scheme.primaryContainer, scheme.onPrimaryContainer),
      OrderStatus.placed => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      _ => (scheme.secondaryContainer, scheme.onSecondaryContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
      child: Text(
        status.label(context.l10n),
        style: TextStyle(color: foreground, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

/// Progress through the normal path for the order's fulfillment type.
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({required this.order, super.key});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    if (order.status.isFailed) {
      final change = order.history.where((h) => h.status == order.status).lastOrNull;
      return ListTile(
        leading: Icon(Icons.cancel_outlined, color: scheme.error),
        title: Text(order.status.label(l10n)),
        subtitle: order.cancelReason == null ? null : Text(l10n.rejectedBecause(order.cancelReason!)),
        trailing: change == null ? null : Text(formatOrderTime(context, change.at)),
      );
    }
    final path = order.fulfillment == Fulfillment.delivery
        ? const [OrderStatus.placed, OrderStatus.confirmed, OrderStatus.packed, OrderStatus.outForDelivery, OrderStatus.delivered]
        : const [OrderStatus.placed, OrderStatus.confirmed, OrderStatus.packed, OrderStatus.readyForPickup, OrderStatus.pickedUp];
    final reached = path.indexOf(order.status);
    return Column(
      children: [
        for (final (i, step) in path.indexed)
          ListTile(
            dense: true,
            leading: Icon(
              i <= reached ? Icons.check_circle : Icons.radio_button_unchecked,
              color: i <= reached ? scheme.primary : scheme.outlineVariant,
            ),
            title: Text(
              step.label(l10n),
              style: TextStyle(fontWeight: i == reached ? FontWeight.bold : null, color: i <= reached ? null : scheme.outline),
            ),
            trailing: switch (order.history.where((h) => h.status == step).lastOrNull) {
              final change? => Text(formatOrderTime(context, change.at)),
              null => null,
            },
          ),
      ],
    );
  }
}

class OrderItemsCard extends ConsumerWidget {
  const OrderItemsCard({required this.order, super.key});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final theme = Theme.of(context);
    return Card(
      child: Column(
        children: [
          for (final item in order.items)
            ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox.square(dimension: 44, child: ServerImage(item.thumbUrl)),
              ),
              title: Text(item.localizedName(locale)),
              subtitle: Text(
                [if (item.variantLabel.isNotEmpty) item.localizedLabel(locale), '${item.qty} × ${formatPaise(item.pricePaise)}'].join(' · '),
                style: TextStyle(color: theme.colorScheme.outline),
              ),
              trailing: Text(formatPaise(item.lineTotalPaise), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
