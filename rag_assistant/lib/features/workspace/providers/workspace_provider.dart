import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../models/tree_node_model.dart';

class WorkspaceState {
  final List<TreeNodeModel> tree;
  final bool isLoading;
  final String? error;
  final String sortMode;
  final String? selectedFolderId;

  const WorkspaceState({
    this.tree = const [],
    this.isLoading = false,
    this.error,
    this.sortMode = 'name',
    this.selectedFolderId,
  });

  WorkspaceState copyWith({
    List<TreeNodeModel>? tree,
    bool? isLoading,
    String? error,
    String? sortMode,
    String? selectedFolderId,
    bool clearError = false,
    bool clearSelectedFolder = false,
  }) {
    return WorkspaceState(
      tree: tree ?? this.tree,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      sortMode: sortMode ?? this.sortMode,
      selectedFolderId: clearSelectedFolder ? null : (selectedFolderId ?? this.selectedFolderId),
    );
  }
}

class WorkspaceNotifier extends StateNotifier<WorkspaceState> {
  final ApiClient _apiClient;

  WorkspaceNotifier(this._apiClient) : super(const WorkspaceState());

  Future<void> loadTree() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiClient.dio.get('/workspace/tree');
      final nodes = (response.data as List)
          .map((e) => TreeNodeModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(tree: _sortNodes(nodes, state.sortMode), isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load workspace');
    }
  }

  Future<void> createNode(String name, String nodeType,
      {String? parentId, String? fileType, String? content}) async {
    try {
      await _apiClient.dio.post('/workspace/node', data: {
        'name': name,
        'node_type': nodeType,
        'parent_id': parentId ?? state.selectedFolderId,
        'file_type': fileType,
        'content': content,
      });
      await loadTree();
    } catch (e) {
      state = state.copyWith(error: 'Failed to create $nodeType');
    }
  }

  Future<void> renameNode(String nodeId, String newName) async {
    try {
      await _apiClient.dio.put('/workspace/node/$nodeId', data: {'name': newName});
      await loadTree();
    } catch (e) {
      state = state.copyWith(error: 'Failed to rename');
    }
  }

  Future<void> moveNode(String nodeId, String newParentId) async {
    try {
      await _apiClient.dio.put('/workspace/node/$nodeId', data: {'parent_id': newParentId});
      await loadTree();
    } catch (e) {
      state = state.copyWith(error: 'Failed to move node');
    }
  }

  Future<void> deleteNode(String nodeId) async {
    try {
      await _apiClient.dio.delete('/workspace/node/$nodeId');
      await loadTree();
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete node');
    }
  }

  Future<void> uploadFileData(String fileName, List<int> bytes, {String? parentId}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final multipartFile = MultipartFile.fromBytes(bytes, filename: fileName);
      final formData = FormData.fromMap({'file': multipartFile});
      final targetParent = parentId ?? state.selectedFolderId;
      String url = '/workspace/upload';
      if (targetParent != null) {
        url += '?parent_id=$targetParent';
      }
      await _apiClient.dio.post(url, data: formData);
      await loadTree();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to upload file');
    }
  }

  void selectFolder(String? folderId) {
    if (folderId == state.selectedFolderId) {
      state = state.copyWith(clearSelectedFolder: true);
    } else {
      state = state.copyWith(selectedFolderId: folderId);
    }
  }

  void setSortMode(String mode) {
    state = state.copyWith(sortMode: mode, tree: _sortNodes(state.tree, mode));
  }

  void toggleExpand(String nodeId) {
    state = state.copyWith(tree: _toggleInTree(state.tree, nodeId));
  }

  List<TreeNodeModel> _sortNodes(List<TreeNodeModel> nodes, String mode) {
    final sorted = List<TreeNodeModel>.from(nodes);
    switch (mode) {
      case 'name':
        sorted.sort((a, b) {
          if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case 'type':
        sorted.sort((a, b) {
          if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
          return (a.fileType ?? '').compareTo(b.fileType ?? '');
        });
        break;
      case 'date':
        sorted.sort((a, b) => b.sortOrder.compareTo(a.sortOrder));
        break;
    }
    return sorted.map((n) => TreeNodeModel(
      id: n.id, parentId: n.parentId, name: n.name, nodeType: n.nodeType,
      fileType: n.fileType, ingestionStatus: n.ingestionStatus, sortOrder: n.sortOrder,
      children: _sortNodes(n.children, mode), isExpanded: n.isExpanded,
    )).toList();
  }

  List<TreeNodeModel> _toggleInTree(List<TreeNodeModel> nodes, String id) {
    return nodes.map((node) {
      if (node.id == id) {
        node.isExpanded = !node.isExpanded;
        return node;
      }
      if (node.children.isNotEmpty) {
        return TreeNodeModel(
          id: node.id, parentId: node.parentId, name: node.name, nodeType: node.nodeType,
          fileType: node.fileType, ingestionStatus: node.ingestionStatus, sortOrder: node.sortOrder,
          children: _toggleInTree(node.children, id), isExpanded: node.isExpanded,
        );
      }
      return node;
    }).toList();
  }
}

final workspaceProvider = StateNotifierProvider<WorkspaceNotifier, WorkspaceState>((ref) {
  return WorkspaceNotifier(ref.read(apiClientProvider));
});
