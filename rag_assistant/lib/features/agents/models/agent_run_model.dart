class AgentRunModel {
  final String id;
  final String agentName;
  final String trigger;
  final String status;
  final String? outputNodeId;
  final Map<String, dynamic>? outputPayload;
  final List<Map<String, dynamic>> recommendations;
  final String? errorMessage;
  final int? durationMs;
  final int? userRating;
  final List<bool> taskCompletions;
  final DateTime startedAt;
  final DateTime? completedAt;

  const AgentRunModel({
    required this.id,
    required this.agentName,
    required this.trigger,
    required this.status,
    this.outputNodeId,
    this.outputPayload,
    this.recommendations = const [],
    this.errorMessage,
    this.durationMs,
    this.userRating,
    this.taskCompletions = const [],
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
      recommendations: ((json['recommendations'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      errorMessage: json['error_message'] as String?,
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      userRating: (json['user_rating'] as num?)?.toInt(),
      taskCompletions: (json['task_completions'] as List<dynamic>?)
              ?.map((e) => e == true)
              .toList() ??
          const [],
      startedAt: DateTime.tryParse((json['started_at'] ?? '').toString()) ??
          DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
    );
  }

  AgentRunModel copyWith({List<bool>? taskCompletions, int? userRating}) {
    return AgentRunModel(
      id: id,
      agentName: agentName,
      trigger: trigger,
      status: status,
      outputNodeId: outputNodeId,
      outputPayload: outputPayload,
      recommendations: recommendations,
      errorMessage: errorMessage,
      durationMs: durationMs,
      userRating: userRating ?? this.userRating,
      taskCompletions: taskCompletions ?? this.taskCompletions,
      startedAt: startedAt,
      completedAt: completedAt,
    );
  }

  List<String> get topPriorities {
    // Prioritizer format: structured priorities with rationale + evidence
    final structured = outputPayload?['priorities'];
    if (structured is List && structured.isNotEmpty) {
      return structured
          .map((e) => (e is Map ? e['title']?.toString() ?? '' : e.toString()))
          .where((s) => s.isNotEmpty)
          .toList();
    }
    // Legacy daily_brief format: flat list
    final raw = outputPayload?['top_priorities'];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return [];
  }

  /// Rich structured priorities (Prioritizer agent only).
  List<PriorityRecommendation> get priorityRecommendations {
    final raw = outputPayload?['priorities'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => PriorityRecommendation.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  List<String> get deferred {
    final raw = outputPayload?['deferred'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
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


class PriorityRecommendation {
  final String? todoId;
  final String title;
  final int rank;
  final String? rationale;
  final List<String> evidence;
  final int? estimatedMinutes;
  final String? suggestedBlock;

  const PriorityRecommendation({
    this.todoId,
    required this.title,
    required this.rank,
    this.rationale,
    this.evidence = const [],
    this.estimatedMinutes,
    this.suggestedBlock,
  });

  factory PriorityRecommendation.fromJson(Map<String, dynamic> json) {
    return PriorityRecommendation(
      todoId: json['todo_id'] as String?,
      title: json['title'] as String? ?? '(no title)',
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      rationale: json['rationale'] as String?,
      evidence: ((json['evidence'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      estimatedMinutes: (json['estimated_minutes'] as num?)?.toInt(),
      suggestedBlock: json['suggested_block'] as String?,
    );
  }
}
