import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/delivery_repository.dart';
import '../domain/delivery_models.dart';

final _httpDeliveryProvider = Provider<HttpDeliveryRepository>((ref) => HttpDeliveryRepository(ref.watch(dioProvider)));

final customerDeliveryRepositoryProvider = Provider<CustomerDeliveryRepository>((ref) => ref.watch(_httpDeliveryProvider));
final adminDeliveryRepositoryProvider = Provider<AdminDeliveryRepository>(
  (ref) => HttpAdminDeliveryRepository(ref.watch(_httpDeliveryProvider)),
);
final riderRepositoryProvider = Provider<RiderRepository>((ref) => ref.watch(_httpDeliveryProvider));
final teamRepositoryProvider = Provider<TeamRepository>((ref) => ref.watch(_httpDeliveryProvider));

/// Customer: rider + door code for an order (null until a rider is assigned).
final customerDeliveryProvider = FutureProvider.autoDispose.family<CustomerDelivery?, String>(
  (ref, orderId) => ref.watch(customerDeliveryRepositoryProvider).forOrder(orderId),
);

/// Shop: who delivers an order (null until assigned).
final adminDeliveryProvider = FutureProvider.autoDispose.family<AdminDelivery?, String>(
  (ref, orderId) => ref.watch(adminDeliveryRepositoryProvider).forOrder(orderId),
);

final ridersProvider = FutureProvider.autoDispose<List<Rider>>((ref) => ref.watch(adminDeliveryRepositoryProvider).riders());

/// Rider: open jobs (`true`) or finished ones (`false`).
final riderDeliveriesProvider = FutureProvider.autoDispose.family<List<RiderDelivery>, bool>(
  (ref, active) => ref.watch(riderRepositoryProvider).deliveries(active: active),
);

final riderDeliveryProvider = FutureProvider.autoDispose.family<RiderDelivery, String>(
  (ref, id) => ref.watch(riderRepositoryProvider).delivery(id),
);

final teamProvider = FutureProvider.autoDispose<List<TeamMember>>((ref) => ref.watch(teamRepositoryProvider).members());

/// Latest rider location per order, pushed live while the rider is on the way.
class RiderLocations extends Notifier<Map<String, RiderLocation>> {
  @override
  Map<String, RiderLocation> build() => const {};

  void update(String orderId, RiderLocation location) => state = {...state, orderId: location};
}

final riderLocationsProvider = NotifierProvider<RiderLocations, Map<String, RiderLocation>>(RiderLocations.new);
