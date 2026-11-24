import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/realtime/realtime_providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../orders/domain/order_models.dart';
import '../../orders/presentation/orders_providers.dart';
import '../../orders/presentation/widgets/order_extras.dart';
import '../../orders/presentation/widgets/order_widgets.dart';
import '../../orders/presentation/widgets/slot_picker.dart';

/// Shop's order inbox: New / In progress / Completed. Live updates; polls while they are down.
class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  static const refreshEvery = Duration(seconds: 20);
  static const groups = ['new', 'active', 'done'];

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(AdminOrdersScreen.refreshEvery, (_) {
      if (!ref.isLive) ref.invalidate(adminOrdersProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final newCount = ref.watch(adminOrdersProvider('new')).value?.length;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.adminOrders),
          bottom: TabBar(
            tabs: [
              Tab(text: newCount == null || newCount == 0 ? l10n.tabNew : '${l10n.tabNew} ($newCount)'),
              Tab(text: l10n.tabActive),
              Tab(text: l10n.tabDone),
            ],
          ),
        ),
        body: TabBarView(children: [for (final group in AdminOrdersScreen.groups) _OrderList(group: group)]),
      ),
    );
  }
}

class _OrderList extends ConsumerWidget {
  const _OrderList({required this.group});

  final String group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final orders = ref.watch(adminOrdersProvider(group));
    return switch (orders) {
      AsyncValue(:final value?) when value.isEmpty => RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminOrdersProvider(group)),
        child: ListView(children: [Padding(padding: const EdgeInsets.all(48), child: Center(child: Text(l10n.noOrdersHere)))]),
      ),
      AsyncValue(:final value?) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminOrdersProvider(group)),
        child: ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: value.length,
          itemBuilder: (context, index) => _OrderCard(order: value[index]),
        ),
      ),
      AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(adminOrdersProvider(group))),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: ValueKey('admin-order-${order.id}'),
        onTap: () => context.push(Routes.adminOrder(order.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Row(
                children: [
                  Text(l10n.orderNumber(order.number), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Icon(order.fulfillment == Fulfillment.delivery ? Icons.delivery_dining_outlined : Icons.storefront_outlined, size: 18),
                  const Spacer(),
                  OrderStatusChip(order.status),
                ],
              ),
              Text('${order.customerName ?? order.customerPhone} · ${formatOrderTime(context, order.placedAt)}'),
              Text(
                [
                  if (order.needsPricing) l10n.listOrderBadge else '${l10n.cartItems(order.itemCount)} · ${formatPaise(order.totalPaise)}',
                  order.paymentMethod.label(l10n),
                ].join(' · '),
                style: TextStyle(color: theme.colorScheme.outline),
              ),
              if (order.slot case final slot?)
                Text(
                  l10n.deliverySlotLine(
                    formatDay(context, slot.start, DateTime.now()),
                    formatWindow(slot, Localizations.localeOf(context)),
                  ),
                  style: theme.textTheme.labelLarge,
                ),
              if (order.returnRequest case final request? when request.status == ReturnStatus.requested)
                Text('${request.type.label(l10n)} · ${request.status.label(l10n)}', style: TextStyle(color: theme.colorScheme.error)),
            ],
          ),
        ),
      ),
    );
  }
}
