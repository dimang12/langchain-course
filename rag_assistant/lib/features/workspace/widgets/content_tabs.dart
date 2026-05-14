import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../core/markdown_delta.dart';
import '../../../shared/theme/glass_theme.dart';
import '../../settings/providers/settings_provider.dart';
import '../../agents/providers/agents_provider.dart';
import '../../agents/widgets/brief_card.dart';
import '../../meetings/models/meeting_model.dart';
import '../../meetings/providers/meetings_provider.dart';
import '../providers/tab_provider.dart';
import '../models/tab_model.dart';
import '../../chat/screens/chat_screen.dart';

class ContentTabs extends ConsumerWidget {
  const ContentTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabState = ref.watch(tabProvider);

    return Column(
      children: [
        // Glass tab bar
        Container(
          height: 46,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: GlassTheme.line)),
          ),
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ...tabState.tabs.map((tab) {
                      final isActive = tab.id == tabState.activeTabId;
                      return _GlassTab(
                        tab: tab,
                        isActive: isActive,
                        onTap: () => ref.read(tabProvider.notifier).setActive(tab.id),
                        onClose: () => ref.read(tabProvider.notifier).closeTab(tab.id),
                      );
                    }),
                    // Add tab button
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: _GlassAddTab(onTap: () {}),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: tabState.activeTab == null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.folder_open, size: 64, color: GlassTheme.accent.withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    const Text('Open a file from the sidebar', style: TextStyle(color: GlassTheme.ink3, fontSize: 16)),
                  ]),
                )
              : tabState.activeTab!.type == 'chat'
                  ? const ChatScreen()
                  : Column(
                      children: [
                        // Breadcrumb + per-tab actions (e.g. Finalize for meeting docs)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                          child: Row(
                            children: [
                              const Text('workspace', style: TextStyle(fontSize: 12, color: GlassTheme.ink3)),
                              const SizedBox(width: 6),
                              const Text('/', style: TextStyle(fontSize: 12, color: GlassTheme.ink3)),
                              const SizedBox(width: 6),
                              Text(
                                tabState.activeTab!.title,
                                style: const TextStyle(fontSize: 12, color: GlassTheme.ink2, fontWeight: FontWeight.w500),
                              ),
                              const Spacer(),
                              _MeetingActions(nodeId: tabState.activeTab!.nodeId),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _FileContentView(
                            key: ValueKey('${tabState.activeTab!.nodeId}_${tabState.activeTab!.reloadCounter}'),
                            tabId: tabState.activeTab!.id,
                            nodeId: tabState.activeTab!.nodeId!,
                            fileType: tabState.activeTab!.fileType,
                          ),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }
}

class _GlassTab extends StatefulWidget {
  final TabModel tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _GlassTab({
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<_GlassTab> createState() => _GlassTabState();
}

class _GlassTabState extends State<_GlassTab> {
  bool _hovered = false;

  IconData _tabIcon(TabModel tab) {
    if (tab.type == 'chat') return Icons.chat_bubble;
    switch (tab.fileType) {
      case 'md': return Icons.article;
      case 'pdf': return Icons.picture_as_pdf;
      case 'docx': return Icons.description;
      case 'csv': return Icons.table_chart;
      case 'txt': return Icons.text_snippet;
      default: return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = true); }),
      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = false); }),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: widget.isActive
                ? const Color(0xCCFFFFFF)
                : _hovered
                    ? const Color(0x80FFFFFF)
                    : Colors.transparent,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
            border: widget.isActive
                ? const Border(bottom: BorderSide(color: GlassTheme.accent, width: 2))
                : null,
            boxShadow: widget.isActive
                ? const [BoxShadow(color: Color(0x20302050), blurRadius: 1, offset: Offset(0, 1))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.tab.isModified == true)
                Container(
                  width: 6, height: 6, margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: GlassTheme.accent),
                ),
              Icon(_tabIcon(widget.tab), size: 13, color: GlassTheme.accent),
              const SizedBox(width: 8),
              Text(
                widget.tab.title,
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isActive ? GlassTheme.ink : GlassTheme.ink2,
                  fontWeight: widget.isActive ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedOpacity(
                opacity: widget.isActive || _hovered ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Icon(Icons.close, size: 12, color: GlassTheme.ink3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassAddTab extends StatefulWidget {
  final VoidCallback onTap;
  const _GlassAddTab({required this.onTap});

  @override
  State<_GlassAddTab> createState() => _GlassAddTabState();
}

class _GlassAddTabState extends State<_GlassAddTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = true); }),
      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = false); }),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xB3FFFFFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: AnimatedRotation(
            turns: _hovered ? 0.25 : 0,
            duration: const Duration(milliseconds: 300),
            child: const Icon(Icons.add, size: 14, color: GlassTheme.ink3),
          ),
        ),
      ),
    );
  }
}

