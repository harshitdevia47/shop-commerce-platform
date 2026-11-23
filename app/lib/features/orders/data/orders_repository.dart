import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../catalog/domain/catalog_models.dart';
import '../domain/order_models.dart';

/// Customer orders, addresses and payments.
abstract interface class OrdersRepository {
  Future<Quote> quote(List<Map<String, dynamic>> items, Fulfillment fulfillment);
  Future<(Order, Payment?)> place(PlaceOrderRequest request);
  Future<PageResult<Order>> myOrders({String? cursor});
  Future<Order> order(String id);
  Future<Order> cancel(String id, {String? reason});

  Future<Payment> payment(String orderId);
  Future<Payment> submitUtr(String orderId, String utr);

  Future<List<Address>> addresses();
  Future<Address> addAddress(Map<String, dynamic> address);
  Future<void> deleteAddress(String id);
}

class HttpOrdersRepository implements OrdersRepository {
  HttpOrdersRepository(this._dio);

  final Dio _dio;

  Future<Order> _order(Future<Response<dynamic>> request) async =>
      Order.fromJson(await unwrap<Map<String, dynamic>>(request));

  @override
  Future<Quote> quote(List<Map<String, dynamic>> items, Fulfillment fulfillment) async => Quote.fromJson(
    await unwrap<Map<String, dynamic>>(
      _dio.post<dynamic>('/api/v1/orders/quote', data: {'items': items, 'fulfillment': fulfillment.wire}),
    ),
  );

  @override
  Future<(Order, Payment?)> place(PlaceOrderRequest request) async {
    final data = await unwrap<Map<String, dynamic>>(_dio.post<dynamic>('/api/v1/orders', data: request.toJson()));
    final payment = data['payment'] as Map<String, dynamic>?;
    return (Order.fromJson(data['order'] as Map<String, dynamic>), payment == null ? null : Payment.fromJson(payment));
  }

  @override
  Future<PageResult<Order>> myOrders({String? cursor}) async {
    final page = await unwrapList(_dio.get<dynamic>('/api/v1/orders', queryParameters: {'cursor': ?cursor}));
    return PageResult([for (final o in page.items) Order.fromJson(o as Map<String, dynamic>)], page.nextCursor);
  }

  @override
  Future<Order> order(String id) => _order(_dio.get<dynamic>('/api/v1/orders/$id'));

  @override
  Future<Order> cancel(String id, {String? reason}) =>
      _order(_dio.post<dynamic>('/api/v1/orders/$id/cancel', data: {'reason': ?reason}));

  @override
  Future<Payment> payment(String orderId) async =>
      Payment.fromJson(await unwrap<Map<String, dynamic>>(_dio.get<dynamic>('/api/v1/payments/orders/$orderId')));

  @override
  Future<Payment> submitUtr(String orderId, String utr) async => Payment.fromJson(
    await unwrap<Map<String, dynamic>>(_dio.post<dynamic>('/api/v1/payments/orders/$orderId/utr', data: {'utr': utr})),
  );

  @override
  Future<List<Address>> addresses() async {
    final data = await unwrap<List<dynamic>>(_dio.get<dynamic>('/api/v1/me/addresses'));
    return [for (final a in data) Address.fromJson(a as Map<String, dynamic>)];
  }

  @override
  Future<Address> addAddress(Map<String, dynamic> address) async =>
      Address.fromJson(await unwrap<Map<String, dynamic>>(_dio.post<dynamic>('/api/v1/me/addresses', data: address)));

  @override
  Future<void> deleteAddress(String id) => send(_dio.delete<dynamic>('/api/v1/me/addresses/$id'));
}

/// Shop admin order handling.
abstract interface class AdminOrdersRepository {
  /// [group]: `new` | `active` | `done`
  Future<PageResult<Order>> orders({required String group, String? cursor});
  Future<Order> order(String id);
  Future<Order> setStatus(String id, OrderStatus status, {String? reason});
  Future<Payment> payment(String orderId);
  Future<Payment> markPaid(String orderId);
}

class HttpAdminOrdersRepository implements AdminOrdersRepository {
  HttpAdminOrdersRepository(this._dio);

  final Dio _dio;

  @override
  Future<PageResult<Order>> orders({required String group, String? cursor}) async {
    final page = await unwrapList(
      _dio.get<dynamic>('/api/v1/admin/orders', queryParameters: {'group': group, 'limit': 50, 'cursor': ?cursor}),
    );
    return PageResult([for (final o in page.items) Order.fromJson(o as Map<String, dynamic>)], page.nextCursor);
  }

  @override
  Future<Order> order(String id) async =>
      Order.fromJson(await unwrap<Map<String, dynamic>>(_dio.get<dynamic>('/api/v1/admin/orders/$id')));

  @override
  Future<Order> setStatus(String id, OrderStatus status, {String? reason}) async => Order.fromJson(
    await unwrap<Map<String, dynamic>>(
      _dio.post<dynamic>('/api/v1/admin/orders/$id/status', data: {'status': status.wire, 'reason': ?reason}),
    ),
  );

  @override
  Future<Payment> payment(String orderId) async =>
      Payment.fromJson(await unwrap<Map<String, dynamic>>(_dio.get<dynamic>('/api/v1/payments/orders/$orderId')));

  @override
  Future<Payment> markPaid(String orderId) async => Payment.fromJson(
    await unwrap<Map<String, dynamic>>(_dio.post<dynamic>('/api/v1/admin/payments/orders/$orderId/mark-paid')),
  );
}
