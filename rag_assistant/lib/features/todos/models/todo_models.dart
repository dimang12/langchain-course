class TodoFolderModel {
  final String id;
  final String? parentId;
  final String name;
  final int sortOrder;

  const TodoFolderModel({
    required this.id,
    required this.parentId,
    required this.name,
    required this.sortOrder,
  });

  factory TodoFolderModel.fromJson(Map<String, dynamic> json) {
    return TodoFolderModel(
      id: json['id'] as String,
      parentId: json['parent_id'] as String?,
      name: json['name'] as String? ?? '(unnamed)',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class TodoStatusModel {
  final String id;
  final String folderId;
  final String name;
  final String color;
  final int sortOrder;

  const TodoStatusModel({
    required this.id,
    required this.folderId,
    required this.name,
    required this.color,
    required this.sortOrder,
  });

  factory TodoStatusModel.fromJson(Map<String, dynamic> json) {
    return TodoStatusModel(
      id: json['id'] as String,
      folderId: json['folder_id'] as String,
      name: json['name'] as String? ?? '',
      color: json['color'] as String? ?? '#7C5CFF',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class TodoModel {
  final String id;
  final String? folderId;
  final String? statusId;
  final String title;
  final String? description;
  final String priority;
  final DateTime? dueDate;
  final List<String> tags;
  final int sortOrder;
  final DateTime? completedAt;
  final DateTime updatedAt;
  final String? goalId;
  final int? estimatedMinutes;
  final bool isTodayPriority;

  const TodoModel({
    required this.id,
    required this.folderId,
    required this.statusId,
    required this.title,
    required this.description,
    required this.priority,
    required this.dueDate,
    required this.tags,
    required this.sortOrder,
    required this.completedAt,
    required this.updatedAt,
    this.goalId,
    this.estimatedMinutes,
    this.isTodayPriority = false,
  });

  bool get isCompleted => completedAt != null;

  factory TodoModel.fromJson(Map<String, dynamic> json) {
    return TodoModel(
      id: json['id'] as String,
      folderId: json['folder_id'] as String?,
      statusId: json['status_id'] as String?,
      title: json['title'] as String? ?? '(untitled)',
      description: json['description'] as String?,
      priority: json['priority'] as String? ?? 'medium',
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'].toString()) : null,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null,
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ?? DateTime.now(),
      goalId: json['goal_id'] as String?,
      estimatedMinutes: (json['estimated_minutes'] as num?)?.toInt(),
      isTodayPriority: json['is_today_priority'] as bool? ?? false,
    );
  }
}


class GoalOptionModel {
  final String id;
  final String title;
  final String level;
  final int priority;

  const GoalOptionModel({
    required this.id,
    required this.title,
    required this.level,
    required this.priority,
  });

  factory GoalOptionModel.fromJson(Map<String, dynamic> json) {
    return GoalOptionModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '(untitled goal)',
      level: json['level'] as String? ?? 'personal',
      priority: (json['priority'] as num?)?.toInt() ?? 3,
    );
  }
}
