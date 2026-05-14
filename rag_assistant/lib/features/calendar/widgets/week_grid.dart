import 'package:flutter/material.dart';
import '../../../shared/theme/glass_theme.dart';
import '../models/calendar_event_model.dart';
import 'event_block.dart';

class WeekGrid extends StatefulWidget {
  final DateTime weekStart;
  final List<CalendarEventModel> events;
  final void Function(DateTime date, TimeOfDay time)? onEmptyTap;
  final void Function(CalendarEventModel event)? onEventTap;
  final void Function(DateTime date, TimeOfDay startTime, TimeOfDay endTime)? onDragCreate;
  final void Function(CalendarEventModel event, DateTime newStart, DateTime newEnd)? onEventMove;
  final void Function(CalendarEventModel event, DateTime newEnd)? onEventResize;

  const WeekGrid({
    super.key,
    required this.weekStart,
    required this.events,
    this.onEmptyTap,
    this.onEventTap,
    this.onDragCreate,
    this.onEventMove,
    this.onEventResize,
  });

  @override
  State<WeekGrid> createState() => _WeekGridState();
}

class _WeekGridState extends State<WeekGrid> {
  final _scrollController = ScrollController();

  static const _startHour = 7;
  static const _endHour = 21;
  static const _hourHeight = 60.0;
  static const _headerHeight = 54.0;
  static const _timeGutterWidth = 52.0;
  static const _snapMinutes = 15;
  static const _minDragMinutes = 15;

  int? _dragDayIndex;
  double? _dragStartY;
  double? _dragCurrentY;

