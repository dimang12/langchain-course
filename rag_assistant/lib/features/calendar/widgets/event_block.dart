import 'package:flutter/material.dart';
import '../../../shared/theme/glass_theme.dart';
import '../models/calendar_event_model.dart';

/// Height of the bottom resize handle in pixels. Hit-tested as a separate
/// gesture detector so dragging the bottom edge resizes instead of moving.
const double kEventResizeHandleHeight = 8;

class EventBlock extends StatefulWidget {
  final CalendarEventModel event;
  final VoidCallback onTap;
  // Move (body pan) — only invoked for editable (local) events.
  final void Function(CalendarEventModel event)? onMoveStart;
  final void Function(double dx, double dy)? onMoveUpdate;
  final VoidCallback? onMoveEnd;
  final VoidCallback? onMoveCancel;
  // Resize (bottom edge pan).
  final void Function(CalendarEventModel event)? onResizeStart;
  final void Function(double dy)? onResizeUpdate;
  final VoidCallback? onResizeEnd;
  final VoidCallback? onResizeCancel;
  // Visual state during a drag.
  final bool isDragSource;

  const EventBlock({
    super.key,
    required this.event,
    required this.onTap,
    this.onMoveStart,
    this.onMoveUpdate,
    this.onMoveEnd,
    this.onMoveCancel,
    this.onResizeStart,
    this.onResizeUpdate,
    this.onResizeEnd,
    this.onResizeCancel,
    this.isDragSource = false,
  });

  @override
  State<EventBlock> createState() => _EventBlockState();
}

class _EventBlockState extends State<EventBlock> {
  bool _hovering = false;

  Color get _color {
    final colors = [
      GlassTheme.accent,
      const Color(0xFF5CD4A8),
      const Color(0xFFE8C85C),
      const Color(0xFF6CA8E8),
      const Color(0xFFE57398),
      const Color(0xFFA78BFA),
    ];
    return colors[widget.event.title.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final canDrag = widget.event.isLocal &&
        (widget.onMoveStart != null || widget.onResizeStart != null);
    final opacity = widget.isDragSource ? 0.3 : 1.0;

    final body = GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      onPanStart: canDrag && widget.onMoveStart != null
          ? (_) => widget.onMoveStart!(widget.event)
          : null,
      onPanUpdate: canDrag && widget.onMoveUpdate != null
          ? (d) => widget.onMoveUpdate!(d.delta.dx, d.delta.dy)
          : null,
      onPanEnd: canDrag && widget.onMoveEnd != null ? (_) => widget.onMoveEnd!() : null,
      onPanCancel: canDrag && widget.onMoveCancel != null ? widget.onMoveCancel : null,
      child: Opacity(
        opacity: opacity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Adapt content density to the actual height available to the block.
            // Thresholds account for outer margin (2 vertical) + padding.
            final h = constraints.maxHeight;
            final isTiny = h < 28; // < ~25min
            final pad = isTiny ? 2.0 : (h < 56 ? 4.0 : 6.0);
            final innerH = h - pad * 2;
            // ~14.4px per title line (font 12 * 1.2 height). Time line ~12px + 2px gap.
            const titleLineH = 14.4;
            const timeBlockH = 14.0; // time line + small gap
            const locBlockH = 12.0;
            final canShowTwoTitleLines = innerH >= (titleLineH * 2 + timeBlockH);
            final canShowTime = !isTiny && innerH >= (titleLineH + timeBlockH - 2);
            final canShowLocation = canShowTwoTitleLines &&
                widget.event.location != null &&
                innerH >= (titleLineH * 2 + timeBlockH + locBlockH);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              padding: EdgeInsets.all(pad),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border(left: BorderSide(color: color, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      widget.event.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: GlassTheme.ink,
                        height: 1.2,
                      ),
                      maxLines: canShowTwoTitleLines ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (canShowTime) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${_fmt(widget.event.startTime)} - ${_fmt(widget.event.endTime)}',
                      style: const TextStyle(fontSize: 10, color: GlassTheme.ink3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (canShowLocation) ...[
                    const SizedBox(height: 1),
                    Text(
                      widget.event.location!,
                      style: const TextStyle(fontSize: 10, color: GlassTheme.ink3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );

    final resizeHandle = canDrag && widget.onResizeStart != null
        ? Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: kEventResizeHandleHeight,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeUpDown,
              onEnter: (_) => setState(() => _hovering = true),
              onExit: (_) => setState(() => _hovering = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => widget.onResizeStart!(widget.event),
                onPanUpdate: widget.onResizeUpdate == null
                    ? null
                    : (d) => widget.onResizeUpdate!(d.delta.dy),
                onPanEnd: widget.onResizeEnd == null ? null : (_) => widget.onResizeEnd!(),
                onPanCancel: widget.onResizeCancel,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: _hovering ? 1.0 : 0.0,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    height: 3,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              ),
            ),
          )
        : null;

    if (resizeHandle == null) return body;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Stack(children: [body, resizeHandle]),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