// ── Active tab underline ──
// Rendered via the tab's bottom border as a gradient line
// matching the prototype's scaleX animation

class _FileContentView extends ConsumerStatefulWidget {
  final String tabId;
  final String nodeId;
  final String? fileType;

  const _FileContentView({super.key, required this.tabId, required this.nodeId, this.fileType});

  @override
  ConsumerState<_FileContentView> createState() => _FileContentViewState();
}

class _FileContentViewState extends ConsumerState<_FileContentView> {
  bool _showSource = false;
  bool _isLoading = true;
  String _content = '';
  final _editController = TextEditingController();
  quill.QuillController? _quillController;
  final _quillFocusNode = FocusNode();
  final _quillScrollController = ScrollController();
  Timer? _saveTimer;

  bool get _isEditable => widget.fileType == 'md' || widget.fileType == 'txt' || widget.fileType == null;
  bool get _isMarkdown => widget.fileType == 'md' || widget.fileType == null;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _editController.dispose();
    _quillController?.dispose();
    _quillFocusNode.dispose();
    _quillScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    try {
      final content = await ref.read(tabProvider.notifier).loadContent(widget.nodeId);
      if (mounted) {
        setState(() {
          _content = content;
          _editController.text = content;
          if (_isMarkdown) _initQuill(content);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _content = 'Failed to load content'; _isLoading = false; });
    }
  }

  void _initQuill(String markdown) {
    _quillController?.dispose();
    try {
      _quillController = quill.QuillController(
        document: markdownToDocument(markdown),
        selection: const TextSelection.collapsed(offset: 0),
      );
      _quillController!.document.changes.listen((_) {
        if (_quillController == null) return;
        final md = documentToMarkdown(_quillController!.document);
        ref.read(tabProvider.notifier).setModified(widget.tabId, true);
        ref.read(tabProvider.notifier).updateCachedContent(widget.nodeId, md);
        _saveTimer?.cancel();
        _saveTimer = Timer(const Duration(seconds: 2), () {
          ref.read(tabProvider.notifier).saveContent(widget.nodeId, md);
        });
      });
    } catch (_) {
      _quillController = null;
    }
  }

