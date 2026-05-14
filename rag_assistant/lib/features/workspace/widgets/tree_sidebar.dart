import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/glass_theme.dart';
import '../models/tree_node_model.dart';
import '../providers/workspace_provider.dart';
import '../providers/tab_provider.dart';
import '../../chat/providers/chat_provider.dart';
import 'floating_chat.dart';

class TreeSidebar extends ConsumerStatefulWidget {
  final double width;
  final ValueChanged<double>? onWidthChanged;
  const TreeSidebar({super.key, this.width = 280, this.onWidthChanged});

  @override
  ConsumerState<TreeSidebar> createState() => _TreeSidebarState();
}

class _TreeSidebarState extends ConsumerState<TreeSidebar> {
  String? _editingNodeId;
  late TextEditingController _renameController;

  @override
  void initState() {
    super.initState();
    _renameController = TextEditingController();
    Future.microtask(() => ref.read(workspaceProvider.notifier).loadTree());
  }

  @override
  void dispose() {
    _renameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceProvider);

    return SizedBox(
      width: widget.width,
      child: Column(
        children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: GlassTheme.line)),
                ),
                child: Row(
                  children: [
                    const Text(
                      'WORKSPACE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: GlassTheme.ink3,
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.sort, size: 14, color: GlassTheme.ink3),
                      tooltip: 'Sort',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (mode) => ref.read(workspaceProvider.notifier).setSortMode(mode),
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'name', child: Row(children: [
                          Icon(Icons.sort_by_alpha, size: 16, color: workspace.sortMode == 'name' ? GlassTheme.accent : GlassTheme.ink3),
                          const SizedBox(width: 8), const Text('Name', style: TextStyle(fontSize: 13)),
                        ])),
                        PopupMenuItem(value: 'date', child: Row(children: [
                          Icon(Icons.schedule, size: 16, color: workspace.sortMode == 'date' ? GlassTheme.accent : GlassTheme.ink3),
                          const SizedBox(width: 8), const Text('Date', style: TextStyle(fontSize: 13)),
                        ])),
                        PopupMenuItem(value: 'type', child: Row(children: [
                          Icon(Icons.category, size: 16, color: workspace.sortMode == 'type' ? GlassTheme.accent : GlassTheme.ink3),
                          const SizedBox(width: 8), const Text('Type', style: TextStyle(fontSize: 13)),
                        ])),
                      ],
                    ),
                    const SizedBox(width: 2),
                    _GlassIconBtn(icon: Icons.upload_file, tooltip: 'Import File', onTap: () => _importFile()),
                    const SizedBox(width: 2),
                    _GlassIconBtn(icon: Icons.create_new_folder_outlined, tooltip: 'New Folder', onTap: () => _createNode('folder')),
                    const SizedBox(width: 2),
                    _GlassIconBtn(icon: Icons.note_add_outlined, tooltip: 'New File', onTap: () => _createNode('file')),
                  ],
                ),
              ),
              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0x40FFFFFF),
                    borderRadius: BorderRadius.circular(GlassTheme.inputRadius),
                    border: Border.all(color: GlassTheme.line),
                  ),
                  child: const TextField(
                    style: TextStyle(fontSize: 13, color: GlassTheme.ink),
                    decoration: InputDecoration(
                      hintText: 'Search workspace...',
                      hintStyle: TextStyle(color: GlassTheme.ink3, fontSize: 13),
                      prefixIcon: Icon(Icons.search, size: 14, color: GlassTheme.ink3),
                      prefixIconConstraints: BoxConstraints(minWidth: 34),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                    ),
                  ),
                ),
              ),
              // Tree
              Expanded(
                child: workspace.isLoading && workspace.tree.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: GlassTheme.accent))
                    : workspace.tree.isEmpty
                        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.folder_open, size: 48, color: GlassTheme.ink3.withValues(alpha: 0.4)),
                            const SizedBox(height: 8),
                            const Text('Empty workspace', style: TextStyle(color: GlassTheme.ink3, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('Create a file or import documents', style: TextStyle(color: GlassTheme.ink3.withValues(alpha: 0.7), fontSize: 12)),
                          ]))
                        : ListView(
                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
                            children: workspace.tree.map((node) => _buildTreeNode(node, 0)).expand((e) => e).toList(),
                          ),
              ),
        ],
      ),
    );
  }

  List<Widget> _buildTreeNode(TreeNodeModel node, int depth) {
    final workspace = ref.watch(workspaceProvider);
    final activeTabNodeId = ref.watch(tabProvider).activeTab?.nodeId;
    final isSelected = (workspace.selectedFolderId == node.id && node.isFolder) ||
        (node.isFile && node.id == activeTabNodeId);
    final isEditing = _editingNodeId == node.id;
    final widgets = <Widget>[];

    Widget nodeWidget = _TreeNodeItem(
      node: node,
      depth: depth,
      isSelected: isSelected,
      isEditing: isEditing,
      onTap: () {
        if (node.isFolder) {
          ref.read(workspaceProvider.notifier).selectFolder(node.id);
          ref.read(workspaceProvider.notifier).toggleExpand(node.id);
        } else {
          ref.read(workspaceProvider.notifier).clearFolderSelection();
          ref.read(tabProvider.notifier).openFileTab(node.id, node.name, node.fileType);
        }
      },
      onContextMenu: (pos) => _showContextMenu(context, pos, node),
      onDoubleTap: () => _startRename(node),
      renameController: _renameController,
      onRenameSubmitted: (value) => _finishRename(node.id, value),
      fileIcon: _fileIcon(node),
      statusDot: node.ingestionStatus != null && !isEditing ? _statusDot(node.ingestionStatus!) : null,
    );

    final feedbackWidget = Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xF0FFFFFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: GlassTheme.glassBorder),
          boxShadow: const [BoxShadow(color: Color(0x28000000), blurRadius: 12)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _fileIcon(node),
          const SizedBox(width: 8),
          Text(node.name, style: const TextStyle(fontSize: 13.5, color: GlassTheme.ink)),
        ]),
      ),
    );

    final draggingWidget = Opacity(opacity: 0.3, child: nodeWidget);

    Widget finalWidget;
    if (node.isFolder) {
      finalWidget = DragTarget<TreeNodeModel>(
        onWillAcceptWithDetails: (details) => details.data.id != node.id,
        onAcceptWithDetails: (details) {
          ref.read(workspaceProvider.notifier).moveNode(details.data.id, node.id);
        },
        builder: (context, candidateData, rejectedData) {
          return Draggable<TreeNodeModel>(
            data: node,
            feedback: feedbackWidget,
            childWhenDragging: draggingWidget,
            child: Container(
              decoration: BoxDecoration(
                color: candidateData.isNotEmpty ? GlassTheme.accent.withValues(alpha: 0.1) : null,
                border: candidateData.isNotEmpty ? Border.all(color: GlassTheme.accent.withValues(alpha: 0.3)) : null,
                borderRadius: candidateData.isNotEmpty ? BorderRadius.circular(10) : null,
              ),
              child: nodeWidget,
            ),
          );
        },
      );
    } else {
      finalWidget = Draggable<TreeNodeModel>(
        data: node,
        feedback: feedbackWidget,
        childWhenDragging: draggingWidget,
        child: nodeWidget,
      );
    }

    widgets.add(finalWidget);

    if (node.isFolder && node.isExpanded) {
      for (final child in node.children) {
        widgets.addAll(_buildTreeNode(child, depth + 1));
      }
    }
    return widgets;
  }

  void _startRename(TreeNodeModel node) {
    setState(() {
      _editingNodeId = node.id;
      _renameController.text = node.name;
    });
  }

  void _finishRename(String nodeId, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isNotEmpty) {
      ref.read(workspaceProvider.notifier).renameNode(nodeId, trimmed);
    }
    setState(() => _editingNodeId = null);
  }

  void _showContextMenu(BuildContext context, Offset position, TreeNodeModel node) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final pos = position == Offset.zero
        ? const RelativeRect.fromLTRB(100, 200, 100, 200)
        : RelativeRect.fromRect(Rect.fromLTWH(position.dx, position.dy, 1, 1), Offset.zero & overlay.size);

    showMenu<String>(
      context: context,
      position: pos,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xF0FCFBFF),
      items: [
        PopupMenuItem(value: 'rename', child: Row(children: [const Icon(Icons.edit, size: 16, color: GlassTheme.ink2), const SizedBox(width: 8), const Text('Rename', style: TextStyle(fontSize: 13))])),
        PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red.shade400), const SizedBox(width: 8), Text('Delete', style: TextStyle(fontSize: 13, color: Colors.red.shade400))])),
        if (node.isFile && node.ingestionStatus != null)
          PopupMenuItem(value: 'reprocess', child: Row(children: [const Icon(Icons.refresh, size: 16, color: GlassTheme.ink2), const SizedBox(width: 8), const Text('Reprocess', style: TextStyle(fontSize: 13))])),
        PopupMenuItem(value: 'ask_ai', child: Row(children: [
          const Icon(Icons.smart_toy, size: 16, color: GlassTheme.accent),
          const SizedBox(width: 8),
          const Text('Ask AI about this', style: TextStyle(fontSize: 13)),
        ])),
      ],
    ).then((value) {
      if (value == 'rename') _startRename(node);
      if (value == 'delete') _confirmDelete(node);
      if (value == 'ask_ai') _askAiAbout(node);
    });
  }

  void _askAiAbout(TreeNodeModel node) {
    ref.read(chatVisibleProvider.notifier).state = true;
    ref.read(chatProvider.notifier).sendMessage('Tell me about the file "${node.name}". Summarize its key content.');
  }

  void _confirmDelete(TreeNodeModel node) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: const Color(0xF0FCFBFF),
        title: const Text('Delete'),
        content: Text('Are you sure you want to delete "${node.name}"${node.isFolder ? " and all its contents" : ""}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(workspaceProvider.notifier).deleteNode(node.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _fileIcon(TreeNodeModel node) {
    if (node.isFolder) {
      return Icon(node.isExpanded ? Icons.folder_open : Icons.folder, size: 16, color: GlassTheme.accent);
    }
    final colors = {
      'md': GlassTheme.accent,
      'pdf': const Color(0xFFE57398),
      'docx': const Color(0xFF6CA8E8),
      'txt': const Color(0xFF5CD4A8),
      'csv': const Color(0xFFE8C85C),
    };
    return Icon(Icons.description, size: 16, color: colors[node.fileType] ?? GlassTheme.ink3);
  }

  Widget _statusDot(String status) {
    final color = {
      'complete': const Color(0xFF5CD4A8),
      'processing': const Color(0xFFE8C85C),
      'failed': const Color(0xFFE57398),
      'pending': const Color(0xFF6CA8E8),
    }[status] ?? GlassTheme.ink3;
    return Container(
      width: 7, height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)],
      ),
    );
  }

  Future<void> _importFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    ref.read(workspaceProvider.notifier).uploadFileData(file.name, file.bytes!);
  }

  void _createNode(String type) {
    final name = type == 'folder' ? 'New Folder' : 'Untitled.md';
    ref.read(workspaceProvider.notifier).createNode(name, type, fileType: type == 'file' ? 'md' : null, content: type == 'file' ? '' : null);
  }
}

