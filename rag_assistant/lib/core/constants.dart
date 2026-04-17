class AppConstants {
  AppConstants._();

  static const String baseUrl = 'http://127.0.0.1:8000/api/v1';
  static const String wsUrl = 'ws://127.0.0.1:8000/api/v1';
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
