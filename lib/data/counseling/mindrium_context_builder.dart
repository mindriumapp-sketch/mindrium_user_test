import 'package:flutter/foundation.dart';

import '../api/diaries_api.dart';
import '../api/relaxation_api.dart';
import '../api/worry_groups_api.dart';
import 'counseling_models.dart';

/// 서버 API 를 감싸 컨텍스트 빌더가 필요한 것만 노출한다.
///
/// 테스트에서 가짜 구현을 넣기 위해 인터페이스로 둔다. 각 메서드는 서버 응답을
/// 그대로(Map) 돌려주고, 정규화는 빌더가 한다.
abstract class MindriumDataSource {
  Future<List<Map<String, dynamic>>> listDiarySummaries();

  Future<List<Map<String, dynamic>>> listWorryGroups();

  Future<List<Map<String, dynamic>>> listRelaxationTasks();
}

/// 실제 API 를 쓰는 구현.
class ApiMindriumDataSource implements MindriumDataSource {
  final DiariesApi diariesApi;
  final WorryGroupsApi worryGroupsApi;
  final RelaxationApi relaxationApi;

  const ApiMindriumDataSource({
    required this.diariesApi,
    required this.worryGroupsApi,
    required this.relaxationApi,
  });

  @override
  Future<List<Map<String, dynamic>>> listDiarySummaries() =>
      diariesApi.listDiarySummaries();

  @override
  Future<List<Map<String, dynamic>>> listWorryGroups() =>
      worryGroupsApi.listWorryGroups();

  @override
  Future<List<Map<String, dynamic>>> listRelaxationTasks() =>
      relaxationApi.listRelaxationTasks();
}

/// 사용자 기록에서 **LLM 에 줄 수 있는 최소 컨텍스트**를 만든다.
///
/// raw 응답을 그대로 합치는 객체가 아니다. 세 가지를 한다.
///   1. 선택 — 관련 있는 소수만 고른다(규칙 기반, 임베딩 없음)
///   2. 정규화 — 한 줄 텍스트 + id 로 줄인다
///   3. 위생 — 좌표·주소처럼 상담에 필요 없는 값은 프롬프트로 내보내지 않는다
class MindriumContextBuilder {
  final MindriumDataSource dataSource;

  // 서버 원본은 화면 수명 동안 한 번만 읽는다. build()를 현재 발화마다 다시
  // 호출하더라도 아래 snapshot에서 관련 항목만 재선별하므로 네트워크 요청은
  // 반복되지 않는다.
  List<Map<String, dynamic>>? _diarySnapshot;
  List<Map<String, dynamic>>? _groupSnapshot;
  List<Map<String, dynamic>>? _relaxationSnapshot;

  /// 한 턴에 제공할 사용자 데이터 항목 수 상한.
  static const int maxItems = 5;

  /// 후보로 훑을 최근 일기 수.
  static const int diaryScanLimit = 30;

  /// 반복 주제로 인정할 최소 등장 횟수.
  static const int recurringThemeMinCount = 2;

  // 선택 점수 가중치. 임베딩 대신 이 규칙으로 시작한다.
  static const int _scoreRecentDiary = 3;
  static const int _scoreSameWorryGroup = 3;
  static const int _scoreKeywordOverlap = 2;
  static const int _scoreHighSud = 2;

  /// 높은 불안으로 보는 SUD 하한.
  static const int highSudThreshold = 7;

  MindriumContextBuilder({required this.dataSource});

  /// 서버에 새 일기/훈련 기록이 생긴 뒤 다음 build에서 다시 조회하게 한다.
  void invalidateSnapshot() {
    _diarySnapshot = null;
    _groupSnapshot = null;
    _relaxationSnapshot = null;
  }

