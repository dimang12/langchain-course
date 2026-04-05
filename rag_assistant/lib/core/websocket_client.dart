import 'package:web_socket_channel/web_socket_channel.dart';
import 'constants.dart';

class WebSocketClient {
  WebSocketChannel? _channel;

  bool get isConnected => _channel != null;

  Future<void> connect() async {
    final uri = Uri.parse('${AppConstants.wsUrl}/ws/chat');
    _channel = WebSocketChannel.connect(uri);
    await _channel?.ready;
  }

  void sendQuery(String query) {
    _channel?.sink.add(query);
  }

  Stream<dynamic>? get messages => _channel?.stream;

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
