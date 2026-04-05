import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsState {
  final bool darkMode;
  final String apiEndpoint;

  const SettingsState({
    this.darkMode = false,
    this.apiEndpoint = 'http://localhost:8000/api/v1',
  });

  SettingsState copyWith({
    bool? darkMode,
    String? apiEndpoint,
  }) {
    return SettingsState(
      darkMode: darkMode ?? this.darkMode,
      apiEndpoint: apiEndpoint ?? this.apiEndpoint,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState());

  void toggleDarkMode() {
    state = state.copyWith(darkMode: !state.darkMode);
  }

  void setApiEndpoint(String endpoint) {
    state = state.copyWith(apiEndpoint: endpoint);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
