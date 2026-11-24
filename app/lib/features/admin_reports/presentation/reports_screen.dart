import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../data/reports_repository.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) => HttpReportsRepository(ref.watch(dioProvider)));

/// Injectable "today" (tests).
final reportsTodayProvider = Provider<DateTime Function()>((ref) => DateTime.now);

enum ReportPeriod { today, yesterday, last7, last30, thisMonth }

class ReportPeriodController extends Notifier<ReportPeriod> {
  @override
  ReportPeriod build() => ReportPeriod.last7;

  void set(ReportPeriod value) => state = value;
}

final reportPeriodProvider = NotifierProvider<ReportPeriodController, ReportPeriod>(ReportPeriodController.new);

/// Shop days for a period (the phone's calendar day is the shop's: both are in India).
ReportRange rangeFor(ReportPeriod period, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return switch (period) {
    ReportPeriod.today => ReportRange(today, today),
    ReportPeriod.yesterday => ReportRange(today.subtract(const Duration(days: 1)), today.subtract(const Duration(days: 1))),
    ReportPeriod.last7 => ReportRange(today.subtract(const Duration(days: 6)), today),
    ReportPeriod.last30 => ReportRange(today.subtract(const Duration(days: 29)), today),
    ReportPeriod.thisMonth => ReportRange(DateTime(today.year, today.month), today),
  };
}

final _rangeProvider = Provider.autoDispose<ReportRange>(
  (ref) => rangeFor(ref.watch(reportPeriodProvider), ref.watch(reportsTodayProvider)()),
);
final salesSummaryProvider = FutureProvider.autoDispose<SalesSummary>(
  (ref) => ref.watch(reportsRepositoryProvider).summary(ref.watch(_rangeProvider)),
);
final dailySalesProvider = FutureProvider.autoDispose<List<DailySales>>(
  (ref) => ref.watch(reportsRepositoryProvider).daily(ref.watch(_rangeProvider)),
);
final topProductsProvider = FutureProvider.autoDispose<List<TopProduct>>(
  (ref) => ref.watch(reportsRepositoryProvider).topProducts(ref.watch(_rangeProvider)),
);

