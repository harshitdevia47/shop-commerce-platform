import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import 'orders_providers.dart';
import 'widgets/order_widgets.dart';

class MyOrdersScreen extends ConsumerWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final orders = ref.watch(myOrdersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.ordersTitle)),
      body: switch (orders) {
        AsyncValue(:final value?) when value.isEmpty => Center(child: Text(l10n.noOrders)),
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(myOrdersProvider),
          child: ListView.separated(
            itemCount: value.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final order = value[index];
              return ListTile(
                key: ValueKey('order-${order.id}'),
                title: Text(l10n.orderNumber(order.number)),
                subtitle: Text('${formatOrderTime(context, order.placedAt)} · ${l10n.cartItems(order.itemCount)} · ${formatPaise(order.totalPaise)}'),
                trailing: OrderStatusChip(order.status),
                onTap: () => context.push(Routes.order(order.id)),
              );
            },
          ),
        ),
        AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(myOrdersProvider)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
