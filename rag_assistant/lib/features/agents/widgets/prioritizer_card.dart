import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/agent_run_model.dart';
import '../providers/agents_provider.dart';

class PrioritizerCard extends ConsumerWidget {
  final AgentRunModel run;
  const PrioritizerCard({super.key, required this.run});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final priorities = run.priorityRecommendations;
    final deferred = run.deferred;
    final snapshot = run.contextSnapshot;
    final insight = run.oneInsight;

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
                    color: primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: primary),
                      const SizedBox(width: 6),
                      Text(
                        'Prioritizer',
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

            if (priorities.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No priorities returned. Link your todos to goals for sharper output.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),

            ...priorities.asMap().entries.map((e) {
              final isDone = e.key < run.taskCompletions.length && run.taskCompletions[e.key];
              return _PriorityRow(
                p: e.value,
                index: e.key,
                isDone: isDone,
                primary: primary,
                onToggle: () {
                  ref
                      .read(agentsProvider.notifier)
                      .toggleTaskCompletion(run.id, e.key, !isDone);
                },
              );
            }),

            if (snapshot != null && snapshot.isNotEmpty) ...[
              const SizedBox(height: 12),
              _sectionHeader(context, 'Context'),
              const SizedBox(height: 4),
              Text(
                snapshot,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.5),
              ),
            ],

            if (insight != null && insight.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border(left: BorderSide(color: primary, width: 3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, size: 16, color: primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        insight,
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (deferred.isNotEmpty) ...[
              const SizedBox(height: 14),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text(
                  'Deferred (${deferred.length})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                children: deferred
                    .map((d) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '• $d',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String label) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Colors.grey.shade600,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}';
  }
}


class _PriorityRow extends StatefulWidget {
  final PriorityRecommendation p;
  final int index;
  final bool isDone;
  final Color primary;
  final VoidCallback onToggle;

  const _PriorityRow({
    required this.p,
    required this.index,
    required this.isDone,
    required this.primary,
    required this.onToggle,
  });

  @override
  State<_PriorityRow> createState() => _PriorityRowState();
}

class _PriorityRowState extends State<_PriorityRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.primary;
    final isDone = widget.isDone;
    final p = widget.p;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: Tooltip(
              message: isDone ? 'Mark as not done' : 'Mark this priority done',
              child: GestureDetector(
                onTap: widget.onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? primary
                        : (_hover ? primary.withValues(alpha: 0.14) : Colors.transparent),
                    border: Border.all(
                      color: primary,
                      width: _hover && !isDone ? 2 : 1.5,
                    ),
                    boxShadow: _hover && !isDone
                        ? [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.25),
                              blurRadius: 6,
                              spreadRadius: 0.5,
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: isDone
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : (_hover
                          ? Icon(Icons.check, size: 16, color: primary)
                          : Text(
                              '${p.rank}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: primary,
                              ),
                            )),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDone ? Colors.grey.shade500 : Colors.black87,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    height: 1.3,
                  ),
                ),
                if (p.rationale != null && p.rationale!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    p.rationale!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
                if (p.suggestedBlock != null || p.estimatedMinutes != null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (p.suggestedBlock != null && p.suggestedBlock!.isNotEmpty)
                        _MetaChip(
                          icon: Icons.schedule,
                          label: p.suggestedBlock!,
                          color: primary,
                        ),
                      if (p.estimatedMinutes != null)
                        _MetaChip(
                          icon: Icons.timer_outlined,
                          label: '${p.estimatedMinutes}m',
                          color: Colors.grey.shade600,
                        ),
                    ],
                  ),
                ],
                if (p.evidence.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: p.evidence.map((ref) => _EvidenceChip(refStr: ref)).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}


class _EvidenceChip extends StatelessWidget {
  final String refStr;
  const _EvidenceChip({required this.refStr});

  ({IconData icon, Color color, String label}) _kind() {
    final parts = refStr.split(':');
    final kind = parts.isNotEmpty ? parts[0] : '';
    final id = parts.length > 1 ? parts[1] : '';
    final short = id.length > 8 ? id.substring(0, 8) : id;
    switch (kind) {
      case 'goal':
        return (icon: Icons.flag_outlined, color: const Color(0xFFA78BFA), label: 'goal • $short');
      case 'followup':
        return (icon: Icons.task_alt, color: const Color(0xFFE57398), label: 'followup • $short');
      case 'meeting':
        return (icon: Icons.event_note, color: const Color(0xFF6CA8E8), label: 'meeting • $short');
      case 'calendar':
        return (icon: Icons.calendar_today, color: const Color(0xFF5CD4A8), label: 'event • $short');
      case 'todo':
        return (icon: Icons.check_box_outlined, color: const Color(0xFFE8C85C), label: 'todo • $short');
      default:
        return (icon: Icons.label_outline, color: Colors.grey.shade600, label: refStr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = _kind();
    return Tooltip(
      message: refStr,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: k.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: k.color.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(k.icon, size: 10, color: k.color),
            const SizedBox(width: 3),
            Text(
              k.label,
              style: TextStyle(fontSize: 10, color: k.color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
