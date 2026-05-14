import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../shared/theme/glass_theme.dart';
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
      bottom: 8,
      right: 8,
      child: GestureDetector(
        onTap: () => ref.read(chatVisibleProvider.notifier).state = true,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [GlassTheme.accent, GlassTheme.accentDeep],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              const BoxShadow(
                color: Color(0x20302050),
                blurRadius: 1,
                offset: Offset(0, 1),
              ),
              BoxShadow(
                color: GlassTheme.accentDeep.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class FloatingChatWindow extends ConsumerStatefulWidget {
  const FloatingChatWindow({super.key});

  @override
  ConsumerState<FloatingChatWindow> createState() => _FloatingChatWindowState();
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
          width: 360,
          height: 480,
          decoration: GlassTheme.glassDecoration(
            background: const Color(0xE6FCFBFF),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(GlassTheme.panelRadius),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildMessageList(chatState)),
                _buildInput(chatState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      onPanUpdate: (details) => setState(() => _position += details.delta),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: GlassTheme.line)),
        ),
        child: Row(
          children: [
            // Spinning orb
            const _AiOrb(),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Assistant', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GlassTheme.ink)),
                Text('online', style: TextStyle(fontSize: 11, color: GlassTheme.ink3)),
              ],
            ),
            const Spacer(),
            _HeaderBtn(icon: Icons.add_comment, tooltip: 'New conversation', onTap: () {
              ref.read(chatProvider.notifier).newConversation();
            }),
            const SizedBox(width: 2),
            _HeaderBtn(icon: Icons.open_in_new, tooltip: 'Open as tab', onTap: () {
              ref.read(tabProvider.notifier).openChatTab();
              ref.read(chatVisibleProvider.notifier).state = false;
            }),
            const SizedBox(width: 2),
            _HeaderBtn(icon: Icons.close, tooltip: 'Close', onTap: () {
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
            Icon(Icons.smart_toy, size: 40, color: GlassTheme.accent.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            const Text('Ask me about your documents', style: TextStyle(color: GlassTheme.ink3, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(18),
      itemCount: chatState.messages.length + (chatState.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == chatState.messages.length) return _buildLoadingIndicator();
        return _buildMessage(chatState.messages[index]);
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xCCFFFFFF),
        border: Border.all(color: GlassTheme.glassBorder),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(3, (i) => Container(
            width: 6, height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(shape: BoxShape.circle, color: GlassTheme.accent.withValues(alpha: 0.6)),
          )),
        ],
      ),
    );
  }

  Widget _buildMessage(MessageModel msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 7),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          gradient: msg.isUser
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [GlassTheme.accent, GlassTheme.accentDeep],
                )
              : null,
          color: msg.isUser ? null : const Color(0xCCFFFFFF),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 16),
          ),
          border: msg.isUser
              ? null
              : Border.all(color: GlassTheme.glassBorder),
          boxShadow: msg.isUser
              ? [
                  const BoxShadow(color: Color(0x20302050), blurRadius: 1, offset: Offset(0, 1)),
                  BoxShadow(color: GlassTheme.accentDeep.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 3)),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!msg.isUser && msg.toolActions.isNotEmpty) ...[
              ...msg.toolActions.map((action) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: GlassTheme.accentSoft.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: GlassTheme.accentSoft.withValues(alpha: 0.5)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_toolIcon(action.tool), size: 12, color: GlassTheme.accentDeep),
                      const SizedBox(width: 6),
                      Flexible(child: Text(action.displayName, style: const TextStyle(fontSize: 12, color: GlassTheme.accentDeep))),
                    ]),
                  )),
            ],
            if (msg.isUser)
              Text(msg.content, style: const TextStyle(fontSize: 13.5, color: Colors.white, height: 1.5))
            else
              MarkdownBody(
                data: msg.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: 13.5, color: GlassTheme.ink, height: 1.5),
                  h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: GlassTheme.ink),
                  h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: GlassTheme.ink),
                  h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: GlassTheme.ink),
                  code: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    backgroundColor: Color(0x0A000000),
                    color: GlassTheme.accentDeep,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: const Color(0x0A000000),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  codeblockPadding: const EdgeInsets.all(12),
                  listBullet: const TextStyle(fontSize: 13.5, color: GlassTheme.ink),
                  blockquoteDecoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: GlassTheme.line, width: 3)),
                  ),
                  blockquotePadding: const EdgeInsets.only(left: 12),
                  strong: const TextStyle(fontWeight: FontWeight.w700, color: GlassTheme.ink),
                  em: const TextStyle(fontStyle: FontStyle.italic, color: GlassTheme.ink),
                ),
              ),
            if (msg.sources.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: msg.sources.map((source) {
                  final filename = source.split('/').last;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? const Color(0x33FFFFFF)
                          : GlassTheme.accentSoft.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.description, size: 10, color: msg.isUser ? Colors.white70 : GlassTheme.accentDeep),
                      const SizedBox(width: 4),
                      Text(filename, style: TextStyle(fontSize: 11, color: msg.isUser ? Colors.white70 : GlassTheme.accentDeep)),
                    ]),
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        color: Color(0x80FFFFFF),
        border: Border(top: BorderSide(color: GlassTheme.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xCCFFFFFF),
                borderRadius: BorderRadius.circular(GlassTheme.inputRadius),
                border: Border.all(color: GlassTheme.glassBorder),
              ),
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Ask anything...',
                  hintStyle: TextStyle(color: GlassTheme.ink3, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13, color: GlassTheme.ink),
                onSubmitted: (_) => _send(),
                enabled: !chatState.isLoading,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: chatState.isLoading ? null : _send,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: chatState.isLoading
                      ? [GlassTheme.ink3, GlassTheme.ink3]
                      : [GlassTheme.accent, GlassTheme.accentDeep],
                ),
                borderRadius: BorderRadius.circular(11),
                boxShadow: chatState.isLoading
                    ? null
                    : [
                        const BoxShadow(color: Color(0x20302050), blurRadius: 1, offset: Offset(0, 1)),
                        BoxShadow(color: GlassTheme.accentDeep.withValues(alpha: 0.5), blurRadius: 14, offset: const Offset(0, 3)),
                      ],
              ),
              child: const Center(child: Icon(Icons.send, color: Colors.white, size: 14)),
            ),
          ),
        ],
      ),
    );
  }

  IconData _toolIcon(String tool) {
    switch (tool) {
      case 'read_file': return Icons.description;
      case 'create_file': return Icons.note_add;
      case 'search_files': return Icons.search;
      case 'list_folder': return Icons.folder_open;
      default: return Icons.build;
    }
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

class _HeaderBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.tooltip, required this.onTap});

  @override
  State<_HeaderBtn> createState() => _HeaderBtnState();
}

class _HeaderBtnState extends State<_HeaderBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = true); }),
      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = false); }),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: _hovered ? const Color(0xB3FFFFFF) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Icon(widget.icon, size: 14, color: GlassTheme.ink3)),
          ),
        ),
      ),
    );
  }
}

class _AiOrb extends StatefulWidget {
  const _AiOrb();

  @override
  State<_AiOrb> createState() => _AiOrbState();
}

class _AiOrbState extends State<_AiOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              transform: GradientRotation(_controller.value * 6.283),
              colors: const [
                GlassTheme.accent,
                Color(0xFFE89060), // warm
                Color(0xFF60B8E8), // cool
                GlassTheme.accent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: GlassTheme.accent.withValues(alpha: 0.4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xF0FCFBFF),
                border: Border.all(color: const Color(0x99FFFFFF), width: 1),
              ),
            ),
          ),
        );
      },
    );
  }
}