  // Move/resize of an existing event.
  String? _activeDragEventId;
  CalendarEventModel? _activeDragEvent;
  int _activeDragSourceDayIndex = 0;
  bool _isResizing = false;
  double _activeDragDx = 0;
  double _activeDragDy = 0;
  double _columnWidth = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  void _scrollToNow() {
    final now = DateTime.now();
    final offset = ((now.hour - _startHour) * _hourHeight + (now.minute / 60) * _hourHeight - 100)
        .clamp(0.0, double.infinity);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(offset, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Column(
      children: [
        // Day headers
        SizedBox(
          height: _headerHeight,
          child: Row(
            children: [
              SizedBox(width: _timeGutterWidth),
              ...List.generate(7, (i) {
                final day = widget.weekStart.add(Duration(days: i));
                final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
                return Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: const BorderSide(color: GlassTheme.line),
                        left: i > 0 ? const BorderSide(color: GlassTheme.line, width: 0.5) : BorderSide.none,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _weekdayShort(day.weekday),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isToday ? GlassTheme.accent : GlassTheme.ink3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isToday ? GlassTheme.accent : Colors.transparent,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                              color: isToday ? Colors.white : GlassTheme.ink2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        // Time grid
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: LayoutBuilder(
              builder: (context, outerConstraints) {
                final colWidthOuter = ((outerConstraints.maxWidth - _timeGutterWidth) / 7)
                    .clamp(1.0, double.infinity);
                _columnWidth = colWidthOuter;
                return SizedBox(
                  height: (_endHour - _startHour) * _hourHeight,
                  child: Stack(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Time gutter
                          SizedBox(
                            width: _timeGutterWidth,
                            child: Stack(
                              children: List.generate(_endHour - _startHour, (i) {
                                final hour = _startHour + i;
                                return Positioned(
                                  top: i * _hourHeight - 7,
                                  left: 0,
                                  right: 8,
                                  child: Text(
                                    '${hour.toString().padLeft(2, '0')}:00',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 10, color: GlassTheme.ink3),
                                  ),
                                );
                              }),
                            ),
                          ),
                          // Day columns
                          ...List.generate(7, (dayIndex) {
                            final day = widget.weekStart.add(Duration(days: dayIndex));
                            final dayEvents = _eventsForDay(day);
                            return Expanded(
                              child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: dayIndex > 0
                                ? const BorderSide(color: GlassTheme.line, width: 0.5)
                                : BorderSide.none,
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final colWidth = constraints.maxWidth;
                            return Stack(
                              children: [
                                // Tap + drag target for empty space
                                if (widget.onEmptyTap != null || widget.onDragCreate != null)
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onDoubleTapDown: widget.onEmptyTap == null
                                          ? null
                                          : (details) {
                                              final time = _yToTimeOfDay(details.localPosition.dy);
                                              widget.onEmptyTap!(day, time);
                                            },
                                      onPanStart: widget.onDragCreate == null
                                          ? null
                                          : (details) {
                                              setState(() {
                                                _dragDayIndex = dayIndex;
                                                _dragStartY = details.localPosition.dy;
                                                _dragCurrentY = details.localPosition.dy;
                                              });
                                            },
                                      onPanUpdate: widget.onDragCreate == null
                                          ? null
                                          : (details) {
                                              if (_dragDayIndex != dayIndex) return;
                                              setState(() => _dragCurrentY = details.localPosition.dy);
                                            },
                                      onPanEnd: widget.onDragCreate == null
                                          ? null
                                          : (_) => _completeDrag(day, dayIndex),
                                      onPanCancel: widget.onDragCreate == null ? null : _cancelDrag,
                                    ),
                                  ),
                                // Hour lines
                                ...List.generate(_endHour - _startHour, (i) {
                                  return Positioned(
                                    top: i * _hourHeight,
                                    left: 0,
                                    right: 0,
                                    child: Container(height: 0.5, color: GlassTheme.line),
                                  );
                                }),
                                // Now indicator
                                if (_isToday(day)) _buildNowLine(),
                                // Event blocks
                                ..._layoutEvents(dayEvents, colWidth, dayIndex),
                                // Ghost block during drag
                                if (_dragDayIndex == dayIndex) _buildGhostBlock(),
                              ],
                            );
                          },
                        ),
                      ),
                    );
                  }),
                ],
              ),
                      // Active-drag ghost overlay across columns
                      if (_activeDragEvent != null)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _buildActiveDragGhost(colWidthOuter),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  List<CalendarEventModel> _eventsForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return widget.events
        .where((e) => !e.isAllDay && e.startTime.isBefore(dayEnd) && e.endTime.isAfter(dayStart))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<Widget> _layoutEvents(List<CalendarEventModel> events, double columnWidth, int dayIndex) {
    if (events.isEmpty) return [];

    // Compute overlap groups for side-by-side layout
    final columns = <List<CalendarEventModel>>[];
    for (final event in events) {
      bool placed = false;
      for (final col in columns) {
        if (col.last.endTime.isBefore(event.startTime) || col.last.endTime == event.startTime) {
          col.add(event);
          placed = true;
          break;
        }
      }
      if (!placed) columns.add([event]);
    }

    final widgets = <Widget>[];
    final totalCols = columns.length;
    final eventWidth = columnWidth / totalCols;

    for (int colIdx = 0; colIdx < totalCols; colIdx++) {
      for (final event in columns[colIdx]) {
        final top = _timeToOffset(event.startTime);
        final height = (event.durationMinutes / 60 * _hourHeight).clamp(20.0, double.infinity);
        final isDragSource = _activeDragEventId == event.id;

        widgets.add(
          Positioned(
            top: top,
            left: colIdx * eventWidth,
            width: eventWidth,
            height: height,
            child: EventBlock(
              event: event,
              isDragSource: isDragSource,
              onTap: () => widget.onEventTap?.call(event),
              onMoveStart: widget.onEventMove == null
                  ? null
                  : (e) => _onMoveStart(e, dayIndex),
              onMoveUpdate: widget.onEventMove == null ? null : _onMoveUpdate,
              onMoveEnd: widget.onEventMove == null ? null : _onMoveEnd,
              onMoveCancel: widget.onEventMove == null ? null : _onDragCancel,
              onResizeStart: widget.onEventResize == null
                  ? null
                  : (e) => _onResizeStart(e, dayIndex),
              onResizeUpdate: widget.onEventResize == null ? null : _onResizeUpdate,
              onResizeEnd: widget.onEventResize == null ? null : _onResizeEnd,
              onResizeCancel: widget.onEventResize == null ? null : _onDragCancel,
            ),
          ),
        );
      }
    }
    return widgets;
  }

  // ------------------ Move / resize helpers --------------------------------
  void _onMoveStart(CalendarEventModel event, int sourceDayIndex) {
    setState(() {
      _activeDragEventId = event.id;
      _activeDragEvent = event;
      _activeDragSourceDayIndex = sourceDayIndex;
      _isResizing = false;
      _activeDragDx = 0;
      _activeDragDy = 0;
    });
  }

  void _onMoveUpdate(double dx, double dy) {
    if (_activeDragEvent == null || _isResizing) return;
    setState(() {
      _activeDragDx += dx;
      _activeDragDy += dy;
    });
  }

  void _onMoveEnd() {
    final ev = _activeDragEvent;
    final dx = _activeDragDx;
    final dy = _activeDragDy;
    final sourceDayIndex = _activeDragSourceDayIndex;
    final wasResizing = _isResizing;
    setState(() {
      _activeDragEventId = null;
      _activeDragEvent = null;
      _isResizing = false;
      _activeDragDx = 0;
      _activeDragDy = 0;
    });
    if (ev == null || wasResizing) return;
    final dayDelta = _columnWidth > 0 ? (dx / _columnWidth).round() : 0;
    final newDayIndex = (sourceDayIndex + dayDelta).clamp(0, 6);
    final minuteDelta = _snap((dy / _hourHeight * 60).round());
    if (dayDelta == 0 && minuteDelta == 0) return;
    final targetDay = widget.weekStart.add(Duration(days: newDayIndex));
    final duration = ev.endTime.difference(ev.startTime);
    var newStart = DateTime(
      targetDay.year,
      targetDay.month,
      targetDay.day,
      ev.startTime.hour,
      ev.startTime.minute,
    ).add(Duration(minutes: minuteDelta));
    final dayStart = DateTime(targetDay.year, targetDay.month, targetDay.day, _startHour);
    final dayEnd = DateTime(targetDay.year, targetDay.month, targetDay.day, _endHour);
    if (newStart.isBefore(dayStart)) newStart = dayStart;
    var newEnd = newStart.add(duration);
    if (newEnd.isAfter(dayEnd)) {
      newEnd = dayEnd;
      newStart = newEnd.subtract(duration);
    }
    widget.onEventMove?.call(ev, newStart, newEnd);
  }

  void _onResizeStart(CalendarEventModel event, int sourceDayIndex) {
    setState(() {
      _activeDragEventId = event.id;
      _activeDragEvent = event;
      _activeDragSourceDayIndex = sourceDayIndex;
      _isResizing = true;
      _activeDragDx = 0;
      _activeDragDy = 0;
    });
  }

  void _onResizeUpdate(double dy) {
    if (_activeDragEvent == null || !_isResizing) return;
    setState(() => _activeDragDy += dy);
  }

  void _onResizeEnd() {
    final ev = _activeDragEvent;
    final dy = _activeDragDy;
    final wasResizing = _isResizing;
    setState(() {
      _activeDragEventId = null;
      _activeDragEvent = null;
      _isResizing = false;
      _activeDragDx = 0;
      _activeDragDy = 0;
    });
    if (ev == null || !wasResizing) return;
    final deltaMinutes = _snap((dy / _hourHeight * 60).round());
    if (deltaMinutes == 0) return;
    var newEnd = ev.endTime.add(Duration(minutes: deltaMinutes));
    final minEnd = ev.startTime.add(const Duration(minutes: _minDragMinutes));
    final dayEnd = DateTime(ev.startTime.year, ev.startTime.month, ev.startTime.day, _endHour);
    if (newEnd.isBefore(minEnd)) newEnd = minEnd;
    if (newEnd.isAfter(dayEnd)) newEnd = dayEnd;
    widget.onEventResize?.call(ev, newEnd);
  }

  void _onDragCancel() {
    setState(() {
      _activeDragEventId = null;
      _activeDragEvent = null;
      _isResizing = false;
      _activeDragDx = 0;
      _activeDragDy = 0;
    });
  }

  Widget _buildActiveDragGhost(double colWidth) {
    final ev = _activeDragEvent!;
    final sourceDayIndex = _activeDragSourceDayIndex;
    final deltaMinutes = _snap((_activeDragDy / _hourHeight * 60).round());
    final dayDelta = colWidth > 0 && !_isResizing ? (_activeDragDx / colWidth).round() : 0;
    final targetDayIndex = (sourceDayIndex + dayDelta).clamp(0, 6);
    int startMin = ((ev.startTime.hour - _startHour) * 60 + ev.startTime.minute);
    int endMin = ((ev.endTime.hour - _startHour) * 60 + ev.endTime.minute);
    if (_isResizing) {
      endMin += deltaMinutes;
      if (endMin < startMin + _minDragMinutes) endMin = startMin + _minDragMinutes;
      final maxMin = (_endHour - _startHour) * 60;
      if (endMin > maxMin) endMin = maxMin;
    } else {
      final duration = endMin - startMin;
      startMin += deltaMinutes;
      if (startMin < 0) startMin = 0;
      endMin = startMin + duration;
      final maxMin = (_endHour - _startHour) * 60;
      if (endMin > maxMin) {
        endMin = maxMin;
        startMin = endMin - duration;
      }
    }
    final top = (startMin / 60) * _hourHeight;
    final height = ((endMin - startMin) / 60 * _hourHeight).clamp(12.0, double.infinity);
    final left = _timeGutterWidth + targetDayIndex * colWidth + 2;
    final width = (colWidth - 4).clamp(1.0, double.infinity);
    return Stack(
      children: [
        Positioned(
          top: top,
          left: left,
          width: width,
          height: height,
          child: Container(
            decoration: BoxDecoration(
              color: GlassTheme.accent.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: GlassTheme.accent, width: 1.4),
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ev.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: GlassTheme.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_fmtMin(startMin)} – ${_fmtMin(endMin)}',
                  style: const TextStyle(fontSize: 11, color: GlassTheme.ink2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double _timeToOffset(DateTime dt) {
    return ((dt.hour - _startHour) + dt.minute / 60) * _hourHeight;
  }

  int _yToMinutesFromStartHour(double y) {
    final totalMinutes = ((_endHour - _startHour) * 60);
    final raw = (y / _hourHeight * 60).round();
    return raw.clamp(0, totalMinutes);
  }

  int _snap(int minutes) => (minutes / _snapMinutes).round() * _snapMinutes;

  TimeOfDay _yToTimeOfDay(double y) {
    final snapped = _snap(_yToMinutesFromStartHour(y));
    final hour = _startHour + snapped ~/ 60;
    final minute = snapped % 60;
    return TimeOfDay(hour: hour.clamp(_startHour, _endHour - 1), minute: minute);
  }

  ({int startMin, int endMin})? _dragRange() {
    if (_dragStartY == null || _dragCurrentY == null) return null;
    final a = _snap(_yToMinutesFromStartHour(_dragStartY!));
    final b = _snap(_yToMinutesFromStartHour(_dragCurrentY!));
    final lo = a < b ? a : b;
    final hi = a < b ? b : a;
    return (startMin: lo, endMin: hi);
  }

  void _completeDrag(DateTime day, int dayIndex) {
    final range = _dragRange();
    setState(() {
      _dragDayIndex = null;
      _dragStartY = null;
      _dragCurrentY = null;
    });
    if (range == null) return;
    final span = range.endMin - range.startMin;
    if (span < _minDragMinutes) {
      if (widget.onEmptyTap != null) {
        widget.onEmptyTap!(day, _minutesToTimeOfDay(range.startMin));
      }
      return;
    }
    widget.onDragCreate?.call(
      day,
      _minutesToTimeOfDay(range.startMin),
      _minutesToTimeOfDay(range.endMin),
    );
  }

  void _cancelDrag() {
    setState(() {
      _dragDayIndex = null;
      _dragStartY = null;
      _dragCurrentY = null;
    });
  }

  TimeOfDay _minutesToTimeOfDay(int minutesFromStart) {
    final hour = _startHour + minutesFromStart ~/ 60;
    final minute = minutesFromStart % 60;
    return TimeOfDay(hour: hour.clamp(_startHour, _endHour), minute: minute);
  }

  Widget _buildGhostBlock() {
    final range = _dragRange();
    if (range == null) return const SizedBox.shrink();
    final top = (range.startMin / 60) * _hourHeight;
    final height = ((range.endMin - range.startMin) / 60 * _hourHeight).clamp(8.0, double.infinity);
    final showLabel = (range.endMin - range.startMin) >= _minDragMinutes;
    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: GlassTheme.accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: GlassTheme.accent.withValues(alpha: 0.65), width: 1.2),
          ),
          alignment: Alignment.center,
          child: showLabel
              ? Text(
                  '${_fmtMin(range.startMin)} – ${_fmtMin(range.endMin)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: GlassTheme.ink,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  String _fmtMin(int minutesFromStart) {
    final h = _startHour + minutesFromStart ~/ 60;
    final m = minutesFromStart % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  Widget _buildNowLine() {
    final now = DateTime.now();
    final top = _timeToOffset(now);
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE57398))),
          Expanded(child: Container(height: 1.5, color: const Color(0xFFE57398))),
        ],
      ),
    );
  }

  String _weekdayShort(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[weekday - 1];
  }
}
