class MeetingModel {
  final String id;
  final String title;
  final String status; // 'draft' | 'finalized'
  final DateTime? scheduledAt;
  final DateTime? finalizedAt;
  final List<Map<String, dynamic>> attendees;
  final String? calendarEventId;
  final String? treeNodeId;
  final int decisionsExtracted;
  final int followUpsExtracted;
  final int todosCreated;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MeetingModel({
    required this.id,
    required this.title,
    required this.status,
    this.scheduledAt,
    this.finalizedAt,
    this.attendees = const [],
    this.calendarEventId,
    this.treeNodeId,
    this.decisionsExtracted = 0,
    this.followUpsExtracted = 0,
    this.todosCreated = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isFinalized => status == 'finalized';

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? s) => s == null ? null : DateTime.tryParse(s);
    return MeetingModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '(Untitled)',
      status: json['status'] as String? ?? 'draft',
      scheduledAt: parseDate(json['scheduled_at'] as String?),
      finalizedAt: parseDate(json['finalized_at'] as String?),
      attendees: ((json['attendees'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      calendarEventId: json['calendar_event_id'] as String?,
      treeNodeId: json['tree_node_id'] as String?,
      decisionsExtracted: (json['decisions_extracted'] as num?)?.toInt() ?? 0,
      followUpsExtracted: (json['follow_ups_extracted'] as num?)?.toInt() ?? 0,
      todosCreated: (json['todos_created'] as num?)?.toInt() ?? 0,
      createdAt: parseDate(json['created_at'] as String?) ?? DateTime.now(),
      updatedAt: parseDate(json['updated_at'] as String?) ?? DateTime.now(),
    );
  }
}


class FinalizeResult {
  final int decisionsExtracted;
  final int followUpsExtracted;
  final int goalsExtracted;
  final int peopleExtracted;
  final List<Map<String, dynamic>> decisions;
  final List<Map<String, dynamic>> followUps;

  const FinalizeResult({
    required this.decisionsExtracted,
    required this.followUpsExtracted,
    required this.goalsExtracted,
    required this.peopleExtracted,
    required this.decisions,
    required this.followUps,
  });

  factory FinalizeResult.fromJson(Map<String, dynamic> json) {
    return FinalizeResult(
      decisionsExtracted: (json['decisions_extracted'] as num?)?.toInt() ?? 0,
      followUpsExtracted: (json['follow_ups_extracted'] as num?)?.toInt() ?? 0,
      goalsExtracted: (json['goals_extracted'] as num?)?.toInt() ?? 0,
      peopleExtracted: (json['people_extracted'] as num?)?.toInt() ?? 0,
      decisions: ((json['decisions'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      followUps: ((json['follow_ups'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }
}
