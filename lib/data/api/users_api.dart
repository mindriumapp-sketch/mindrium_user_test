import 'package:dio/dio.dart';
import 'api_client.dart';

class UsersApi {
  final ApiClient _client;

  UsersApi(this._client);

  Future<Map<String, dynamic>> me() async {
    final authClient = ApiClient.platformAuth(tokens: _client.tokens);
    final res = await authClient.dio.get('/api/me');
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid me response',
    );
  }
}
