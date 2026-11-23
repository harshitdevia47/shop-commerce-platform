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
import '../../features/catalog/presentation/category_screen.dart';
import '../../features/catalog/presentation/product_detail_screen.dart';
import '../../features/catalog/presentation/search_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/rider_deliveries/presentation/rider_home_screen.dart';
import 'routes.dart';

/// Pure redirect rules (unit-testable).
///   - guests may browse `/`; `/account`, `/admin`, `/rider` need login
///   - signed-in users never see `/login*`; they land on their role's home
///   - admin and rider areas are role-gated; staff/riders opening `/` go to their area
String? authRedirect({required AppUser? user, required String location}) {
  final loggingIn = location == Routes.login || location.startsWith('${Routes.login}/');
  final protected = [Routes.account, Routes.admin, Routes.rider];
  bool under(String root) => location == root || location.startsWith('$root/');

  if (user == null) return protected.any(under) ? Routes.login : null;

  final home = Routes.homeFor(user.role);
  if (loggingIn) return home;
  if (under(Routes.admin) && !user.role.isAdmin) return home;
  if (under(Routes.rider) && user.role != UserRole.rider) return home;
  if (location == Routes.home && home != Routes.home) return home;
  return null;
}

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
        builder: (context, state) => const LoginScreen(),
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
        ],
      ),
      GoRoute(path: Routes.rider, builder: (context, state) => const RiderHomeScreen()),
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
    final location = router.routerDelegate.currentConfiguration.last.matchedLocation;
    final target = authRedirect(user: after, location: location);
    if (target != null) router.go(target);
  }, fireImmediately: true);

  ref.onDispose(() {
    router.dispose();
    authChanges.dispose();
  });
  return router;
});
