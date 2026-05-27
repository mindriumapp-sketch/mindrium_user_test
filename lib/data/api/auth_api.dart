import 'package:dio/dio.dart';
import 'api_client.dart';
import '../storage/auth_session_storage.dart';
import '../storage/token_storage.dart';

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
  }) async {
    final body = {
      'email': email,
      'password': password,
      'name': name,
      'phone': phone,
      'patient_code': patientCode,
    };
    final res = await _client.dio.post('/auth/signup', data: body);
    await _saveTokensFromResponse(res);
  }

  Future<({bool passwordChangeRecommended, String? passwordChangeNotice})> login({
    required String email,
    required String password,
  }) async {
    final res = await _client.dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    await _saveTokensFromResponse(res);
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return (
        passwordChangeRecommended:
            data['password_change_recommended'] == true,
        passwordChangeNotice: data['password_change_notice'] as String?,
      );
    }
    return (passwordChangeRecommended: false, passwordChangeNotice: null);
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
    await AuthSessionStorage().clear();
  }

  Future<void> requestPasswordReset(String email) async {
    await _client.dio.post(
      '/auth/password/reset/start',
      data: {'email': email},
    );
  }

  Future<void> deleteAccount({required String password}) async {
    await _client.dio.delete(
      '/users/me',
      data: {'password': password},
    );
    await logout();
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
    await logout();
  }

  Future<void> _saveTokensFromResponse(Response<dynamic> res) async {
    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: res.requestOptions,
        message: 'Invalid auth response',
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
}
