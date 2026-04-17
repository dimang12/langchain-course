import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'constants.dart';

/// WebSocket client for the /agents/notifications/ws channel.
///
/// Connects with the user's JWT access token, emits server events on a
/// broadcast stream, and auto-reconnects on disconnect with exponential
/// backoff. Failures during connect or send are swallowed so the UI
/// never crashes because the notification channel is unavailable.
class NotificationsClient {
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  String? _token;
  bool _shouldReconnect = false;
  int _backoffSeconds = 1;
  Timer? _reconnectTimer;

  Stream<Map<String, dynamic>> get events => _controller.stream;

  bool get isConnected => _channel != null;

  /// Connect (or reconnect) using the given token. Safe to call repeatedly.
  Future<void> connect(String token) async {
    _token = token;
    _shouldReconnect = true;
    await _connectInternal();
  }

  Future<void> _connectInternal() async {
    if (_token == null) return;

    await _teardown();

    try {
      final channel = WebSocketChannel.connect(
        Uri.parse('${AppConstants.wsUrl}/agents/notifications/ws'),
      );
      await channel.ready;
      channel.sink.add(_token);

      _channel = channel;
      _backoffSeconds = 1; // reset after successful connect

      _subscription = channel.stream.listen(
        (raw) {
          try {
            final decoded = jsonDecode(raw as String);
            if (decoded is Map<String, dynamic>) {
              _controller.add(decoded);
            }
          } catch (_) {
            // Ignore malformed frames
          }
        },
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _channel = null;
    _subscription?.cancel();
    _subscription = null;

    if (!_shouldReconnect || _token == null) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _backoffSeconds), () {
      _backoffSeconds = (_backoffSeconds * 2).clamp(1, 30);
      _connectInternal();
    });
  }

  Future<void> _teardown() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  /// Stop reconnecting and close the connection. Call on logout.
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _token = null;
    await _teardown();
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}

final notificationsClient = NotificationsClient();
