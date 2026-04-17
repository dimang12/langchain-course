import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tree_node_model.dart';
import '../providers/workspace_provider.dart';
import '../providers/tab_provider.dart';
import '../../chat/providers/chat_provider.dart';
import 'floating_chat.dart';

class TreeSidebar extends ConsumerStatefulWidget {
  final double width;
  final ValueChanged<double>? onWidthChanged;
  const TreeSidebar({super.key, this.width = 260, this.onWidthChanged});

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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: widget.width,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.45),
          ),
          child: Column(
            children: [
          // Header
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text('WORKSPACE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Colors.grey.shade600)),
                const Spacer(),
                // Sort menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.sort, size: 18, color: Colors.grey.shade600),
                  tooltip: 'Sort',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (mode) => ref.read(workspaceProvider.notifier).setSortMode(mode),
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'name', child: Row(children: [
                      Icon(Icons.sort_by_alpha, size: 16, color: workspace.sortMode == 'name' ? const Color(0xFF6c5ce7) : Colors.grey),
                      const SizedBox(width: 8), const Text('Name', style: TextStyle(fontSize: 13)),
                    ])),
                    PopupMenuItem(value: 'date', child: Row(children: [
                      Icon(Icons.schedule, size: 16, color: workspace.sortMode == 'date' ? const Color(0xFF6c5ce7) : Colors.grey),
                      const SizedBox(width: 8), const Text('Date', style: TextStyle(fontSize: 13)),
                    ])),
                    PopupMenuItem(value: 'type', child: Row(children: [
                      Icon(Icons.category, size: 16, color: workspace.sortMode == 'type' ? const Color(0xFF6c5ce7) : Colors.grey),
                      const SizedBox(width: 8), const Text('Type', style: TextStyle(fontSize: 13)),
                    ])),
                  ],
                ),
                const SizedBox(width: 4),
                _ActionButton(icon: Icons.upload_file, tooltip: 'Import File', onTap: () => _importFile()),
                const SizedBox(width: 4),
                _ActionButton(icon: Icons.create_new_folder_outlined, tooltip: 'New Folder', onTap: () => _createNode('folder')),
                const SizedBox(width: 4),
                _ActionButton(icon: Icons.note_add_outlined, tooltip: 'New File', onTap: () => _createNode('file')),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade300),
          // Tree
          Expanded(
            child: workspace.isLoading && workspace.tree.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : workspace.tree.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.folder_open, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text('Empty workspace', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Create a file or import documents', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                      ]))
                    : ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: workspace.tree.map((node) => _buildTreeNode(node, 0)).expand((e) => e).toList(),
                      ),
          ),
        ],
      ),
    ),
    MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          final newWidth = (widget.width + details.delta.dx).clamp(180.0, 500.0);
          widget.onWidthChanged?.call(newWidth);
        },
        child: Container(
          width: 4,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 1,
              color: Colors.grey.shade300,
            ),
          ),
        ),
      ),
    ),
    ],
    );
  }

  List<Widget> _buildTreeNode(TreeNodeModel node, int depth) {
    final workspace = ref.watch(workspaceProvider);
    final isSelected = workspace.selectedFolderId == node.id && node.isFolder;
    final isEditing = _editingNodeId == node.id;
    final widgets = <Widget>[];

    Widget nodeWidget = GestureDetector(
      onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition, node),
      onLongPress: () => _showContextMenu(context, Offset.zero, node),
      onDoubleTap: () => _startRename(node),
      child: InkWell(
        onTap: () {
          if (node.isFolder) {
            ref.read(workspaceProvider.notifier).selectFolder(node.id);
            ref.read(workspaceProvider.notifier).toggleExpand(node.id);
          } else {
            ref.read(tabProvider.notifier).openFileTab(node.id, node.name, node.fileType);
          }
        },
        child: Container(
          padding: EdgeInsets.only(left: 12.0 + depth * 16, right: 12, top: 5, bottom: 5),
          color: isSelected ? const Color(0xFF6c5ce7).withValues(alpha: 0.08) : null,
          child: Row(
            children: [
              if (node.isFolder)
                Icon(node.isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, size: 18, color: Colors.grey.shade600)
              else
                const SizedBox(width: 18),
              const SizedBox(width: 4),
              _fileIcon(node),
              const SizedBox(width: 8),
              Expanded(
                child: isEditing
                    ? TextField(
                        controller: _renameController,
                        autofocus: true,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 4), border: OutlineInputBorder()),
                        onSubmitted: (value) => _finishRename(node.id, value),
                        onTapOutside: (_) => _finishRename(node.id, _renameController.text),
                      )
                    : Text(node.name, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
              ),
              if (node.ingestionStatus != null && !isEditing) _statusDot(node.ingestionStatus!),
            ],
          ),
        ),
      ),
    );

    final feedbackWidget = Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _fileIcon(node),
          const SizedBox(width: 8),
          Text(node.name, style: const TextStyle(fontSize: 14)),
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
                color: candidateData.isNotEmpty ? const Color(0xFF6c5ce7).withValues(alpha: 0.1) : null,
                border: candidateData.isNotEmpty ? Border.all(color: const Color(0xFF6c5ce7).withValues(alpha: 0.3)) : null,
                borderRadius: candidateData.isNotEmpty ? BorderRadius.circular(4) : null,
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
        ? RelativeRect.fromLTRB(100, 200, 100, 200)
        : RelativeRect.fromRect(Rect.fromLTWH(position.dx, position.dy, 1, 1), Offset.zero & overlay.size);

    showMenu<String>(
      context: context,
      position: pos,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(value: 'rename', child: Row(children: [Icon(Icons.edit, size: 16, color: Colors.grey.shade700), const SizedBox(width: 8), const Text('Rename', style: TextStyle(fontSize: 13))])),
        PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete, size: 16, color: Colors.red), const SizedBox(width: 8), const Text('Delete', style: TextStyle(fontSize: 13, color: Colors.red))])),
        if (node.isFile && node.ingestionStatus != null)
          PopupMenuItem(value: 'reprocess', child: Row(children: [Icon(Icons.refresh, size: 16, color: Colors.grey.shade700), const SizedBox(width: 8), const Text('Reprocess', style: TextStyle(fontSize: 13))])),
        PopupMenuItem(value: 'ask_ai', child: Row(children: [
          const Icon(Icons.smart_toy, size: 16, color: Color(0xFF6c5ce7)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete'),
        content: Text('Are you sure you want to delete "${node.name}"${node.isFolder ? " and all its contents" : ""}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
      return Icon(node.isExpanded ? Icons.folder_open : Icons.folder, size: 18, color: const Color(0xFF6c5ce7));
    }
    final colors = {'md': const Color(0xFF6c5ce7), 'pdf': const Color(0xFFfd79a8), 'docx': const Color(0xFF74b9ff), 'txt': const Color(0xFF55efc4), 'csv': const Color(0xFFffeaa7)};
    return Icon(Icons.description, size: 18, color: colors[node.fileType] ?? Colors.grey);
  }

  Widget _statusDot(String status) {
    final color = {'complete': const Color(0xFF55efc4), 'processing': const Color(0xFFffeaa7), 'failed': const Color(0xFFfd79a8), 'pending': const Color(0xFF74b9ff)}[status] ?? Colors.grey;
    return Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)]));
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.grey.shade200,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: Colors.grey.shade600),
        ),
      ),
    );
  }
}