  void _onRawChanged(String value) {
    ref.read(tabProvider.notifier).setModified(widget.tabId, true);
    ref.read(tabProvider.notifier).updateCachedContent(widget.nodeId, value);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      ref.read(tabProvider.notifier).saveContent(widget.nodeId, value);
    });
  }

  bool get _isDailyBrief {
    final trimmed = _content.trimLeft();
    return trimmed.startsWith('# Daily Brief') ||
        RegExp(r'^\d+\.\s+Daily Brief').hasMatch(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: GlassTheme.accent));

    if (_isDailyBrief && !_showSource) {
      return _buildBriefView(context);
    }

    if (_isMarkdown && _quillController != null && !_showSource) {
      return _buildQuillView(context);
    }

    return Column(
      children: [
        if (_isEditable) _buildGlassToolbar(),
        Expanded(child: _buildFallbackContent()),
      ],
    );
  }

  Widget _buildBriefView(BuildContext context) {
    final agentsState = ref.watch(agentsProvider);
    // Find the AgentRun whose output_node_id matches this file
    final matchingRun = agentsState.runs.where((r) =>
        r.outputNodeId == widget.nodeId && r.status == 'success').firstOrNull;

    // If agent runs haven't been loaded yet, trigger load
    if (agentsState.runs.isEmpty && !agentsState.isLoading) {
      Future.microtask(() => ref.read(agentsProvider.notifier).loadRuns());
    }

    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: GlassTheme.line)),
          ),
          child: Row(
            children: [
              Icon(Icons.wb_sunny_outlined, size: 16, color: GlassTheme.accent),
              const SizedBox(width: 8),
              const Text(
                'Daily Brief',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GlassTheme.ink),
              ),
              if (matchingRun != null) ...[
                const SizedBox(width: 12),
                _buildCompletionBadge(matchingRun.taskCompletions, matchingRun.topPriorities.length),
              ],
              const Spacer(),
              _GlassToolbarChip(
                icon: Icons.code,
                label: 'Source',
                onTap: () {
                  _editController.text = _content;
                  setState(() => _showSource = true);
                },
              ),
            ],
          ),
        ),
        // Brief card content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: matchingRun != null
                    ? BriefCard(run: matchingRun)
                    : _buildFallbackBriefContent(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionBadge(List<bool> completions, int total) {
    final done = completions.where((c) => c).length;
    if (total == 0) return const SizedBox.shrink();
    final allDone = done == total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: allDone
            ? const Color(0xFF5CD4A8).withValues(alpha: 0.15)
            : GlassTheme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$done/$total done',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: allDone ? const Color(0xFF2E9E78) : GlassTheme.accent,
        ),
      ),
    );
  }

  Widget _buildFallbackBriefContent() {
    // Show the markdown content as read-only when no AgentRun is found
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xD9FFFFFF),
        borderRadius: BorderRadius.circular(GlassTheme.cardRadius),
        border: Border.all(color: GlassTheme.glassBorder),
      ),
      child: SelectableText(
        _content,
        style: const TextStyle(fontSize: 15, height: 1.7, color: GlassTheme.ink2),
      ),
    );
  }

  Widget _buildQuillView(BuildContext context) {
    return Column(
      children: [
        // Toolbar — flat strip, icons left, actions right
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: GlassTheme.line), top: BorderSide(color: GlassTheme.line)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 550,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    iconButtonTheme: IconButtonThemeData(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: GlassTheme.ink2,
                      ),
                    ),
                  ),
                  child: quill.QuillSimpleToolbar(
                  configurations: quill.QuillSimpleToolbarConfigurations(
                    controller: _quillController!,
                    decoration: const BoxDecoration(color: Colors.transparent),
                    buttonOptions: const quill.QuillSimpleToolbarButtonOptions(
                      base: quill.QuillToolbarBaseButtonOptions(
                        iconSize: 18,
                        iconButtonFactor: 1.0,
                        iconTheme: quill.QuillIconTheme(
                          iconButtonSelectedData: quill.IconButtonData(
                            color: GlassTheme.accentDeep,
                            highlightColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            splashColor: Colors.transparent,
                            style: ButtonStyle(
                              backgroundColor: WidgetStatePropertyAll(Colors.transparent),
                              overlayColor: WidgetStatePropertyAll(Colors.transparent),
                              padding: WidgetStatePropertyAll(EdgeInsets.all(4)),
                              minimumSize: WidgetStatePropertyAll(Size.zero),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          iconButtonUnselectedData: quill.IconButtonData(
                            color: GlassTheme.ink2,
                            highlightColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            splashColor: Colors.transparent,
                            style: ButtonStyle(
                              backgroundColor: WidgetStatePropertyAll(Colors.transparent),
                              overlayColor: WidgetStatePropertyAll(Colors.transparent),
                              padding: WidgetStatePropertyAll(EdgeInsets.all(4)),
                              minimumSize: WidgetStatePropertyAll(Size.zero),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ),
                    ),
                    showBoldButton: true,
                    showItalicButton: true,
                    showHeaderStyle: true,
                    showListBullets: true,
                    showListNumbers: true,
                    showQuote: true,
                    showLink: true,
                    showInlineCode: true,
                    showCodeBlock: true,
                    showUnderLineButton: false,
                    showStrikeThrough: false,
                    showColorButton: false,
                    showBackgroundColorButton: false,
                    showClearFormat: false,
                    showAlignmentButtons: false,
                    showIndent: false,
                    showSearchButton: false,
                    showFontFamily: false,
                    showFontSize: false,
                    showDividers: false,
                    showSmallButton: false,
                    showSubscript: false,
                    showSuperscript: false,
                    multiRowsDisplay: false,
                  ),
                ),
              ),
              ),
              const Spacer(),
              _GlassToolbarChip(
                icon: Icons.code,
                label: 'Source',
                onTap: () {
                  _editController.text = documentToMarkdown(_quillController!.document);
                  _content = _editController.text;
                  setState(() => _showSource = true);
                },
              ),
              const SizedBox(width: 4),
              Consumer(builder: (context, ref, _) {
                final centered = ref.watch(settingsProvider).centeredContent;
                return _GlassToolbarChip(
                  icon: centered ? Icons.align_horizontal_center : Icons.width_full,
                  label: centered ? 'Centered' : 'Full',
                  onTap: () => ref.read(settingsProvider.notifier).toggleContentWidth(),
                );
              }),
            ],
          ),
        ),
        // Glass document surface — respects centered/full setting
        Expanded(
          child: _wrapContent(
            Container(
              margin: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: const Color(0xD9FFFFFF),
                borderRadius: BorderRadius.circular(GlassTheme.cardRadius),
                border: Border.all(color: GlassTheme.glassBorder),
                boxShadow: const [
                  BoxShadow(color: Color(0x20302050), blurRadius: 1, offset: Offset(0, 1)),
                  BoxShadow(color: Color(0x20302050), blurRadius: 30, offset: Offset(0, 15)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(GlassTheme.cardRadius),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 40),
                  child: _buildQuillEditorWithPaste(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassToolbar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: GlassTheme.glassInnerDecoration(radius: GlassTheme.buttonRadius),
      child: Row(
        children: [
          if (_isMarkdown && _showSource) ...[
            _GlassToolbarChip(
              icon: _isDailyBrief ? Icons.wb_sunny_outlined : Icons.visibility,
              label: _isDailyBrief ? 'Brief View' : 'Rich Edit',
              isPrimary: true,
              onTap: () {
                if (!_isDailyBrief) _initQuill(_editController.text);
                setState(() => _showSource = false);
              },
            ),
            Container(width: 1, height: 20, color: GlassTheme.line, margin: const EdgeInsets.symmetric(horizontal: 6)),
          ],
          const Icon(Icons.edit, size: 14, color: GlassTheme.ink3),
          const SizedBox(width: 6),
          Text(
            _showSource ? 'Markdown Source' : 'Editing',
            style: const TextStyle(fontSize: 13, color: GlassTheme.ink2),
          ),
          const Spacer(),
          Consumer(builder: (context, ref, _) {
            final centered = ref.watch(settingsProvider).centeredContent;
            return _GlassToolbarChip(
              icon: centered ? Icons.align_horizontal_center : Icons.width_full,
              label: centered ? 'Centered' : 'Full Width',
              onTap: () => ref.read(settingsProvider.notifier).toggleContentWidth(),
            );
          }),
          if (widget.fileType != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: GlassTheme.accentSoft.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.fileType!.toUpperCase(),
                style: const TextStyle(fontSize: 11, color: GlassTheme.accentDeep, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuillEditorWithPaste() {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV): const _PasteMarkdownIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyV): const _PasteMarkdownIntent(),
      },
      child: Actions(
        actions: {
          _PasteMarkdownIntent: CallbackAction<_PasteMarkdownIntent>(
            onInvoke: (_) async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text == null || data!.text!.isEmpty) return null;
              final text = data.text!;
              final hasMarkdown = RegExp(r'(^#{1,6}\s|^\*\*|^\- |^\d+\.\s|\*\*.*\*\*)', multiLine: true).hasMatch(text);
              if (!hasMarkdown) {
                // Let default paste handle plain text
                _quillController!.replaceText(
                  _quillController!.selection.baseOffset,
                  _quillController!.selection.extentOffset - _quillController!.selection.baseOffset,
                  text,
                  null,
                );
                return null;
              }
              final doc = markdownToDocument(text);
              final pasteDelta = doc.toDelta();
              // Remove trailing newline from paste delta to avoid double newlines
              final index = _quillController!.selection.baseOffset;
              final length = _quillController!.selection.extentOffset - index;
              _quillController!.replaceText(index, length, pasteDelta, null);
              return null;
            },
          ),
        },
        child: quill.QuillEditor(
          scrollController: _quillScrollController,
          focusNode: _quillFocusNode,
          configurations: quill.QuillEditorConfigurations(
            controller: _quillController!,
            scrollable: true,
            autoFocus: false,
            expands: true,
            padding: const EdgeInsets.all(0),
            placeholder: 'Start writing...',
            customStyles: quill.DefaultStyles(
              paragraph: quill.DefaultTextBlockStyle(
                const TextStyle(fontSize: 15, height: 1.7, color: GlassTheme.ink2),
                const quill.VerticalSpacing(6, 6),
                const quill.VerticalSpacing(0, 0),
                null,
              ),
              h1: quill.DefaultTextBlockStyle(
                const TextStyle(fontSize: 38, fontWeight: FontWeight.w600, height: 1.1, letterSpacing: -0.3, color: GlassTheme.ink),
                const quill.VerticalSpacing(16, 10),
                const quill.VerticalSpacing(0, 0),
                null,
              ),
              h2: quill.DefaultTextBlockStyle(
                const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: -0.2, color: GlassTheme.ink),
                const quill.VerticalSpacing(32, 14),
                const quill.VerticalSpacing(0, 0),
                null,
              ),
              h3: quill.DefaultTextBlockStyle(
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3, color: GlassTheme.ink),
                const quill.VerticalSpacing(10, 4),
                const quill.VerticalSpacing(0, 0),
                null,
              ),
              code: quill.DefaultTextBlockStyle(
                const TextStyle(fontSize: 13, fontFamily: 'Courier New', height: 1.5, color: GlassTheme.ink2),
                const quill.VerticalSpacing(8, 8),
                const quill.VerticalSpacing(0, 0),
                BoxDecoration(
                  color: const Color(0x0A000000),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wrapContent(Widget child) {
    return Consumer(builder: (context, ref, _) {
      final centered = ref.watch(settingsProvider).centeredContent;
      if (!centered) return child;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: child,
        ),
      );
    });
  }

  Widget _buildFallbackContent() {
    if (_isEditable) {
      return _wrapContent(
        Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          decoration: BoxDecoration(
            color: const Color(0xD9FFFFFF),
            borderRadius: BorderRadius.circular(GlassTheme.cardRadius),
            border: Border.all(color: GlassTheme.glassBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(GlassTheme.cardRadius),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: TextField(
                controller: _editController,
                maxLines: null,
                expands: true,
                style: TextStyle(
                  fontSize: _showSource ? 14 : 16,
                  height: 1.7,
                  fontFamily: widget.fileType == 'txt' || _showSource ? 'monospace' : null,
                  color: GlassTheme.ink2,
                ),
                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                onChanged: _onRawChanged,
              ),
            ),
          ),
        ),
      );
    }

    switch (widget.fileType) {
      case 'csv':
        return _wrapContent(_buildCsvTable());
      case 'pdf':
      case 'docx':
        return _wrapContent(
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xD9FFFFFF),
              borderRadius: BorderRadius.circular(GlassTheme.cardRadius),
              border: Border.all(color: GlassTheme.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: GlassTheme.accentSoft.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(widget.fileType == 'pdf' ? Icons.picture_as_pdf : Icons.description, size: 16, color: GlassTheme.ink2),
                    const SizedBox(width: 8),
                    Text('Extracted text from ${widget.fileType!.toUpperCase()}', style: const TextStyle(fontSize: 13, color: GlassTheme.ink2)),
                  ]),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SelectableText(_content, style: const TextStyle(fontSize: 15, height: 1.7, color: GlassTheme.ink2)),
                ),
              ],
            ),
          ),
        );
      default:
        return _wrapContent(
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xD9FFFFFF),
              borderRadius: BorderRadius.circular(GlassTheme.cardRadius),
              border: Border.all(color: GlassTheme.glassBorder),
            ),
            child: SelectableText(_content, style: const TextStyle(fontSize: 15, height: 1.7, color: GlassTheme.ink2)),
          ),
        );
    }
  }

  Widget _buildCsvTable() {
    final lines = _content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return const Center(child: Text('Empty CSV', style: TextStyle(color: GlassTheme.ink3)));

    final headers = lines.first.split(',').map((h) => h.trim()).toList();
    final rows = lines.skip(1).map((line) => line.split(',').map((c) => c.trim()).toList()).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xD9FFFFFF),
        borderRadius: BorderRadius.circular(GlassTheme.cardRadius),
        border: Border.all(color: GlassTheme.glassBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GlassTheme.cardRadius),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(GlassTheme.accentSoft.withValues(alpha: 0.3)),
              columns: headers.map((h) => DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: GlassTheme.ink)))).toList(),
              rows: rows.map((row) => DataRow(
                cells: List.generate(headers.length, (i) => DataCell(Text(i < row.length ? row[i] : '', style: const TextStyle(fontSize: 14, color: GlassTheme.ink2)))),
              )).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassToolbarChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _GlassToolbarChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  State<_GlassToolbarChip> createState() => _GlassToolbarChipState();
}

