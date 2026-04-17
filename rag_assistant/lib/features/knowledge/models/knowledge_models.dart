class GoalModel {
  final String id;
  final String? parentId;
  final String level;
  final String title;
  final String? description;
  final String status;
  final int priority;
  final String? dueDate;
  final String source;

  const GoalModel({
    required this.id,
    this.parentId,
    required this.level,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.dueDate,
    required this.source,
  });

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'] as String,
      parentId: json['parent_id'] as String?,
      level: json['level'] as String? ?? 'personal',
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'active',
      priority: (json['priority'] as num?)?.toInt() ?? 3,
      dueDate: json['due_date'] as String?,
      source: json['source'] as String? ?? 'manual',
    );
  }
}

class FollowUpModel {
  final String id;
  final String description;
  final String? owner;
  final String status;
  final String? dueDate;
  final String? relatedGoalId;
  final String source;

  const FollowUpModel({
    required this.id,
    required this.description,
    this.owner,
    required this.status,
    this.dueDate,
    this.relatedGoalId,
    required this.source,
  });

  factory FollowUpModel.fromJson(Map<String, dynamic> json) {
    return FollowUpModel(
      id: json['id'] as String,
      description: json['description'] as String,
      owner: json['owner'] as String?,
      status: json['status'] as String? ?? 'open',
      dueDate: json['due_date'] as String?,
      relatedGoalId: json['related_goal_id'] as String?,
      source: json['source'] as String? ?? 'manual',
    );
  }
}

class DecisionModel {
  final String id;
  final String title;
  final String? rationale;
  final String? decidedAt;

  const DecisionModel({
    required this.id,
    required this.title,
    this.rationale,
    this.decidedAt,
  });

  factory DecisionModel.fromJson(Map<String, dynamic> json) {
    return DecisionModel(
      id: json['id'] as String,
      title: json['title'] as String,
      rationale: json['rationale'] as String?,
      decidedAt: json['decided_at'] as String?,
    );
  }
}

class PersonModel {
  final String id;
  final String name;
  final String? email;
  final String? role;
  final String? relationship;

  const PersonModel({
    required this.id,
    required this.name,
    this.email,
    this.role,
    this.relationship,
  });

  factory PersonModel.fromJson(Map<String, dynamic> json) {
    return PersonModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      role: json['role'] as String?,
      relationship: json['relationship'] as String?,
    );
  }
}
