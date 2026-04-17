import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/models/message_model.dart';
import '../providers/tab_provider.dart';

final chatVisibleProvider = StateProvider<bool>((ref) => false);

class FloatingChatFAB extends ConsumerWidget {
  const FloatingChatFAB({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(chatVisibleProvider);
    if (isVisible) return const SizedBox();

    return Positioned(
      bottom: 20,
      right: 20,
      child: GestureDetector(
        onTap: () => ref.read(chatVisibleProvider.notifier).state = true,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF6c5ce7),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF6c5ce7).withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4))
            ],
          ),
          child: const Icon(Icons.chat_bubble_rounded,
              color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class FloatingChatWindow extends ConsumerStatefulWidget {
  const FloatingChatWindow({super.key});

  @override
  ConsumerState<FloatingChatWindow> createState() =>
      _FloatingChatWindowState();
}

class _FloatingChatWindowState extends ConsumerState<FloatingChatWindow> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Offset _position = const Offset(0, 0);
  bool _initialized = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isVisible = ref.watch(chatVisibleProvider);
    if (!isVisible) return const SizedBox();

    final size = MediaQuery.of(context).size;
    if (!_initialized) {
      _position = Offset(size.width - 400, size.height - 560);
      _initialized = true;
    }

    final chatState = ref.watch(chatProvider);

    ref.listen<ChatState>(chatProvider, (prev, next) {
      if ((prev?.messages.length ?? 0) != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Positioned(
      left: _position.dx.clamp(0, size.width - 390),
      top: _position.dy.clamp(0, size.height - 520),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 380,
          height: 510,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF6c5ce7).withValues(alpha: 0.15),
                  blurRadius: 32,
                  offset: const Offset(0, 8))
            ],
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildMessageList(chatState)),
              _buildInput(chatState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      onPanUpdate: (details) => setState(() => _position += details.delta),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF6c5ce7), Color(0xFFa29bfe)]),
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Row(
          children: [
            const Icon(Icons.smart_toy, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Text('AI Assistant',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            const Spacer(),
            _headerIcon(Icons.add_comment, 'New conversation', () {
              ref.read(chatProvider.notifier).newConversation();
            }),
            const SizedBox(width: 8),
            _headerIcon(Icons.open_in_new, 'Open as tab', () {
              ref.read(tabProvider.notifier).openChatTab();
              ref.read(chatVisibleProvider.notifier).state = false;
            }),
            const SizedBox(width: 8),
            _headerIcon(Icons.close, 'Close', () {
              ref.read(chatVisibleProvider.notifier).state = false;
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ChatState chatState) {
    if (chatState.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy,
                size: 40,
                color: const Color(0xFF6c5ce7).withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text('Ask me about your documents',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: chatState.messages.length + (chatState.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == chatState.messages.length) {
          return _buildLoadingIndicator();
        }
        return _buildMessage(chatState.messages[index]);
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF6c5ce7))),
          const SizedBox(width: 8),
          Text('Thinking...',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildMessage(MessageModel msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 310),
        decoration: BoxDecoration(
          gradient: msg.isUser
              ? const LinearGradient(
                  colors: [Color(0xFF6c5ce7), Color(0xFFa29bfe)])
              : null,
          color: msg.isUser ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(msg.isUser ? 14 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 14),
          ),
          border: msg.isUser ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!msg.isUser && msg.toolActions.isNotEmpty) ...[
              ...msg.toolActions.map((action) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6c5ce7)
                          .withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF6c5ce7)
                              .withValues(alpha: 0.15)),
                    ),
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_toolIcon(action.tool),
                              size: 12,
                              color: const Color(0xFF6c5ce7)),
                          const SizedBox(width: 6),
                          Flexible(
                              child: Text(action.displayName,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6c5ce7)))),
                        ]),
                  )),
            ],
            if (msg.isUser)
              Text(msg.content,
                  style: const TextStyle(fontSize: 14, color: Colors.white))
            else
              MarkdownBody(
                data: msg.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: 14, color: Color(0xFF2d3436), height: 1.5),
                  h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF2d3436)),
                  h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF2d3436)),
                  h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2d3436)),
                  code: TextStyle(fontSize: 13, fontFamily: 'monospace', backgroundColor: Colors.grey.shade100, color: const Color(0xFF2d3436)),
                  codeblockDecoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  codeblockPadding: const EdgeInsets.all(12),
                  listBullet: const TextStyle(fontSize: 14, color: Color(0xFF2d3436)),
                  blockquoteDecoration: BoxDecoration(
                    border: Border(left: BorderSide(color: Colors.grey.shade300, width: 3)),
                  ),
                  blockquotePadding: const EdgeInsets.only(left: 12),
                  strong: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2d3436)),
                  em: const TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF2d3436)),
                ),
              ),
            if (msg.sources.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: msg.sources.map((source) {
                  final filename = source.split('/').last;
                  return InkWell(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: msg.isUser
                            ? Colors.white.withValues(alpha: 0.2)
                            : const Color(0xFF6c5ce7)
                                .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.description,
                              size: 11,
                              color: msg.isUser
                                  ? Colors.white70
                                  : const Color(0xFF6c5ce7)),
                          const SizedBox(width: 4),
                          Text(filename,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: msg.isUser
                                      ? Colors.white70
                                      : const Color(0xFF6c5ce7))),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInput(ChatState chatState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Ask anything...',
                hintStyle:
                    TextStyle(color: Colors.grey.shade400, fontSize: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFF6c5ce7))),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
              onSubmitted: (_) => _send(),
              enabled: !chatState.isLoading,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: chatState.isLoading ? null : _send,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: chatState.isLoading
                        ? [Colors.grey.shade300, Colors.grey.shade300]
                        : [
                            const Color(0xFF6c5ce7),
                            const Color(0xFF74b9ff)
                          ]),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  IconData _toolIcon(String tool) {
    switch (tool) {
      case 'read_file':
        return Icons.description;
      case 'create_file':
        return Icons.note_add;
      case 'search_files':
        return Icons.search;
      case 'list_folder':
        return Icons.folder_open;
      default:
        return Icons.build;
    }
  }

  Widget _headerIcon(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Icon(icon,
            color: Colors.white.withValues(alpha: 0.8), size: 16),
      ),
    );
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      ref.read(chatProvider.notifier).sendMessage(text);
      _controller.clear();
      _scrollToBottom();
    }
  }
}