  /// 세션 시작 시 한 번 호출한다. 턴마다 다시 부르지 않는다.
  ///
  /// 서버 조회가 실패해도 예외를 던지지 않는다. 상담은 컨텍스트 없이도 이어져야 한다.
  Future<MindriumCounselingContext> build({
    required int currentWeek,
    String? userMessage,
    String? focusGroupId,
  }) async {
    List<Map<String, dynamic>> diaries = const [];
    List<Map<String, dynamic>> groups = const [];
    List<Map<String, dynamic>> relaxations = const [];
    var degraded = false;

    // 하나가 실패해도 나머지는 쓴다.
    Future<List<Map<String, dynamic>>> safely(
      Future<List<Map<String, dynamic>>> Function() load,
      String label,
    ) async {
      try {
        return await load();
      } on Object catch (e) {
        debugPrint('[MindriumContextBuilder] $label 조회 실패: $e');
        degraded = true;
        return const [];
      }
    }

    diaries =
        _diarySnapshot ??= await safely(
          dataSource.listDiarySummaries,
          'diaries',
        );
    groups =
        _groupSnapshot ??= await safely(
          dataSource.listWorryGroups,
          'worry_groups',
        );
    relaxations =
        _relaxationSnapshot ??= await safely(
          dataSource.listRelaxationTasks,
          'relaxation',
        );

    final groupTitles = {
      for (final group in groups)
        if (group['group_id'] != null)
          group['group_id'].toString(): (group['group_title'] ?? '').toString(),
    };

    final candidates = _diaryItems(diaries, groupTitles);
    final keywords = _keywords(userMessage ?? '');

    final selected = _select(
      candidates,
      keywords: keywords,
      focusGroupId: focusGroupId,
    );

    return MindriumCounselingContext(
      currentWeek: currentWeek,
      relevantItems: selected,
      recentSud: _sudContext(candidates),
      recurringThemes: _recurringThemes(candidates),
      effectiveInterventions: _interventions(relaxations),
      degraded: degraded,
    );
  }

  /// 일기 요약을 컨텍스트 항목으로 정규화한다.
  ///
  /// 위치·좌표는 담지 않는다. 상담에 필요 없고, 프롬프트로 내보낼 이유도 없다.
  List<UserContextItem> _diaryItems(
    List<Map<String, dynamic>> diaries,
    Map<String, String> groupTitles,
  ) {
    final sorted = [...diaries]..sort((a, b) {
      final at = _parseDate(a['created_at']);
      final bt = _parseDate(b['created_at']);
      if (at == null || bt == null) return 0;
      return bt.compareTo(at);
    });

    final items = <UserContextItem>[];
    for (final diary in sorted.take(diaryScanLimit)) {
      final id = diary['diary_id']?.toString();
      if (id == null || id.isEmpty) continue;

      final situation = _chipLabel(diary['activation']);
      final thoughts = _chipLabels(diary['belief']);
      final emotions = _chipLabels(diary['consequence_emotion']);
      final behaviors = _chipLabels(diary['consequence_action']);

      if (situation.isEmpty && thoughts.isEmpty) continue;

      final parts = <String>[
        if (situation.isNotEmpty) '상황: $situation',
        if (thoughts.isNotEmpty) '생각: ${thoughts.join(', ')}',
        if (emotions.isNotEmpty) '감정: ${emotions.join(', ')}',
        if (behaviors.isNotEmpty) '행동: ${behaviors.join(', ')}',
      ];

      final groupId = diary['group_id']?.toString();
      final groupTitle = groupId == null ? null : groupTitles[groupId];

      items.add(
        UserContextItem(
          id: 'diary:$id',
          type: UserContextType.diary,
          text: [
            if (groupTitle != null && groupTitle.isNotEmpty) '[$groupTitle]',
            parts.join(' / '),
          ].join(' '),
          occurredAt: _parseDate(diary['created_at']),
          groupId: groupId,
          sud: _asInt(diary['latest_sud']),
        ),
      );

      // 대안적 생각은 별도 항목으로 둔다. 개입 이력이라 참조 근거가 다르다.
      final alternatives =
          (diary['alternative_thoughts'] as List?)
              ?.whereType<String>()
              .where((t) => t.trim().isNotEmpty)
              .toList();
      if (alternatives != null && alternatives.isNotEmpty) {
        items.add(
          UserContextItem(
            id: 'alt:$id',
            type: UserContextType.alternativeThought,
            text: '이전에 찾은 도움이 되는 생각: ${alternatives.join(' / ')}',
            occurredAt: _parseDate(diary['created_at']),
            groupId: groupId,
          ),
        );
      }
    }

    return items;
  }

