import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';

class SourceItem {
  final String id;
  final String filename;
  final String status;
  final int? chunks;
  final String? error;
  final String uploadedAt;

  const SourceItem({
    required this.id,
    required this.filename,
    required this.status,
    this.chunks,
    this.error,
    required this.uploadedAt,
  });

  factory SourceItem.fromJson(Map<String, dynamic> json) {
    return SourceItem(
      id: json['id'] as String,
      filename: json['filename'] as String,
      status: json['status'] as String,
      chunks: json['chunks'] as int?,
      error: json['error'] as String?,
      uploadedAt: json['uploaded_at'] as String,
    );
  }
}

class SourcesState {
  final List<SourceItem> sources;
  final bool isLoading;
  final String? error;

  const SourcesState({this.sources = const [], this.isLoading = false, this.error});

  SourcesState copyWith({List<SourceItem>? sources, bool? isLoading, String? error, bool clearError = false}) {
    return SourcesState(
      sources: sources ?? this.sources,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SourcesNotifier extends StateNotifier<SourcesState> {
  final ApiClient _apiClient;

  SourcesNotifier(this._apiClient) : super(const SourcesState());

  Future<void> loadSources() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiClient.dio.get('/ingestion/sources');
      final sources = (response.data as List).map((e) => SourceItem.fromJson(e as Map<String, dynamic>)).toList();
      state = state.copyWith(sources: sources, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load sources');
    }
  }

  Future<void> uploadFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null && file.path == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final MultipartFile multipartFile;
      if (file.bytes != null) {
        multipartFile = MultipartFile.fromBytes(file.bytes!, filename: file.name);
      } else {
        multipartFile = await MultipartFile.fromFile(file.path!, filename: file.name);
      }
      final formData = FormData.fromMap({'file': multipartFile});
      await _apiClient.dio.post('/ingestion/upload', data: formData);
      await loadSources();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to upload file');
    }
  }

  Future<void> deleteSource(String sourceId) async {
    try {
      await _apiClient.dio.delete('/ingestion/sources/$sourceId');
      state = state.copyWith(
        sources: state.sources.where((s) => s.id != sourceId).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete source');
    }
  }
}

final sourcesProvider = StateNotifierProvider<SourcesNotifier, SourcesState>((ref) {
  return SourcesNotifier(ref.read(apiClientProvider));
});
