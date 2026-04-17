class AgentRunModel {
  final String id;
  final String agentName;
  final String trigger;
  final String status;
  final String? outputNodeId;
  final Map<String, dynamic>? outputPayload;
  final String? errorMessage;
  final int? durationMs;
  final int? userRating;
  final DateTime startedAt;
  final DateTime? completedAt;

  const AgentRunModel({
    required this.id,
    required this.agentName,
    required this.trigger,
    required this.status,
    this.outputNodeId,
    this.outputPayload,
    this.errorMessage,
    this.durationMs,
    this.userRating,
    required this.startedAt,
    this.completedAt,
  });

  factory AgentRunModel.fromJson(Map<String, dynamic> json) {
    return AgentRunModel(
      id: json['id'] as String,
      agentName: json['agent_name'] as String? ?? 'unknown',
      trigger: json['trigger'] as String? ?? 'manual',
      status: json['status'] as String? ?? 'unknown',
      outputNodeId: json['output_node_id'] as String?,
      outputPayload: json['output_payload'] as Map<String, dynamic>?,
      errorMessage: json['error_message'] as String?,
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      userRating: (json['user_rating'] as num?)?.toInt(),
      startedAt: DateTime.tryParse(json['started_at'] as String? ?? '') ??
          DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
    );
  }

  List<String> get topPriorities {
    final raw = outputPayload?['top_priorities'];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return [];
  }

  String? get contextSnapshot => outputPayload?['context_snapshot'] as String?;
  String? get suggestedPlan => outputPayload?['suggested_plan'] as String?;
  String? get oneInsight => outputPayload?['one_insight'] as String?;
  List<String> get followUps {
    final raw = outputPayload?['follow_ups'];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return [];
  }
}
