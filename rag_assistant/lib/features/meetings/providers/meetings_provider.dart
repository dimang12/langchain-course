import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../models/meeting_model.dart';

class MeetingsState {
  final List<MeetingModel> meetings;
  final bool isLoading;
  final String? error;

  const MeetingsState({
    this.meetings = const [],
    this.isLoading = false,
    this.error,
  });

  MeetingsState copyWith({
    List<MeetingModel>? meetings,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return MeetingsState(
      meetings: meetings ?? this.meetings,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  MeetingModel? findByNodeId(String? nodeId) {
    if (nodeId == null) return null;
    for (final m in meetings) {
      if (m.treeNodeId == nodeId) return m;
    }
    return null;
  }

  MeetingModel? findByCalendarEventId(String calendarEventId) {
    for (final m in meetings) {
      if (m.calendarEventId == calendarEventId) return m;
    }
    return null;
  }
}

class MeetingsNotifier extends StateNotifier<MeetingsState> {
  final ApiClient _apiClient;

  MeetingsNotifier(this._apiClient) : super(const MeetingsState());

  Future<void> loadMeetings({String? status, int limit = 50}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final query = <String, dynamic>{'limit': limit};
      if (status != null) query['status'] = status;
      final response = await _apiClient.dio.get('/meetings', queryParameters: query);
      final list = (response.data as List)
          .map((e) => MeetingModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(meetings: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load meetings');
    }
  }

  Future<MeetingModel?> createMeeting({
    required String title,
    DateTime? scheduledAt,
    List<Map<String, dynamic>>? attendees,
    String? calendarEventId,
  }) async {
    try {
      final response = await _apiClient.dio.post('/meetings', data: {
        'title': title,
        if (scheduledAt != null) 'scheduled_at': scheduledAt.toIso8601String(),
        if (attendees != null) 'attendees': attendees,
        if (calendarEventId != null) 'calendar_event_id': calendarEventId,
      });
      final meeting = MeetingModel.fromJson(response.data as Map<String, dynamic>);
      state = state.copyWith(meetings: [meeting, ...state.meetings]);
      return meeting;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create meeting');
      return null;
    }
  }

  Future<MeetingModel?> getOrCreateForCalendarEvent({
    required String calendarEventId,
    required String title,
    DateTime? scheduledAt,
    List<String> attendeeNames = const [],
  }) async {
    final existing = state.findByCalendarEventId(calendarEventId);
    if (existing != null) return existing;
    if (state.meetings.isEmpty) {
      await loadMeetings();
      final found = state.findByCalendarEventId(calendarEventId);
      if (found != null) return found;
    }
    final attendees = attendeeNames
        .where((n) => n.isNotEmpty)
        .map((n) => {'name': n})
        .toList();
    return createMeeting(
      title: title,
      scheduledAt: scheduledAt,
      attendees: attendees,
      calendarEventId: calendarEventId,
    );
  }

  Future<FinalizeResult?> finalizeMeeting(String meetingId) async {
    try {
      final response = await _apiClient.dio.post('/meetings/$meetingId/finalize');
      final result = FinalizeResult.fromJson(response.data as Map<String, dynamic>);
      final updated = state.meetings.map((m) {
        if (m.id != meetingId) return m;
        return MeetingModel(
          id: m.id,
          title: m.title,
          status: 'finalized',
          scheduledAt: m.scheduledAt,
          finalizedAt: DateTime.now(),
          attendees: m.attendees,
          calendarEventId: m.calendarEventId,
          treeNodeId: m.treeNodeId,
          decisionsExtracted: result.decisionsExtracted,
          followUpsExtracted: result.followUpsExtracted,
          todosCreated: m.todosCreated,
          createdAt: m.createdAt,
          updatedAt: DateTime.now(),
        );
      }).toList();
      state = state.copyWith(meetings: updated);
      return result;
    } catch (e) {
      state = state.copyWith(error: 'Failed to finalize meeting');
      return null;
    }
  }

  Future<MeetingModel?> createFromText({
    required String title,
    required String rawText,
    DateTime? scheduledAt,
    bool autoFinalize = true,
  }) async {
    try {
      final response = await _apiClient.dio.post('/meetings/from-text', data: {
        'title': title,
        'raw_text': rawText,
        if (scheduledAt != null) 'scheduled_at': scheduledAt.toIso8601String(),
        'auto_finalize': autoFinalize,
      });
      final meeting = MeetingModel.fromJson(response.data as Map<String, dynamic>);
      state = state.copyWith(meetings: [meeting, ...state.meetings]);
      return meeting;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create meeting from text');
      return null;
    }
  }
}

final meetingsProvider = StateNotifierProvider<MeetingsNotifier, MeetingsState>((ref) {
  return MeetingsNotifier(ref.read(apiClientProvider));
});

/// Global navigation provider so non-workspace screens can request a section switch.
/// Indices match WorkspaceNavRail: 0=workspace, 4=today, 5=goals, 6=calendar, 7=todos.
final navIndexProvider = StateProvider<int>((ref) => 0);
