import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/knowledge_models.dart';
import '../providers/knowledge_provider.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(knowledgeProvider.notifier).loadAll();
    });
  }

  Future<void> _addGoalDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String level = 'personal';
    int priority = 3;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Goal'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g., Ship AI coworker v1'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: level,
                        decoration: const InputDecoration(labelText: 'Level'),
                        items: const [
                          DropdownMenuItem(value: 'org', child: Text('Organization')),
                          DropdownMenuItem(value: 'team', child: Text('Team')),
                          DropdownMenuItem(value: 'personal', child: Text('Personal')),
                        ],
                        onChanged: (v) => setDialogState(() => level = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: priority,
                        decoration: const InputDecoration(labelText: 'Priority'),
                        items: List.generate(5, (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text('P${i + 1}${i == 0 ? ' Critical' : i == 4 ? ' Nice' : ''}'),
                        )),
                        onChanged: (v) => setDialogState(() => priority = v!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result == true && titleCtrl.text.trim().isNotEmpty) {
      await ref.read(knowledgeProvider.notifier).createGoal(
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        level: level,
        priority: priority,
      );
    }
  }

  Future<void> _extractDialog() async {
    final contentCtrl = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Extract from text'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Paste meeting notes, emails, or any text. The AI will extract goals, decisions, follow-ups, and people.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 10,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Paste text here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, contentCtrl.text.trim()),
            child: const Text('Extract'),
          ),
        ],
      ),
    );

    if (result != null && result.length >= 20) {
      final counts = await ref.read(knowledgeProvider.notifier).extract(result);
      if (counts != null && mounted) {
        final total = counts.values.fold(0, (a, b) => a + b);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Extracted $total entities: ${counts.entries.where((e) => e.value > 0).map((e) => "${e.value} ${e.key}").join(", ")}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(knowledgeProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return Stack(
      children: [
        if (state.isLoading && state.goals.isEmpty && state.followups.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (state.goals.isEmpty && state.followups.isEmpty)
          _emptyState(context)
        else
          RefreshIndicator(
            onRefresh: () => ref.read(knowledgeProvider.notifier).loadAll(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
              children: [
                Row(
                  children: [
                    Text('Goals & Knowledge', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (state.people.isNotEmpty || state.decisions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(label: Text('${state.people.length} people, ${state.decisions.length} decisions', style: const TextStyle(fontSize: 11))),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                if (state.orgGoals.isNotEmpty) _goalSection(context, 'Organization', state.orgGoals, Colors.indigo),
                if (state.teamGoals.isNotEmpty) _goalSection(context, 'Team', state.teamGoals, Colors.teal),
                if (state.personalGoals.isNotEmpty) _goalSection(context, 'Personal', state.personalGoals, primary),
                if (state.openFollowups.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Open Follow-Ups', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ...state.openFollowups.map((f) => _followupTile(f)),
                ],
                if (state.decisions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Recent Decisions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ...state.decisions.take(5).map((d) => _decisionTile(d)),
                ],
              ],
            ),
          ),

        // FABs
        Positioned(
          right: 16,
          bottom: 80,
          child: FloatingActionButton.small(
            heroTag: 'extract',
            onPressed: state.isExtracting ? null : _extractDialog,
            tooltip: 'Extract from text',
            child: state.isExtracting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_fix_high, size: 18),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'addgoal',
            onPressed: _addGoalDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Goal'),
          ),
        ),
      ],
    );
  }

  Widget _goalSection(BuildContext context, String label, List<GoalModel> goals, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: accent),
              ),
              const SizedBox(width: 8),
              Text('${goals.length}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 8),
          ...goals.map((g) => _goalTile(g, accent)),
        ],
      ),
    );
  }

  Widget _goalTile(GoalModel goal, Color accent) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            'P${goal.priority}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent),
          ),
        ),
        title: Text(goal.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: goal.dueDate != null
            ? Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Due ${goal.dueDate}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              )
            : null,
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey.shade400),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete goal?'),
                content: Text(goal.title),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              ref.read(knowledgeProvider.notifier).deleteGoal(goal.id);
            }
          },
        ),
      ),
    );
  }

  Widget _followupTile(FollowUpModel followup) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: IconButton(
          icon: const Icon(Icons.check_circle_outline),
          color: Theme.of(context).colorScheme.primary,
          onPressed: () => ref.read(knowledgeProvider.notifier).markFollowupDone(followup.id),
          tooltip: 'Mark done',
        ),
        title: Text(followup.description, style: const TextStyle(fontSize: 14)),
        subtitle: Row(
          children: [
            if (followup.owner != null) ...[
              Icon(Icons.person_outline, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 3),
              Text(followup.owner!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(width: 10),
            ],
            if (followup.dueDate != null) ...[
              Icon(Icons.schedule, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 3),
              Text(followup.dueDate!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _decisionTile(DecisionModel decision) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(Icons.gavel, size: 18, color: Colors.grey.shade600),
        title: Text(decision.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: decision.rationale != null
            ? Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  decision.rationale!,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : null,
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No goals yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Add goals manually, or paste meeting notes/documents to extract them automatically.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
