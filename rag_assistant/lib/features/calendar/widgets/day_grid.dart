import 'package:flutter/material.dart';
import '../../../shared/theme/glass_theme.dart';
import '../models/calendar_event_model.dart';
import 'event_block.dart';

class DayGrid extends StatefulWidget {
  final DateTime day;
  final List<CalendarEventModel> events;
  final void Function(DateTime date, TimeOfDay time)? onEmptyTap;
  final void Function(CalendarEventModel event)? onEventTap;
  final void Function(DateTime date, TimeOfDay startTime, TimeOfDay endTime)? onDragCreate;
  final void Function(CalendarEventModel event, DateTime newStart, DateTime newEnd)? onEventMove;
  final void Function(CalendarEventModel event, DateTime newEnd)? onEventResize;

  const DayGrid({
    super.key,
    required this.day,
    required this.events,
    this.onEmptyTap,
    this.onEventTap,
    this.onDragCreate,
    this.onEventMove,
    this.onEventResize,
  });

  @override
  State<DayGrid> createState() => _DayGridState();
}

class _DayGridState extends State<DayGrid> {
  final _scrollController = ScrollController();

  static const _startHour = 7;
  static const _endHour = 21;
  static const _hourHeight = 60.0;
  static const _timeGutterWidth = 56.0;
  static const _snapMinutes = 15;
  static const _minDragMinutes = 15;

  double? _dragStartY;
  double? _dragCurrentY;

  // Move/resize state for an existing event being dragged.
  String? _activeDragEventId;
  CalendarEventModel? _activeDragEvent;
  bool _isResizing = false;
  double _activeDragDy = 0; // accumulated pixel delta along Y

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

