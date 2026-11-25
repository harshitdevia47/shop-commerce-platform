import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'auth/session.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/shop_screen.dart';

/// Page a notification asked to open before the admin logged in.
final pendingRouteProvider = NotifierProvider<PendingRoute, String?>(PendingRoute.new);

class PendingRoute extends Notifier<String?> {
  @override
  String? build() => null;
  // ignore: use_setters_to_change_properties
  void set(String? route) => state = route;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      if (session.isLoading) return null;
      final loggedIn = session.value != null;
      final atLogin = state.matchedLocation == '/login';
      if (!loggedIn) {
        if (!atLogin && state.matchedLocation != '/') ref.read(pendingRouteProvider.notifier).set(state.matchedLocation);
        return atLogin ? null : '/login';
      }
      if (atLogin) {
        final pending = ref.read(pendingRouteProvider);
        ref.read(pendingRouteProvider.notifier).set(null);
        return pending ?? '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/shops/:id', builder: (context, state) => ShopScreen(shopId: state.pathParameters['id']!)),
    ],
  );
});

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    const seed = Color(0xFF1B5E20);
    return MaterialApp.router(
      title: 'Shop Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true, filledButtonTheme: _fullWidth),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true, filledButtonTheme: _fullWidth),
      routerConfig: session.isLoading ? _splash : ref.watch(routerProvider),
    );
  }
}

final _fullWidth = FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)));

final _splash = GoRouter(routes: [GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Center(child: CircularProgressIndicator())))]);
