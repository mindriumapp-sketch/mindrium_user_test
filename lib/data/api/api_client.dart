import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../storage/token_storage.dart';

const String _envAppDataBaseUrl = String.fromEnvironment(
  'APP_DATA_BASE_URL',
  defaultValue: '',
);

const String _envPlatformAuthBaseUrl = String.fromEnvironment(
  'PLATFORM_AUTH_BASE_URL',
  defaultValue: '',
);

class ApiClient {
  final Dio dio;
  final TokenStorage tokens;
  final String baseUrl;

  static String _defaultAppDataBaseUrl() {
    if (_envAppDataBaseUrl.isNotEmpty) {
      return _envAppDataBaseUrl;
    }

    // [현재] 기존 앱데이터 API는 Render 사용
    return 'https://mindrium-backend.onrender.com';

    // [향후] 8070으로 전환할 때
    // return 'http://115.145.134.180:8070';
    // return 'http://lamda-dtx.skku.edu:8070';
  }

  static String _platformAuthBaseUrl() {
    if (_envPlatformAuthBaseUrl.isNotEmpty) {
      return _envPlatformAuthBaseUrl;
    }

    // 회원가입 / 로그인 / 계정정보 / refresh 전용
    return 'http://115.145.134.180:8061';
  }

  static String _resolveBaseUrl(String? override) {
    if (override != null && override.isNotEmpty) {
      return override;
    }
    return _defaultAppDataBaseUrl();
  }

  factory ApiClient.platformAuth({required TokenStorage tokens}) {
    return ApiClient(tokens: tokens, baseUrl: _platformAuthBaseUrl());
  }

  ApiClient({required this.tokens, String? baseUrl})
      : baseUrl = _resolveBaseUrl(baseUrl),
        dio = Dio(BaseOptions(baseUrl: _resolveBaseUrl(baseUrl))) {
    debugPrint('ApiClient baseUrl = ${_resolveBaseUrl(baseUrl)}');

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipAuth'] == true) {
            return handler.next(options);
          }

          final access = await tokens.access;
          if (access != null && access.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $access';
          }

          debugPrint('[REQ] ${options.method} ${options.baseUrl}${options.path}');
          debugPrint('[REQ DATA] ${options.data}');
          handler.next(options);
        },
        onError: (e, handler) async {
          debugPrint('[ERR] ${e.requestOptions.method} ${e.requestOptions.baseUrl}${e.requestOptions.path}');
          debugPrint('[ERR MSG] ${e.message}');
          debugPrint('[ERR RESP] ${e.response?.data}');

          if (e.requestOptions.extra['skipAuth'] == true) {
            return handler.next(e);
          }

          if (e.response?.statusCode == 401) {
            final ok = await _tryRefresh();
            if (ok) {
              final req = e.requestOptions;
              final newAccess = await tokens.access;
              if (newAccess != null && newAccess.isNotEmpty) {
                req.headers['Authorization'] = 'Bearer $newAccess';
              }
              try {
                final response = await dio.fetch(req);
                return handler.resolve(response);
              } catch (re) {
                return handler.next(re as DioException);
              }
            }
          }

          handler.next(e);
        },
      ),
    );
  }

  Future<bool> _tryRefresh() async {
    final refresh = await tokens.refresh;
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final authClient = ApiClient.platformAuth(tokens: tokens);

      final res = await authClient.dio.post(
        '/auth/refresh',
        data: {'refresh_token': refresh},
        options: Options(extra: {'skipAuth': true}),
      );

      final data = res.data;
      if (data is Map<String, dynamic>) {
        final access = data['access_token'] as String?;
        final newRefresh = data['refresh_token'] as String?;
        if (access == null || newRefresh == null) return false;
        await tokens.save(access, newRefresh);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
