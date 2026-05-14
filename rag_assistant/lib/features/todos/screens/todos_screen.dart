import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/glass_theme.dart';
import '../providers/todos_provider.dart';
import '../widgets/todo_form_dialog.dart';
import '../widgets/todo_table_view.dart';
import '../widgets/todos_tree_sidebar.dart';

class TodosScreen extends ConsumerStatefulWidget {
  const TodosScreen({super.key});

  @override
  ConsumerState<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends ConsumerState<TodosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(todosProvider.notifier);
      await notifier.loadFolders();
      await notifier.loadTodos();
      await notifier.loadGoalOptions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todosProvider);
    final notifier = ref.read(todosProvider.notifier);

    return Row(
      children: [
        const TodosTreeSidebar(),
        Expanded(
          child: Column(
            children: [
              _header(state, notifier),
              Expanded(
                child: state.isLoading && state.todos.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: GlassTheme.accent))
                    : const TodoTableView(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(TodosState state, TodosNotifier notifier) {
    final folder = state.selectedFolderId != null
        ? state.folders.firstWhere(
            (f) => f.id == state.selectedFolderId,
            orElse: () => state.folders.first,
          )
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GlassTheme.line)),
      ),
      child: Row(
        children: [
          Text(
            folder?.name ?? 'All Tasks',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: GlassTheme.ink,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${state.todos.length} ${state.todos.length == 1 ? 'task' : 'tasks'}',
            style: const TextStyle(fontSize: 12, color: GlassTheme.ink3),
          ),
          const Spacer(),
          _AddTaskButton(
            enabled: state.selectedFolderId != null,
            onTap: () => _addTask(notifier, state),
          ),
        ],
      ),
    );
  }

  Future<void> _addTask(TodosNotifier notifier, TodosState state) async {
    final statuses = state.currentStatuses;
    await showDialog<bool>(
      context: context,
      builder: (_) => TodoFormDialog(
        notifier: notifier,
        statuses: statuses,
        goalOptions: state.goalOptions,
      ),
    );
  }
}

class _AddTaskButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _AddTaskButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = enabled ? GlassTheme.accent : GlassTheme.ink3.withValues(alpha: 0.4);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'Task',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
