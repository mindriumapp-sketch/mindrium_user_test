import 'dart:convert';

import 'package:flutter/services.dart';

import 'cbt_knowledge_repository.dart';
import 'counseling_models.dart';

/// 앱에 동봉된 assets/counseling/knowledge/ 코퍼스를 메모리에 올려 검색한다.
///
/// 임베딩을 쓰지 않는다. 코퍼스가 85개 항목 규모라 선형 스캔으로 충분하고,
/// Step 1 의 목적은 검색 품질이 아니라 harness contract 검증이다.
class LocalCbtKnowledgeRepository implements CbtKnowledgeRepository {
  static const String manifestPath =
      'assets/counseling/knowledge/manifest.json';
  static const String _assetDir = 'assets/counseling/knowledge';

  /// 자산 로더. 테스트에서 파일 시스템 로더를 주입할 수 있게 열어 둔다.
  final Future<String> Function(String path) _loadAsset;

  final Map<String, CbtKnowledgeItem> _byId = {};
  final Map<int, List<CbtKnowledgeItem>> _byWeek = {};
  final Map<String, String> _searchCache = {};
  bool _initialized = false;

  LocalCbtKnowledgeRepository({Future<String> Function(String path)? loadAsset})
    : _loadAsset = loadAsset ?? rootBundle.loadString;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    final manifest =
        jsonDecode(await _loadAsset(manifestPath)) as Map<String, dynamic>;
    final files = (manifest['files'] as List).cast<Map<String, dynamic>>();

    for (final entry in files) {
      final raw =
          jsonDecode(await _loadAsset('$_assetDir/${entry['file']}'))
              as Map<String, dynamic>;
      for (final json in (raw['items'] as List).cast<Map<String, dynamic>>()) {
        final item = CbtKnowledgeItem.fromJson(json);
        _byId[item.id] = item;
        _byWeek.putIfAbsent(item.week, () => []).add(item);
        _searchCache[item.id] = item.searchableText;
      }
    }

    _initialized = true;
  }

  @override
  List<CbtKnowledgeItem> getByWeek(int week) =>
      List.unmodifiable(_byWeek[week] ?? const []);

  @override
  CbtKnowledgeItem? getById(String id) => _byId[id];

  @override
  Set<String> get allIds => _byId.keys.toSet();

  @override
  List<CbtKnowledgeItem> search({
    required String query,
    int? week,
    Set<String>? tags,
    int limit = 5,
  }) {
    final keywords = _keywords(query);

    final scored = <(CbtKnowledgeItem, int)>[];
    for (final item in _byId.values) {
      // 주차가 지정되면 그 주차와 공통 지식(week 0)만 후보로 둔다.
      if (week != null && item.week != week && item.week != 0) continue;

      final score = _score(item, keywords, week: week, tags: tags);
      if (score > 0) scored.add((item, score));
    }

    // 점수가 같으면 id 순으로 고정한다. 같은 입력에 같은 결과가 나와야 테스트가 성립한다.
    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      return byScore != 0 ? byScore : a.$1.id.compareTo(b.$1.id);
    });

    return scored.take(limit).map((e) => e.$1).toList();
  }

  int _score(
    CbtKnowledgeItem item,
    List<String> keywords, {
    int? week,
    Set<String>? tags,
  }) {
    var score = 0;

    if (tags != null && tags.isNotEmpty) {
      final matched = item.tags.where(tags.contains).length;
      // 태그를 지정했는데 하나도 안 맞으면 관련 없는 항목으로 본다.
      if (matched == 0) return 0;
      score += matched * 4;
    }

    if (week != null && item.week == week) score += 2;

    final title = item.title.toLowerCase();
    final body = _searchCache[item.id] ?? '';
    for (final keyword in keywords) {
      if (title.contains(keyword)) score += 3;
      if (body.contains(keyword)) score += 1;
    }

    return score;
  }

  /// 한국어는 공백 분절만으로는 조사가 붙어 잘 맞지 않아, 어절과 그 접두어를 함께 본다.
  List<String> _keywords(String query) {
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'[^0-9a-z가-힣]+'))
        .where((t) => t.length >= 2)
        .toSet();

    final keywords = <String>{};
    for (final token in tokens) {
      keywords.add(token);
      // '불안한' → '불안' 처럼 조사/어미가 붙은 어절도 걸리도록 앞 2글자를 추가한다.
      if (token.length >= 3) keywords.add(token.substring(0, 2));
    }
    return keywords.toList();
  }
}
