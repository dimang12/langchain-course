import 'package:dio/dio.dart';
import 'constants.dart';
import 'auth_interceptor.dart';

class ApiClient {
  late final Dio dio;
  late final AuthInterceptor authInterceptor;

  ApiClient() {
    authInterceptor = AuthInterceptor();
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.connectionTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    dio.interceptors.add(authInterceptor);
  }

  void setToken(String? token) {
    authInterceptor.setToken(token);
  }
}
