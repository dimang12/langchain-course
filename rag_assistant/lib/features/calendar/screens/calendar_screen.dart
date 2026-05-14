import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/glass_theme.dart';
import '../../agents/providers/agents_provider.dart';
import '../../meetings/providers/meetings_provider.dart';
import '../../workspace/providers/tab_provider.dart';
import '../../workspace/providers/workspace_provider.dart';
import '../providers/calendar_provider.dart';
import '../models/calendar_event_model.dart';
import '../widgets/day_grid.dart';
import '../widgets/week_grid.dart';
import '../widgets/month_grid.dart';
import '../widgets/week_nav_bar.dart';
import '../widgets/calendar_sidebar.dart';
import '../widgets/add_event_dialog.dart';
import '../widgets/event_detail_sheet.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(calendarProvider.notifier).loadEvents();
      final agents = ref.read(agentsProvider);
      if (agents.runs.isEmpty) {
        ref.read(agentsProvider.notifier).loadRuns();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;

        return Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  WeekNavBar(
                    weekStart: state.currentWeekStart,
                    selectedDate: state.selectedDate,
                    viewMode: state.viewMode,
                    onPrev: () => ref.read(calendarProvider.notifier).goPrev(),
                    onNext: () => ref.read(calendarProvider.notifier).goNext(),
                    onToday: () => ref.read(calendarProvider.notifier).goToToday(),
                    onAddEvent: () => _showAddEvent(state),
                    onViewModeChanged: (mode) => ref.read(calendarProvider.notifier).setViewMode(mode),
                  ),
                  Expanded(
                    child: state.isLoading && state.events.isEmpty
                        ? const Center(child: CircularProgressIndicator(color: GlassTheme.accent))
                        : state.error != null && state.events.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.error_outline, size: 40, color: GlassTheme.ink3.withValues(alpha: 0.4)),
                                    const SizedBox(height: 12),
                                    Text(state.error!, style: const TextStyle(color: GlassTheme.ink3)),
                                    const SizedBox(height: 12),
                                    TextButton(
                                      onPressed: () => ref.read(calendarProvider.notifier).loadEvents(),
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            : _buildView(state),
                  ),
                ],
              ),
            ),
            if (isWide) const CalendarSidebar(),
          ],
        );
      },
    );
  }

  void _showAddEvent(CalendarState state) {
    final date = state.viewMode == CalendarViewMode.day ? state.selectedDate : null;
    final notifier = ref.read(calendarProvider.notifier);
    showDialog<bool>(
      context: context,
      builder: (_) => AddEventDialog(initialDate: date, notifier: notifier),
    );
  }

  void _onEmptyTap(DateTime date, TimeOfDay time) {
    final notifier = ref.read(calendarProvider.notifier);
    showDialog<bool>(
      context: context,
      builder: (_) => AddEventDialog(initialDate: date, initialTime: time, notifier: notifier),
    );
  }

  void _onDragCreate(DateTime date, TimeOfDay start, TimeOfDay end) {
    final notifier = ref.read(calendarProvider.notifier);
    showDialog<bool>(
      context: context,
      builder: (_) => AddEventDialog(
        initialDate: date,
        initialTime: start,
        initialEndTime: end,
        notifier: notifier,
      ),
    );
  }

  Future<void> _onEventMove(CalendarEventModel event, DateTime newStart, DateTime newEnd) async {
    if (!event.isLocal) return;
    final notifier = ref.read(calendarProvider.notifier);
    final ok = await notifier.updateEvent(
      eventId: event.id,
      title: event.title,
      startTime: newStart,
      endTime: newEnd,
      description: event.description,
      isAllDay: event.isAllDay,
      location: event.location,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to move event')),
      );
    }
  }

  Future<void> _onEventResize(CalendarEventModel event, DateTime newEnd) async {
    if (!event.isLocal) return;
    final notifier = ref.read(calendarProvider.notifier);
    final ok = await notifier.updateEvent(
      eventId: event.id,
      title: event.title,
      startTime: event.startTime,
      endTime: newEnd,
      description: event.description,
      isAllDay: event.isAllDay,
      location: event.location,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to resize event')),
      );
    }
  }

  Future<void> _onEventTap(CalendarEventModel event) async {
    final action = await EventDetailSheet.show(context, event);
    if (!mounted || action == null) return;

    final notifier = ref.read(calendarProvider.notifier);
    switch (action) {
      case EventDetailAction.edit:
        await showDialog<bool>(
          context: context,
          builder: (_) => AddEventDialog(notifier: notifier, existing: event),
        );
        break;
      case EventDetailAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Delete event?'),
            content: Text('"${event.title}" will be permanently removed.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          final ok = await notifier.deleteEvent(event.id);
          if (mounted && !ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to delete event')),
            );
          }
        }
        break;
      case EventDetailAction.openMeetingDoc:
        await _openMeetingDocForEvent(event);
        break;
    }
  }

  Future<void> _openMeetingDocForEvent(CalendarEventModel event) async {
    final meetingsNotifier = ref.read(meetingsProvider.notifier);
    final meeting = await meetingsNotifier.getOrCreateForCalendarEvent(
      calendarEventId: event.id,
      title: event.title,
      scheduledAt: event.startTime,
      attendeeNames: event.attendees,
    );
    if (!mounted) return;
    if (meeting == null || meeting.treeNodeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open meeting doc')),
      );
      return;
    }
    await ref.read(workspaceProvider.notifier).loadTree();
    if (!mounted) return;
    final docName = '${meeting.scheduledAt?.toIso8601String().substring(0, 10) ?? ""} - ${meeting.title}'.trim();
    ref.read(tabProvider.notifier).openFileTab(meeting.treeNodeId!, docName, 'md');
    ref.read(navIndexProvider.notifier).state = 0;
  }

  Widget _buildView(CalendarState state) {
    switch (state.viewMode) {
      case CalendarViewMode.day:
        return DayGrid(
          day: state.selectedDate,
          events: state.eventsForDay(state.selectedDate),
          onEmptyTap: _onEmptyTap,
          onEventTap: _onEventTap,
          onDragCreate: _onDragCreate,
          onEventMove: _onEventMove,
          onEventResize: _onEventResize,
        );
      case CalendarViewMode.week:
        return WeekGrid(
          weekStart: state.currentWeekStart,
          events: state.events,
          onEmptyTap: _onEmptyTap,
          onEventTap: _onEventTap,
          onDragCreate: _onDragCreate,
          onEventMove: _onEventMove,
          onEventResize: _onEventResize,
        );
      case CalendarViewMode.month:
        return MonthGrid(
          selectedDate: state.selectedDate,
          events: state.events,
          onDayTap: (day) => ref.read(calendarProvider.notifier).selectDay(day),
        );
    }
  }
}
