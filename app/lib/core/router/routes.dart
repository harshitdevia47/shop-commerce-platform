import 'package:flutter/foundation.dart';

import '../../features/auth/domain/auth_models.dart';

abstract final class Routes {
  static const home = '/';
  static const login = '/login';
  static const otp = '/login/otp';
  static const account = '/account';
  static const admin = '/admin';
  static const rider = '/rider';

  /// Landing page for a signed-in user.
  static String homeFor(UserRole role) => switch (role) {
    UserRole.owner || UserRole.staff => admin,
    UserRole.rider => rider,
    UserRole.customer => home,
  };
}

@immutable
class OtpRouteArgs {
  const OtpRouteArgs({required this.phone, required this.request});

  final String phone;
  final OtpRequestResult request;
}
