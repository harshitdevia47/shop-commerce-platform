import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';

abstract final class Routes {
  static const home = '/';
}

/// App routes. Phase 1 adds auth routes and a role-based `redirect`
/// (customer vs `admin_*` vs `rider_*` areas).
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.home,
    routes: [GoRoute(path: Routes.home, builder: (context, state) => const HomeScreen())],
  );
  ref.onDispose(router.dispose);
  return router;
});
