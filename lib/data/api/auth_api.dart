import 'package:dio/dio.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

class AuthApi {
  final ApiClient _client;
  final TokenStorage _tokens;

  AuthApi(this._client, this._tokens);

  Future<void> signup({
    required String email,
    required String password,
    required String name,
    required String patientCode,
    String gender = 'male',
    String? address,
  }) async {
    final body = {
      'email': email,
      'password': password,
      'name': name,
      'gender': gender,
      // Keep both keys for backend compatibility across deployments.
      'code': patientCode,
      'patient_code': patientCode,
      'mindrium_code': patientCode,
      if (address != null && address.isNotEmpty) 'address': address,
    };

    await _client.dio.post('/auth/signup', data: body);
  }

  Future<void> login({required String email, required String password}) async {
    final res = await _client.dio.post(
      '/api/login',
      data: {'email': email, 'password': password},
    );

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

    await _tokens.save(access, refresh);
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _client.dio.get('/api/me');
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
    final res = await _client.dio.post(
      '/auth/password/reset/start',
      data: {'email': email},
    );
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
    await _client.dio.post(
      '/auth/password/reset/finish',
      data: {'token': token, 'new_password': newPassword},
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.dio.post(
      '/auth/password/change',
      data: {'current_password': currentPassword, 'new_password': newPassword},
    );
  }
}
