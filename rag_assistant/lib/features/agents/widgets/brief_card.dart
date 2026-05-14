import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/agent_run_model.dart';
import '../providers/agents_provider.dart';

class BriefCard extends ConsumerWidget {
  final AgentRunModel run;
  const BriefCard({super.key, required this.run});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white.withValues(alpha: 0.85),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wb_sunny_outlined, size: 14, color: primary),
                      const SizedBox(width: 6),
                      Text(
                        'Daily Brief',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(run.startedAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Top priorities (interactive checkboxes)
            if (run.topPriorities.isNotEmpty) ...[
              Row(
                children: [
                  Text(
                    'Top Priorities',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                  ),
                  const Spacer(),
                  if (run.taskCompletions.where((c) => c).isNotEmpty)
                    Text(
                      '${run.taskCompletions.where((c) => c).length}/${run.topPriorities.length} done',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ...run.topPriorities.asMap().entries.map((e) {
                final isDone = e.key < run.taskCompletions.length &&
                    run.taskCompletions[e.key];
                return _PriorityCheckbox(
                  index: e.key,
                  text: e.value,
                  isDone: isDone,
                  primary: primary,
                  onToggle: () {
                    ref.read(agentsProvider.notifier).toggleTaskCompletion(
                      run.id,
                      e.key,
                      !isDone,
                    );
                  },
                );
              }),
              const SizedBox(height: 12),
            ],

            // Context snapshot
            if (run.contextSnapshot != null && run.contextSnapshot!.isNotEmpty) ...[
              _sectionHeader(context, 'Context Snapshot'),
              const SizedBox(height: 6),
              Text(
                run.contextSnapshot!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Follow-ups
            if (run.followUps.isNotEmpty) ...[
              _sectionHeader(context, 'Follow-Ups'),
              const SizedBox(height: 6),
              ...run.followUps.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ', style: TextStyle(fontSize: 13)),
                        Expanded(
                          child: Text(
                            f,
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
            ],

            // Suggested plan
            if (run.suggestedPlan != null && run.suggestedPlan!.isNotEmpty) ...[
              _sectionHeader(context, 'Suggested Plan'),
              const SizedBox(height: 6),
              MarkdownBody(
                data: run.suggestedPlan!,
                shrinkWrap: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(fontSize: 13, height: 1.5, color: Colors.grey.shade800),
                  strong: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade900),
                  listBullet: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                  h2: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade900),
                  blockSpacing: 6,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // One insight
            if (run.oneInsight != null && run.oneInsight!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(color: primary, width: 3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, size: 16, color: primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        run.oneInsight!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Colors.grey.shade800,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Rating row
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Was this brief useful?',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 12),
                ...List.generate(5, (i) {
                  final starIndex = i + 1;
                  final filled = (run.userRating ?? 0) >= starIndex;
                  return IconButton(
                    icon: Icon(
                      filled ? Icons.star : Icons.star_border,
                      color: filled ? Colors.amber : Colors.grey.shade400,
                      size: 20,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ref.read(agentsProvider.notifier).rateRun(run.id, starIndex);
                    },
                  );
                }),
                const Spacer(),
                if (run.durationMs != null)
                  Text(
                    '${(run.durationMs! / 1000).toStringAsFixed(1)}s',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _PriorityCheckbox extends StatefulWidget {
  final int index;
  final String text;
  final bool isDone;
  final Color primary;
  final VoidCallback onToggle;

  const _PriorityCheckbox({
    required this.index,
    required this.text,
    required this.isDone,
    required this.primary,
    required this.onToggle,
  });

  @override
  State<_PriorityCheckbox> createState() => _PriorityCheckboxState();
}

class _PriorityCheckboxState extends State<_PriorityCheckbox> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = true); }),
      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = false); }),
      child: GestureDetector(
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.primary.withValues(alpha: 0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: widget.isDone
                      ? widget.primary
                      : widget.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: widget.isDone
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '${widget.index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: widget.primary,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    decoration: widget.isDone
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: widget.isDone ? Colors.grey.shade500 : null,
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
