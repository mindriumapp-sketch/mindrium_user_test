import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../storage/token_storage.dart';

const String _envBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://115.145.134.180:8070',
);

class ApiClient {
  final Dio dio;
  final TokenStorage tokens;
  final String baseUrl;

  static String _resolveBaseUrl(String? override) {
    if (override != null && override.isNotEmpty) {
      return _enforceTransportPolicy(override);
    }
    if (_envBaseUrl.isNotEmpty) {
      return _enforceTransportPolicy(_envBaseUrl);
    }
    if (kIsWeb) {
      return 'https://mindrium-backend.onrender.com';
    }
    if (kDebugMode) {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8080';
      }
      return 'http://127.0.0.1:8080';
    }
    throw StateError(
      'API_BASE_URL must be set via --dart-define for release builds.',
    );
  }

  static String _enforceTransportPolicy(String url) {
    final trimmed = url.trim();
    if (kReleaseMode && trimmed.toLowerCase().startsWith('http://')) {
      throw StateError(
        'Release builds require HTTPS API_BASE_URL (SI-01 / DC-01).',
      );
    }
    return trimmed;
  }

  ApiClient({required this.tokens, String? baseUrl})
    : baseUrl = _resolveBaseUrl(baseUrl),
      dio = Dio(
        BaseOptions(
          baseUrl: _resolveBaseUrl(baseUrl),
          // Render 무료 등은 cold start로 1분 이상 걸릴 수 있어 여유 있게 둔다.
          connectTimeout: const Duration(seconds: 90),
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 30),
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipAuth'] == true) {
            return handler.next(options);
          }
          final access = await tokens.access;
          if (access != null) {
            options.headers['Authorization'] = 'Bearer $access';
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          if (e.requestOptions.extra['skipAuth'] == true) {
            return handler.next(e);
          }
          if (e.response?.statusCode == 401) {
            final ok = await _tryRefresh();
            if (ok) {
              final req = e.requestOptions;
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
    if (refresh == null) return false;
    try {
      final res = await dio.post(
        '/auth/refresh',
        data: {'refresh_token': refresh},
        options: Options(extra: {'skipAuth': true}),
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final access = data['access_token'] as String?;
        final newRefresh = data['refresh_token'] as String? ?? refresh;
        if (access == null) return false;
        await tokens.save(access, newRefresh);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
