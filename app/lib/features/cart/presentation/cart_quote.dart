import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../orders/domain/order_models.dart';
import '../../orders/presentation/orders_providers.dart';
import 'cart_controller.dart';

/// Delivery or pickup, chosen in the cart. Defaults to delivery when the shop delivers.
class FulfillmentController extends Notifier<Fulfillment> {
  @override
  Fulfillment build() {
    final settings = ref.watch(shopSettingsProvider).value;
    return settings == null || settings.delivery.enabled ? Fulfillment.delivery : Fulfillment.pickup;
  }

  void set(Fulfillment value) => state = value;
}

final fulfillmentProvider = NotifierProvider<FulfillmentController, Fulfillment>(FulfillmentController.new);

/// Server price of the cart. Re-fetched (debounced) whenever the cart or fulfillment changes.
final cartQuoteProvider = FutureProvider.autoDispose<Quote?>((ref) async {
  final cart = ref.watch(cartProvider);
  final fulfillment = ref.watch(fulfillmentProvider);
  if (cart.isEmpty) return null;

  // Rapid +/+/+ taps: wait for a pause, then ask once. A newer change disposes this run.
  var cancelled = false;
  ref.onDispose(() => cancelled = true);
  await Future<void>.delayed(quoteDebounce);
  if (cancelled) throw StateError('superseded');

  return ref.watch(ordersRepositoryProvider).quote(cart.toRequestItems(), fulfillment);
});

/// Overridable in tests.
Duration quoteDebounce = const Duration(milliseconds: 300);