/// Owner: how the shop is doing. Headline numbers first, then the daily chart (with a list view),
/// payment / fulfillment / customer splits, and best sellers.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  void _refresh(WidgetRef ref) {
    ref
      ..invalidate(salesSummaryProvider)
      ..invalidate(dailySalesProvider)
      ..invalidate(topProductsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final period = ref.watch(reportPeriodProvider);
    final summary = ref.watch(salesSummaryProvider);
    final daily = ref.watch(dailySalesProvider).value;
    final top = ref.watch(topProductsProvider).value;
    final labels = {
      ReportPeriod.today: l10n.today,
      ReportPeriod.yesterday: l10n.periodYesterday,
      ReportPeriod.last7: l10n.period7,
      ReportPeriod.last30: l10n.period30,
      ReportPeriod.thisMonth: l10n.periodMonth,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminSales)),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Filters in one row above everything they control.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 8,
                children: [
                  for (final p in ReportPeriod.values)
                    ChoiceChip(
                      key: ValueKey('period-${p.name}'),
                      label: Text(labels[p]!),
                      selected: p == period,
                      onSelected: (_) => ref.read(reportPeriodProvider.notifier).set(p),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            switch (summary) {
              AsyncValue(:final value?) => _Body(summary: value, daily: daily, top: top),
              AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => _refresh(ref)),
              _ => const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator())),
            },
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.summary, required this.daily, required this.top});

  final SalesSummary summary;
  final List<DailySales>? daily;
  final List<TopProduct>? top;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.9,
          children: [
            _StatTile(key: const Key('statSales'), label: l10n.statSales, value: formatPaise(summary.salesPaise)),
            _StatTile(key: const Key('statOrders'), label: l10n.statOrders, value: '${summary.orders}'),
            _StatTile(label: l10n.statAverage, value: formatPaise(summary.averageOrderPaise)),
            _StatTile(label: l10n.statCancelled, value: '${summary.cancelled}'),
          ],
        ),
        Text(l10n.salesNote, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        if (daily != null && daily!.length > 1)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.dailySalesTitle, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  DailySalesChart(days: daily!),
                  ExpansionTile(
                    key: const Key('dayByDay'),
                    tilePadding: EdgeInsets.zero,
                    title: Text(l10n.dayByDay, style: theme.textTheme.bodyMedium),
                    children: [
                      for (final d in daily!.reversed)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(DateFormat.MMMEd(Localizations.localeOf(context).languageCode).format(d.day)),
                          subtitle: Text(l10n.ordersCount(d.orders)),
                          trailing: Text(formatPaise(d.salesPaise)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        Card(
          child: Column(
            children: [
              ListTile(title: Text(l10n.paymentsTitle, style: theme.textTheme.titleSmall)),
              _SplitRow(label: l10n.paymentCod, count: summary.codOrders, paise: summary.codPaise),
              _SplitRow(label: l10n.paymentUpi, count: summary.upiOrders, paise: summary.upiPaise),
              ListTile(dense: true, title: Text(l10n.markedPaidTotal(formatPaise(summary.paidPaise)))),
            ],
          ),
        ),
        Card(
          child: Column(
            children: [
              ListTile(title: Text(l10n.fulfillmentTitle, style: theme.textTheme.titleSmall)),
              ListTile(dense: true, leading: const Icon(Icons.delivery_dining_outlined), title: Text(l10n.deliveryOption), trailing: Text('${summary.delivery}')),
              ListTile(dense: true, leading: const Icon(Icons.storefront_outlined), title: Text(l10n.pickupOption), trailing: Text('${summary.pickup}')),
              ListTile(
                title: Text(l10n.customersTitle, style: theme.textTheme.titleSmall),
                subtitle: Text('${l10n.newCustomers(summary.newCustomers)} · ${l10n.returningCustomers(summary.returningCustomers)}'),
                trailing: Text('${summary.customers}', style: theme.textTheme.titleMedium),
              ),
            ],
          ),
        ),
        Card(
          child: Column(
            children: [
              ListTile(title: Text(l10n.topProductsTitle, style: theme.textTheme.titleSmall)),
              if (top == null)
                const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())
              else if (top!.isEmpty)
                ListTile(title: Text(l10n.noTopProducts))
              else
                for (final (i, p) in top!.indexed)
                  ListTile(
                    key: ValueKey('top-${p.productId}'),
                    leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: theme.textTheme.labelMedium)),
                    title: Text(p.productName),
                    subtitle: Text(l10n.soldQty(p.qty)),
                    trailing: Text(formatPaise(p.salesPaise)),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: theme.textTheme.headlineSmall)),
          ],
        ),
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  const _SplitRow({required this.label, required this.count, required this.paise});

  final String label;
  final int count;
  final int paise;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    title: Text(label),
    subtitle: Text(context.l10n.ordersCount(count)),
    trailing: Text(formatPaise(paise)),
  );
}

/// One series: sales per day as bars in the shop's colour (thin bars, 4 px rounded tops, 2 px gaps,
/// a quiet baseline). Tapping a bar shows that day's value; the list below is the table view.
class DailySalesChart extends StatefulWidget {
  const DailySalesChart({required this.days, super.key});

  final List<DailySales> days;

  @override
  State<DailySalesChart> createState() => _DailySalesChartState();
}

class _DailySalesChartState extends State<DailySalesChart> {
  int? _selected;

  @override
  void didUpdateWidget(DailySalesChart old) {
    super.didUpdateWidget(old);
    if (old.days.length != widget.days.length) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final days = widget.days;
    final max = days.fold(0, (m, d) => d.salesPaise > m ? d.salesPaise : m);
    final selected = _selected == null ? null : days[_selected!];
    final dayFormat = DateFormat.MMMd(locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          selected == null
              ? l10n.tapBarHint
              : '${DateFormat.MMMEd(locale).format(selected.day)} · ${formatPaise(selected.salesPaise)} · ${l10n.ordersCount(selected.orders)}',
          key: const Key('chartReadout'),
          style: theme.textTheme.bodySmall?.copyWith(color: selected == null ? theme.colorScheme.outline : null),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, d) in days.indexed)
                Expanded(
                  child: GestureDetector(
                    key: ValueKey('bar-$i'),
                    behavior: HitTestBehavior.opaque, // the whole column is the hit target, not just the bar
                    onTap: () => setState(() => _selected = _selected == i ? null : i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1), // 2 px gap between bars
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: max == 0 ? 0 : d.salesPaise / max,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _selected == null || _selected == i
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withValues(alpha: 0.35),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(dayFormat.format(days.first.day), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
            Text(dayFormat.format(days.last.day), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ],
    );
  }
}
