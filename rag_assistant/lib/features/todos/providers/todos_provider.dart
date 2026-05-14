import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../models/todo_models.dart';

class TodosState {
  final List<TodoFolderModel> folders;
  final Map<String, List<TodoStatusModel>> statusesByFolder;
  final List<TodoModel> todos;
  final List<GoalOptionModel> goalOptions;
  final String? selectedFolderId;
  final bool isLoading;
  final String? error;

  const TodosState({
    this.folders = const [],
    this.statusesByFolder = const {},
    this.todos = const [],
    this.goalOptions = const [],
    this.selectedFolderId,
    this.isLoading = false,
    this.error,
  });

  TodosState copyWith({
    List<TodoFolderModel>? folders,
    Map<String, List<TodoStatusModel>>? statusesByFolder,
    List<TodoModel>? todos,
    List<GoalOptionModel>? goalOptions,
    String? selectedFolderId,
    bool clearSelection = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return TodosState(
      folders: folders ?? this.folders,
      statusesByFolder: statusesByFolder ?? this.statusesByFolder,
      todos: todos ?? this.todos,
      goalOptions: goalOptions ?? this.goalOptions,
      selectedFolderId: clearSelection ? null : (selectedFolderId ?? this.selectedFolderId),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  List<TodoStatusModel> get currentStatuses =>
      selectedFolderId != null ? (statusesByFolder[selectedFolderId!] ?? const []) : const [];

  GoalOptionModel? goalForTodo(TodoModel t) {
    if (t.goalId == null) return null;
    for (final g in goalOptions) {
      if (g.id == t.goalId) return g;
    }
    return null;
  }
}

class TodosNotifier extends StateNotifier<TodosState> {
  final ApiClient _api;

  TodosNotifier(this._api) : super(const TodosState());

  Future<void> loadFolders() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _api.dio.get('/todos/folders');
      final folders = (res.data as List)
          .map((e) => TodoFolderModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(folders: folders, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load folders: $e');
    }
  }

  Future<TodoFolderModel?> createFolder({required String name, String? parentId}) async {
    try {
      final res = await _api.dio.post('/todos/folders', data: {
        'name': name,
        if (parentId != null) 'parent_id': parentId,
      });
      final folder = TodoFolderModel.fromJson(res.data as Map<String, dynamic>);
      state = state.copyWith(folders: [...state.folders, folder]);
      await loadStatuses(folder.id);
      return folder;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create folder: $e');
      return null;
    }
  }

  Future<bool> renameFolder(String folderId, String name) async {
    try {
      await _api.dio.patch('/todos/folders/$folderId', data: {'name': name});
      state = state.copyWith(
        folders: state.folders
            .map((f) => f.id == folderId
                ? TodoFolderModel(id: f.id, parentId: f.parentId, name: name, sortOrder: f.sortOrder)
                : f)
            .toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to rename: $e');
      return false;
    }
  }

  Future<bool> deleteFolder(String folderId) async {
    try {
      await _api.dio.delete('/todos/folders/$folderId');
      final remaining = state.folders.where((f) => f.id != folderId && f.parentId != folderId).toList();
      state = state.copyWith(
        folders: remaining,
        clearSelection: state.selectedFolderId == folderId,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete folder: $e');
      return false;
    }
  }

  Future<void> loadStatuses(String folderId) async {
    try {
      final res = await _api.dio.get('/todos/folders/$folderId/statuses');
      final statuses = (res.data as List)
          .map((e) => TodoStatusModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final newMap = Map<String, List<TodoStatusModel>>.from(state.statusesByFolder);
      newMap[folderId] = statuses;
      state = state.copyWith(statusesByFolder: newMap);
    } catch (e) {
      state = state.copyWith(error: 'Failed to load statuses: $e');
    }
  }

  Future<void> selectFolder(String? folderId) async {
    state = state.copyWith(
      selectedFolderId: folderId,
      clearSelection: folderId == null,
    );
    if (folderId != null && !state.statusesByFolder.containsKey(folderId)) {
      await loadStatuses(folderId);
    }
    await loadTodos();
  }

  Future<void> loadTodos() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _api.dio.get(
        '/todos/todos',
        queryParameters: state.selectedFolderId != null ? {'folder_id': state.selectedFolderId} : null,
      );
      final todos = (res.data as List)
          .map((e) => TodoModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(todos: todos, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load todos: $e');
    }
  }

  Future<TodoModel?> createTodo({
    required String title,
    String? description,
    String priority = 'medium',
    DateTime? dueDate,
    List<String>? tags,
    String? statusId,
    String? goalId,
    int? estimatedMinutes,
    String? folderId,
  }) async {
    try {
      final targetFolderId = folderId ?? state.selectedFolderId;
      final res = await _api.dio.post('/todos/todos', data: {
        'title': title,
        if (targetFolderId != null) 'folder_id': targetFolderId,
        if (statusId != null) 'status_id': statusId,
        if (description != null) 'description': description,
        'priority': priority,
        if (dueDate != null) 'due_date': dueDate.toIso8601String(),
        if (tags != null && tags.isNotEmpty) 'tags': tags,
        if (goalId != null) 'goal_id': goalId,
        if (estimatedMinutes != null) 'estimated_minutes': estimatedMinutes,
      });
      final todo = TodoModel.fromJson(res.data as Map<String, dynamic>);
      state = state.copyWith(todos: [todo, ...state.todos]);
      return todo;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create todo: $e');
      return null;
    }
  }

  Future<void> loadGoalOptions() async {
    try {
      final res = await _api.dio.get('/knowledge/goals', queryParameters: {'status': 'active'});
      final goals = (res.data as List)
          .map((e) => GoalOptionModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(goalOptions: goals);
    } catch (_) {
      // non-fatal — UI gracefully falls back to "no goal"
    }
  }

  Future<bool> updateTodo(String todoId, Map<String, dynamic> patch) async {
    try {
      final res = await _api.dio.patch('/todos/todos/$todoId', data: patch);
      final updated = TodoModel.fromJson(res.data as Map<String, dynamic>);
      state = state.copyWith(
        todos: state.todos.map((t) => t.id == todoId ? updated : t).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update todo: $e');
      return false;
    }
  }

  Future<bool> deleteTodo(String todoId) async {
    try {
      await _api.dio.delete('/todos/todos/$todoId');
      state = state.copyWith(todos: state.todos.where((t) => t.id != todoId).toList());
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete todo: $e');
      return false;
    }
  }

  Future<bool> toggleComplete(String todoId, bool completed) =>
      updateTodo(todoId, {'completed': completed});
}

final todosProvider = StateNotifierProvider<TodosNotifier, TodosState>((ref) {
  return TodosNotifier(ref.read(apiClientProvider));
});