  bool get _isToday {
    final now = DateTime.now();
    return widget.day.year == now.year && widget.day.month == now.month && widget.day.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final dayEvents = widget.events
        .where((e) => !e.isAllDay)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return SingleChildScrollView(
      controller: _scrollController,
      child: SizedBox(
        height: (_endHour - _startHour) * _hourHeight,
        child: Row(
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
                      style: const TextStyle(fontSize: 11, color: GlassTheme.ink3),
                    ),
                  );
                }),
              ),
            ),
            // Day column
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      if (widget.onEmptyTap != null || widget.onDragCreate != null)
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onDoubleTapDown: widget.onEmptyTap == null
                                ? null
                                : (details) {
                                    widget.onEmptyTap!(widget.day, _yToTimeOfDay(details.localPosition.dy));
                                  },
                            onPanStart: widget.onDragCreate == null
                                ? null
                                : (details) {
                                    setState(() {
                                      _dragStartY = details.localPosition.dy;
                                      _dragCurrentY = details.localPosition.dy;
                                    });
                                  },
                            onPanUpdate: widget.onDragCreate == null
                                ? null
                                : (details) {
                                    setState(() => _dragCurrentY = details.localPosition.dy);
                                  },
                            onPanEnd: widget.onDragCreate == null ? null : (_) => _completeDrag(),
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
                      if (_isToday) _buildNowLine(),
                      // Events
                      ..._layoutEvents(dayEvents, constraints.maxWidth),
                      // Ghost block during drag
                      if (_dragStartY != null) _buildGhostBlock(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _layoutEvents(List<CalendarEventModel> events, double columnWidth) {
    if (events.isEmpty) return [];

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
        final top = ((event.startTime.hour - _startHour) + event.startTime.minute / 60) * _hourHeight;
        final height = (event.durationMinutes / 60 * _hourHeight).clamp(24.0, double.infinity);

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
              onMoveStart: widget.onEventMove == null ? null : _onMoveStart,
              onMoveUpdate: widget.onEventMove == null ? null : _onMoveUpdate,
              onMoveEnd: widget.onEventMove == null ? null : _onMoveEnd,
              onMoveCancel: widget.onEventMove == null ? null : _onDragCancel,
              onResizeStart: widget.onEventResize == null ? null : _onResizeStart,
              onResizeUpdate: widget.onEventResize == null ? null : _onResizeUpdate,
              onResizeEnd: widget.onEventResize == null ? null : _onResizeEnd,
              onResizeCancel: widget.onEventResize == null ? null : _onDragCancel,
            ),
          ),
        );
      }
    }
    if (_activeDragEvent != null) {
      widgets.add(_buildActiveDragGhost(columnWidth));
    }
    return widgets;
  }

  // ------------------ Move / resize helpers --------------------------------
  void _onMoveStart(CalendarEventModel event) {
    setState(() {
      _activeDragEventId = event.id;
      _activeDragEvent = event;
      _isResizing = false;
      _activeDragDy = 0;
    });
  }

  void _onMoveUpdate(double dx, double dy) {
    if (_activeDragEvent == null || _isResizing) return;
    setState(() => _activeDragDy += dy);
  }

  void _onMoveEnd() {
    final ev = _activeDragEvent;
    final dy = _activeDragDy;
    final wasResizing = _isResizing;
    setState(() {
      _activeDragEventId = null;
      _activeDragEvent = null;
      _isResizing = false;
      _activeDragDy = 0;
    });
    if (ev == null || wasResizing) return;
    final deltaMinutes = _snap((dy / _hourHeight * 60).round());
    if (deltaMinutes == 0) return;
    final duration = ev.endTime.difference(ev.startTime);
    var newStart = ev.startTime.add(Duration(minutes: deltaMinutes));
    final dayStart = DateTime(widget.day.year, widget.day.month, widget.day.day, _startHour);
    final dayEnd = DateTime(widget.day.year, widget.day.month, widget.day.day, _endHour);
    if (newStart.isBefore(dayStart)) newStart = dayStart;
    var newEnd = newStart.add(duration);
    if (newEnd.isAfter(dayEnd)) {
      newEnd = dayEnd;
      newStart = newEnd.subtract(duration);
    }
    widget.onEventMove?.call(ev, newStart, newEnd);
  }

  void _onResizeStart(CalendarEventModel event) {
    setState(() {
      _activeDragEventId = event.id;
      _activeDragEvent = event;
      _isResizing = true;
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
      _activeDragDy = 0;
    });
    if (ev == null || !wasResizing) return;
    final deltaMinutes = _snap((dy / _hourHeight * 60).round());
    if (deltaMinutes == 0) return;
    var newEnd = ev.endTime.add(Duration(minutes: deltaMinutes));
    final minEnd = ev.startTime.add(const Duration(minutes: _minDragMinutes));
    final dayEnd = DateTime(widget.day.year, widget.day.month, widget.day.day, _endHour);
    if (newEnd.isBefore(minEnd)) newEnd = minEnd;
    if (newEnd.isAfter(dayEnd)) newEnd = dayEnd;
    widget.onEventResize?.call(ev, newEnd);
  }

  void _onDragCancel() {
    setState(() {
      _activeDragEventId = null;
      _activeDragEvent = null;
      _isResizing = false;
      _activeDragDy = 0;
    });
  }

  Widget _buildActiveDragGhost(double columnWidth) {
    final ev = _activeDragEvent!;
    final deltaMinutes = _snap((_activeDragDy / _hourHeight * 60).round());
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
    return Positioned(
      top: top,
      left: 2,
      width: columnWidth - 4,
      height: height,
      child: IgnorePointer(
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
    );
  }

  int _yToMinutesFromStartHour(double y) {
    final totalMinutes = (_endHour - _startHour) * 60;
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

  TimeOfDay _minutesToTimeOfDay(int minutesFromStart) {
    final hour = _startHour + minutesFromStart ~/ 60;
    final minute = minutesFromStart % 60;
    return TimeOfDay(hour: hour.clamp(_startHour, _endHour), minute: minute);
  }

  void _completeDrag() {
    final range = _dragRange();
    setState(() {
      _dragStartY = null;
      _dragCurrentY = null;
    });
    if (range == null) return;
    final span = range.endMin - range.startMin;
    if (span < _minDragMinutes) {
      if (widget.onEmptyTap != null) {
        widget.onEmptyTap!(widget.day, _minutesToTimeOfDay(range.startMin));
      }
      return;
    }
    widget.onDragCreate?.call(
      widget.day,
      _minutesToTimeOfDay(range.startMin),
      _minutesToTimeOfDay(range.endMin),
    );
  }

  void _cancelDrag() {
    setState(() {
      _dragStartY = null;
      _dragCurrentY = null;
    });
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
                    fontSize: 12,
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

  Widget _buildNowLine() {
    final now = DateTime.now();
    final top = ((now.hour - _startHour) + now.minute / 60) * _hourHeight;
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
}
