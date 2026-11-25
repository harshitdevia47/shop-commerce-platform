import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../api/models.dart';
import '../auth/session.dart';
import '../format.dart';
import '../providers.dart';
import 'error_view.dart';
import 'status_badge.dart';

/// All shops: count tiles, then the list with what needs attention first.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(overviewProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shops'),
        actions: [
          PopupMenuButton<String>(
            key: const Key('menuButton'),
            onSelected: (_) => ref.read(sessionProvider.notifier).logout(),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'logout', child: Text('Log out (${ref.read(sessionProvider).value?.email ?? ''})')),
            ],
          ),
        ],
      ),
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(error: error, onRetry: () => ref.invalidate(overviewProvider)),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(overviewProvider.future).then<void>((_) {}, onError: (_) {}),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Tiles(counts: data.counts),
              const SizedBox(height: 16),
              if (data.rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No shops yet. Add one with "npm run new-shop" on the laptop.', textAlign: TextAlign.center),
                ),
              for (final row in data.rows) _ShopTile(row: row),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tiles extends StatelessWidget {
  const _Tiles({required this.counts});
  final Map<ShopStatus, int> counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = [
      ShopStatus.overdue,
      ShopStatus.due,
      ShopStatus.dueSoon,
      ShopStatus.paid,
      if ((counts[ShopStatus.paused] ?? 0) > 0) ShopStatus.paused,
      if ((counts[ShopStatus.notSetUp] ?? 0) > 0) ShopStatus.notSetUp,
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.15,
      children: [
        for (final status in shown)
          Card(
            key: Key('tile-${status.key}'),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(status.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: statusColor(status, theme.colorScheme), fontWeight: FontWeight.w600)),
                  FittedBox(child: Text('${counts[status] ?? 0}', style: theme.textTheme.headlineSmall)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({required this.row});
  final OverviewRow row;

  @override
  Widget build(BuildContext context) {
    final sub = row.subscription;
    final n = row.numbers;
    return Card(
      child: ListTile(
        key: Key('shop-${row.shop.id}'),
        title: Text(row.shop.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            if (sub != null) '${rupees(sub.feePaise)}/month · due ${niceDate(sub.nextDueDate)}' else 'No subscription yet',
            '${count(n.customers)} customers · ${count(n.orders)} orders this month',
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: StatusBadge(row.status),
        onTap: () => context.push('/shops/${row.shop.id}'),
      ),
    );
  }
}
