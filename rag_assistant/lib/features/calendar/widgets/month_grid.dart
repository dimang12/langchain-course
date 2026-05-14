import 'package:flutter/material.dart';
import '../../../shared/theme/glass_theme.dart';
import '../models/calendar_event_model.dart';

class MonthGrid extends StatelessWidget {
  final DateTime selectedDate;
  final List<CalendarEventModel> events;
  final ValueChanged<DateTime> onDayTap;

  const MonthGrid({
    super.key,
    required this.selectedDate,
    required this.events,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final lastOfMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0);
    final startDay = firstOfMonth.subtract(Duration(days: firstOfMonth.weekday - 1));
    final totalDays = ((lastOfMonth.difference(startDay).inDays + 1) / 7).ceil() * 7;
    final today = DateTime.now();

    return Column(
      children: [
        // Weekday header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: GlassTheme.line)),
          ),
          child: Row(
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) {
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: GlassTheme.ink3),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Day grid
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final weeks = totalDays ~/ 7;
              final cellHeight = constraints.maxHeight / weeks;

              return Column(
                children: List.generate(weeks, (week) {
                  return SizedBox(
                    height: cellHeight,
                    child: Row(
                      children: List.generate(7, (dayOfWeek) {
                        final day = startDay.add(Duration(days: week * 7 + dayOfWeek));
                        final isCurrentMonth = day.month == selectedDate.month;
                        final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
                        final dayEvents = _eventsForDay(day);

                        return Expanded(
                          child: _MonthDayCell(
                            day: day,
                            isCurrentMonth: isCurrentMonth,
                            isToday: isToday,
                            eventCount: dayEvents.length,
                            events: dayEvents.take(3).toList(),
                            onTap: () => onDayTap(day),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  List<CalendarEventModel> _eventsForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return events
        .where((e) => e.startTime.isBefore(dayEnd) && e.endTime.isAfter(dayStart))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }
}

class _MonthDayCell extends StatefulWidget {
  final DateTime day;
  final bool isCurrentMonth;
  final bool isToday;
  final int eventCount;
  final List<CalendarEventModel> events;
  final VoidCallback onTap;

  const _MonthDayCell({
    required this.day,
    required this.isCurrentMonth,
    required this.isToday,
    required this.eventCount,
    required this.events,
    required this.onTap,
  });

  @override
  State<_MonthDayCell> createState() => _MonthDayCellState();
}

class _MonthDayCellState extends State<_MonthDayCell> {
  bool _hovered = false;

  static const _eventColors = [
    GlassTheme.accent,
    Color(0xFF5CD4A8),
    Color(0xFFE8C85C),
    Color(0xFF6CA8E8),
    Color(0xFFE57398),
    Color(0xFFA78BFA),
  ];

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = true); }),
      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = false); }),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0x08000000) : Colors.transparent,
            border: Border.all(color: GlassTheme.line, width: 0.5),
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day number
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isToday ? GlassTheme.accent : Colors.transparent,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.day.day}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: widget.isToday ? FontWeight.w700 : FontWeight.w400,
                      color: widget.isToday
                          ? Colors.white
                          : widget.isCurrentMonth
                              ? GlassTheme.ink2
                              : GlassTheme.ink3.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // Event chips
              ...widget.events.map((e) {
                final color = _eventColors[e.title.hashCode.abs() % _eventColors.length];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      e.title,
                      style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }),
              if (widget.eventCount > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    '+${widget.eventCount - 3} more',
                    style: TextStyle(fontSize: 9, color: GlassTheme.ink3),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
