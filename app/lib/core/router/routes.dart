import 'package:flutter/foundation.dart';

import '../../features/auth/domain/auth_models.dart';

abstract final class Routes {
  static const home = '/';
  static const login = '/login';
  static const otp = '/login/otp';
  static const account = '/account';
  static const admin = '/admin';
  static const rider = '/rider';
  static const search = '/search';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const orders = '/orders';
  static const adminOrders = '/admin/orders';
  static const adminProducts = '/admin/products';
  static const adminNewProduct = '/admin/products/new';
  static const adminCategories = '/admin/categories';
  static const adminTeam = '/admin/team';
  static const adminReturns = '/admin/returns';

  static String product(String id) => '/p/$id';
  static String category(String id) => '/c/$id';
  static String adminProduct(String id) => '/admin/products/$id';
  static String order(String id) => '/orders/$id';
  static String adminOrder(String id) => '/admin/orders/$id';
  static String riderDelivery(String id) => '/rider/deliveries/$id';

  /// Landing page for a signed-in user.
  static String homeFor(UserRole role) => switch (role) {
    UserRole.owner || UserRole.staff => admin,
    UserRole.rider => rider,
    UserRole.customer => home,
  };
}

@immutable
class OtpRouteArgs {
  const OtpRouteArgs({required this.phone, required this.request, this.returnTo});

  final String phone;
  final OtpRequestResult request;

  /// Customer page to continue on after login (e.g. checkout), opened on top of home.
  final String? returnTo;
}