class _GlassToolbarChipState extends State<_GlassToolbarChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = true); }),
      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = false); }),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? GlassTheme.accentSoft.withValues(alpha: _hovered ? 0.7 : 0.5)
                : _hovered
                    ? const Color(0xCCFFFFFF)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              widget.icon,
              size: 12,
              color: widget.isPrimary ? GlassTheme.accentDeep : GlassTheme.ink2,
            ),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                color: widget.isPrimary ? GlassTheme.accentDeep : GlassTheme.ink2,
                fontWeight: widget.isPrimary ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MeetingActions extends ConsumerStatefulWidget {
  final String? nodeId;
  const _MeetingActions({required this.nodeId});

  @override
  ConsumerState<_MeetingActions> createState() => _MeetingActionsState();
}

class _MeetingActionsState extends ConsumerState<_MeetingActions> {
  bool _isFinalizing = false;
  bool _meetingsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(meetingsProvider);
      if (state.meetings.isEmpty && !state.isLoading) {
        ref.read(meetingsProvider.notifier).loadMeetings();
      }
      if (mounted) setState(() => _meetingsLoaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.nodeId == null) return const SizedBox.shrink();
    final meetingsState = ref.watch(meetingsProvider);
    final meeting = meetingsState.findByNodeId(widget.nodeId);
    if (meeting == null) {
      if (!_meetingsLoaded || meetingsState.isLoading) return const SizedBox.shrink();
      return const SizedBox.shrink();
    }
    final isFinalized = meeting.isFinalized;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (isFinalized ? const Color(0xFF5CD4A8) : GlassTheme.accent).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            isFinalized ? 'finalized' : 'draft',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isFinalized ? const Color(0xFF1B9A6F) : GlassTheme.accent,
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: _isFinalizing ? null : () => _runFinalize(meeting),
          icon: _isFinalizing
              ? const SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.auto_awesome, size: 14),
          label: Text(isFinalized ? 'Re-finalize' : 'Finalize'),
          style: FilledButton.styleFrom(
            backgroundColor: GlassTheme.accent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: const Size(0, 28),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Future<void> _runFinalize(MeetingModel meeting) async {
    setState(() => _isFinalizing = true);
    // Persist any unsaved notes first so the extractor sees the latest text.
    final tabState = ref.read(tabProvider);
    final cached = meeting.treeNodeId != null
        ? tabState.contentCache[meeting.treeNodeId!]
        : null;
    if (cached != null) {
      await ref.read(tabProvider.notifier).saveContent(meeting.treeNodeId!, cached);
    }
    final result = await ref.read(meetingsProvider.notifier).finalizeMeeting(meeting.id);
    if (!mounted) return;
    setState(() => _isFinalizing = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finalize failed')),
      );
      return;
    }
    if (meeting.treeNodeId != null) {
      ref.read(tabProvider.notifier).forceReload(meeting.treeNodeId!);
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => _FinalizeResultDialog(result: result, meetingTitle: meeting.title),
    );
  }
}

