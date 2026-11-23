import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/realtime_providers.dart';
import 'orders_providers.dart';

/// Applies live updates: an order or payment changed, so the screens showing it re-fetch.
/// After every (re)connect everything visible is refreshed, covering events missed while offline.
/// Kept alive by `QcApp`.
final orderLiveUpdatesProvider = Provider<void>((ref) {
  ref.watch(realtimeConnectedProvider); // keep the connection state tracked from the start
  final channel = ref.watch(realtimeChannelProvider);
  if (channel == null) return;

  void refreshOrder(String orderId) {
    ref
      ..invalidate(orderProvider(orderId))
      ..invalidate(paymentProvider(orderId))
      ..invalidate(adminOrderProvider(orderId))
      ..invalidate(adminPaymentProvider(orderId))
      ..invalidate(myOrdersProvider)
      ..invalidate(adminOrdersProvider);
  }

  void refreshAll() {
    ref
      ..invalidate(orderProvider)
      ..invalidate(paymentProvider)
      ..invalidate(adminOrderProvider)
      ..invalidate(adminPaymentProvider)
      ..invalidate(myOrdersProvider)
      ..invalidate(adminOrdersProvider);
  }

  final subscriptions = <StreamSubscription<Object?>>[
    channel.events.listen((event) => refreshOrder(event.orderId)),
    channel.connection.where((up) => up).listen((_) => refreshAll()),
  ];
  ref.onDispose(() {
    for (final s in subscriptions) {
      unawaited(s.cancel());
    }
  });
});
