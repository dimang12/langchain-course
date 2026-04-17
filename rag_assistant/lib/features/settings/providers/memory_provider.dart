import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../models/memory_models.dart';

class MemoryState {
  final UserProfileModel profile;
  final OrgContextModel org;
  final List<MemoryFactModel> facts;
  final bool isLoadingProfile;
  final bool isLoadingOrg;
  final bool isLoadingFacts;
  final bool isSavingProfile;
  final bool isSavingOrg;
  final String? error;

  const MemoryState({
    this.profile = const UserProfileModel(),
    this.org = const OrgContextModel(),
    this.facts = const [],
    this.isLoadingProfile = false,
    this.isLoadingOrg = false,
    this.isLoadingFacts = false,
    this.isSavingProfile = false,
    this.isSavingOrg = false,
    this.error,
  });

  MemoryState copyWith({
    UserProfileModel? profile,
    OrgContextModel? org,
    List<MemoryFactModel>? facts,
    bool? isLoadingProfile,
    bool? isLoadingOrg,
    bool? isLoadingFacts,
    bool? isSavingProfile,
    bool? isSavingOrg,
    String? error,
    bool clearError = false,
  }) {
    return MemoryState(
      profile: profile ?? this.profile,
      org: org ?? this.org,
      facts: facts ?? this.facts,
      isLoadingProfile: isLoadingProfile ?? this.isLoadingProfile,
      isLoadingOrg: isLoadingOrg ?? this.isLoadingOrg,
      isLoadingFacts: isLoadingFacts ?? this.isLoadingFacts,
      isSavingProfile: isSavingProfile ?? this.isSavingProfile,
      isSavingOrg: isSavingOrg ?? this.isSavingOrg,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MemoryNotifier extends StateNotifier<MemoryState> {
  final ApiClient _apiClient;

  MemoryNotifier(this._apiClient) : super(const MemoryState());

  // ---------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------
  Future<void> loadProfile() async {
    state = state.copyWith(isLoadingProfile: true, clearError: true);
    try {
      final response = await _apiClient.dio.get('/memory/profile');
      state = state.copyWith(
        profile: UserProfileModel.fromJson(response.data as Map<String, dynamic>),
        isLoadingProfile: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingProfile: false,
        error: 'Failed to load profile: $e',
      );
    }
  }

  Future<bool> saveProfile(UserProfileModel updated) async {
    state = state.copyWith(isSavingProfile: true, clearError: true);
    try {
      final response = await _apiClient.dio.put(
        '/memory/profile',
        data: updated.toJson(),
      );
      state = state.copyWith(
        profile: UserProfileModel.fromJson(response.data as Map<String, dynamic>),
        isSavingProfile: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSavingProfile: false,
        error: 'Failed to save profile: $e',
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------
  // Org context
  // ---------------------------------------------------------------------
  Future<void> loadOrg() async {
    state = state.copyWith(isLoadingOrg: true, clearError: true);
    try {
      final response = await _apiClient.dio.get('/memory/org');
      state = state.copyWith(
        org: OrgContextModel.fromJson(response.data as Map<String, dynamic>),
        isLoadingOrg: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingOrg: false,
        error: 'Failed to load organization: $e',
      );
    }
  }

  Future<bool> saveOrg(OrgContextModel updated) async {
    state = state.copyWith(isSavingOrg: true, clearError: true);
    try {
      final response = await _apiClient.dio.put(
        '/memory/org',
        data: updated.toJson(),
      );
      state = state.copyWith(
        org: OrgContextModel.fromJson(response.data as Map<String, dynamic>),
        isSavingOrg: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSavingOrg: false,
        error: 'Failed to save organization: $e',
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------
  // Facts
  // ---------------------------------------------------------------------
  Future<void> loadFacts() async {
    state = state.copyWith(isLoadingFacts: true, clearError: true);
    try {
      final response = await _apiClient.dio.get('/memory/facts');
      final list = (response.data as List<dynamic>)
          .map((e) => MemoryFactModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(facts: list, isLoadingFacts: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingFacts: false,
        error: 'Failed to load memories: $e',
      );
    }
  }

  Future<bool> createFact(String fact, {double confidence = 0.9}) async {
    try {
      await _apiClient.dio.post('/memory/facts', data: {
        'fact': fact,
        'source': 'manual',
        'confidence': confidence,
      });
      await loadFacts();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create memory: $e');
      return false;
    }
  }

  Future<bool> deleteFact(String factId) async {
    try {
      await _apiClient.dio.delete('/memory/facts/$factId');
      state = state.copyWith(
        facts: state.facts.where((f) => f.id != factId).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete memory: $e');
      return false;
    }
  }
}

final memoryProvider =
    StateNotifierProvider<MemoryNotifier, MemoryState>((ref) {
  return MemoryNotifier(ref.read(apiClientProvider));
});
