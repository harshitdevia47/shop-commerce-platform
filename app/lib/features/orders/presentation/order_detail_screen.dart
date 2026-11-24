import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/shop_settings.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/realtime/realtime_providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/launcher.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/splash_view.dart';
import '../../delivery/presentation/delivery_providers.dart';
import '../../delivery/presentation/delivery_widgets.dart';
import '../domain/order_models.dart';
import 'orders_providers.dart';
import 'widgets/bill_summary.dart';
import 'widgets/order_extras.dart';
import 'widgets/order_widgets.dart';

/// Customer's view of one order: progress, payment, items, cancel.
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({required this.orderId, this.justPlaced = false, super.key});

  final String orderId;
  final bool justPlaced;

  /// Open orders refresh on this interval only while live updates are down.
  static const refreshEvery = Duration(seconds: 30);

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(OrderDetailScreen.refreshEvery, (_) {
      final order = ref.read(orderProvider(widget.orderId)).value;
      if (order != null && !order.status.isDone && !ref.isLive) _refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Returns are on, the order was handed over within the shop's window, nothing asked yet.
  bool _canAskReturn(Order order) {
    final settings = ref.read(shopSettingsProvider).value;
    final handedOver = order.handedOverAt;
    if (settings == null || !settings.isEnabled(Feature.returns) || order.returnRequest != null || handedOver == null) {
      return false;
    }
    return DateTime.now().difference(handedOver) <= Duration(days: settings.returns.windowDays);
  }

  void _refresh() {
    ref
      ..invalidate(orderProvider(widget.orderId))
      ..invalidate(paymentProvider(widget.orderId))
      ..invalidate(customerDeliveryProvider(widget.orderId));
  }

  Future<void> _cancel() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.cancelOrderConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.keepOrder)),
          TextButton(
            key: const Key('confirmCancelButton'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.cancelOrder),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(ordersRepositoryProvider).cancel(widget.orderId);
      ref.invalidate(myOrdersProvider);
    } on Object catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(l10n, error))));
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final order = ref.watch(orderProvider(widget.orderId));
    final shopPhone = ref.watch(shopSettingsProvider).value?.shop.phone;

    return Scaffold(
      appBar: AppBar(
        title: Text(order.value == null ? '' : l10n.orderNumber(order.value!.number)),
        actions: [
          if (shopPhone != null)
            IconButton(
              tooltip: l10n.callShop,
              icon: const Icon(Icons.call_outlined),
              onPressed: () => ref.read(externalLauncherProvider)(Uri(scheme: 'tel', path: shopPhone)),
            ),
        ],
      ),
      body: switch (order) {
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (widget.justPlaced)
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.check_circle, size: 32),
                    title: Text(l10n.orderPlacedTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(l10n.orderNumber(value.number)),
                  ),
                ),
              CustomerDeliveryCard(order: value),
              AwaitingPricingCard(order: value),
              if (value.returnRequest case final request?) ReturnRequestCard(request: request),
              OrderSlotTile(order: value),
              Card(child: OrderTimeline(order: value)),
              const SizedBox(height: 8),
              if (!value.needsPricing) ...[_PaymentCard(order: value), const SizedBox(height: 8)],
              OrderPhotosCard(photos: value.attachments, title: l10n.yourPhotos),
              OrderItemsCard(order: value),
              const SizedBox(height: 8),
              if (!value.needsPricing)
                BillSummary(
                  subtotalPaise: value.subtotalPaise,
                  deliveryFeePaise: value.deliveryFeePaise,
                  totalPaise: value.totalPaise,
                  showDelivery: value.fulfillment == Fulfillment.delivery,
                ),
              if (value.address case final address?)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(l10n.deliverTo),
                    subtitle: Text(address.summary),
                  ),
                ),
              if (_canAskReturn(value)) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const Key('requestReturnButton'),
                  icon: const Icon(Icons.assignment_return_outlined),
                  label: Text(l10n.requestReturn),
                  onPressed: () => context.push('${Routes.order(value.id)}/return'),
                ),
              ],
              if (value.canCancel) ...[
                const SizedBox(height: 16),
                OutlinedButton(key: const Key('cancelOrderButton'), onPressed: _cancel, child: Text(l10n.cancelOrder)),
              ],
            ],
          ),
        ),
        AsyncValue(:final error?) => ErrorView(error: error, onRetry: _refresh),
        _ => const SplashView(),
      },
    );
  }
}

/// How to pay: cash note, or the UPI button and UTR form, plus the payment status.
class _PaymentCard extends ConsumerStatefulWidget {
  const _PaymentCard({required this.order});

  final Order order;

  @override
  ConsumerState<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends ConsumerState<_PaymentCard> {
  final _utr = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _utr.dispose();
    super.dispose();
  }

  Future<void> _payWithUpi(String uri) async {
    final opened = await ref.read(externalLauncherProvider)(Uri.parse(uri));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.noUpiApp)));
    }
  }

  Future<void> _submitUtr() async {
    final l10n = context.l10n;
    if (!RegExp(r'^\d{12}$').hasMatch(_utr.text)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.utrInvalid)));
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(ordersRepositoryProvider).submitUtr(widget.order.id, _utr.text);
      ref.invalidate(paymentProvider(widget.order.id));
    } on Object catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(l10n, error))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final order = widget.order;
    final payment = ref.watch(paymentProvider(order.id)).value;
    final amount = formatPaise(order.totalPaise);
    final open =
        payment != null && (payment.status == PaymentStatus.pending || payment.status == PaymentStatus.submitted);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Row(
              children: [
                Icon(order.paymentMethod == PaymentMethod.cod ? Icons.payments_outlined : Icons.qr_code_2),
                const SizedBox(width: 12),
                // Status under the method, not beside it: long Gujarati/Hindi labels need the width.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.paymentMethod == PaymentMethod.cod ? l10n.paymentCod : l10n.paymentUpi,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (payment != null)
                        Text(
                          payment.status.label(l10n),
                          key: const Key('paymentStatus'),
                          style: TextStyle(
                            color: payment.status == PaymentStatus.paid
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (order.paymentMethod == PaymentMethod.cod && open && !order.status.isFailed)
              Text(l10n.payOnDelivery(amount)),
            if (payment?.upiUri case final uri? when !order.status.isFailed && payment!.status == PaymentStatus.pending)
              FilledButton.icon(
                key: const Key('payUpiButton'),
                onPressed: () => _payWithUpi(uri),
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.payWithUpi(amount)),
              ),
            if (order.paymentMethod == PaymentMethod.upi && open && !order.status.isFailed) ...[
              if (payment.utr case final utr?) Text(l10n.utrShown(utr)),
              Text(l10n.utrPrompt, style: Theme.of(context).textTheme.bodySmall),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('utrField'),
                      controller: _utr,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
                      decoration: InputDecoration(
                        labelText: l10n.utrLabel,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  FilledButton.tonal(
                    key: const Key('submitUtrButton'),
                    // The theme's full-width minimum size cannot work inside a Row.
                    style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
                    onPressed: _sending ? null : _submitUtr,
                    child: Text(l10n.submit),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
