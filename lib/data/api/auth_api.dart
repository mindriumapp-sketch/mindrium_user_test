import 'package:dio/dio.dart';
import 'api_client.dart';
import '../storage/token_storage.dart';
import 'package:flutter/foundation.dart';

class LoginResult {
  final String accessToken;
  final String refreshToken;
  final bool mustChangePassword;
  final bool passwordExpired;

  const LoginResult({
    required this.accessToken,
    required this.refreshToken,
    required this.mustChangePassword,
    required this.passwordExpired,
  });
}

class AuthApi {
  final ApiClient _client;
  final TokenStorage _tokens;

  AuthApi(this._client, this._tokens);

  Future<void> signup({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String patientCode,
    String gender = 'male',
    String? address,
  }) async {
    final body = {
      'email': email,
      'password': password,
      'name': name,
      'phone': phone,
      'gender': gender,
      'patient_code': patientCode,
      if (address != null && address.isNotEmpty) 'address': address,
    };
    await _client.dio.post('/auth/signup', data: body);
  }

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final res = await _client.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: res.requestOptions,
        message: 'Invalid login response',
      );
    }
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    if (access == null || refresh == null) {
      throw DioException(
        requestOptions: res.requestOptions,
        message: 'Tokens missing in response',
      );
    }
    final mustChangePassword = data['must_change_password'] == true;
    final passwordExpired = data['password_expired'] == true;

    await _tokens.save(access, refresh);

    return LoginResult(
    accessToken: access,
    refreshToken: refresh,
    mustChangePassword: mustChangePassword,
    passwordExpired: passwordExpired,
    );
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _client.dio.get('/users/me');
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid me response',
    );
  }

  Future<void> logout() async {
    await _tokens.clear();
  }

  Future<String?> requestPasswordResetToken(String email) async {
    final res = await _client.dio.post('/auth/password/reset/start', data: {
      'email': email,
    });
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return data['token_debug'] as String?;
    }
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid password reset start response',
    );
  }

  Future<void> resetPasswordWithToken({
    required String token,
    required String newPassword,
  }) async {
    await _client.dio.post('/auth/password/reset/finish', data: {
      'token': token,
      'new_password': newPassword,
    });
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      debugPrint('[AuthApi] POST /auth/password/change start');

      final res = await _client.dio.post('/auth/password/change', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });

      debugPrint(
        '[AuthApi] POST /auth/password/change success: ${res.statusCode}',
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;

      debugPrint(
        '[AuthApi] POST /auth/password/change failed: '
        'status=$statusCode data=$data message=${e.message}',
      );

      throw Exception(_resolvePasswordChangeErrorMessage(e));
    }
  }

  String _resolvePasswordChangeErrorMessage(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;

    if (statusCode == 401) {
      return '현재 비밀번호가 일치하지 않습니다.';
    }

    if (statusCode == 422) {
      if (data is Map && data['detail'] is List) {
        final details = data['detail'] as List;
        if (details.isNotEmpty) {
          final first = details.first;
          if (first is Map) {
            final msg = first['msg']?.toString();
            if (msg != null && msg.isNotEmpty) {
              return msg
                  .replaceAll('Value error, ', '')
                  .replaceAll('String should have at most 20 characters', '비밀번호는 20자 이하로 입력해주세요.')
                  .replaceAll('String should have at least 8 characters', '비밀번호는 8자 이상 입력해주세요.');
            }
          }
        }
      }

      return '새 비밀번호는 8~20자이며, 영문/숫자/특수문자를 각각 1자 이상 포함해야 합니다.';
    }

    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }

    return '비밀번호 변경에 실패했습니다.';
  }
}
