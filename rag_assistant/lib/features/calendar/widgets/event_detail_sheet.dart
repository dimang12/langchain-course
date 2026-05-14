import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/theme/glass_theme.dart';
import '../models/calendar_event_model.dart';

enum EventDetailAction { edit, delete, openMeetingDoc }

class EventDetailSheet extends StatelessWidget {
  final CalendarEventModel event;
  const EventDetailSheet({super.key, required this.event});

  static Future<EventDetailAction?> show(BuildContext context, CalendarEventModel event) {
    return showModalBottomSheet<EventDetailAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventDetailSheet(event: event),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xF2FCFBFF),
        borderRadius: BorderRadius.circular(GlassTheme.cardRadius),
        border: Border.all(color: GlassTheme.glassBorder),
        boxShadow: const [BoxShadow(color: Color(0x30000000), blurRadius: 30, offset: Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: GlassTheme.ink),
                ),
              ),
              if (event.isLocal) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: GlassTheme.ink3),
                  onPressed: () => Navigator.pop(context, EventDetailAction.edit),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  onPressed: () => Navigator.pop(context, EventDetailAction.delete),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: GlassTheme.ink3),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          if (!event.isLocal)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Synced from ${event.provider == "google_calendar" ? "Google Calendar" : event.provider} — read-only',
                style: const TextStyle(fontSize: 11, color: GlassTheme.ink3, fontStyle: FontStyle.italic),
              ),
            ),
          const SizedBox(height: 16),
          _row(Icons.schedule, '${_fmtFull(event.startTime)} - ${_fmtFull(event.endTime)}'),
          if (event.location != null) _row(Icons.location_on_outlined, event.location!),
          if (event.meetingUrl != null)
            _row(
              Icons.videocam_outlined,
              event.meetingUrl!,
              isTappable: true,
              onTap: () => Clipboard.setData(ClipboardData(text: event.meetingUrl!)),
            ),
          if (event.organizer != null) _row(Icons.person_outline, 'Organizer: ${event.organizer}'),
          if (event.attendees.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Attendees', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GlassTheme.ink2)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: event.attendees.map((a) => Chip(
                label: Text(a, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                backgroundColor: GlassTheme.accent.withValues(alpha: 0.08),
                side: BorderSide.none,
              )).toList(),
            ),
          ],
          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              event.description!,
              style: TextStyle(fontSize: 13, height: 1.5, color: GlassTheme.ink2),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, EventDetailAction.openMeetingDoc),
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: const Text('Open meeting doc'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GlassTheme.accent,
                    side: const BorderSide(color: GlassTheme.accent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (event.meetingUrl != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Clipboard.setData(ClipboardData(text: event.meetingUrl!)),
                    icon: const Icon(Icons.videocam, size: 16),
                    label: const Text('Join'),
                    style: FilledButton.styleFrom(
                      backgroundColor: GlassTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text, {bool isTappable = false, VoidCallback? onTap}) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: GlassTheme.ink3),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isTappable ? GlassTheme.accent : GlassTheme.ink2,
                decoration: isTappable ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
    return isTappable ? GestureDetector(onTap: onTap, child: content) : content;
  }

  String _fmtFull(DateTime dt) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[dt.weekday - 1]} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