  /// 규칙 기반 선택. 임베딩은 Step 5 에서 이 함수만 교체한다.
  List<UserContextItem> _select(
    List<UserContextItem> candidates, {
    required List<String> keywords,
    String? focusGroupId,
  }) {
    if (candidates.isEmpty) return const [];

    final now = DateTime.now();
    final scored = <(UserContextItem, int)>[];
    final relevanceKeywords =
        keywords
            .where((keyword) => !_genericRelevanceKeywords.contains(keyword))
            .toList();

    bool textMatches(String text) {
      final active = relevanceKeywords.isEmpty ? keywords : relevanceKeywords;
      return active.any(text.contains);
    }

    // 대안적 생각 자체에는 상황명이 없을 수 있다. 관련성이 확인된 원본 일기와
    // 같은 ID인 경우에만 함께 제공한다.
    final relevantDiaryIds = <String>{};
    for (final item in candidates) {
      if (item.type != UserContextType.diary) continue;
      final matchesFocus = focusGroupId != null && item.groupId == focusGroupId;
      if (matchesFocus || textMatches(item.text.toLowerCase())) {
        relevantDiaryIds.add(item.id.replaceFirst('diary:', ''));
      }
    }

    for (var i = 0; i < candidates.length; i++) {
      final item = candidates[i];
      var score = 0;

      final text = item.text.toLowerCase();
      final matchesKeyword = keywords.any(text.contains);
      final matchesTopic = textMatches(text);
      final matchesFocus = focusGroupId != null && item.groupId == focusGroupId;
      final matchesLinkedDiary =
          item.type == UserContextType.alternativeThought &&
          relevantDiaryIds.contains(item.id.replaceFirst('alt:', ''));

      // 현재 발화가 있는 턴에는 **주제 관련성**이 admission gate다.
      // 최근 기록이거나 SUD가 높다는 이유만으로 발표 일기가 인간관계 대화에
      // 들어오면 이후 planner가 그것을 현재 생각처럼 반영하게 된다.
      if (keywords.isNotEmpty &&
          !matchesTopic &&
          !matchesFocus &&
          !matchesLinkedDiary) {
        continue;
      }

      // 최근성: 2주 이내면 가산.
      final occurredAt = item.occurredAt;
      if (occurredAt != null && now.difference(occurredAt).inDays <= 14) {
        score += _scoreRecentDiary;
      }

      if (matchesFocus) {
        score += _scoreSameWorryGroup;
      }

      if (matchesKeyword) score += _scoreKeywordOverlap;

      final sud = item.sud;
      if (sud != null && sud >= highSudThreshold) score += _scoreHighSud;

      if (score > 0) scored.add((item, score));
    }

    // 점수가 같으면 원래 순서(최신순)를 지킨다. 같은 입력에 같은 결과가 나와야 한다.
    final indexOf = {
      for (var i = 0; i < candidates.length; i++) candidates[i].id: i,
    };
    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      if (byScore != 0) return byScore;
      return indexOf[a.$1.id]!.compareTo(indexOf[b.$1.id]!);
    });

    return scored.take(maxItems).map((e) => e.$1).toList();
  }

  /// 이것 하나가 겹친다는 이유만으로 같은 생활 주제라고 볼 수 없는 표현.
  /// 다른 주제어가 없는 짧은 검색("걱정")에서는 기존 검색 동작을 유지한다.
  static const Set<String> _genericRelevanceKeywords = {
    '걱정',
    '걱',
    '불안',
    '답하지',
    '답하',
    '답',
    '생각',
    '생',
    '느낌',
    '느',
    '마음',
    '마',
    '힘들',
    '힘',
    '속상',
    '속',
  };

  /// SUD 추이를 일기의 latest_sud 로 계산한다.
  ///
  /// 서버의 주차별 통계 엔드포인트(getWeeklySudStats)는 현재 sud_api.dart 에서
  /// 주석 처리되어 있어 쓰지 않는다. 이미 가져온 일기만으로 추이를 낸다.
  SudContext? _sudContext(List<UserContextItem> items) {
    // 최신순으로 들어온 일기에서 SUD 가 있는 것만 추린다.
    final scores =
        items
            .where((item) => item.type == UserContextType.diary)
            .map((item) => item.sud)
            .whereType<int>()
            .toList();

    if (scores.isEmpty) return null;

    final average = scores.reduce((a, b) => a + b) / scores.length;

    // 최근 절반과 이전 절반의 평균을 비교한다. 표본이 적으면 stable 로 둔다.
    var trend = 'stable';
    if (scores.length >= 4) {
      final half = scores.length ~/ 2;
      final recent = scores.take(half).reduce((a, b) => a + b) / half;
      final older =
          scores.skip(half).reduce((a, b) => a + b) / (scores.length - half);
      final delta = recent - older;
      // 0.5 미만 변화는 흔들림으로 보고 stable 로 둔다.
      if (delta >= 0.5) trend = 'increasing';
      if (delta <= -0.5) trend = 'decreasing';
    }

    return SudContext(
      latest: scores.first,
      weeklyAverage: double.parse(average.toStringAsFixed(1)),
      trend: trend,
    );
  }

  /// 여러 기록에 반복해서 나오는 생각/감정 표현을 뽑는다.
  List<String> _recurringThemes(List<UserContextItem> items) {
    final counts = <String, int>{};
    for (final item in items) {
      if (item.type != UserContextType.diary) continue;
      for (final token in _keywords(item.text)) {
        counts[token] = (counts[token] ?? 0) + 1;
      }
    }

    final themes =
        counts.entries.where((e) => e.value >= recurringThemeMinCount).toList()
          ..sort((a, b) {
            final byCount = b.value.compareTo(a.value);
            return byCount != 0 ? byCount : a.key.compareTo(b.key);
          });

    return themes.take(5).map((e) => e.key).toList();
  }

  List<EffectiveIntervention> _interventions(
    List<Map<String, dynamic>> relaxations,
  ) {
    final result = <EffectiveIntervention>[];
    for (final task in relaxations) {
      final id =
          (task['task_log_id'] ?? task['id'] ?? task['task_id'])?.toString();
      if (id == null || id.isEmpty) continue;

      final intervention = EffectiveIntervention(
        id: 'relax:$id',
        type: 'relaxation',
        label: (task['task_id'] ?? '이완 훈련').toString(),
        preSud: _asInt(task['before_sud'] ?? task['pre_sud']),
        postSud: _asInt(task['after_sud'] ?? task['post_sud']),
      );

      // 효과가 확인된 것만 남긴다. 모델이 "지난번에 도움이 되었던" 이라고 말할 근거가 된다.
      if (intervention.improved) result.add(intervention);
    }

    result.sort((a, b) => a.id.compareTo(b.id));
    return result.take(3).toList();
  }

  // ───── 파싱 도우미 ─────

  String _chipLabel(Object? chip) {
    if (chip is Map && chip['label'] != null) {
      return chip['label'].toString().trim();
    }
    return '';
  }

  List<String> _chipLabels(Object? chips) {
    if (chips is! List) return const [];
    return chips.map(_chipLabel).where((label) => label.isNotEmpty).toList();
  }

  DateTime? _parseDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// 한국어 조사를 고려해 어절과 앞 2글자를 함께 본다.
  /// LocalCbtKnowledgeRepository 와 같은 방식이라 두 검색의 동작이 어긋나지 않는다.
  List<String> _keywords(String text) {
    final tokens =
        text
            .toLowerCase()
            .split(RegExp(r'[^0-9a-z가-힣]+'))
            .where((t) => t.length >= 2)
            .toSet();

    final keywords = <String>{};
    for (final token in tokens) {
      keywords.add(token);
      if (token.length >= 3) keywords.add(token.substring(0, 2));
    }
    return keywords.toList();
  }
}
