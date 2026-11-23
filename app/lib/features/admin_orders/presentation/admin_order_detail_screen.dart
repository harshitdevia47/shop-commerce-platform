import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/launcher.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/splash_view.dart';
import '../../delivery/presentation/delivery_providers.dart';
import '../../delivery/presentation/delivery_widgets.dart';
import '../../orders/domain/order_models.dart';
import '../../orders/presentation/orders_providers.dart';
import '../../orders/presentation/widgets/bill_summary.dart';
import '../../orders/presentation/widgets/order_widgets.dart';

/// One order for the shop: customer, items, payment, and the next step buttons.
class AdminOrderDetailScreen extends ConsumerStatefulWidget {
  const AdminOrderDetailScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends ConsumerState<AdminOrderDetailScreen> {
  bool _busy = false;

  void _refresh() {
    ref
      ..invalidate(adminOrderProvider(widget.orderId))
      ..invalidate(adminPaymentProvider(widget.orderId))
      ..invalidate(adminDeliveryProvider(widget.orderId))
      ..invalidate(adminOrdersProvider);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(context.l10n, error))));
    } finally {
      _refresh();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setStatus(OrderStatus status) async {
    String? reason;
    if (status == OrderStatus.rejected) {
      reason = await _askReason();
      if (reason == null) return;
    }
    await _run(() => ref.read(adminOrdersRepositoryProvider).setStatus(widget.orderId, status, reason: reason));
  }

  Future<String?> _askReason() => showDialog<String>(context: context, builder: (_) => const _RejectDialog());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final order = ref.watch(adminOrderProvider(widget.orderId));
    return Scaffold(
      appBar: AppBar(title: Text(order.value == null ? '' : l10n.orderNumber(order.value!.number))),
      body: switch (order) {
        AsyncValue(:final value?) => _body(context, value),
        AsyncValue(:final error?) => ErrorView(error: error, onRetry: _refresh),
        _ => const SplashView(),
      },
      bottomNavigationBar: switch (order.value) {
        final value? when value.nextStatuses.isNotEmpty => SafeArea(child: _actions(value)),
        _ => null,
      },
    );
  }

  Widget _actions(Order order) {
    final l10n = context.l10n;
    final forward = order.nextStatuses.where((s) => !s.isFailed).firstOrNull;
    final canReject = order.nextStatuses.contains(OrderStatus.rejected);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        spacing: 12,
        children: [
          if (canReject)
            OutlinedButton(
              key: const Key('rejectButton'),
              onPressed: _busy ? null : () => _setStatus(OrderStatus.rejected),
              child: Text(l10n.rejectOrder),
            ),
          if (forward != null)
            Expanded(
              child: FilledButton(
                key: const Key('nextStatusButton'),
                onPressed: _busy ? null : () => _setStatus(forward),
                child: Text(forward.actionLabel(l10n)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, Order order) {
    final l10n = context.l10n;
    final payment = ref.watch(adminPaymentProvider(order.id)).value;
    final launch = ref.read(externalLauncherProvider);
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(order.customerName ?? order.customerPhone),
              subtitle: Text(
                [if (order.customerName != null) order.customerPhone, if (order.address != null) order.address!.summary].join('\n'),
              ),
              isThreeLine: order.customerName != null && order.address != null,
              trailing: IconButton(
                tooltip: l10n.callCustomer,
                icon: const Icon(Icons.call_outlined),
                onPressed: () => launch(Uri(scheme: 'tel', path: order.customerPhone)),
              ),
            ),
          ),
          if (order.note case final note?)
            Card(
              child: ListTile(leading: const Icon(Icons.sticky_note_2_outlined), title: Text(l10n.customerNote), subtitle: Text(note)),
            ),
          AdminRiderCard(order: order),
          Card(child: OrderTimeline(order: order)),
          Card(
            child: ListTile(
              leading: Icon(order.paymentMethod == PaymentMethod.cod ? Icons.payments_outlined : Icons.qr_code_2),
              title: Text(
                '${order.paymentMethod == PaymentMethod.cod ? l10n.paymentCod : l10n.paymentUpi} · ${formatPaise(order.totalPaise)}',
              ),
              subtitle: payment == null
                  ? null
                  : Text([payment.status.label(l10n), if (payment.utr != null) l10n.utrShown(payment.utr!)].join(' · ')),
              trailing: payment != null &&
                      (payment.status == PaymentStatus.pending || payment.status == PaymentStatus.submitted) &&
                      !order.status.isFailed
                  ? TextButton(
                      key: const Key('markPaidButton'),
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              await ref.read(adminOrdersRepositoryProvider).markPaid(order.id);
                            }),
                      child: Text(l10n.markPaid),
                    )
                  : null,
            ),
          ),
          OrderItemsCard(order: order),
          BillSummary(
            subtotalPaise: order.subtotalPaise,
            deliveryFeePaise: order.deliveryFeePaise,
            totalPaise: order.totalPaise,
            showDelivery: order.fulfillment == Fulfillment.delivery,
          ),
        ],
      ),
    );
  }
}

/// Asks why the order is rejected. Owns its controller so it outlives the closing animation.
class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.rejectOrder),
      content: TextField(
        key: const Key('rejectReasonField'),
        controller: _reason,
        autofocus: true,
        maxLength: 200,
        decoration: InputDecoration(labelText: l10n.rejectReason),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        TextButton(
          key: const Key('confirmRejectButton'),
          onPressed: () {
            final reason = _reason.text.trim();
            if (reason.isNotEmpty) Navigator.pop(context, reason);
          },
          child: Text(l10n.rejectOrder),
        ),
      ],
    );
  }
}
