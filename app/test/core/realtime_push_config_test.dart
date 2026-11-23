import 'package:flutter_test/flutter_test.dart';
import 'package:qc_app/core/config/client_config.dart';
import 'package:qc_app/core/realtime/realtime_channel.dart';

void main() {
  test('socket payloads become events; malformed ones are dropped', () {
    final event = RealtimeEvent.fromSocket('order.updated', {'orderId': 'o1', 'number': 7, 'status': 'PACKED'});
    expect(event?.orderId, 'o1');
    expect(event?.status, 'PACKED');
    expect(RealtimeEvent.fromSocket('order.updated', 'nope'), isNull);
    expect(RealtimeEvent.fromSocket('order.updated', {'orderId': 7}), isNull);
  });

  test('push is enabled only with a complete Firebase app config', () {
    const full = {
      'FIREBASE_API_KEY': 'key',
      'FIREBASE_APP_ID': '1:123:android:abc',
      'FIREBASE_SENDER_ID': '123',
      'FIREBASE_PROJECT_ID': 'qc-shops',
    };
    expect(FirebaseConfig.fromMap(full)?.projectId, 'qc-shops');
    expect(FirebaseConfig.fromMap({...full, 'FIREBASE_APP_ID': ''}), isNull);
    expect(FirebaseConfig.fromMap(const {}), isNull);
  });
}
