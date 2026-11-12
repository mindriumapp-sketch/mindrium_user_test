import 'package:dio/dio.dart';
import '../counseling/counseling_patterns.dart';
import 'api_client.dart';

class CounselingPatternsApi {
  final ApiClient client;
  CounselingPatternsApi(this.client);

  Future<CounselingPatterns> fetch() async {
    final result = await client.dio
        .get(
          '/counseling/patterns',
          options: Options(
            receiveTimeout: const Duration(seconds: 5),
            sendTimeout: const Duration(seconds: 5),
          ),
        )
        .timeout(const Duration(seconds: 5));
    final data = result.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid counseling patterns response');
    }
    return CounselingPatterns.fromJson(data);
  }
}
