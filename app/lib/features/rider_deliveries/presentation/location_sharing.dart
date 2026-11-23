import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/providers.dart';
import '../../../core/realtime/realtime_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../delivery/domain/delivery_models.dart';
import '../../delivery/presentation/delivery_providers.dart';

@immutable
class GeoFix {
  const GeoFix(this.lat, this.lng, this.accuracy);
  final double lat;
  final double lng;
  final double? accuracy;
}

enum LocationAccess { granted, denied, serviceOff }

/// The phone's GPS. Tests replace it.
abstract interface class LocationSource {
  Future<LocationAccess> ensureAccess();

  /// Fixes while subscribed. On Android this runs a foreground service with a visible
  /// notification, so it keeps working when the rider switches to the maps app.
  Stream<GeoFix> watch({required String notificationTitle, required String notificationText});
}

class GeolocatorSource implements LocationSource {
  const GeolocatorSource();

  @override
  Future<LocationAccess> ensureAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceOff;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse
        ? LocationAccess.granted
        : LocationAccess.denied;
  }

  @override
  Stream<GeoFix> watch({required String notificationTitle, required String notificationText}) async* {
    // Google's fused provider refuses to start when "Google Location Accuracy" is off, even with GPS on.
    // Then fall back to the plain GPS provider (LocationManager) instead of leaving the customer blind.
    try {
      await for (final fix in _positions(notificationTitle, notificationText, legacyGps: false)) {
        yield fix;
      }
    } on LocationServiceDisabledException {
      if (!await Geolocator.isLocationServiceEnabled()) rethrow;
      yield* _positions(notificationTitle, notificationText, legacyGps: true);
    }
  }

  Stream<GeoFix> _positions(String title, String text, {required bool legacyGps}) {
    final settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 15,
            intervalDuration: const Duration(seconds: 10),
            forceLocationManager: legacyGps,
            foregroundNotificationConfig: ForegroundNotificationConfig(
              notificationTitle: title,
              notificationText: text,
              notificationChannelName: title,
              enableWakeLock: true,
            ),
          )
        : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15);
    return Geolocator.getPositionStream(locationSettings: settings).map((p) => GeoFix(p.latitude, p.longitude, p.accuracy));
  }
}

final locationSourceProvider = Provider<LocationSource>((ref) => const GeolocatorSource());

/// Rider banner state: whether the customer can currently see where the rider is.
enum SharingState { idle, sharing, needsPermission, gpsOff }

class LocationSharingState extends Notifier<SharingState> {
  @override
  SharingState build() => SharingState.idle;

  void set(SharingState value) {
    if (state != value) state = value;
  }
}

final locationSharingStateProvider = NotifierProvider<LocationSharingState, SharingState>(LocationSharingState.new);

/// Minimum gap between pings sent to the server.
const locationPingInterval = Duration(seconds: 10);

/// Rider phones: shares the location only while a delivery is picked up (on the way), at most
/// every [locationPingInterval]. Stops when it is delivered, cancelled, or the rider logs out.
/// Kept alive by `QcApp`.
final locationSharingProvider = Provider<void>((ref) {
  final isRider = ref.watch(authControllerProvider.select((auth) => auth.value?.role == UserRole.rider));
  if (!isRider) return;
  final onTheWay = ref.watch(
    riderDeliveriesProvider(true).select(
      (jobs) => jobs.value?.any((d) => d.status == DeliveryStatus.pickedUp) ?? false,
    ),
  );
  final state = ref.read(locationSharingStateProvider.notifier);
  if (!onTheWay) {
    Future.microtask(() => state.set(SharingState.idle));
    return;
  }

  final source = ref.read(locationSourceProvider);
  final l10n = lookupAppLocalizations(ref.read(localeProvider));
  StreamSubscription<GeoFix>? subscription;
  DateTime? lastSent;
  var disposed = false;

  Future<void> start() async {
    final access = await source.ensureAccess();
    if (disposed) return;
    if (access != LocationAccess.granted) {
      state.set(access == LocationAccess.serviceOff ? SharingState.gpsOff : SharingState.needsPermission);
      return;
    }
    state.set(SharingState.sharing);
    subscription = source
        .watch(notificationTitle: l10n.riderSharingTitle, notificationText: l10n.riderSharingText)
        .listen((fix) {
          final now = DateTime.now();
          if (lastSent != null && now.difference(lastSent!) < locationPingInterval) return;
          lastSent = now;
          final channel = ref.read(realtimeChannelProvider);
          unawaited(channel?.sendLocation(lat: fix.lat, lng: fix.lng, accuracy: fix.accuracy));
        }, onError: (Object error) {
          // e.g. the rider switched location off after granting permission.
          debugPrint('Location stream error: $error');
          state.set(error is LocationServiceDisabledException ? SharingState.gpsOff : SharingState.needsPermission);
        });
  }

  unawaited(start());
  ref.onDispose(() {
    disposed = true;
    unawaited(subscription?.cancel());
  });
});

/// Retry after the rider fixed permissions or turned GPS on.
void retryLocationSharing(WidgetRef ref) => ref.invalidate(locationSharingProvider);
