import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../delivery/domain/delivery_models.dart';
import '../../delivery/presentation/delivery_providers.dart';
import '../../delivery/presentation/delivery_widgets.dart';
import 'location_sharing.dart';

/// RIDER landing page: today's jobs (Active / Done). Updates live; pull to refresh.
class RiderHomeScreen extends ConsumerWidget {
  const RiderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final activeCount = ref.watch(riderDeliveriesProvider(true)).value?.length;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.riderTitle),
          actions: [
            IconButton(
              tooltip: l10n.account,
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => context.push(Routes.account),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: activeCount == null || activeCount == 0 ? l10n.riderActive : '${l10n.riderActive} ($activeCount)'),
              Tab(text: l10n.riderDone),
            ],
          ),
        ),
        body: const Column(
          children: [
            SharingBanner(),
            Expanded(child: TabBarView(children: [_Jobs(active: true), _Jobs(active: false)])),
          ],
        ),
      ),
    );
  }
}

/// Tells the rider whether the customer can see them, and how to fix it if not.
class SharingBanner extends ConsumerWidget {
  const SharingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(locationSharingStateProvider);
    final scheme = Theme.of(context).colorScheme;
    return switch (state) {
      SharingState.idle => const SizedBox.shrink(),
      SharingState.sharing => MaterialBanner(
        key: const Key('sharingBanner'),
        backgroundColor: scheme.primaryContainer,
        leading: const Icon(Icons.my_location),
        content: Text(l10n.riderSharingText),
        actions: const [SizedBox.shrink()],
      ),
      SharingState.needsPermission || SharingState.gpsOff => MaterialBanner(
        key: const Key('sharingProblemBanner'),
        backgroundColor: scheme.errorContainer,
        leading: const Icon(Icons.location_disabled),
        content: Text(state == SharingState.gpsOff ? l10n.riderGpsOff : l10n.riderNeedsPermission),
        actions: [TextButton(onPressed: () => retryLocationSharing(ref), child: Text(l10n.retry))],
      ),
    };
  }
}

class _Jobs extends ConsumerWidget {
  const _Jobs({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final jobs = ref.watch(riderDeliveriesProvider(active));
    Future<void> refresh() async => ref.invalidate(riderDeliveriesProvider(active));
    return switch (jobs) {
      AsyncValue(:final value?) => RefreshIndicator(
        onRefresh: refresh,
        child: value.isEmpty
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(active ? l10n.riderNoActive : l10n.riderNoDone, textAlign: TextAlign.center),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: value.length,
                itemBuilder: (context, i) => _JobCard(job: value[i]),
              ),
      ),
      AsyncValue(:final error?) => ErrorView(error: error, onRetry: refresh),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final RiderDelivery job;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        key: ValueKey('job-${job.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(Routes.riderDelivery(job.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l10n.orderNumber(job.orderNumber), style: theme.textTheme.titleMedium),
                  Chip(label: Text(job.status.label(l10n)), visualDensity: VisualDensity.compact),
                ],
              ),
              Text(job.customer.display),
              Text(job.address.summary, style: theme.textTheme.bodySmall),
              Text(
                job.codPaise > 0 ? l10n.riderCollectCash(formatPaise(job.codPaise)) : l10n.riderPrepaid,
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
