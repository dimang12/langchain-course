import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'constants.dart';

class ChatWebSocket {
  WebSocketChannel? _channel;
  final String token;

  ChatWebSocket({required this.token});

  Future<void> connect() async {
    _channel = WebSocketChannel.connect(
      Uri.parse('${AppConstants.wsUrl}/chat/stream'),
    );
    await _channel?.ready;
    _channel?.sink.add(token);
  }

  Stream<String> sendQuery(String query) async* {
    _channel?.sink.add(query);
    await for (final raw in _channel!.stream) {
      final data = jsonDecode(raw as String);
      if (data['type'] == 'done') break;
      yield data['data'] as String;
    }
  }

  void dispose() {
    _channel?.sink.close();
    _channel = null;
  }
}
