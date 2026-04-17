class MessageModel {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final List<String> sources;
  final List<ToolAction> toolActions;

  const MessageModel({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.sources = const [],
    this.toolActions = const [],
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      content: json['content'] as String,
      isUser: json['is_user'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      sources: (json['sources'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      toolActions: (json['tool_actions'] as List<dynamic>?)
              ?.map((e) => ToolAction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'is_user': isUser,
      'timestamp': timestamp.toIso8601String(),
      'sources': sources,
    };
  }
}

class ToolAction {
  final String tool;
  final Map<String, dynamic> args;
  final String result;

  const ToolAction({
    required this.tool,
    required this.args,
    required this.result,
  });

  factory ToolAction.fromJson(Map<String, dynamic> json) {
    return ToolAction(
      tool: json['tool'] as String,
      args: json['args'] as Map<String, dynamic>? ?? {},
      result: json['result'] as String? ?? '',
    );
  }

  String get displayName {
    switch (tool) {
      case 'read_file':
        return 'Read file: ${args['filename'] ?? ''}';
      case 'create_file':
        return 'Created: ${args['name'] ?? ''}';
      case 'search_files':
        return 'Searched: ${args['query'] ?? ''}';
      case 'list_folder':
        return 'Listed: ${args['folder_name'] ?? 'root'}';
      default:
        return tool;
    }
  }
}