class _FinalizeResultDialog extends StatelessWidget {
  final FinalizeResult result;
  final String meetingTitle;

  const _FinalizeResultDialog({required this.result, required this.meetingTitle});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Finalized "$meetingTitle"',
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statRow('Decisions', result.decisionsExtracted),
            _statRow('Action items', result.followUpsExtracted),
            _statRow('Goals', result.goalsExtracted),
            _statRow('People', result.peopleExtracted),
            if (result.decisions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Decisions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              ...result.decisions.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${d['title'] ?? ''}', style: const TextStyle(fontSize: 12, color: GlassTheme.ink2)),
              )),
            ],
            if (result.followUps.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Action items', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              ...result.followUps.map((f) {
                final owner = (f['owner'] as String?)?.isNotEmpty == true ? ' @${f['owner']}' : '';
                final due = (f['due_date'] as String?) != null ? ' • due ${f['due_date']}' : '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${f['description'] ?? ''}$owner$due',
                      style: const TextStyle(fontSize: 12, color: GlassTheme.ink2)),
                );
              }),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(backgroundColor: GlassTheme.accent),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _statRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 13, color: GlassTheme.ink2)),
          ),
          Text('$count', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GlassTheme.ink)),
        ],
      ),
    );
  }
}

class _PasteMarkdownIntent extends Intent {
  const _PasteMarkdownIntent();
}
