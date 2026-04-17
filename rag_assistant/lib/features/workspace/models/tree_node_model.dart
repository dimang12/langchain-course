class TreeNodeModel {
  final String id;
  final String? parentId;
  final String name;
  final String nodeType;
  final String? fileType;
  final String? ingestionStatus;
  final int sortOrder;
  final List<TreeNodeModel> children;
  bool isExpanded;

  TreeNodeModel({
    required this.id,
    this.parentId,
    required this.name,
    required this.nodeType,
    this.fileType,
    this.ingestionStatus,
    this.sortOrder = 0,
    this.children = const [],
    this.isExpanded = false,
  });

  bool get isFolder => nodeType == 'folder';
  bool get isFile => nodeType == 'file';

  factory TreeNodeModel.fromJson(Map<String, dynamic> json) {
    return TreeNodeModel(
      id: json['id'] as String,
      parentId: json['parent_id'] as String?,
      name: json['name'] as String,
      nodeType: json['node_type'] as String,
      fileType: json['file_type'] as String?,
      ingestionStatus: json['ingestion_status'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => TreeNodeModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
