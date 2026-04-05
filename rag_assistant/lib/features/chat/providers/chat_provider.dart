import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_model.dart';

class ChatNotifier extends StateNotifier<List<MessageModel>> {
  ChatNotifier() : super([]);

  void addMessage(MessageModel message) {
    state = [...state, message];
  }

  void clearMessages() {
    state = [];
  }

  Future<void> sendMessage(String content) async {
    final userMessage = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );
    addMessage(userMessage);

    // TODO: Send to backend and receive AI response
  }
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, List<MessageModel>>((ref) {
  return ChatNotifier();
});
