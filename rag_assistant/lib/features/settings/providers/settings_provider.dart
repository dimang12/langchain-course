import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsState {
  final bool darkMode;
  final String apiEndpoint;
  final bool centeredContent;

  const SettingsState({
    this.darkMode = false,
    this.apiEndpoint = 'http://localhost:8000/api/v1',
    this.centeredContent = true,
  });

  SettingsState copyWith({
    bool? darkMode,
    String? apiEndpoint,
    bool? centeredContent,
  }) {
    return SettingsState(
      darkMode: darkMode ?? this.darkMode,
      apiEndpoint: apiEndpoint ?? this.apiEndpoint,
      centeredContent: centeredContent ?? this.centeredContent,
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

  void toggleContentWidth() {
    state = state.copyWith(centeredContent: !state.centeredContent);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
