class MessageModel {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final List<String> sources;

  const MessageModel({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.sources = const [],
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
