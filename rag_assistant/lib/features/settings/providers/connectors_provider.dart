import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';

class ConnectionInfo {
  final String provider;
  final String? accountEmail;
  final String? lastSyncedAt;
  final String? expiresAt;

  const ConnectionInfo({
    required this.provider,
    this.accountEmail,
    this.lastSyncedAt,
    this.expiresAt,
  });

  factory ConnectionInfo.fromJson(Map<String, dynamic> json) {
    return ConnectionInfo(
      provider: json['provider'] as String? ?? 'unknown',
      accountEmail: json['account_email'] as String?,
      lastSyncedAt: json['last_synced_at'] as String?,
      expiresAt: json['expires_at'] as String?,
    );
  }
}

class ConnectorsState {
  final bool googleConfigured;
  final List<ConnectionInfo> connections;
  final bool isLoading;
  final bool isSyncing;
  final bool isSeeding;
  final String? authorizeUrl;
  final String? error;
  final String? successMessage;

  const ConnectorsState({
    this.googleConfigured = false,
    this.connections = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.isSeeding = false,
    this.authorizeUrl,
    this.error,
    this.successMessage,
  });

  ConnectionInfo? get googleConnection {
    for (final c in connections) {
      if (c.provider == 'google_calendar') return c;
    }
    return null;
  }

  bool get isGoogleConnected => googleConnection != null;

  ConnectorsState copyWith({
    bool? googleConfigured,
    List<ConnectionInfo>? connections,
    bool? isLoading,
    bool? isSyncing,
    bool? isSeeding,
    String? authorizeUrl,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ConnectorsState(
      googleConfigured: googleConfigured ?? this.googleConfigured,
      connections: connections ?? this.connections,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      isSeeding: isSeeding ?? this.isSeeding,
      authorizeUrl: authorizeUrl ?? this.authorizeUrl,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class ConnectorsNotifier extends StateNotifier<ConnectorsState> {
  final ApiClient _apiClient;

  ConnectorsNotifier(this._apiClient) : super(const ConnectorsState());

  Future<void> loadStatus() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiClient.dio.get('/connectors/');
      final data = response.data as Map<String, dynamic>;
      final conns = (data['connections'] as List<dynamic>)
          .map((e) => ConnectionInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        googleConfigured: data['google_calendar_configured'] as bool? ?? false,
        connections: conns,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load: $e');
    }
  }

  Future<String?> getAuthorizeUrl() async {
    try {
      final response = await _apiClient.dio.get('/connectors/google/authorize');
      final url = (response.data as Map<String, dynamic>)['authorize_url'] as String?;
      state = state.copyWith(authorizeUrl: url);
      return url;
    } catch (e) {
      state = state.copyWith(error: 'Not configured — set GOOGLE_CLIENT_ID in backend .env');
      return null;
    }
  }

  Future<void> sync() async {
    state = state.copyWith(isSyncing: true, clearError: true);
    try {
      final response = await _apiClient.dio.post('/connectors/google/sync');
      final count = (response.data as Map<String, dynamic>)['events_upserted'] ?? 0;
      state = state.copyWith(
        isSyncing: false,
        successMessage: 'Synced $count events',
      );
      await loadStatus();
    } catch (e) {
      state = state.copyWith(isSyncing: false, error: 'Sync failed: $e');
    }
  }

  Future<void> devSeed() async {
    state = state.copyWith(isSeeding: true, clearError: true);
    try {
      final response = await _apiClient.dio.post('/connectors/google/dev-seed');
      final count = (response.data as Map<String, dynamic>)['events_created'] ?? 0;
      state = state.copyWith(
        isSeeding: false,
        successMessage: 'Seeded $count fake events',
      );
    } catch (e) {
      state = state.copyWith(isSeeding: false, error: 'Seed failed: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      await _apiClient.dio.delete('/connectors/google');
      state = state.copyWith(
        connections: state.connections
            .where((c) => c.provider != 'google_calendar')
            .toList(),
        successMessage: 'Google Calendar disconnected',
      );
    } catch (e) {
      state = state.copyWith(error: 'Disconnect failed: $e');
    }
  }
}

final connectorsProvider =
    StateNotifierProvider<ConnectorsNotifier, ConnectorsState>((ref) {
  return ConnectorsNotifier(ref.read(apiClientProvider));
});
