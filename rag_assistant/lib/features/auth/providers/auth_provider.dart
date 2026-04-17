import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api_client.dart';
import '../models/user_model.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final _storage = const FlutterSecureStorage();

  AuthNotifier(this._apiClient) : super(const AuthState());

  Future<void> tryAutoLogin() async {
    try {
      final accessToken = await _storage.read(key: 'access_token');
      final refreshToken = await _storage.read(key: 'refresh_token');
      final email = await _storage.read(key: 'email');
      final name = await _storage.read(key: 'name');
      if (accessToken != null &&
          refreshToken != null &&
          email != null &&
          name != null) {
        final user = UserModel(
          email: email,
          name: name,
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
        _apiClient.setToken(accessToken);
        _apiClient.setRefreshToken(refreshToken);
        state = AuthState(user: user);
      }
    } catch (_) {
      // Keychain unavailable or corrupted — silently proceed to login screen
    }
  }

  Future<void> register(String email, String password, String name) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiClient.dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        'name': name,
      });
      final data = response.data;
      final user = UserModel(
        email: email,
        name: name,
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
      );
      _apiClient.setToken(user.accessToken);
      _apiClient.setRefreshToken(user.refreshToken);
      try {
        await _saveTokens(user);
      } catch (storageErr) {
        // Keychain write failed — non-fatal, auto-login won't persist
      }
      state = AuthState(user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiClient.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      final data = response.data;
      final user = UserModel(
        email: email,
        name: email.split('@').first,
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
      );
      _apiClient.setToken(user.accessToken);
      _apiClient.setRefreshToken(user.refreshToken);
      try {
        await _saveTokens(user);
      } catch (storageErr) {
        // Keychain write failed — non-fatal, auto-login won't persist
      }
      state = AuthState(user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
    }
  }

  Future<void> logout() async {
    _apiClient.setToken(null);
    await _storage.deleteAll();
    state = const AuthState();
  }

  Future<void> _saveTokens(UserModel user) async {
    await _storage.write(key: 'access_token', value: user.accessToken);
    await _storage.write(key: 'refresh_token', value: user.refreshToken);
    await _storage.write(key: 'email', value: user.email);
    await _storage.write(key: 'name', value: user.name);
  }

  String _parseError(dynamic e) {
    try {
      final dioErr = e as dynamic;
      final detail = dioErr.response?.data?['detail']?.toString();
      if (detail != null && detail.isNotEmpty) return detail;
      final statusCode = dioErr.response?.statusCode;
      if (statusCode != null) return 'Server error ($statusCode)';
      final message = dioErr.message?.toString();
      if (message != null && message.isNotEmpty) return message;
    } catch (_) {}
    return 'Connection failed — is the backend running on localhost:8000?';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiClientProvider));
});
