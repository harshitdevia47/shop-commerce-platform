import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/delivery_models.dart';

/// Customer: the delivery of one of their orders (null until a rider is assigned).
abstract interface class CustomerDeliveryRepository {
  Future<CustomerDelivery?> forOrder(String orderId);
}

/// Shop: riders, assignment, and an order's delivery.
abstract interface class AdminDeliveryRepository {
  Future<List<Rider>> riders();
  Future<AdminDelivery> assign(String orderId, String riderId);
  Future<AdminDelivery?> forOrder(String orderId);
}

/// Rider: own jobs and the two steps.
abstract interface class RiderRepository {
  Future<List<RiderDelivery>> deliveries({required bool active});
  Future<RiderDelivery> delivery(String id);
  Future<RiderDelivery> pickUp(String id);
  Future<RiderDelivery> deliver(String id, String otp);
}

/// Owner: staff and riders.
abstract interface class TeamRepository {
  Future<List<TeamMember>> members();
  Future<TeamMember> add({required String phone, required String role, String? name});
  Future<void> remove(String id);
}

Future<T?> _orNullWhenMissing<T>(Future<T> Function() load) async {
  try {
    return await load();
  } on ApiException catch (error) {
    if (error.statusCode == 404) return null;
    rethrow;
  }
}

class HttpDeliveryRepository implements CustomerDeliveryRepository, RiderRepository, TeamRepository {
  HttpDeliveryRepository(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> _map(Future<Response<dynamic>> request) => unwrap<Map<String, dynamic>>(request);
  Future<List<Map<String, dynamic>>> _list(Future<Response<dynamic>> request) async =>
      (await unwrap<List<dynamic>>(request)).cast<Map<String, dynamic>>();

  // ---- Customer ----
  @override
  Future<CustomerDelivery?> forOrder(String orderId) => _orNullWhenMissing(
    () async => CustomerDelivery.fromJson(await _map(_dio.get<dynamic>('/api/v1/deliveries/orders/$orderId'))),
  );

  // ---- Shop (exposed through HttpAdminDeliveryRepository) ----
  Future<List<Rider>> riders() async => [for (final r in await _list(_dio.get<dynamic>('/api/v1/admin/riders'))) Rider.fromJson(r)];

  Future<AdminDelivery> assign(String orderId, String riderId) async => AdminDelivery.fromJson(
    await _map(_dio.post<dynamic>('/api/v1/admin/deliveries', data: {'orderId': orderId, 'riderId': riderId})),
  );

  Future<AdminDelivery?> adminForOrder(String orderId) => _orNullWhenMissing(
    () async => AdminDelivery.fromJson(await _map(_dio.get<dynamic>('/api/v1/admin/deliveries/orders/$orderId'))),
  );

  // ---- Rider ----
  @override
  Future<List<RiderDelivery>> deliveries({required bool active}) async => [
    for (final d in await _list(_dio.get<dynamic>('/api/v1/rider/deliveries', queryParameters: {'group': active ? 'active' : 'done'})))
      RiderDelivery.fromJson(d),
  ];

  @override
  Future<RiderDelivery> delivery(String id) async => RiderDelivery.fromJson(await _map(_dio.get<dynamic>('/api/v1/rider/deliveries/$id')));

  @override
  Future<RiderDelivery> pickUp(String id) async =>
      RiderDelivery.fromJson(await _map(_dio.post<dynamic>('/api/v1/rider/deliveries/$id/pickup')));

  @override
  Future<RiderDelivery> deliver(String id, String otp) async =>
      RiderDelivery.fromJson(await _map(_dio.post<dynamic>('/api/v1/rider/deliveries/$id/deliver', data: {'otp': otp})));

  // ---- Team ----
  @override
  Future<List<TeamMember>> members() async => [for (final m in await _list(_dio.get<dynamic>('/api/v1/admin/team'))) TeamMember.fromJson(m)];

  @override
  Future<TeamMember> add({required String phone, required String role, String? name}) async => TeamMember.fromJson(
    await _map(_dio.post<dynamic>('/api/v1/admin/team', data: {'phone': phone, 'role': role, 'name': ?name})),
  );

  @override
  Future<void> remove(String id) => send(_dio.delete<dynamic>('/api/v1/admin/team/$id'));
}

/// The shop's view and the customer's view share a path shape but not an endpoint.
class HttpAdminDeliveryRepository implements AdminDeliveryRepository {
  HttpAdminDeliveryRepository(this._http);

  final HttpDeliveryRepository _http;

  @override
  Future<List<Rider>> riders() => _http.riders();

  @override
  Future<AdminDelivery> assign(String orderId, String riderId) => _http.assign(orderId, riderId);

  @override
  Future<AdminDelivery?> forOrder(String orderId) => _http.adminForOrder(orderId);
}
