import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qc_app/features/admin_reports/data/reports_repository.dart';
import 'package:qc_app/features/admin_reports/presentation/reports_screen.dart';
import 'package:qc_app/features/auth/domain/auth_models.dart';

import 'ordering_test.dart' show pumpShop, sessionFor;

class FakeReports implements ReportsRepository {
  final List<ReportRange> asked = [];
  List<TopProduct> top = const [
    TopProduct(productId: 'p1', productName: 'Basmati Rice', qty: 12, salesPaise: 144000),
    TopProduct(productId: 'p2', productName: 'Toor Dal', qty: 5, salesPaise: 45000),
  ];

  @override
  Future<SalesSummary> summary(ReportRange range) async {
    asked.add(range);
    return const SalesSummary(
      orders: 9,
      cancelled: 1,
      open: 2,
      completed: 7,
      salesPaise: 259500,
      averageOrderPaise: 28833,
      paidPaise: 51900,
      codOrders: 7,
      codPaise: 207600,
      upiOrders: 2,
      upiPaise: 51900,
      delivery: 6,
      pickup: 3,
      customers: 5,
      newCustomers: 3,
      returningCustomers: 2,
    );
  }

  @override
  Future<List<DailySales>> daily(ReportRange range) async => [
    for (var d = range.from; !d.isAfter(range.to); d = d.add(const Duration(days: 1)))
      DailySales(day: d, orders: d.day == 23 ? 5 : 1, salesPaise: d.day == 23 ? 150000 : 10000),
  ];

  @override
  Future<List<TopProduct>> topProducts(ReportRange range, {int limit = 10}) async => top;
}

void main() {
  late FakeReports reports;
  List<Override> overrides() => [
    reportsRepositoryProvider.overrideWithValue(reports),
    reportsTodayProvider.overrideWithValue(() => DateTime(2026, 11, 24, 15)),
  ];
  setUp(() => reports = FakeReports());

  test('periods map to shop days', () {
    final now = DateTime(2026, 11, 24, 15);
    String fmt(ReportPeriod p) => rangeFor(p, now).query.values.join('..');
    expect(fmt(ReportPeriod.today), '2026-11-24..2026-11-24');
    expect(fmt(ReportPeriod.yesterday), '2026-11-23..2026-11-23');
    expect(fmt(ReportPeriod.last7), '2026-11-18..2026-11-24');
    expect(fmt(ReportPeriod.last30), '2026-10-26..2026-11-24');
    expect(fmt(ReportPeriod.thisMonth), '2026-11-01..2026-11-24');
  });

  testWidgets('owner sees sales, the daily chart with a readout, splits and best sellers', (tester) async {
    await pumpShop(tester, session: sessionFor(UserRole.owner), extraOverrides: overrides());
    await tester.tap(find.byKey(const Key('adminSalesTile')));
    await tester.pumpAndSettle();

    expect(reports.asked.single.query, {'from': '2026-11-18', 'to': '2026-11-24'});
    expect(find.descendant(of: find.byKey(const Key('statSales')), matching: find.text('₹2,595')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('statOrders')), matching: find.text('9')), findsOneWidget);
    expect(find.text('Tap a bar to see that day.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bar-5'))); // 23 Nov
    await tester.pump();
    expect(find.text('Mon, Nov 23 · ₹1,500 · 5 orders'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Basmati Rice'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('12 sold'), findsOneWidget);
    expect(find.text('3 new · 2 returning'), findsOneWidget);

    await tester.scrollUntilVisible(find.byKey(const ValueKey('period-last30')), -200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('period-last30')));
    await tester.pumpAndSettle();
    expect(reports.asked.last.query, {'from': '2026-10-26', 'to': '2026-11-24'});
  });

  testWidgets('a single day shows numbers without a chart; no sales says so', (tester) async {
    reports.top = const [];
    await pumpShop(tester, session: sessionFor(UserRole.owner), extraOverrides: overrides());
    await tester.tap(find.byKey(const Key('adminSalesTile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('period-today')));
    await tester.pumpAndSettle();
    expect(find.byType(DailySalesChart), findsNothing);
    await tester.scrollUntilVisible(find.text('No item sales in this period yet.'), 200, scrollable: find.byType(Scrollable).first);
  });

  testWidgets('staff do not see sales', (tester) async {
    await pumpShop(tester, session: sessionFor(UserRole.staff), extraOverrides: overrides());
    expect(find.byKey(const Key('adminSalesTile')), findsNothing);
  });
}
