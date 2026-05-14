import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../models/calendar_event_model.dart';

enum CalendarViewMode { day, week, month }

class CalendarState {
  final DateTime currentWeekStart;
  final DateTime selectedDate;
  final CalendarViewMode viewMode;
  final List<CalendarEventModel> events;
  final bool isLoading;
  final String? error;

  CalendarState({
    DateTime? currentWeekStart,
    DateTime? selectedDate,
    this.viewMode = CalendarViewMode.week,
    this.events = const [],
    this.isLoading = false,
    this.error,
  })  : currentWeekStart = currentWeekStart ?? _mondayOfWeek(DateTime.now()),
        selectedDate = selectedDate ?? DateTime.now();

  static DateTime _mondayOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  static DateTime _firstOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  CalendarState copyWith({
    DateTime? currentWeekStart,
    DateTime? selectedDate,
    CalendarViewMode? viewMode,
    List<CalendarEventModel>? events,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return CalendarState(
      currentWeekStart: currentWeekStart ?? this.currentWeekStart,
      selectedDate: selectedDate ?? this.selectedDate,
      viewMode: viewMode ?? this.viewMode,
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  List<CalendarEventModel> eventsForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return events
        .where((e) => e.startTime.isBefore(dayEnd) && e.endTime.isAfter(dayStart))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<({TimeOfDay start, TimeOfDay end, int minutes})> freeSlotsForDay(DateTime day) {
    const workStart = 9;
    const workEnd = 18;
    final dayEvents = eventsForDay(day).where((e) => !e.isAllDay).toList();

    final slots = <({TimeOfDay start, TimeOfDay end, int minutes})>[];
    var cursor = workStart * 60; // minutes from midnight

    for (final event in dayEvents) {
      final evStart = event.startTime.hour * 60 + event.startTime.minute;
      final evEnd = event.endTime.hour * 60 + event.endTime.minute;
      final clampedStart = evStart.clamp(workStart * 60, workEnd * 60);
      final clampedEnd = evEnd.clamp(workStart * 60, workEnd * 60);

      if (clampedStart > cursor) {
        final duration = clampedStart - cursor;
        if (duration >= 30) {
          slots.add((
            start: TimeOfDay(hour: cursor ~/ 60, minute: cursor % 60),
            end: TimeOfDay(hour: clampedStart ~/ 60, minute: clampedStart % 60),
            minutes: duration,
          ));
        }
      }
      if (clampedEnd > cursor) cursor = clampedEnd;
    }

    if (cursor < workEnd * 60) {
      final duration = workEnd * 60 - cursor;
      if (duration >= 30) {
        slots.add((
          start: TimeOfDay(hour: cursor ~/ 60, minute: cursor % 60),
          end: TimeOfDay(hour: workEnd, minute: 0),
          minutes: duration,
        ));
      }
    }
    return slots;
  }

  CalendarEventModel? get nextUpcoming {
    final now = DateTime.now();
    for (final e in events) {
      if (e.startTime.isAfter(now)) return e;
    }
    return null;
  }

  DateTime get weekEnd => currentWeekStart.add(const Duration(days: 7));
}

class CalendarNotifier extends StateNotifier<CalendarState> {
  final ApiClient _apiClient;

  CalendarNotifier(this._apiClient) : super(CalendarState());

  void setViewMode(CalendarViewMode mode) {
    state = state.copyWith(viewMode: mode);
    loadEvents();
  }

  Future<void> loadEvents() async {
    DateTime start;
    DateTime end;

    switch (state.viewMode) {
      case CalendarViewMode.day:
        final d = DateTime(state.selectedDate.year, state.selectedDate.month, state.selectedDate.day);
        start = d;
        end = d.add(const Duration(days: 1));
        break;
      case CalendarViewMode.week:
        start = state.currentWeekStart;
        end = start.add(const Duration(days: 7));
        break;
      case CalendarViewMode.month:
        final first = CalendarState._firstOfMonth(state.selectedDate);
        // Load from Monday before first to Sunday after last
        start = first.subtract(Duration(days: first.weekday - 1));
        final lastDay = DateTime(first.year, first.month + 1, 0);
        end = lastDay.add(Duration(days: 7 - lastDay.weekday));
        break;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiClient.dio.get('/connectors/events', queryParameters: {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'limit': 500,
      });
      final events = (response.data as List)
          .map((e) => CalendarEventModel.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      state = state.copyWith(events: events, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load events');
    }
  }

  // Keep loadWeek for backward compat
  Future<void> loadWeek([DateTime? weekStart]) async {
    if (weekStart != null) {
      state = state.copyWith(currentWeekStart: weekStart);
    }
    await loadEvents();
  }

  void goNext() {
    switch (state.viewMode) {
      case CalendarViewMode.day:
        state = state.copyWith(selectedDate: state.selectedDate.add(const Duration(days: 1)));
        break;
      case CalendarViewMode.week:
        state = state.copyWith(currentWeekStart: state.currentWeekStart.add(const Duration(days: 7)));
        break;
      case CalendarViewMode.month:
        final d = state.selectedDate;
        state = state.copyWith(selectedDate: DateTime(d.year, d.month + 1, 1));
        break;
    }
    loadEvents();
  }

  void goPrev() {
    switch (state.viewMode) {
      case CalendarViewMode.day:
        state = state.copyWith(selectedDate: state.selectedDate.subtract(const Duration(days: 1)));
        break;
      case CalendarViewMode.week:
        state = state.copyWith(currentWeekStart: state.currentWeekStart.subtract(const Duration(days: 7)));
        break;
      case CalendarViewMode.month:
        final d = state.selectedDate;
        state = state.copyWith(selectedDate: DateTime(d.year, d.month - 1, 1));
        break;
    }
    loadEvents();
  }

  void goToToday() {
    final now = DateTime.now();
    state = state.copyWith(
      currentWeekStart: CalendarState._mondayOfWeek(now),
      selectedDate: now,
    );
    loadEvents();
  }

  void selectDay(DateTime day) {
    state = state.copyWith(
      selectedDate: day,
      viewMode: CalendarViewMode.day,
    );
    loadEvents();
  }

  Future<bool> createEvent({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? description,
    bool isAllDay = false,
    String? location,
  }) async {
    try {
      await _apiClient.dio.post('/connectors/events', data: {
        'title': title,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'description': description,
        'is_all_day': isAllDay,
        'location': location,
      });
      await loadEvents();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create event');
      return false;
    }
  }

  Future<bool> updateEvent({
    required String eventId,
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? description,
    bool isAllDay = false,
    String? location,
  }) async {
    try {
      await _apiClient.dio.put('/connectors/events/$eventId', data: {
        'title': title,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'description': description,
        'is_all_day': isAllDay,
        'location': location,
      });
      await loadEvents();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update event');
      return false;
    }
  }

  Future<bool> deleteEvent(String eventId) async {
    try {
      await _apiClient.dio.delete('/connectors/events/$eventId');
      await loadEvents();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete event');
      return false;
    }
  }

  // Legacy
  void goNextWeek() => goNext();
  void goPrevWeek() => goPrev();
}

final calendarProvider = StateNotifierProvider<CalendarNotifier, CalendarState>((ref) {
  return CalendarNotifier(ref.read(apiClientProvider));
});
