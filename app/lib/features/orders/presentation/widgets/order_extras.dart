import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../private_media/presentation/private_media.dart';
import '../../domain/order_models.dart';
import 'slot_picker.dart';

extension ReturnStatusLabel on ReturnStatus {
  String label(AppLocalizations l10n) => switch (this) {
    ReturnStatus.requested => l10n.returnRequested,
    ReturnStatus.approved => l10n.returnApproved,
    ReturnStatus.rejected => l10n.returnRejected,
    ReturnStatus.completed => l10n.returnCompleted,
  };
}

extension ReturnKindLabel on ReturnKind {
  String label(AppLocalizations l10n) => this == ReturnKind.exchange ? l10n.returnTypeExchange : l10n.returnTypeReturn;
}

/// "Delivery: Today, 12:00 PM – 4:00 PM" (nothing when no window was chosen).
class OrderSlotTile extends StatelessWidget {
  const OrderSlotTile({required this.order, super.key});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final slot = order.slot;
    if (slot == null) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context);
    return Card(
      child: ListTile(
        key: const Key('orderSlot'),
        leading: const Icon(Icons.schedule_outlined),
        title: Text(context.l10n.deliverySlotLine(formatDay(context, slot.start, DateTime.now()), formatWindow(slot, locale))),
      ),
    );
  }
}

/// Prescription / list photos attached to the order (tap to view full size).
class OrderPhotosCard extends StatelessWidget {
  const OrderPhotosCard({required this.photos, required this.title, super.key});

  final List<Attachment> photos;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            Wrap(spacing: 8, runSpacing: 8, children: [for (final p in photos) PrivatePhoto(id: p.id)]),
          ],
        ),
      ),
    );
  }
}

/// List order the shop has not priced yet.
class AwaitingPricingCard extends StatelessWidget {
  const AwaitingPricingCard({required this.order, super.key});

  final Order order;

  @override
  Widget build(BuildContext context) {
    if (!order.needsPricing || order.status.isFailed) return const SizedBox.shrink();
    return Card(
      key: const Key('awaitingPricing'),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(leading: const Icon(Icons.hourglass_top_outlined), title: Text(context.l10n.awaitingPricing)),
    );
  }
}

/// A return / exchange request with its answer. [actions] for the shop.
class ReturnRequestCard extends StatelessWidget {
  const ReturnRequestCard({required this.request, this.actions = const [], super.key});

  final ReturnRequest request;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      key: const Key('returnRequestCard'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(request.type.label(l10n), style: theme.textTheme.titleMedium),
                Chip(label: Text(request.status.label(l10n)), visualDensity: VisualDensity.compact),
              ],
            ),
            for (final line in request.items) Text('${line.qty} × ${line.productName} · ${line.variantLabel}'),
            Text('“${request.reason}”', style: theme.textTheme.bodySmall),
            if (request.photos.isNotEmpty)
              Wrap(spacing: 8, runSpacing: 8, children: [for (final p in request.photos) PrivatePhoto(id: p.id, size: 56)]),
            if (request.shopNote case final note?) Text(l10n.returnShopNote(note), style: theme.textTheme.bodyMedium),
            if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
      ),
    );
  }
}
