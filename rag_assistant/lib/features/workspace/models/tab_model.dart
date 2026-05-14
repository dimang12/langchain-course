class TabModel {
  final String id;
  final String? nodeId;
  final String type; // "file" or "chat"
  final String title;
  final String? fileType;
  final bool isModified;
  final int reloadCounter;

  const TabModel({
    required this.id,
    this.nodeId,
    required this.type,
    required this.title,
    this.fileType,
    this.isModified = false,
    this.reloadCounter = 0,
  });

  TabModel copyWith({bool? isModified, int? reloadCounter}) {
    return TabModel(
      id: id,
      nodeId: nodeId,
      type: type,
      title: title,
      fileType: fileType,
      isModified: isModified ?? this.isModified,
      reloadCounter: reloadCounter ?? this.reloadCounter,
    );
  }
}
