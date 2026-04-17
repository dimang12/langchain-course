import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../models/agent_run_model.dart';

class AgentsState {
  final List<AgentRunModel> runs;
  final bool isLoading;
  final bool isTriggering;
  final String? error;

  const AgentsState({
    this.runs = const [],
    this.isLoading = false,
    this.isTriggering = false,
    this.error,
  });

  AgentRunModel? get latestDailyBrief {
    for (final run in runs) {
      if (run.agentName == 'daily_brief' && run.status == 'success') {
        return run;
      }
    }
    return null;
  }

  AgentsState copyWith({
    List<AgentRunModel>? runs,
    bool? isLoading,
    bool? isTriggering,
    String? error,
    bool clearError = false,
  }) {
    return AgentsState(
      runs: runs ?? this.runs,
      isLoading: isLoading ?? this.isLoading,
      isTriggering: isTriggering ?? this.isTriggering,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AgentsNotifier extends StateNotifier<AgentsState> {
  final ApiClient _apiClient;

  AgentsNotifier(this._apiClient) : super(const AgentsState());

  Future<void> loadRuns({int limit = 50}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiClient.dio.get(
        '/agents/runs',
        queryParameters: {'limit': limit},
      );
      final list = (response.data as List<dynamic>)
          .map((e) => AgentRunModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(runs: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load agent runs: $e',
      );
    }
  }

  Future<AgentRunModel?> triggerDailyBrief() async {
    state = state.copyWith(isTriggering: true, clearError: true);
    try {
      final response = await _apiClient.dio.post('/agents/daily-brief/run');
      final run = AgentRunModel.fromJson(response.data as Map<String, dynamic>);
      state = state.copyWith(
        runs: [run, ...state.runs],
        isTriggering: false,
      );
      return run;
    } catch (e) {
      state = state.copyWith(
        isTriggering: false,
        error: 'Failed to trigger brief: $e',
      );
      return null;
    }
  }

  Future<bool> rateRun(String runId, int rating) async {
    try {
      final response = await _apiClient.dio.post(
        '/agents/runs/$runId/rate',
        data: {'rating': rating},
      );
      final updated = AgentRunModel.fromJson(response.data as Map<String, dynamic>);
      state = state.copyWith(
        runs: state.runs.map((r) => r.id == runId ? updated : r).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to rate run: $e');
      return false;
    }
  }
}

final agentsProvider =
    StateNotifierProvider<AgentsNotifier, AgentsState>((ref) {
  return AgentsNotifier(ref.read(apiClientProvider));
});
