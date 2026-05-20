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

class AuthException implements Exception {
  final String message;
  final int? statusCode;

  const AuthException(this.message, {this.statusCode});

  @override
  String toString() => message;
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
    try {
      final res = await _client.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final data = res.data;
      if (data is! Map<String, dynamic>) {
        throw AuthException('로그인 응답 형식이 올바르지 않습니다.');
      }

      final access = data['access_token'] as String?;
      final refresh = data['refresh_token'] as String?;

      if (access == null || refresh == null) {
        throw AuthException('로그인 토큰이 응답에 포함되어 있지 않습니다.');
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
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;

      debugPrint(
        '[AuthApi] login failed: status=$statusCode data=$data message=${e.message}',
      );

      String message = '로그인에 실패했습니다.';

      if (data is Map && data['detail'] != null) {
        final detail = data['detail'];

        if (detail is String) {
          message = detail;
        } else if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) {
            message = first['msg'].toString();
          } else {
            message = detail.toString();
          }
        } else {
          message = detail.toString();
        }
      }

      // 서버가 아직 기존 메시지를 내려주는 경우 프론트에서 한 번 더 변환
      if (message == 'Invalid credentials') {
        message = '이메일 또는 비밀번호가 일치하지 않습니다.';
      } else if (message.startsWith('Invalid credentials.')) {
        message = message.replaceFirst(
          'Invalid credentials.',
          '비밀번호가 일치하지 않습니다.',
        );
      } else if (message.contains('value is not a valid email') ||
          message.contains('valid email') ||
          message.contains('email')) {
        if (statusCode == 422) {
          message = '이메일 형식이 올바르지 않습니다.';
        }
      }

      if (statusCode == 401 && message == '로그인에 실패했습니다.') {
        message = '이메일 또는 비밀번호가 일치하지 않습니다.';
      } else if (statusCode == 423 && message == '로그인에 실패했습니다.') {
        message = '로그인 실패 횟수가 초과되어 계정이 일시적으로 제한되었습니다.';
      } else if (statusCode == 422 && message == '로그인에 실패했습니다.') {
        message = '이메일 또는 비밀번호 입력 형식이 올바르지 않습니다.';
      } else if (statusCode == 503 && message == '로그인에 실패했습니다.') {
        message = '서버가 일시적으로 응답하지 않습니다. 잠시 후 다시 시도해주세요.';
      }

      throw AuthException(message, statusCode: statusCode);
    } catch (e) {
      if (e is AuthException) rethrow;
      debugPrint('[AuthApi] login unexpected error: $e');
      throw const AuthException('로그인 중 오류가 발생했습니다.');
    }
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
