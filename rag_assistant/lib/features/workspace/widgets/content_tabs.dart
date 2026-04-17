import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../../settings/providers/settings_provider.dart';
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
        // Tab bar
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.45),
          ),
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: tabState.tabs.map((tab) {
                    final isActive = tab.id == tabState.activeTabId;
                    return GestureDetector(
                      onTap: () => ref.read(tabProvider.notifier).setActive(tab.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.white.withValues(alpha: 0.6) : Colors.transparent,
                          border: Border(bottom: BorderSide(color: isActive ? const Color(0xFF6c5ce7) : Colors.transparent, width: 2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (tab.isModified == true)
                              Container(
                                width: 6, height: 6, margin: const EdgeInsets.only(right: 6),
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF6c5ce7)),
                              ),
                            Icon(_tabIcon(tab), size: 14, color: isActive ? const Color(0xFF6c5ce7) : Colors.grey),
                            const SizedBox(width: 8),
                            Text(tab.title, style: TextStyle(fontSize: 14, color: isActive ? const Color(0xFF2d3436) : Colors.grey.shade600, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
                            const SizedBox(width: 8),
                            InkWell(onTap: () => ref.read(tabProvider.notifier).closeTab(tab.id), child: Icon(Icons.close, size: 14, color: Colors.grey.shade400)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
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
                    Icon(Icons.folder_open, size: 64, color: const Color(0xFF6c5ce7).withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    Text('Open a file from the sidebar', style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                  ]),
                )
              : tabState.activeTab!.type == 'chat'
                  ? const ChatScreen()
                  : Column(
                      children: [
                        Container(
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.folder, size: 12, color: Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Text('workspace', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                              Icon(Icons.chevron_right, size: 14, color: Colors.grey.shade400),
                              Text(
                                tabState.activeTab!.title,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _FileContentView(
                            key: ValueKey(tabState.activeTab!.nodeId),
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
}

class _FileContentView extends ConsumerStatefulWidget {
  final String tabId;
  final String nodeId;
  final String? fileType;

  const _FileContentView({super.key, required this.tabId, required this.nodeId, this.fileType});

  @override
  ConsumerState<_FileContentView> createState() => _FileContentViewState();
}

class _FileContentViewState extends ConsumerState<_FileContentView> {
  bool _isEditing = false;
  bool _isLoading = true;
  String _content = '';
  final _editController = TextEditingController();
  Timer? _saveTimer;

  bool get _isEditable => widget.fileType == 'md' || widget.fileType == 'txt' || widget.fileType == null;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    try {
      final content = await ref.read(tabProvider.notifier).loadContent(widget.nodeId);
      if (mounted) {
        setState(() {
          _content = content;
          _editController.text = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _content = 'Failed to load content'; _isLoading = false; });
    }
  }

  void _onContentChanged(String value) {
    ref.read(tabProvider.notifier).setModified(widget.tabId, true);
    ref.read(tabProvider.notifier).updateCachedContent(widget.nodeId, value);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      ref.read(tabProvider.notifier).saveContent(widget.nodeId, value);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        // Toolbar
        if (_isEditable)
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                _ToolbarButton(
                  icon: Icons.visibility,
                  label: 'Preview',
                  isActive: !_isEditing,
                  onTap: () => setState(() { _isEditing = false; _content = _editController.text; }),
                ),
                const SizedBox(width: 4),
                _ToolbarButton(
                  icon: Icons.edit,
                  label: 'Edit',
                  isActive: _isEditing,
                  onTap: () => setState(() { _isEditing = true; _editController.text = _content; }),
                ),
                const Spacer(),
                Consumer(builder: (context, ref, _) {
                  final centered = ref.watch(settingsProvider).centeredContent;
                  return _ToolbarButton(
                    icon: centered ? Icons.align_horizontal_center : Icons.width_full,
                    label: centered ? 'Centered' : 'Full Width',
                    isActive: false,
                    onTap: () => ref.read(settingsProvider.notifier).toggleContentWidth(),
                  );
                }),
                const SizedBox(width: 8),
                if (widget.fileType != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                    child: Text(widget.fileType!.toUpperCase(), style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
        // Content
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _wrapContent(Widget child) {
    return Consumer(builder: (context, ref, _) {
      final centered = ref.watch(settingsProvider).centeredContent;
      if (!centered) return child;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: child,
        ),
      );
    });
  }

  Widget _buildContent() {
    if (_isEditing && _isEditable) {
      return _wrapContent(
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _editController,
            maxLines: null,
            expands: true,
            style: TextStyle(fontSize: 16, height: 1.7, fontFamily: widget.fileType == 'txt' ? 'monospace' : null),
            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
            onChanged: _onContentChanged,
          ),
        ),
      );
    }

    switch (widget.fileType) {
      case 'md':
        return _wrapContent(
          Padding(
            padding: const EdgeInsets.all(24),
            child: Markdown(
              data: _content,
              selectable: true,
              builders: {
                'code': _MonospaceCodeBuilder(),
              },
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 16, height: 1.7),
                h1: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.4),
                h1Padding: const EdgeInsets.only(bottom: 8),
                h2: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.4),
                h2Padding: const EdgeInsets.only(bottom: 6),
                h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4),
                horizontalRuleDecoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
                ),
                blockquoteDecoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(left: BorderSide(color: Colors.grey.shade300, width: 4)),
                ),
                blockquotePadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                code: TextStyle(fontSize: 14, fontFamily: 'monospace', backgroundColor: Colors.grey.shade100),
                codeblockDecoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                codeblockPadding: const EdgeInsets.all(16),
                listBullet: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        );
      case 'csv':
        return _wrapContent(_buildCsvTable());
      case 'pdf':
      case 'docx':
        return _wrapContent(
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(widget.fileType == 'pdf' ? Icons.picture_as_pdf : Icons.description, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text('Extracted text from ${widget.fileType!.toUpperCase()}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  ]),
                ),
                const SizedBox(height: 16),
                SelectableText(_content, style: const TextStyle(fontSize: 16, height: 1.7)),
              ],
            ),
          ),
        );
      default:
        return _wrapContent(
          Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(_content, style: const TextStyle(fontSize: 16, height: 1.7)),
          ),
        );
    }
  }

  Widget _buildCsvTable() {
    final lines = _content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return const Center(child: Text('Empty CSV'));

    final headers = lines.first.split(',').map((h) => h.trim()).toList();
    final rows = lines.skip(1).map((line) => line.split(',').map((c) => c.trim()).toList()).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFF6c5ce7).withValues(alpha: 0.08)),
          columns: headers.map((h) => DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)))).toList(),
          rows: rows.map((row) => DataRow(
            cells: List.generate(headers.length, (i) => DataCell(Text(i < row.length ? row[i] : '', style: const TextStyle(fontSize: 14)))),
          )).toList(),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolbarButton({required this.icon, required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6c5ce7).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: isActive ? const Color(0xFF6c5ce7) : Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 13, color: isActive ? const Color(0xFF6c5ce7) : Colors.grey.shade500, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
        ]),
      ),
    );
  }
}

class _MonospaceCodeBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // Only handle fenced code blocks (pre > code), not inline code
    if (element.tag != 'code') return null;

    final text = element.textContent;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SelectableText(
        text,
        style: const TextStyle(
          fontFamily: 'Courier New',
          fontSize: 13,
          height: 1.5,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
