import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../models/knowledge_models.dart';

class KnowledgeState {
  final List<GoalModel> goals;
  final List<FollowUpModel> followups;
  final List<DecisionModel> decisions;
  final List<PersonModel> people;
  final bool isLoading;
  final bool isExtracting;
  final String? error;
  final Map<String, int>? lastExtractionCounts;

  const KnowledgeState({
    this.goals = const [],
    this.followups = const [],
    this.decisions = const [],
    this.people = const [],
    this.isLoading = false,
    this.isExtracting = false,
    this.error,
    this.lastExtractionCounts,
  });

  List<GoalModel> get orgGoals => goals.where((g) => g.level == 'org').toList();
  List<GoalModel> get teamGoals => goals.where((g) => g.level == 'team').toList();
  List<GoalModel> get personalGoals => goals.where((g) => g.level == 'personal').toList();
  List<FollowUpModel> get openFollowups => followups.where((f) => f.status == 'open').toList();

  KnowledgeState copyWith({
    List<GoalModel>? goals,
    List<FollowUpModel>? followups,
    List<DecisionModel>? decisions,
    List<PersonModel>? people,
    bool? isLoading,
    bool? isExtracting,
    String? error,
    Map<String, int>? lastExtractionCounts,
    bool clearError = false,
    bool clearExtraction = false,
  }) {
    return KnowledgeState(
      goals: goals ?? this.goals,
      followups: followups ?? this.followups,
      decisions: decisions ?? this.decisions,
      people: people ?? this.people,
      isLoading: isLoading ?? this.isLoading,
      isExtracting: isExtracting ?? this.isExtracting,
      error: clearError ? null : (error ?? this.error),
      lastExtractionCounts: clearExtraction ? null : (lastExtractionCounts ?? this.lastExtractionCounts),
    );
  }
}

class KnowledgeNotifier extends StateNotifier<KnowledgeState> {
  final ApiClient _apiClient;

  KnowledgeNotifier(this._apiClient) : super(const KnowledgeState());

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _apiClient.dio.get('/knowledge/goals'),
        _apiClient.dio.get('/knowledge/followups', queryParameters: {'status': 'open'}),
        _apiClient.dio.get('/knowledge/decisions'),
        _apiClient.dio.get('/knowledge/people'),
      ]);

      state = state.copyWith(
        goals: (results[0].data as List).map((e) => GoalModel.fromJson(e as Map<String, dynamic>)).toList(),
        followups: (results[1].data as List).map((e) => FollowUpModel.fromJson(e as Map<String, dynamic>)).toList(),
        decisions: (results[2].data as List).map((e) => DecisionModel.fromJson(e as Map<String, dynamic>)).toList(),
        people: (results[3].data as List).map((e) => PersonModel.fromJson(e as Map<String, dynamic>)).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load: $e');
    }
  }

  Future<bool> createGoal({
    required String title,
    String? description,
    String level = 'personal',
    int priority = 3,
    String? dueDate,
  }) async {
    try {
      await _apiClient.dio.post('/knowledge/goals', data: {
        'title': title,
        'description': description,
        'level': level,
        'priority': priority,
        'due_date': dueDate,
      });
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create goal: $e');
      return false;
    }
  }

  Future<bool> deleteGoal(String goalId) async {
    try {
      await _apiClient.dio.delete('/knowledge/goals/$goalId');
      state = state.copyWith(
        goals: state.goals.where((g) => g.id != goalId).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete goal: $e');
      return false;
    }
  }

  Future<bool> markFollowupDone(String followupId) async {
    try {
      await _apiClient.dio.put('/knowledge/followups/$followupId/done');
      state = state.copyWith(
        followups: state.followups.where((f) => f.id != followupId).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update follow-up: $e');
      return false;
    }
  }

  Future<Map<String, int>?> extract(String content) async {
    state = state.copyWith(isExtracting: true, clearError: true);
    try {
      final response = await _apiClient.dio.post('/knowledge/extract', data: {
        'content': content,
      });
      final counts = Map<String, int>.from(
        (response.data as Map<String, dynamic>)['counts'] as Map<String, dynamic>,
      );
      state = state.copyWith(isExtracting: false, lastExtractionCounts: counts);
      await loadAll();
      return counts;
    } catch (e) {
      state = state.copyWith(isExtracting: false, error: 'Extraction failed: $e');
      return null;
    }
  }
}

final knowledgeProvider =
    StateNotifierProvider<KnowledgeNotifier, KnowledgeState>((ref) {
  return KnowledgeNotifier(ref.read(apiClientProvider));
});
