import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/glass_theme.dart';
import '../../todos/providers/todos_provider.dart';
import '../models/calendar_event_model.dart';
import '../providers/calendar_provider.dart';

class AddEventDialog extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final TimeOfDay? initialEndTime;
  final CalendarNotifier notifier;
  final CalendarEventModel? existing;

  const AddEventDialog({
    super.key,
    this.initialDate,
    this.initialTime,
    this.initialEndTime,
    required this.notifier,
    this.existing,
  });

  @override
  ConsumerState<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends ConsumerState<AddEventDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _isAllDay = false;
  bool _isSaving = false;

  // Task generation state (new events only).
  bool _alsoCreateTask = false;
  String? _taskFolderId;
  String? _taskGoalId;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _descriptionController.text = existing.description ?? '';
      _locationController.text = existing.location ?? '';
      _startDate = DateTime(existing.startTime.year, existing.startTime.month, existing.startTime.day);
      _startTime = TimeOfDay(hour: existing.startTime.hour, minute: existing.startTime.minute);
      _endTime = TimeOfDay(hour: existing.endTime.hour, minute: existing.endTime.minute);
      _isAllDay = existing.isAllDay;
    } else {
      _startDate = widget.initialDate ?? DateTime.now();
      _startTime = widget.initialTime ?? TimeOfDay(hour: DateTime.now().hour + 1, minute: 0);
      _endTime = widget.initialEndTime ?? TimeOfDay(hour: _startTime.hour + 1, minute: _startTime.minute);
      // Lazy-load folders + goals so the picker has options if user opts in.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final todos = ref.read(todosProvider.notifier);
        final state = ref.read(todosProvider);
        if (state.folders.isEmpty) await todos.loadFolders();
        if (state.goalOptions.isEmpty) await todos.loadGoalOptions();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSaving = true);

    final start = DateTime(_startDate.year, _startDate.month, _startDate.day, _startTime.hour, _startTime.minute);
    final end = DateTime(_startDate.year, _startDate.month, _startDate.day, _endTime.hour, _endTime.minute);
    final startFinal = _isAllDay ? DateTime(_startDate.year, _startDate.month, _startDate.day) : start;
    final endFinal = _isAllDay ? DateTime(_startDate.year, _startDate.month, _startDate.day, 23, 59) : end;
    final descFinal = _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();
    final locFinal = _locationController.text.trim().isEmpty ? null : _locationController.text.trim();

    final ok = _isEditing
        ? await widget.notifier.updateEvent(
            eventId: widget.existing!.id,
            title: title,
            startTime: startFinal,
            endTime: endFinal,
            description: descFinal,
            isAllDay: _isAllDay,
            location: locFinal,
          )
        : await widget.notifier.createEvent(
            title: title,
            startTime: startFinal,
            endTime: endFinal,
            description: descFinal,
            isAllDay: _isAllDay,
            location: locFinal,
          );

    // Spawn a paired Todo if requested (new events only).
    if (ok && !_isEditing && _alsoCreateTask && _taskFolderId != null) {
      final durationMin = endFinal.difference(startFinal).inMinutes;
      await ref.read(todosProvider.notifier).createTodo(
            title: title,
            description: descFinal,
            dueDate: startFinal,
            estimatedMinutes: durationMin > 0 ? durationMin : null,
            goalId: _taskGoalId,
            folderId: _taskFolderId,
          );
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) Navigator.pop(context, true);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  String _formatDate(DateTime d) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Widget _buildTaskSection() {
    final todosState = ref.watch(todosProvider);
    final folders = todosState.folders;
    final goals = todosState.goalOptions;

    // Auto-pick the first folder once it loads, so the user just has to check
    // the box without thinking about which list.
    if (_alsoCreateTask && _taskFolderId == null && folders.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _taskFolderId = folders.first.id);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        const Divider(height: 1, color: GlassTheme.line),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          value: _alsoCreateTask,
          onChanged: (v) => setState(() => _alsoCreateTask = v ?? false),
          title: const Text(
            'Also create a task',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          subtitle: const Text(
            "Spawn a linked Todo with this event's title, due date, and estimated minutes.",
            style: TextStyle(fontSize: 11, color: GlassTheme.ink3),
          ),
        ),
        if (_alsoCreateTask) ...[
          const SizedBox(height: 4),
          if (folders.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'No todo folders yet — create one from the Todos tab first.',
                style: TextStyle(fontSize: 11, color: Colors.redAccent),
              ),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _taskFolderId ?? folders.first.id,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Todo folder'),
              items: folders
                  .map((f) => DropdownMenuItem(value: f.id, child: Text(f.name)))
                  .toList(),
              onChanged: (v) => setState(() => _taskFolderId = v),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _taskGoalId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Linked Goal (optional)',
              helperText: 'Helps the Prioritizer rank this task',
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('— No goal —'),
              ),
              ...goals.map(
                (g) => DropdownMenuItem<String?>(
                  value: g.id,
                  child: Text(
                    '${g.title} [${g.level} • P${g.priority}]',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _taskGoalId = v),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const defaultFontStyle = TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w400);
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Event' : 'New Event', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      actionsAlignment: MainAxisAlignment.end,
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Title'),
              style: defaultFontStyle,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today, size: 20),
              title: Text(_formatDate(_startDate), style: defaultFontStyle),
              onTap: _pickDate,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('All day'),
              value: _isAllDay,
              onChanged: (v) => setState(() => _isAllDay = v),
            ),
            if (!_isAllDay)
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule, size: 20),
                      title: Text(_formatTime(_startTime), style: defaultFontStyle),
                      onTap: () => _pickTime(true),
                    ),
                  ),
                  const Text(' - '),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_formatTime(_endTime), style: defaultFontStyle),
                      onTap: () => _pickTime(false),
                    ),
                  ),
                ],
              ),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location (optional)'),
              style: defaultFontStyle,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              style: defaultFontStyle,
            ),
            if (!_isEditing) _buildTaskSection(),
          ],
        ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
