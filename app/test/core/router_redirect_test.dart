import 'package:flutter_test/flutter_test.dart';
import 'package:qc_app/core/router/app_router.dart';
import 'package:qc_app/features/auth/domain/auth_models.dart';

AppUser user(UserRole role) => AppUser(id: 'u', phone: '+919876543210', role: role);

void main() {
  group('guest', () {
    test('may browse home and login', () {
      expect(authRedirect(user: null, location: '/'), isNull);
      expect(authRedirect(user: null, location: '/login'), isNull);
      expect(authRedirect(user: null, location: '/login/otp'), isNull);
      expect(authRedirect(user: null, location: '/cart'), isNull); // guests fill a cart, log in at checkout
    });

    test('is sent to login for protected areas', () {
      for (final location in ['/account', '/admin', '/admin/orders', '/rider', '/checkout', '/orders', '/orders/o1']) {
        expect(authRedirect(user: null, location: location), '/login', reason: location);
      }
    });
  });

  group('signed in', () {
    test('never sees login screens', () {
      expect(authRedirect(user: user(UserRole.customer), location: '/login'), '/');
      expect(authRedirect(user: user(UserRole.owner), location: '/login/otp'), '/admin');
    });

    test('owner and staff land on admin, riders on rider', () {
      expect(authRedirect(user: user(UserRole.owner), location: '/'), '/admin');
      expect(authRedirect(user: user(UserRole.staff), location: '/'), '/admin');
      expect(authRedirect(user: user(UserRole.rider), location: '/'), '/rider');
      expect(authRedirect(user: user(UserRole.customer), location: '/'), isNull);
    });

    test('role-gated areas', () {
      expect(authRedirect(user: user(UserRole.customer), location: '/admin'), '/');
      expect(authRedirect(user: user(UserRole.rider), location: '/admin'), '/rider');
      expect(authRedirect(user: user(UserRole.owner), location: '/rider'), '/admin');
      expect(authRedirect(user: user(UserRole.owner), location: '/admin'), isNull);
    });

    test('everyone can open their account', () {
      for (final role in UserRole.values) {
        expect(authRedirect(user: user(role), location: '/account'), isNull);
      }
    });
  });
}
