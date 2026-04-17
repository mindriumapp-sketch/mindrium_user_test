import 'package:dio/dio.dart';
import 'api_client.dart';

class WorryGroupsApi {
  final ApiClient _client;
  WorryGroupsApi(this._client);

  /// 모든 걱정 그룹 조회
  /// - includeArchived = true 이면 archived 포함
  Future<List<Map<String, dynamic>>> listWorryGroups({
    bool includeArchived = false,
  }) async {
    final res = await _client.dio.get(
      '/worry-groups',
      queryParameters: {if (includeArchived) 'include_archived': true},
    );

    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /worry-groups response',
    );
  }

  /// 특정 걱정 그룹 조회
  Future<Map<String, dynamic>> getWorryGroup(String groupId) async {
    final res = await _client.dio.get('/worry-groups/$groupId');
    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /worry-groups/{id} response',
    );
  }

  /// 새 걱정 그룹 생성
  ///
  /// ⚠️ group_id는 서버에서 생성하므로 여기서 안 보냄.
  /// - group_title: 필수
  /// - character_id: 필수 (1~20, 백엔드에서 검증)
  Future<Map<String, dynamic>> createWorryGroup({
    required String groupTitle,
    String groupContents = '',
    required int characterId,
  }) async {
    final base = <String, dynamic>{
      'group_title': groupTitle,
      'group_contents': groupContents,
      'character_id': characterId,
    };

    final res = await _client.dio.post('/worry-groups', data: base);
    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /worry-groups create response',
    );
  }

  /// 걱정 그룹 업데이트
  ///
  /// 백엔드 WorryGroupUpdate:
  Future<Map<String, dynamic>> updateWorryGroup(
    String groupId, {
    String? groupTitle,
    String? groupContents,
    int? characterId,
  }) async {
    final base = <String, dynamic>{
      if (groupTitle != null) 'group_title': groupTitle,
      if (groupContents != null) 'group_contents': groupContents,
      if (characterId != null) 'character_id': characterId,
    };

    // 아무것도 안 보내면 백엔드에서 400("수정할 필드가 없습니다")
    if (base.isEmpty) {
      throw ArgumentError('updateWorryGroup: 업데이트할 필드가 없습니다.');
    }

    final res = await _client.dio.put('/worry-groups/$groupId', data: base);
    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /worry-groups/{id} update response',
    );
  }

  /// 걱정 그룹 아카이브 (소프트 삭제)
  ///
  /// POST /worry-groups/{group_id}/archive
  Future<Map<String, dynamic>> archiveWorryGroup(String groupId) async {
    final res = await _client.dio.post('/worry-groups/$groupId/archive');

    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /worry-groups/{id}/archive response',
    );
  }

  /// 아카이브된 걱정 그룹 목록 조회
  Future<List<Map<String, dynamic>>> getArchivedGroups() async {
    final res = await _client.dio.get('/worry-groups/archived');
    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /worry-groups/archived response',
    );
  }

  /// 걱정 그룹 완전 삭제 (하드 삭제)
  ///
  /// DELETE /worry-groups/{group_id}
  Future<Map<String, dynamic>> deleteWorryGroup(String groupId) async {
    final res = await _client.dio.delete('/worry-groups/$groupId');

    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /worry-groups/{id} delete response',
    );
  }
}
