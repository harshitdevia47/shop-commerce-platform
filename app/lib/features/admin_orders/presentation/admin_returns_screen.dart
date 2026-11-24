import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/error_view.dart';
import '../../orders/domain/order_models.dart';
import '../../orders/presentation/orders_providers.dart';
import '../../orders/presentation/widgets/order_extras.dart';

/// Shop: return / exchange requests. Open ones need an answer; tap opens the order to decide.
class AdminReturnsScreen extends ConsumerWidget {
  const AdminReturnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.adminReturns),
          bottom: TabBar(tabs: [Tab(text: l10n.returnsOpen), Tab(text: l10n.returnsAll)]),
        ),
        body: const TabBarView(children: [_Requests(status: ReturnStatus.requested), _Requests(status: null)]),
      ),
    );
  }
}

class _Requests extends ConsumerWidget {
  const _Requests({required this.status});

  final ReturnStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final requests = ref.watch(adminReturnsProvider(status));
    Future<void> refresh() async => ref.invalidate(adminReturnsProvider(status));
    return switch (requests) {
      AsyncValue(:final value?) => RefreshIndicator(
        onRefresh: refresh,
        child: value.isEmpty
            ? ListView(children: [Padding(padding: const EdgeInsets.all(32), child: Text(l10n.noReturns, textAlign: TextAlign.center))])
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final r in value)
                    Card(
                      child: ListTile(
                        key: ValueKey('return-${r.id}'),
                        leading: Icon(r.type == ReturnKind.exchange ? Icons.swap_horiz : Icons.assignment_return_outlined),
                        title: Text('${l10n.orderNumber(r.orderNumber)} · ${r.type.label(l10n)}'),
                        subtitle: Text('${r.status.label(l10n)}\n${r.reason}', maxLines: 2, overflow: TextOverflow.ellipsis),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(Routes.adminOrder(r.orderId)),
                      ),
                    ),
                ],
              ),
      ),
      AsyncValue(:final error?) => ErrorView(error: error, onRetry: refresh),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}
