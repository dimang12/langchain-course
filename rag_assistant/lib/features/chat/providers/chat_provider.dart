import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../models/message_model.dart';

class ChatState {
  final List<MessageModel> messages;
  final bool isLoading;
  final String? conversationId;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.conversationId,
  });

  ChatState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    String? conversationId,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      conversationId: conversationId ?? this.conversationId,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ApiClient _apiClient;

  ChatNotifier(this._apiClient) : super(const ChatState());

  Future<void> sendMessage(String content) async {
    final userMessage = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
    );

    try {
      final response = await _apiClient.dio.post('/chat/query', data: {
        'question': content,
        if (state.conversationId != null)
          'conversation_id': state.conversationId,
      });

      final data = response.data;
      final assistantMessage = MessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: data['answer'] as String,
        isUser: false,
        timestamp: DateTime.now(),
        sources: (data['sources'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        toolActions: (data['tool_actions'] as List<dynamic>?)
                ?.map((e) =>
                    ToolAction.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        isLoading: false,
        conversationId: data['conversation_id'] as String?,
      );
    } catch (e) {
      final errorMessage = MessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: 'Error: Failed to get response. Please try again.',
        isUser: false,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, errorMessage],
        isLoading: false,
      );
    }
  }

  void newConversation() {
    state = const ChatState();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref.read(apiClientProvider));
});
