import 'previous_session.dart';

/// 지난 상담 에피소드에서 결정론으로 뽑은 개인화 근거.
///
/// 서버의 세션 요약([PreviousSession])을 그대로 읽어 계산한다. 모델 요약이 아니다.
/// 두 가지 결정에만 쓴다.
///
/// 1. 기법 순서: 이 사용자에게 성과로 인정된 적 있는 기법을 먼저, 써 봤지만
///    한 번도 인정되지 않은 기법은 뒤로. 승인 여부와 적용 조건은 바꾸지 않는다.
/// 2. 이전 대안 상기: 비슷한 걱정을 다룬 완료 에피소드에서 사용자가 직접 정리한
///    대안적 생각을 균형 사고 기법 앞에 떠올리게 한다.
class EpisodeHistory {
  /// 최신 순.
  final List<PreviousSession> episodes;

  const EpisodeHistory(this.episodes);

  static const EpisodeHistory empty = EpisodeHistory([]);

  bool get isEmpty => episodes.isEmpty;

  factory EpisodeHistory.fromSessions(List<PreviousSession> sessions) {
    final sorted = [...sessions]..sort((a, b) {
      final ae = a.endedAt, be = b.endedAt;
      if (ae == null && be == null) return 0;
      if (ae == null) return 1;
      if (be == null) return -1;
      return be.compareTo(ae);
    });
    return EpisodeHistory(sorted);
  }

  /// 성과로 인정된 적 있는 기법 id. 인정 횟수가 많은 순, 같으면 최근 순.
  List<String> get effectiveTechniqueIds {
    final counts = <String, int>{};
    final order = <String>[];
    for (final e in episodes) {
      final id = e.interventionUsed;
      if (id == null || e.interventionOutcome != 'credited') continue;
      if (!counts.containsKey(id)) order.add(id);
      counts[id] = (counts[id] ?? 0) + 1;
    }
    order.sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return order;
  }

  /// 써 봤지만 한 번도 성과로 인정되지 않은 기법 id.
  Set<String> get ineffectiveTechniqueIds {
    final effective = effectiveTechniqueIds.toSet();
    return {
      for (final e in episodes)
        if (e.interventionUsed != null &&
            e.interventionOutcome == 'acknowledged' &&
            !effective.contains(e.interventionUsed))
          e.interventionUsed!,
    };
  }

  /// [worry]와 주제가 겹치고, 사용자가 대안적 생각을 정리한 최근 완료 에피소드.
  PreviousSession? similarEpisodeWithAlternative(String worry) {
    final topics = topicKeys(worry);
    if (topics.isEmpty) return null;
    for (final e in episodes) {
      if (!e.isCompleted) continue;
      final alt = e.alternativeThought?.trim();
      if (alt == null || alt.isEmpty) continue;
      final past = {
        ...topicKeys(e.coreThought ?? ''),
        ...topicKeys(e.mainConcern ?? ''),
      };
      if (past.intersection(topics).isNotEmpty) return e;
    }
    return null;
  }

  // 걱정 문장에서 주제어를 거칠게 뽑는다: 두 글자 이상 어절의 앞 두 글자.
  // "발표하다가"/"발표가" → "발표". 감정·채움말·시간 표현은 주제가 아니다.
  static const Set<String> _notTopics = {
    '그냥', '너무', '진짜', '정말', '요즘', '오늘', '내일', '어제', '이번', '다음',
    '내가', '제가', '나는', '저는', '걱정', '불안', '무서', '무섭', '두려', '긴장',
    '생각', '어떡', '어떻', '같아', '같은', '것같', '하면', '해서', '하는', '했는',
    '못하', '못할', '있을', '없을', '아닐', '아닌', '정도', '조금', '많이', '계속',
  };

  static Set<String> topicKeys(String text) {
    return {
      for (final raw in text.split(RegExp(r'[\s.,!?~…]+')))
        if (raw.length >= 2 && RegExp(r'^[가-힣]').hasMatch(raw))
          if (!_notTopics.contains(raw.substring(0, 2))) raw.substring(0, 2),
    };
  }
}
