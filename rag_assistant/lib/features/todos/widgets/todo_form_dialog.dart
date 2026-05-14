import 'package:flutter/material.dart';
import '../models/todo_models.dart';
import '../providers/todos_provider.dart';

class TodoFormDialog extends StatefulWidget {
  final TodosNotifier notifier;
  final TodoModel? existing;
  final List<TodoStatusModel> statuses;
  final List<GoalOptionModel> goalOptions;

  const TodoFormDialog({
    super.key,
    required this.notifier,
    required this.statuses,
    this.existing,
    this.goalOptions = const [],
  });

  @override
  State<TodoFormDialog> createState() => _TodoFormDialogState();
}

class _TodoFormDialogState extends State<TodoFormDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _tagsController = TextEditingController();
  final _estimatedController = TextEditingController();
  String _priority = 'medium';
  DateTime? _dueDate;
  String? _statusId;
  String? _goalId;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleController.text = e.title;
      _descController.text = e.description ?? '';
      _tagsController.text = e.tags.join(', ');
      _priority = e.priority;
      _dueDate = e.dueDate;
      _statusId = e.statusId;
      _goalId = e.goalId;
      if (e.estimatedMinutes != null) {
        _estimatedController.text = e.estimatedMinutes!.toString();
      }
    } else if (widget.statuses.isNotEmpty) {
      _statusId = widget.statuses.first.id;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _tagsController.dispose();
    _estimatedController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);

    final tags = _tagsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final desc = _descController.text.trim().isEmpty ? null : _descController.text.trim();

    final estimatedMinutes = int.tryParse(_estimatedController.text.trim());

    bool ok;
    if (_isEditing) {
      ok = await widget.notifier.updateTodo(widget.existing!.id, {
        'title': title,
        if (desc != null) 'description': desc,
        'priority': _priority,
        'due_date': _dueDate?.toIso8601String() ?? '',
        'tags': tags,
        if (_statusId != null) 'status_id': _statusId,
        'goal_id': _goalId ?? '',
        if (estimatedMinutes != null) 'estimated_minutes': estimatedMinutes,
      });
    } else {
      final created = await widget.notifier.createTodo(
        title: title,
        description: desc,
        priority: _priority,
        dueDate: _dueDate,
        tags: tags,
        statusId: _statusId,
        goalId: _goalId,
        estimatedMinutes: estimatedMinutes,
      );
      ok = created != null;
    }

    if (mounted) {
      setState(() => _saving = false);
      if (ok) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Task' : 'New Task'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (markdown supported)',
                ),
              ),
              const SizedBox(height: 12),
              if (widget.statuses.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _statusId,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: widget.statuses
                      .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _statusId = v),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                ],
                onChanged: (v) => setState(() => _priority = v ?? 'medium'),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined, size: 20),
                title: Text(_dueDate != null ? _formatDate(_dueDate!) : 'No due date'),
                trailing: _dueDate != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _dueDate = null),
                      )
                    : const Icon(Icons.chevron_right, size: 20),
                onTap: _pickDueDate,
              ),
              TextField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma-separated)',
                ),
              ),
              const SizedBox(height: 12),
              if (widget.goalOptions.isNotEmpty)
                DropdownButtonFormField<String?>(
                  initialValue: _goalId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Linked Goal (optional)',
                    helperText: 'Connects this task to a goal for prioritization',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('— No goal —'),
                    ),
                    ...widget.goalOptions.map(
                      (g) => DropdownMenuItem<String?>(
                        value: g.id,
                        child: Text(
                          '${g.title} [${g.level} • P${g.priority}]',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _goalId = v),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _estimatedController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Estimated minutes (optional)',
                  helperText: 'Helps the Prioritizer fit tasks to calendar blocks',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
