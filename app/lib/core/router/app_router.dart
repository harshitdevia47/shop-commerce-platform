import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/account_screen.dart';
import '../../features/admin_catalog/presentation/admin_categories_screen.dart';
import '../../features/admin_catalog/presentation/admin_products_screen.dart';
import '../../features/admin_catalog/presentation/product_edit_screen.dart';
import '../../features/admin_dashboard/presentation/admin_home_screen.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/admin_orders/presentation/admin_order_detail_screen.dart';
import '../../features/admin_orders/presentation/admin_orders_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/catalog/presentation/category_screen.dart';
import '../../features/catalog/presentation/product_detail_screen.dart';
import '../../features/catalog/presentation/search_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/orders/presentation/checkout_screen.dart';
import '../../features/orders/presentation/my_orders_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/admin_team/presentation/admin_team_screen.dart';
import '../../features/rider_deliveries/presentation/rider_delivery_screen.dart';
import '../../features/rider_deliveries/presentation/rider_home_screen.dart';
import '../providers.dart';
import 'routes.dart';

/// Pure redirect rules (unit-testable).
///   - guests may browse `/`; `/account`, `/admin`, `/rider` need login
///   - signed-in users never see `/login*`; they land on their role's home
///   - admin and rider areas are role-gated; staff/riders opening `/` go to their area
String? authRedirect({required AppUser? user, required String location}) {
  final loggingIn = location == Routes.login || location.startsWith('${Routes.login}/');
  final protected = [Routes.account, Routes.admin, Routes.rider, Routes.checkout, Routes.orders];
  bool under(String root) => location == root || location.startsWith('$root/');

  if (user == null) return protected.any(under) ? Routes.login : null;

  final home = Routes.homeFor(user.role);
  if (loggingIn) return home;
  if (under(Routes.admin) && !user.role.isAdmin) return home;
  if (under(Routes.rider) && user.role != UserRole.rider) return home;
  if (location == Routes.home && home != Routes.home) return home;
  return null;
}

/// Customer page to open right after login (set by the OTP screen, used once by the router).
class PendingReturnTo extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? location) => state = location;

  /// Returns the location and clears it. Only internal paths are accepted.
  String? take() {
    final location = state;
    state = null;
    return location != null && location.startsWith('/') && !location.startsWith('//') ? location : null;
  }
}

final pendingReturnToProvider = NotifierProvider<PendingReturnTo, String?>(PendingReturnTo.new);

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects whenever the signed-in user changes.
  final authChanges = ValueNotifier<AppUser?>(null);

  late final GoRouter router;
  router = GoRouter(
    initialLocation: Routes.home,
    refreshListenable: authChanges,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      if (auth.isLoading && !auth.hasValue) return null; // still reading secure storage
      return authRedirect(user: auth.value, location: state.matchedLocation);
    },
    routes: [
      GoRoute(path: Routes.home, builder: (context, state) => const HomeScreen()),
      GoRoute(path: Routes.search, builder: (context, state) => const SearchScreen()),
      GoRoute(path: Routes.cart, builder: (context, state) => const CartScreen()),
      GoRoute(path: Routes.checkout, builder: (context, state) => const CheckoutScreen()),
      GoRoute(
        path: Routes.orders,
        builder: (context, state) => const MyOrdersScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) => OrderDetailScreen(
              orderId: state.pathParameters['id']!,
              justPlaced: state.uri.queryParameters['placed'] == '1',
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/c/:id',
        builder: (context, state) => CategoryScreen(categoryId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/p/:id',
        builder: (context, state) => ProductDetailScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => LoginScreen(returnTo: state.uri.queryParameters['from']),
        routes: [
          GoRoute(
            path: 'otp',
            redirect: (context, state) => state.extra is OtpRouteArgs ? null : Routes.login,
            // extra is lost on rebuilds/deep links; the redirect above sends those back to /login.
            builder: (context, state) => switch (state.extra) {
              final OtpRouteArgs args => OtpScreen(args: args),
              _ => const LoginScreen(),
            },
          ),
        ],
      ),
      GoRoute(path: Routes.account, builder: (context, state) => const AccountScreen()),
      GoRoute(
        path: Routes.admin,
        builder: (context, state) => const AdminHomeScreen(),
        routes: [
          GoRoute(
            path: 'products',
            builder: (context, state) => const AdminProductsScreen(),
            routes: [
              GoRoute(path: 'new', builder: (context, state) => const ProductEditScreen()),
              GoRoute(
                path: ':id',
                builder: (context, state) => ProductEditScreen(productId: state.pathParameters['id']),
              ),
            ],
          ),
          GoRoute(path: 'categories', builder: (context, state) => const AdminCategoriesScreen()),
          GoRoute(
            path: 'team',
            // Owner only (staff cannot hire); the server enforces it too.
            redirect: (context, state) => ref.read(authControllerProvider).value?.role == UserRole.owner ? null : Routes.admin,
            builder: (context, state) => const AdminTeamScreen(),
          ),
          GoRoute(
            path: 'orders',
            builder: (context, state) => const AdminOrdersScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => AdminOrderDetailScreen(orderId: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.rider,
        builder: (context, state) => const RiderHomeScreen(),
        routes: [
          GoRoute(
            path: 'deliveries/:id',
            builder: (context, state) => RiderDeliveryScreen(deliveryId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
  // Redirects alone do not unwind imperatively pushed pages (e.g. /account on top of /),
  // so navigate explicitly when the signed-in user changes.
  ref.listen(authControllerProvider, (previous, next) {
    if (next.isLoading) return;
    final before = previous?.value;
    final after = next.value;
    authChanges.value = after;
    if (before?.id == after?.id && before?.role == after?.role) return;
    if (before != null && after == null) {
      router.go(Routes.home); // logged out or session expired: back to browsing as a guest
      return;
    }
    if (before == null && after != null) {
      // Just logged in: land on the role's home, then resume e.g. checkout for customers.
      final returnTo = ref.read(pendingReturnToProvider.notifier).take();
      router.go(Routes.homeFor(after.role));
      if (returnTo != null && after.role == UserRole.customer) unawaited(router.push(returnTo));
      return;
    }
    final location = router.routerDelegate.currentConfiguration.last.matchedLocation;
    final target = authRedirect(user: after, location: location);
    if (target != null) router.go(target);
  }, fireImmediately: true);

  // Tapped push notifications open their page (e.g. /orders/<id>) when the signed-in role may see it.
  void openFromNotification(String? route) {
    if (route == null) return;
    final user = ref.read(authControllerProvider).value;
    if (user != null && authRedirect(user: user, location: route) == null) unawaited(router.push(route));
  }

  final push = ref.read(pushServiceProvider);
  final taps = push.taps.listen(openFromNotification);
  // A notification that launched the app: open it once the saved session has loaded.
  late final ProviderSubscription<AsyncValue<AppUser?>> launch;
  launch = ref.listen(authControllerProvider, (_, next) {
    if (next.isLoading) return;
    launch.close();
    unawaited(push.takeLaunchRoute().then(openFromNotification));
  }, fireImmediately: true);

  ref.onDispose(() {
    unawaited(taps.cancel());
    router.dispose();
    authChanges.dispose();
  });
  return router;
});
