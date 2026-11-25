import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:url_launcher/url_launcher.dart';

import 'api/admin_api.dart';
import 'api/models.dart';
import 'auth/session.dart';
import 'config.dart';

final appConfigProvider = Provider<AppConfig>((ref) => throw UnimplementedError('Overridden in main()'));

final adminApiProvider = Provider<AdminApi>((ref) => HttpAdminApi(ref.watch(appConfigProvider).apiUrl));

/// Opens WhatsApp, the dialer or a link outside the app (overridden in tests).
typedef ExternalLauncher = Future<bool> Function(Uri uri);
final externalLauncherProvider = Provider<ExternalLauncher>((ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

/// `ref.read` of a provider Ref or a widget's WidgetRef.
typedef Reader = T Function<T>(ProviderListenable<T> provider);

/// Runs an API call with the current token; a 401 logs out (back to the login screen).
Future<T> withToken<T>(Reader read, Future<T> Function(AdminApi api, String token) call) async {
  final session = await read(sessionProvider.future);
  if (session == null) throw const ApiError('ADMIN_AUTH_REQUIRED', 'Please log in again', statusCode: 401);
  try {
    return await call(read(adminApiProvider), session.token);
  } on ApiError catch (e) {
    if (e.isAuth) await read(sessionProvider.notifier).expired();
    rethrow;
  }
}

/// No automatic retries: the screen shows the error with a Retry button instead of spinning.
Duration? _noRetry(int count, Object error) => null;

final overviewProvider = FutureProvider.autoDispose<Overview>((ref) => withToken(ref.read, (api, token) => api.overview(token)), retry: _noRetry);

final shopDetailProvider = FutureProvider.autoDispose.family<ShopDetail, String>(
  (ref, shopId) => withToken(ref.read, (api, token) => api.shop(token, shopId)),
  retry: _noRetry,
);
