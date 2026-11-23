import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../providers.dart';
import 'realtime_channel.dart';

/// Null when the build has no realtime endpoint (tests).
final realtimeConnectorProvider = Provider<RealtimeConnector?>((ref) {
  final url = ref.watch(envConfigProvider).realtimeUrl;
  if (url == null || url.isEmpty) return null;
  return (token) => SocketRealtimeChannel(url, token);
});

/// Access token for the socket handshake. An expired one is refreshed first: any authenticated
/// call does that through `AuthInterceptor` (which also prevents parallel refreshes).
final socketTokenProvider = Provider<Future<String?> Function()>((ref) {
  return () async {
    final store = ref.read(sessionStoreProvider);
    var session = await store.read();
    if (session == null) return null;
    final soon = ref.read(clockProvider)().add(const Duration(seconds: 5));
    if (session.accessTokenExpiresAt.isBefore(soon)) {
      try {
        await ref.read(authApiProvider).me();
      } on Object {
        // Offline or session ended: the socket retries later or is closed on logout.
      }
      session = await store.read();
    }
    return session?.accessToken;
  };
});

/// Live channel for the signed-in user; reopened when the user changes, closed on logout.
final realtimeChannelProvider = Provider<RealtimeChannel?>((ref) {
  final userId = ref.watch(authControllerProvider.select((auth) => auth.value?.id));
  final connector = ref.watch(realtimeConnectorProvider);
  if (userId == null || connector == null) return null;
  final channel = connector(ref.read(socketTokenProvider));
  ref.onDispose(channel.close);
  return channel;
});

/// Whether live updates are flowing. Order screens fall back to polling while false.
final realtimeConnectedProvider = StreamProvider<bool>((ref) {
  final channel = ref.watch(realtimeChannelProvider);
  return channel == null ? Stream.value(false) : channel.connection;
});

extension RealtimeRef on WidgetRef {
  bool get isLive => read(realtimeConnectedProvider).value ?? false;
}
