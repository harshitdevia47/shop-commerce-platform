import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/utils/launcher.dart';
import '../../orders/domain/order_models.dart';
import '../../orders/presentation/orders_providers.dart';
import '../domain/delivery_models.dart';
import 'delivery_providers.dart';

extension DeliveryStatusLabel on DeliveryStatus {
  String label(AppLocalizations l10n) => switch (this) {
    DeliveryStatus.assigned => l10n.deliveryAssigned,
    DeliveryStatus.pickedUp => l10n.deliveryPickedUp,
    DeliveryStatus.delivered => l10n.deliveryDelivered,
    DeliveryStatus.cancelled => l10n.deliveryCancelled,
  };
}

const _assignable = [OrderStatus.confirmed, OrderStatus.packed];
const _withRider = [OrderStatus.confirmed, OrderStatus.packed, OrderStatus.outForDelivery, OrderStatus.delivered];

/// Shop order screen: who delivers, and assigning / changing the rider before pickup.
class AdminRiderCard extends ConsumerWidget {
  const AdminRiderCard({required this.order, super.key});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (order.fulfillment != Fulfillment.delivery || !_withRider.contains(order.status)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final delivery = ref.watch(adminDeliveryProvider(order.id)).value;
    final active = delivery != null && delivery.status != DeliveryStatus.cancelled;
    final canAssign = _assignable.contains(order.status) && (!active || delivery.status == DeliveryStatus.assigned);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.two_wheeler_outlined),
              title: Text(active ? delivery.rider.display : l10n.noRiderYet),
              subtitle: Text(active ? delivery.status.label(l10n) : l10n.deliverySection),
              trailing: active
                  ? IconButton(
                      tooltip: l10n.callRider,
                      icon: const Icon(Icons.call_outlined),
                      onPressed: () => ref.read(externalLauncherProvider)(Uri(scheme: 'tel', path: delivery.rider.phone)),
                    )
                  : null,
            ),
            if (canAssign)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: OutlinedButton.icon(
                  key: const Key('assignRiderButton'),
                  icon: const Icon(Icons.person_add_alt_outlined),
                  label: Text(active ? l10n.changeRider : l10n.assignRider),
                  onPressed: () => showAssignRiderSheet(context, order.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> showAssignRiderSheet(BuildContext context, String orderId) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (_) => _AssignRiderSheet(orderId: orderId),
);

class _AssignRiderSheet extends ConsumerStatefulWidget {
  const _AssignRiderSheet({required this.orderId});

  final String orderId;

  @override
  ConsumerState<_AssignRiderSheet> createState() => _AssignRiderSheetState();
}

class _AssignRiderSheetState extends ConsumerState<_AssignRiderSheet> {
  bool _busy = false;

  Future<void> _assign(Rider rider) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref.read(adminDeliveryRepositoryProvider).assign(widget.orderId, rider.id);
      ref
        ..invalidate(adminDeliveryProvider(widget.orderId))
        ..invalidate(ridersProvider)
        ..invalidate(adminOrderProvider(widget.orderId));
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, error))));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final riders = ref.watch(ridersProvider);
    final current = ref.watch(adminDeliveryProvider(widget.orderId)).value;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l10n.chooseRider, style: Theme.of(context).textTheme.titleMedium),
          ),
          switch (riders) {
            AsyncValue(:final value?) when value.isEmpty => Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noRiders)),
            AsyncValue(:final value?) => Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final rider in value)
                    ListTile(
                      key: ValueKey('rider-${rider.id}'),
                      enabled: !_busy,
                      leading: const Icon(Icons.two_wheeler_outlined),
                      title: Text(rider.display),
                      subtitle: Text('${rider.phone} · ${l10n.riderActiveCount(rider.activeDeliveries)}'),
                      trailing: current?.rider.id == rider.id && current?.status == DeliveryStatus.assigned
                          ? const Icon(Icons.check_circle)
                          : null,
                      onTap: () => _assign(rider),
                    ),
                ],
              ),
            ),
            AsyncValue(:final error?) => Padding(padding: const EdgeInsets.all(16), child: Text(errorMessage(l10n, error))),
            _ => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          },
        ],
      ),
    );
  }
}

/// Customer order screen: the rider, the door code, and how far away the rider is.
class CustomerDeliveryCard extends ConsumerWidget {
  const CustomerDeliveryCard({required this.order, super.key});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (order.fulfillment != Fulfillment.delivery || order.status.isDone) return const SizedBox.shrink();
    final delivery = ref.watch(customerDeliveryProvider(order.id)).value;
    if (delivery == null || !delivery.status.isActive) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final launch = ref.read(externalLauncherProvider);
    final live = ref.watch(riderLocationsProvider.select((all) => all[order.id]));
    final location = delivery.status == DeliveryStatus.pickedUp ? (live ?? delivery.location) : null;
    final destination = order.address;
    final km = location != null && destination?.lat != null && destination?.lng != null
        ? haversineKm(location.lat, location.lng, destination!.lat!, destination.lng!)
        : null;

    return Card(
      key: const Key('customerDeliveryCard'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deliveryPartner, style: theme.textTheme.labelLarge),
            Row(
              children: [
                const Icon(Icons.two_wheeler_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(delivery.rider.display, style: theme.textTheme.titleMedium),
                      Text(delivery.status.label(l10n), style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.callRider,
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () => launch(Uri(scheme: 'tel', path: delivery.rider.phone)),
                ),
              ],
            ),
            if (delivery.status == DeliveryStatus.pickedUp) ...[
              const SizedBox(height: 8),
              Text(
                km != null ? l10n.deliveryRiderDistance(km.toStringAsFixed(1), etaMinutes(km)) : l10n.deliveryRiderOnTheWay,
                key: const Key('riderDistance'),
              ),
              if (location != null)
                TextButton.icon(
                  key: const Key('trackOnMapButton'),
                  icon: const Icon(Icons.map_outlined),
                  label: Text(l10n.deliveryTrackOnMap),
                  onPressed: () => launch(mapsUri(lat: location.lat, lng: location.lng)),
                ),
            ],
            if (delivery.otp case final otp?) ...[
              const Divider(height: 24),
              Text(l10n.deliveryOtpLabel, style: theme.textTheme.labelLarge),
              Text(otp, key: const Key('deliveryOtp'), style: theme.textTheme.displaySmall?.copyWith(letterSpacing: 8)),
              Text(l10n.deliveryOtpHint, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
