import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/glass_theme.dart';
import '../models/todo_models.dart';
import '../providers/todos_provider.dart';
import 'todo_form_dialog.dart';

// ignore: constant_identifier_names
const String DONE_STATUS = 'done';
// ignore: constant_identifier_names
const String TODO_STATUS = 'to do';
// ignore: constant_identifier_names
const String IN_PROGRESS_STATUS = 'in progress';

class TodoTableView extends ConsumerWidget {
  const TodoTableView({super.key});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todosProvider);
    final notifier = ref.read(todosProvider.notifier);
    final statuses = state.currentStatuses;
    final statusById = {for (final s in statuses) s.id: s};

    if (state.todos.isEmpty) {
      return const Center(
        child: Text(
          'No tasks yet. Click "+ Task" to add one.',
          style: TextStyle(color: GlassTheme.ink3),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24,
          headingTextStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: GlassTheme.ink3,
          ),
          columns: const [
            DataColumn(label: Text('DONE')),
            DataColumn(label: Text('TITLE')),
            DataColumn(label: Text('GOAL')),
            DataColumn(label: Text('STATUS')),
            DataColumn(label: Text('PRIORITY')),
            DataColumn(label: Text('DUE')),
            DataColumn(label: Text('EST')),
            DataColumn(label: Text('TAGS')),
            DataColumn(label: Text('')),
          ],
          rows: state.todos.map((t) {
            final status = t.statusId != null ? statusById[t.statusId!] : null;
            final isDoneByStatus = status != null && status.name.toLowerCase() == DONE_STATUS;
            final displayChecked = t.isCompleted || isDoneByStatus;
            final goalOption = state.goalForTodo(t);
            return DataRow(
              cells: [
                DataCell(Checkbox(
                  value: displayChecked,
                  onChanged: (v) => _toggleDone(t, statuses, notifier, v ?? false),
                )),
                DataCell(_TitleCell(todo: t)),
                DataCell(_goalCell(goalOption)),
                DataCell(_StatusCell(
                  todo: t,
                  status: status,
                  statuses: statuses,
                  notifier: notifier,
                )),
                DataCell(_PriorityCell(todo: t, notifier: notifier)),
                DataCell(_DueCell(todo: t, notifier: notifier)),
                DataCell(_estCell(t.estimatedMinutes)),
                DataCell(_tagsCell(t.tags)),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (t.isTodayPriority)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Tooltip(
                          message: "Today's priority (set by Prioritizer)",
                          child: Icon(Icons.star, size: 18, color: Color(0xFFE8C85C)),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: GlassTheme.ink3),
                      onPressed: () => _editTodo(context, notifier, t, statuses, state.goalOptions),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      onPressed: () => _confirmDelete(context, notifier, t),
                    ),
                  ],
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _goalCell(GoalOptionModel? goal) {
    if (goal == null) return const Text('—', style: TextStyle(color: GlassTheme.ink3, fontSize: 12));
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: GlassTheme.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: GlassTheme.accent.withValues(alpha: 0.25)),
        ),
        child: Text(
          goal.title,
          style: const TextStyle(fontSize: 11, color: GlassTheme.ink2, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }

  Widget _estCell(int? minutes) {
    if (minutes == null) return const Text('—', style: TextStyle(color: GlassTheme.ink3, fontSize: 12));
    final label = minutes < 60 ? '${minutes}m' : '${(minutes / 60).toStringAsFixed(minutes % 60 == 0 ? 0 : 1)}h';
    return Text(label, style: const TextStyle(fontSize: 12, color: GlassTheme.ink2));
  }

  Widget _tagsCell(List<String> tags) {
    if (tags.isEmpty) return const Text('—', style: TextStyle(color: GlassTheme.ink3));
    return Wrap(
      spacing: 4,
      children: tags.take(3).map((t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: GlassTheme.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(t, style: const TextStyle(fontSize: 10, color: GlassTheme.ink2)),
      )).toList(),
    );
  }

  Future<void> _toggleDone(
    TodoModel todo,
    List<TodoStatusModel> statuses,
    TodosNotifier notifier,
    bool checked,
  ) async {
    final patch = <String, dynamic>{'completed': checked};
    if (checked) {
      // Find the "Done" status; otherwise leave status_id alone.
      final done = statuses.where((s) => s.name.toLowerCase() == DONE_STATUS).firstOrNull;
      if (done != null && done.id != todo.statusId) {
        patch['status_id'] = done.id;
      }
    } else {
      // Move back to the first non-done status (typically "To Do").
      final firstNonDone = statuses.where((s) => s.name.toLowerCase() != DONE_STATUS).firstOrNull;
      if (firstNonDone != null && firstNonDone.id != todo.statusId) {
        patch['status_id'] = firstNonDone.id;
      }
    }
    await notifier.updateTodo(todo.id, patch);
  }

  Future<void> _editTodo(
    BuildContext context,
    TodosNotifier notifier,
    TodoModel todo,
    List<TodoStatusModel> statuses,
    List<GoalOptionModel> goalOptions,
  ) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => TodoFormDialog(
        notifier: notifier,
        statuses: statuses,
        existing: todo,
        goalOptions: goalOptions,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, TodosNotifier notifier, TodoModel todo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('"${todo.title}" will be permanently removed.'),
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
    if (ok == true) await notifier.deleteTodo(todo.id);
  }
}

class _TitleCell extends StatelessWidget {
  final TodoModel todo;
  const _TitleCell({required this.todo});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Text(
        todo.title,
        style: TextStyle(
          fontSize: 14,
          color: todo.isCompleted ? GlassTheme.ink3 : GlassTheme.ink,
          decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }
}

Color _hexToColor(String hex) {
  final cleaned = hex.replaceAll('#', '');
  final value = int.tryParse('FF$cleaned', radix: 16) ?? 0xFF7C5CFF;
  return Color(value);
}

Color _priorityColor(String priority) {
  switch (priority) {
    case 'high':
      return const Color(0xFFE57398);
    case 'low':
      return const Color(0xFF8D89A0);
    default:
      return const Color(0xFFE8C85C);
  }
}

class _StatusCell extends StatelessWidget {
  final TodoModel todo;
  final TodoStatusModel? status;
  final List<TodoStatusModel> statuses;
  final TodosNotifier notifier;

  const _StatusCell({
    required this.todo,
    required this.status,
    required this.statuses,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final s = status;
    final color = s != null ? _hexToColor(s.color) : GlassTheme.ink3;
    final label = s?.name ?? 'No status';

    return PopupMenuButton<String>(
      tooltip: '',
      padding: EdgeInsets.zero,
      onSelected: (newId) {
        if (newId == todo.statusId) return;
        final newStatus = statuses.where((s) => s.id == newId).firstOrNull;
        final patch = <String, dynamic>{'status_id': newId};
        if (newStatus != null) {
          final isDone = newStatus.name.toLowerCase() == DONE_STATUS;
          if (isDone && !todo.isCompleted) {
            patch['completed'] = true;
          } else if (!isDone && todo.isCompleted) {
            patch['completed'] = false;
          }
        }
        notifier.updateTodo(todo.id, patch);
      },
      itemBuilder: (_) => statuses
          .map((opt) => PopupMenuItem(
                value: opt.id,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _hexToColor(opt.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(opt.name),
                  ],
                ),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }
}

class _PriorityCell extends StatelessWidget {
  final TodoModel todo;
  final TodosNotifier notifier;

  const _PriorityCell({required this.todo, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(todo.priority);

    return PopupMenuButton<String>(
      tooltip: '',
      padding: EdgeInsets.zero,
      onSelected: (newPriority) {
        if (newPriority != todo.priority) {
          notifier.updateTodo(todo.id, {'priority': newPriority});
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'low', child: Text('Low')),
        PopupMenuItem(value: 'medium', child: Text('Medium')),
        PopupMenuItem(value: 'high', child: Text('High')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          todo.priority.toUpperCase(),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );
  }
}

class _DueCell extends StatelessWidget {
  final TodoModel todo;
  final TodosNotifier notifier;

  const _DueCell({required this.todo, required this.notifier});

  bool get _isOverdue =>
      todo.dueDate != null && !todo.isCompleted && todo.dueDate!.isBefore(DateTime.now());

  Color get _color {
    if (todo.dueDate == null) return GlassTheme.ink3;
    if (todo.isCompleted) return GlassTheme.ink3;
    if (_isOverdue) return Colors.redAccent;
    return GlassTheme.ink2;
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: todo.dueDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      await notifier.updateTodo(todo.id, {'due_date': picked.toIso8601String()});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _pick(context),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              todo.dueDate != null ? _formatDate(todo.dueDate!) : '+ Due',
              style: TextStyle(
                fontSize: 13,
                color: _color,
                fontWeight: _isOverdue ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
        if (todo.dueDate != null)
          InkWell(
            onTap: () => notifier.updateTodo(todo.id, {'due_date': ''}),
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close, size: 12, color: GlassTheme.ink3),
            ),
          ),
      ],
    );
  }
}
