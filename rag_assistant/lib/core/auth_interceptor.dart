import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';

class AuthInterceptor extends Interceptor {
  String? _token;
  String? _refreshToken;
  final _storage = const FlutterSecureStorage();

  void setToken(String? token) {
    _token = token;
  }

  void setRefreshToken(String? token) {
    _refreshToken = token;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_token != null) {
      options.headers['Authorization'] = 'Bearer $_token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && _refreshToken != null) {
      try {
        final refreshDio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));
        final response = await refreshDio.post('/auth/refresh', data: {
          'refresh_token': _refreshToken,
        });

        final newAccessToken = response.data['access_token'] as String;
        final newRefreshToken = response.data['refresh_token'] as String;

        _token = newAccessToken;
        _refreshToken = newRefreshToken;

        await _storage.write(key: 'access_token', value: newAccessToken);
        await _storage.write(key: 'refresh_token', value: newRefreshToken);

        final retryOptions = err.requestOptions;
        retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';

        final retryResponse = await Dio().fetch(retryOptions);
        return handler.resolve(retryResponse);
      } catch (_) {
        return handler.next(err);
      }
    }
    handler.next(err);
  }
}
