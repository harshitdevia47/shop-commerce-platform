import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/realtime_channel.dart';
import '../../../core/realtime/realtime_providers.dart';
import '../../delivery/domain/delivery_models.dart';
import '../../delivery/presentation/delivery_providers.dart';
import 'orders_providers.dart';

/// Applies live updates: an order or payment changed, so the screens showing it re-fetch.
/// After every (re)connect everything visible is refreshed, covering events missed while offline.
/// Kept alive by `QcApp`.
final orderLiveUpdatesProvider = Provider<void>((ref) {
  ref.watch(realtimeConnectedProvider); // keep the connection state tracked from the start
  final channel = ref.watch(realtimeChannelProvider);
  if (channel == null) return;

  void refreshDeliveries(String orderId) {
    ref
      ..invalidate(customerDeliveryProvider(orderId))
      ..invalidate(adminDeliveryProvider(orderId))
      ..invalidate(riderDeliveriesProvider)
      ..invalidate(riderDeliveryProvider)
      ..invalidate(ridersProvider);
  }

  void refreshOrder(String orderId) {
    ref
      ..invalidate(orderProvider(orderId))
      ..invalidate(paymentProvider(orderId))
      ..invalidate(adminOrderProvider(orderId))
      ..invalidate(adminPaymentProvider(orderId))
      ..invalidate(myOrdersProvider)
      ..invalidate(adminOrdersProvider);
  }

  void onEvent(RealtimeEvent event) {
    switch (event.type) {
      case 'rider.location':
        final data = event.data;
        if (data['lat'] is num && data['lng'] is num && data['at'] is String) {
          ref.read(riderLocationsProvider.notifier).update(event.orderId, RiderLocation.fromJson(data.cast<String, dynamic>()));
        }
      case 'delivery.updated':
        refreshDeliveries(event.orderId);
        refreshOrder(event.orderId);
      default:
        refreshOrder(event.orderId);
        refreshDeliveries(event.orderId);
    }
  }

  void refreshAll() {
    ref
      ..invalidate(orderProvider)
      ..invalidate(paymentProvider)
      ..invalidate(adminOrderProvider)
      ..invalidate(adminPaymentProvider)
      ..invalidate(myOrdersProvider)
      ..invalidate(adminOrdersProvider)
      ..invalidate(customerDeliveryProvider)
      ..invalidate(adminDeliveryProvider)
      ..invalidate(riderDeliveriesProvider)
      ..invalidate(riderDeliveryProvider);
  }

  final subscriptions = <StreamSubscription<Object?>>[
    channel.events.listen(onEvent),
    channel.connection.where((up) => up).listen((_) => refreshAll()),
  ];
  ref.onDispose(() {
    for (final s in subscriptions) {
      unawaited(s.cancel());
    }
  });
});
