import 'package:flutter_riverpod/flutter_riverpod.dart';

class SourcesState {
  final List<String> sources;
  final bool isLoading;

  const SourcesState({
    this.sources = const [],
    this.isLoading = false,
  });
}

class SourcesNotifier extends StateNotifier<SourcesState> {
  SourcesNotifier() : super(const SourcesState());

  Future<void> loadSources() async {
    state = SourcesState(sources: state.sources, isLoading: true);
    // TODO: Fetch sources from backend
    state = SourcesState(sources: state.sources, isLoading: false);
  }
}

final sourcesProvider =
    StateNotifierProvider<SourcesNotifier, SourcesState>((ref) {
  return SourcesNotifier();
});
