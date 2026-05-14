class CalendarEventModel {
  final String id;
  final String provider;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final String? location;
  final String? meetingUrl;
  final List<String> attendees;
  final String? organizer;
  final String status;

  const CalendarEventModel({
    required this.id,
    this.provider = 'google_calendar',
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
    this.location,
    this.meetingUrl,
    this.attendees = const [],
    this.organizer,
    this.status = 'confirmed',
  });

  int get durationMinutes => endTime.difference(startTime).inMinutes;

  bool get isLocal => provider == 'local';

  factory CalendarEventModel.fromJson(Map<String, dynamic> json) {
    return CalendarEventModel(
      id: json['id'] as String,
      provider: json['provider'] as String? ?? 'google_calendar',
      title: json['title'] as String? ?? '(No title)',
      description: json['description'] as String?,
      startTime: DateTime.tryParse(json['start_time'] as String? ?? '') ?? DateTime.now(),
      endTime: DateTime.tryParse(json['end_time'] as String? ?? '') ?? DateTime.now(),
      isAllDay: json['is_all_day'] as bool? ?? false,
      location: json['location'] as String?,
      meetingUrl: json['meeting_url'] as String?,
      attendees: (json['attendees'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      organizer: json['organizer'] as String?,
      status: json['status'] as String? ?? 'confirmed',
    );
  }
}
