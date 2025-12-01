import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/user_data_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

/// FastAPI 백엔드 기반 설문/진행도 조회 도우미
class UserDatabase {
  static final TokenStorage _tokens = TokenStorage();
  static ApiClient? _client;
  static UserDataApi? _userDataApi;

  static UserDataApi _api() {
    _client ??= ApiClient(tokens: _tokens);
    _userDataApi ??= UserDataApi(_client!);
    return _userDataApi!;
  }

  /// /users/me/progress 원본 전체 가져오기
  static Future<Map<String, dynamic>> getProgress() async {
    return await _api().getProgress();
  }

  /// 사전 설문 완료 여부 (survey_completed 플래그 사용)
  static Future<bool> hasCompletedSurvey() async {
    try {
      final progress = await _api().getProgress();
      return (progress['survey_completed'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 마지막으로 완료한 주차 (없으면 0)
  static Future<int> getLastCompletedWeek() async {
    try {
      final progress = await _api().getProgress();
      final raw = progress['last_completed_week'];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// 마지막 완료 시각 (ISO8601 → DateTime)
  static Future<DateTime?> getLastCompletedAt() async {
    try {
      final progress = await _api().getProgress();
      final raw = progress['last_completed_at'];
      if (raw is String) {
        return DateTime.tryParse(raw);
      }
      if (raw is DateTime) {
        return raw;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

