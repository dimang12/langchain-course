class TabModel {
  final String id;
  final String? nodeId;
  final String type; // "file" or "chat"
  final String title;
  final String? fileType;
  final bool isModified;

  const TabModel({
    required this.id,
    this.nodeId,
    required this.type,
    required this.title,
    this.fileType,
    this.isModified = false,
  });

  TabModel copyWith({bool? isModified}) {
    return TabModel(
      id: id,
      nodeId: nodeId,
      type: type,
      title: title,
      fileType: fileType,
      isModified: isModified ?? this.isModified,
    );
  }
}
