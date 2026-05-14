import 'package:flutter/material.dart';
import '../../../shared/theme/glass_theme.dart';
import '../providers/calendar_provider.dart';

class WeekNavBar extends StatelessWidget {
  final DateTime weekStart;
  final DateTime selectedDate;
  final CalendarViewMode viewMode;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onAddEvent;
  final ValueChanged<CalendarViewMode> onViewModeChanged;

  const WeekNavBar({
    super.key,
    required this.weekStart,
    required this.selectedDate,
    required this.viewMode,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onAddEvent,
    required this.onViewModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GlassTheme.line)),
      ),
      child: Row(
        children: [
          _NavButton(icon: Icons.chevron_left, onTap: onPrev),
          const SizedBox(width: 4),
          _NavButton(icon: Icons.chevron_right, onTap: onNext),
          const SizedBox(width: 12),
          Text(
            _label(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: GlassTheme.ink),
          ),
          const SizedBox(width: 12),
          if (!_isCurrentPeriod())
            GestureDetector(
              onTap: onToday,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: GlassTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: GlassTheme.accent.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'Today',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GlassTheme.accent),
                ),
              ),
            ),
          const Spacer(),
          // Add event button
          Material(
            color: GlassTheme.accent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onAddEvent,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add, size: 16, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Event', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // View mode toggle
          _ViewModeToggle(
            current: viewMode,
            onChanged: onViewModeChanged,
          ),
        ],
      ),
    );
  }

  String _label() {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const monthsFull = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    switch (viewMode) {
      case CalendarViewMode.day:
        return '${weekdays[selectedDate.weekday - 1]}, ${months[selectedDate.month - 1]} ${selectedDate.day}, ${selectedDate.year}';
      case CalendarViewMode.week:
        final weekEnd = weekStart.add(const Duration(days: 6));
        if (weekStart.month == weekEnd.month) {
          return '${months[weekStart.month - 1]} ${weekStart.day} - ${weekEnd.day}, ${weekStart.year}';
        }
        return '${months[weekStart.month - 1]} ${weekStart.day} - ${months[weekEnd.month - 1]} ${weekEnd.day}, ${weekEnd.year}';
      case CalendarViewMode.month:
        return '${monthsFull[selectedDate.month - 1]} ${selectedDate.year}';
    }
  }

  bool _isCurrentPeriod() {
    final now = DateTime.now();
    switch (viewMode) {
      case CalendarViewMode.day:
        return selectedDate.year == now.year && selectedDate.month == now.month && selectedDate.day == now.day;
      case CalendarViewMode.week:
        final weekEnd = weekStart.add(const Duration(days: 7));
        return weekStart.isBefore(now) && weekEnd.isAfter(now);
      case CalendarViewMode.month:
        return selectedDate.year == now.year && selectedDate.month == now.month;
    }
  }
}

class _ViewModeToggle extends StatelessWidget {
  final CalendarViewMode current;
  final ValueChanged<CalendarViewMode> onChanged;
  const _ViewModeToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x10000000),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: CalendarViewMode.values.map((mode) {
          final isActive = mode == current;
          return GestureDetector(
            onTap: () => onChanged(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isActive
                    ? const [BoxShadow(color: Color(0x18000000), blurRadius: 4, offset: Offset(0, 1))]
                    : null,
              ),
              child: Text(
                mode.name[0].toUpperCase() + mode.name.substring(1),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? GlassTheme.ink : GlassTheme.ink3,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.onTap});

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = true); }),
      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = false); }),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _hovered ? const Color(0x18000000) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(widget.icon, size: 18, color: GlassTheme.ink2),
        ),
      ),
    );
  }
}
