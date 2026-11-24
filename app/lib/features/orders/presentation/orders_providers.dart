import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/orders_repository.dart';
import '../domain/order_models.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) => HttpOrdersRepository(ref.watch(dioProvider)));
final adminOrdersRepositoryProvider = Provider<AdminOrdersRepository>(
  (ref) => HttpAdminOrdersRepository(ref.watch(dioProvider)),
);

final addressesProvider = FutureProvider.autoDispose<List<Address>>((ref) => ref.watch(ordersRepositoryProvider).addresses());

final myOrdersProvider = FutureProvider.autoDispose<List<Order>>(
  (ref) async => (await ref.watch(ordersRepositoryProvider).myOrders()).items,
);

final orderProvider = FutureProvider.autoDispose.family<Order, String>(
  (ref, id) => ref.watch(ordersRepositoryProvider).order(id),
);

final paymentProvider = FutureProvider.autoDispose.family<Payment, String>(
  (ref, orderId) => ref.watch(ordersRepositoryProvider).payment(orderId),
);

/// Admin lists by tab: `new` | `active` | `done`.
final adminOrdersProvider = FutureProvider.autoDispose.family<List<Order>, String>(
  (ref, group) async => (await ref.watch(adminOrdersRepositoryProvider).orders(group: group)).items,
);

final adminOrderProvider = FutureProvider.autoDispose.family<Order, String>(
  (ref, id) => ref.watch(adminOrdersRepositoryProvider).order(id),
);

final adminPaymentProvider = FutureProvider.autoDispose.family<Payment, String>(
  (ref, orderId) => ref.watch(adminOrdersRepositoryProvider).payment(orderId),
);

/// Delivery windows offered at checkout (empty when the shop does not use slots).
final deliverySlotsProvider = FutureProvider.autoDispose<List<DeliverySlot>>((ref) => ref.watch(ordersRepositoryProvider).slots());

/// Shop: return requests (`null` = all).
final adminReturnsProvider = FutureProvider.autoDispose.family<List<ReturnRequest>, ReturnStatus?>(
  (ref, status) => ref.watch(adminOrdersRepositoryProvider).returns(status: status),
);
