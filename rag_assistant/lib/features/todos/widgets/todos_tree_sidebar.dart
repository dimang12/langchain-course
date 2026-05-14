import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/glass_theme.dart';
import '../models/todo_models.dart';
import '../providers/todos_provider.dart';

class TodosTreeSidebar extends ConsumerWidget {
  const TodosTreeSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todosProvider);
    final notifier = ref.read(todosProvider.notifier);

    final items = <Widget>[
      _header(context, notifier),
      _allTasksItem(state, notifier),
    ];
    if (state.folders.isEmpty) {
      items.add(const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No folders yet.\nClick + to create one.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: GlassTheme.ink3),
        ),
      ));
    } else {
      items.addAll(_buildTree(context, state, notifier, parentId: null, depth: 0));
    }

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: GlassTheme.line)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: items,
      ),
    );
  }

  Widget _header(BuildContext context, TodosNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'FOLDERS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: GlassTheme.ink3,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined, size: 18),
            onPressed: () => _showCreateFolder(context, notifier, null),
          ),
        ],
      ),
    );
  }

  Widget _allTasksItem(TodosState state, TodosNotifier notifier) {
    final selected = state.selectedFolderId == null;
    return _row(
      depth: 0,
      icon: Icons.inbox_outlined,
      name: 'All Tasks',
      selected: selected,
      onTap: () => notifier.selectFolder(null),
    );
  }

  List<Widget> _buildTree(
    BuildContext outerContext,
    TodosState state,
    TodosNotifier notifier, {
    required String? parentId,
    required int depth,
  }) {
    final children = state.folders.where((f) => f.parentId == parentId).toList();
    final widgets = <Widget>[];
    for (final folder in children) {
      final selected = state.selectedFolderId == folder.id;
      widgets.add(_row(
        depth: depth,
        icon: Icons.folder_outlined,
        name: folder.name,
        selected: selected,
        onTap: () => notifier.selectFolder(folder.id),
        onMore: (action) => _onFolderAction(outerContext, action, folder, notifier),
      ));
      widgets.addAll(_buildTree(outerContext, state, notifier, parentId: folder.id, depth: depth + 1));
    }
    return widgets;
  }

  Widget _row({
    required int depth,
    required IconData icon,
    required String name,
    required bool selected,
    required VoidCallback onTap,
    void Function(String)? onMore,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: EdgeInsets.only(left: 8 + depth * 16.0, right: 4, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: selected ? GlassTheme.accent.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: selected ? GlassTheme.accent : GlassTheme.ink3),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  color: selected ? GlassTheme.accent : GlassTheme.ink2,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onMore != null)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, size: 16, color: GlassTheme.ink3),
                onSelected: onMore,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'add_sub', child: Text('Add subfolder')),
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onFolderAction(
    BuildContext context,
    String action,
    TodoFolderModel folder,
    TodosNotifier notifier,
  ) async {
    switch (action) {
      case 'add_sub':
        await _showCreateFolder(context, notifier, folder.id);
        break;
      case 'rename':
        await _showRenameFolder(context, notifier, folder);
        break;
      case 'delete':
        await _confirmDelete(context, notifier, folder);
        break;
    }
  }

  Future<void> _showCreateFolder(
    BuildContext context,
    TodosNotifier notifier,
    String? parentId,
  ) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(parentId == null ? 'New folder' : 'New subfolder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
          onSubmitted: (_) => Navigator.pop(dialogContext, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok == true && controller.text.trim().isNotEmpty) {
      await notifier.createFolder(name: controller.text.trim(), parentId: parentId);
    }
  }

  Future<void> _showRenameFolder(
    BuildContext context,
    TodosNotifier notifier,
    TodoFolderModel folder,
  ) async {
    final controller = TextEditingController(text: folder.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (_) => Navigator.pop(dialogContext, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && controller.text.trim().isNotEmpty) {
      await notifier.renameFolder(folder.id, controller.text.trim());
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TodosNotifier notifier,
    TodoFolderModel folder,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text('"${folder.name}" and all its tasks will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await notifier.deleteFolder(folder.id);
  }
}
