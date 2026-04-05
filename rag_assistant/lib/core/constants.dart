class AppConstants {
  AppConstants._();

  static const String baseUrl = 'http://localhost:8000/api/v1';
  static const String wsUrl = 'ws://localhost:8000/api/v1';
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
