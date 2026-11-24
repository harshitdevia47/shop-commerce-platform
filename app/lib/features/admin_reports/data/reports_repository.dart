import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';

@immutable
class SalesSummary {
  const SalesSummary({
    required this.orders,
    required this.cancelled,
    required this.open,
    required this.completed,
    required this.salesPaise,
    required this.averageOrderPaise,
    required this.paidPaise,
    required this.codOrders,
    required this.codPaise,
    required this.upiOrders,
    required this.upiPaise,
    this.onlineOrders = 0,
    this.onlinePaise = 0,
    required this.delivery,
    required this.pickup,
    required this.customers,
    required this.newCustomers,
    required this.returningCustomers,
  });

  factory SalesSummary.fromJson(Map<String, dynamic> json) {
    final cod = json['cod'] as Map<String, dynamic>;
    final upi = json['upi'] as Map<String, dynamic>;
    final online = json['online'] as Map<String, dynamic>? ?? const {};
    return SalesSummary(
      orders: json['orders'] as int,
      cancelled: json['cancelled'] as int,
      open: json['open'] as int,
      completed: json['completed'] as int,
      salesPaise: json['salesPaise'] as int,
      averageOrderPaise: json['averageOrderPaise'] as int,
      paidPaise: json['paidPaise'] as int,
      codOrders: cod['orders'] as int,
      codPaise: cod['paise'] as int,
      upiOrders: upi['orders'] as int,
      upiPaise: upi['paise'] as int,
      onlineOrders: online['orders'] as int? ?? 0,
      onlinePaise: online['paise'] as int? ?? 0,
      delivery: json['delivery'] as int,
      pickup: json['pickup'] as int,
      customers: json['customers'] as int,
      newCustomers: json['newCustomers'] as int,
      returningCustomers: json['returningCustomers'] as int,
    );
  }

  final int orders;
  final int cancelled;
  final int open;
  final int completed;
  final int salesPaise;
  final int averageOrderPaise;
  final int paidPaise;
  final int codOrders;
  final int codPaise;
  final int upiOrders;
  final int upiPaise;
  final int onlineOrders;
  final int onlinePaise;
  final int delivery;
  final int pickup;
  final int customers;
  final int newCustomers;
  final int returningCustomers;
}

@immutable
class DailySales {
  const DailySales({required this.day, required this.orders, required this.salesPaise});

  factory DailySales.fromJson(Map<String, dynamic> json) =>
      DailySales(day: DateTime.parse(json['day'] as String), orders: json['orders'] as int, salesPaise: json['salesPaise'] as int);

  final DateTime day;
  final int orders;
  final int salesPaise;
}

@immutable
class TopProduct {
  const TopProduct({required this.productId, required this.productName, required this.qty, required this.salesPaise});

  factory TopProduct.fromJson(Map<String, dynamic> json) => TopProduct(
    productId: json['productId'] as String,
    productName: json['productName'] as String,
    qty: json['qty'] as int,
    salesPaise: json['salesPaise'] as int,
  );

  final String productId;
  final String productName;
  final int qty;
  final int salesPaise;
}

/// Shop days, inclusive (`YYYY-MM-DD`; the shop's calendar).
@immutable
class ReportRange {
  const ReportRange(this.from, this.to);

  final DateTime from;
  final DateTime to;

  String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  Map<String, String> get query => {'from': _day(from), 'to': _day(to)};

  @override
  bool operator ==(Object other) => other is ReportRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// Owner-only sales reports (reporting service).
abstract interface class ReportsRepository {
  Future<SalesSummary> summary(ReportRange range);
  Future<List<DailySales>> daily(ReportRange range);
  Future<List<TopProduct>> topProducts(ReportRange range, {int limit = 10});
}

class HttpReportsRepository implements ReportsRepository {
  HttpReportsRepository(this._dio);

  final Dio _dio;

  @override
  Future<SalesSummary> summary(ReportRange range) async =>
      SalesSummary.fromJson(await unwrap<Map<String, dynamic>>(_dio.get<dynamic>('/api/v1/admin/reports/summary', queryParameters: range.query)));

  @override
  Future<List<DailySales>> daily(ReportRange range) async => [
    for (final d in await unwrap<List<dynamic>>(_dio.get<dynamic>('/api/v1/admin/reports/daily', queryParameters: range.query)))
      DailySales.fromJson(d as Map<String, dynamic>),
  ];

  @override
  Future<List<TopProduct>> topProducts(ReportRange range, {int limit = 10}) async => [
    for (final p in await unwrap<List<dynamic>>(
      _dio.get<dynamic>('/api/v1/admin/reports/top-products', queryParameters: {...range.query, 'limit': '$limit'}),
    ))
      TopProduct.fromJson(p as Map<String, dynamic>),
  ];
}
