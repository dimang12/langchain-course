import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/glass_theme.dart';
import '../../agents/providers/agents_provider.dart';
import '../providers/calendar_provider.dart';

class CalendarSidebar extends ConsumerWidget {
  const CalendarSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agents = ref.watch(agentsProvider);
    final calendar = ref.watch(calendarProvider);
    final brief = agents.latestDailyBrief;
    final today = DateTime.now();
    final freeSlots = calendar.freeSlotsForDay(today);
    final nextUp = calendar.nextUpcoming;

    return Container(
      width: 280,
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: GlassTheme.line)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Priorities
          if (brief != null && brief.topPriorities.isNotEmpty) ...[
            _sectionHeader('PRIORITIES'),
            const SizedBox(height: 8),
            ...brief.topPriorities.asMap().entries.map((e) {
              final isDone = e.key < brief.taskCompletions.length && brief.taskCompletions[e.key];
              return _PriorityRow(
                text: e.value,
                isDone: isDone,
                onToggle: () {
                  ref.read(agentsProvider.notifier).toggleTaskCompletion(brief.id, e.key, !isDone);
                },
              );
            }),
            const SizedBox(height: 20),
          ],

          // Next up
          if (nextUp != null) ...[
            _sectionHeader('NEXT UP'),
            const SizedBox(height: 8),
            _NextUpCard(event: nextUp),
            const SizedBox(height: 20),
          ],

          // Free slots
          if (freeSlots.isNotEmpty) ...[
            _sectionHeader('FREE TIME TODAY'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: freeSlots.map((s) {
                final hours = s.minutes ~/ 60;
                final mins = s.minutes % 60;
                final duration = hours > 0
                    ? (mins > 0 ? '${hours}h${mins}m' : '${hours}h')
                    : '${mins}m';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5CD4A8).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF5CD4A8).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${_fmtTime(s.start)} - ${_fmtTime(s.end)} ($duration)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF2E9E78)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          if (brief == null && freeSlots.isEmpty && nextUp == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    Icon(Icons.auto_awesome_outlined, size: 32, color: GlassTheme.ink3.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text('Generate a brief to see priorities', style: TextStyle(fontSize: 12, color: GlassTheme.ink3)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: GlassTheme.ink3,
      ),
    );
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _PriorityRow extends StatelessWidget {
  final String text;
  final bool isDone;
  final VoidCallback onToggle;
  const _PriorityRow({required this.text, required this.isDone, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        margin: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: isDone ? GlassTheme.accent : GlassTheme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: isDone
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: isDone ? GlassTheme.ink3 : GlassTheme.ink2,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextUpCard extends StatelessWidget {
  final dynamic event;
  const _NextUpCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final diff = event.startTime.difference(DateTime.now());
    final label = diff.isNegative
        ? 'Now'
        : diff.inHours > 0
            ? 'In ${diff.inHours}h ${diff.inMinutes % 60}m'
            : 'In ${diff.inMinutes}m';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GlassTheme.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GlassTheme.accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: GlassTheme.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GlassTheme.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_fmt(event.startTime)} - ${_fmt(event.endTime)}',
                  style: const TextStyle(fontSize: 11, color: GlassTheme.ink3),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: GlassTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: GlassTheme.accent),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
