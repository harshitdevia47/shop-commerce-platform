import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Something changed on the server; the app re-fetches the affected data over REST.
@immutable
class RealtimeEvent {
  const RealtimeEvent({required this.type, required this.orderId, this.status, this.data = const {}});

  /// `order.updated` | `payment.updated` | `delivery.updated` | `rider.location`
  final String type;
  final String orderId;
  final String? status;

  /// The whole payload (e.g. lat/lng/at for `rider.location`).
  final Map<String, Object?> data;

  static RealtimeEvent? fromSocket(String type, Object? data) {
    if (data is! Map) return null;
    final orderId = data['orderId'];
    if (orderId is! String) return null;
    return RealtimeEvent(
      type: type,
      orderId: orderId,
      status: data['status'] as String?,
      data: Map<String, Object?>.from(data.map((key, value) => MapEntry(key.toString(), value))),
    );
  }

  @override
  String toString() => 'RealtimeEvent($type, $orderId, $status)';
}

/// A live connection for the signed-in user. Closed when the user changes.
abstract interface class RealtimeChannel {
  Stream<RealtimeEvent> get events;

  /// true while connected. Screens poll only while this is false.
  Stream<bool> get connection;

  /// Rider phones: sends a location ping. Returns how many orders it is shown on (0 = not on the way,
  /// or not connected / refused).
  Future<int> sendLocation({required double lat, required double lng, double? accuracy});

  void close();
}

/// Opens a channel. [token] is asked on every (re)connect, so it can return a refreshed token.
typedef RealtimeConnector = RealtimeChannel Function(Future<String?> Function() token);

/// Socket.IO client for the realtime service.
///
/// The server closes the socket when the access token expires (`session.expired`) and refuses
/// expired tokens on connect (`TOKEN_EXPIRED`); both reconnect after asking [token] again.
/// Socket.IO itself reconnects after network drops.
class SocketRealtimeChannel implements RealtimeChannel {
  SocketRealtimeChannel(String url, this._token) {
    _socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setPath('/socket.io')
          .enableForceNew()
          .disableAutoConnect()
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(30000)
          .setAuthFn((callback) {
            _token().then((token) => callback({'token': token ?? ''}), onError: (_) => callback({'token': ''}));
          })
          .build(),
    );
    _socket
      ..onConnect((_) {
        _retries = 0;
        _setConnected(true);
      })
      ..onDisconnect((reason) {
        _setConnected(false);
        // The server ended the session (token expired): it does not auto-reconnect.
        if (reason == 'io server disconnect') _reconnectSoon();
      })
      ..onConnectError((error) {
        _setConnected(false);
        final message = error is Map ? error['message'] : error.toString();
        if (message is String && (message.contains('TOKEN_EXPIRED') || message.contains('TOKEN_MISSING'))) {
          _reconnectSoon();
        }
      })
      ..on('order.updated', (data) => _emit('order.updated', data))
      ..on('payment.updated', (data) => _emit('payment.updated', data))
      ..on('delivery.updated', (data) => _emit('delivery.updated', data))
      ..on('rider.location', (data) => _emit('rider.location', data))
      ..connect();
  }

  final Future<String?> Function() _token;
  late final io.Socket _socket;
  final _events = StreamController<RealtimeEvent>.broadcast();
  final _connection = StreamController<bool>.broadcast();
  Timer? _retry;
  int _retries = 0;
  bool _closed = false;

  void _setConnected(bool value) {
    if (!_closed) _connection.add(value);
  }

  void _emit(String type, Object? data) {
    final event = RealtimeEvent.fromSocket(type, data);
    if (event != null && !_closed) _events.add(event);
  }

  void _reconnectSoon() {
    if (_closed || _retry != null || _retries >= 5) return;
    _retries++;
    _retry = Timer(Duration(seconds: 2 * _retries), () {
      _retry = null;
      if (!_closed) _socket.connect();
    });
  }

  @override
  Future<int> sendLocation({required double lat, required double lng, double? accuracy}) async {
    if (_closed || !_socket.connected) return 0;
    try {
      final ack = await _socket
          .emitWithAckAsync('rider.location', {'lat': lat, 'lng': lng, 'accuracy': accuracy})
          .timeout(const Duration(seconds: 10));
      return ack is Map && ack['ok'] == true ? (ack['tracking'] as num? ?? 0).toInt() : 0;
    } on Object {
      return 0;
    }
  }

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  @override
  Stream<bool> get connection => _connection.stream;

  @override
  void close() {
    _closed = true;
    _retry?.cancel();
    _socket.dispose();
    unawaited(_events.close());
    unawaited(_connection.close());
  }
}