class _GlassIconBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _GlassIconBtn({required this.icon, required this.tooltip, required this.onTap});

  @override
  State<_GlassIconBtn> createState() => _GlassIconBtnState();
}

class _GlassIconBtnState extends State<_GlassIconBtn> {
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
            child: Center(
              child: AnimatedScale(
                scale: _hovered ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(widget.icon, size: 14, color: GlassTheme.ink3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TreeNodeItem extends StatefulWidget {
  final TreeNodeModel node;
  final int depth;
  final bool isSelected;
  final bool isEditing;
  final VoidCallback onTap;
  final void Function(Offset) onContextMenu;
  final VoidCallback onDoubleTap;
  final TextEditingController renameController;
  final ValueChanged<String> onRenameSubmitted;
  final Widget fileIcon;
  final Widget? statusDot;

  const _TreeNodeItem({
    required this.node,
    required this.depth,
    required this.isSelected,
    required this.isEditing,
    required this.onTap,
    required this.onContextMenu,
    required this.onDoubleTap,
    required this.renameController,
    required this.onRenameSubmitted,
    required this.fileIcon,
    this.statusDot,
  });

  @override
  State<_TreeNodeItem> createState() => _TreeNodeItemState();
}

class _TreeNodeItemState extends State<_TreeNodeItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isSelected
        ? GlassTheme.accent.withValues(alpha: 0.08)
        : _isHovered
            ? const Color(0x18000000)
            : const Color(0x00FFFFFF);

    return GestureDetector(
      onSecondaryTapDown: (details) => widget.onContextMenu(details.globalPosition),
      onLongPress: () => widget.onContextMenu(Offset.zero),
      onDoubleTap: widget.onDoubleTap,
      child: MouseRegion(
        onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = true); }),
        onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = false); }),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(left: 10.0 + widget.depth * 14, right: 10, top: 7, bottom: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: bgColor,
            ),
            child: Row(
              children: [
                if (widget.isSelected)
                  Container(
                    width: 3, height: 16,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: GlassTheme.accent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                if (widget.node.isFolder)
                  Icon(
                    widget.node.isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    size: 14, color: GlassTheme.ink3,
                  )
                else
                  const SizedBox(width: 14),
                const SizedBox(width: 8),
                widget.fileIcon,
                const SizedBox(width: 8),
                Expanded(
                  child: widget.isEditing
                      ? TextField(
                          controller: widget.renameController,
                          autofocus: true,
                          style: const TextStyle(fontSize: 13.5, color: GlassTheme.ink),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onSubmitted: widget.onRenameSubmitted,
                          onTapOutside: (_) => widget.onRenameSubmitted(widget.renameController.text),
                        )
                      : Text(
                          widget.node.name,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: widget.isSelected ? GlassTheme.ink : GlassTheme.ink2,
                            fontWeight: widget.isSelected ? FontWeight.w500 : FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                if (widget.statusDot != null) widget.statusDot!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
