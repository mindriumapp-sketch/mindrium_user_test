import 'counseling_models.dart';
import 'previous_session.dart';
import 'user_thought_extractor.dart';

/// 검색된 사용자 기록을 상담 맥락으로 재구성한 중간 표현.
///
/// `MindriumCounselingContext` 는 "관련 있어 보이는 항목 목록"이고, 이것은
/// "이번 상담에서 쓸 수 있는 사실"이다. 원문 여러 개를 그대로 내려보내는 대신
/// 필드로 쪼개 두면 planner 가 필요한 것만 골라 문장을 만들 수 있고,
/// 모델에 넘길 때도 기록 원문을 통째로 읊을 위험이 줄어든다.
///
/// **없는 것은 null 이다.** 빈 값을 그럴듯한 문장으로 채우지 않는다.
/// 각 필드가 어떤 기록에서 나왔는지는 [provenanceIds] 로 추적한다.
class RetrievalSummary {
  /// 지금 이야기하는 주제. 걱정 그룹 이름이나 반복 표현에서 온다.
  final String? currentTheme;

  /// 이번 발화에 드러난 핵심 생각.
  final String? currentThought;

  /// 과거 기록에 있는 비슷한 생각. [currentThought] 와 같으면 담지 않는다.
  final String? similarPastThought;

  /// 사용자가 전에 스스로 찾은 대안적 생각.
  final String? previousAlternativeThought;

  final int? recentSud;

  /// 'increasing' | 'decreasing' | 'stable'
  final String? sudTrend;

  /// 전후 SUD 가 낮아진 것이 확인된 활동.
  final EffectiveIntervention? previouslyHelpfulActivity;

  /// 불안이 높았는데 대안적 생각이 남지 않은 기록.
  final String? unfinishedIssue;

  /// 위 필드를 만드는 데 실제로 사용한 기록 id.
  final List<String> provenanceIds;

  /// 지난 상담에서 찾았던 대안적 생각. 이번 주제와 관련될 때만 채운다.
  final String? previousSessionAlternativeThought;

  /// 지난 상담에서 다루던 핵심 생각. 이번 주제와 관련될 때만 채운다.
  final String? previousSessionThought;

  const RetrievalSummary({
    this.currentTheme,
    this.currentThought,
    this.similarPastThought,
    this.previousAlternativeThought,
    this.recentSud,
    this.sudTrend,
    this.previouslyHelpfulActivity,
    this.unfinishedIssue,
    this.provenanceIds = const [],
    this.previousSessionAlternativeThought,
    this.previousSessionThought,
  });

  static const RetrievalSummary empty = RetrievalSummary();

  /// 과거 기록을 언급할 근거가 하나라도 있는지.
  ///
  /// "지난번에도" 같은 표현은 이 값이 true 일 때만 쓸 수 있다.
  bool get hasPastReference =>
      similarPastThought != null ||
      previousAlternativeThought != null ||
      previouslyHelpfulActivity != null ||
      previousSessionThought != null;

  /// 지난 상담을 언급할 근거가 있는지.
  ///
  /// "지난번 상담에서" 같은 표현은 이 값이 참일 때만 쓸 수 있다.
  bool get hasPreviousSessionReference =>
      previousSessionThought != null ||
      previousSessionAlternativeThought != null;

  bool get isEmpty =>
      currentTheme == null &&
      currentThought == null &&
      !hasPastReference &&
      recentSud == null &&
      unfinishedIssue == null;
}

/// 검색 결과를 [RetrievalSummary] 로 압축한다. LLM 을 쓰지 않는다.
class RetrievalSummaryBuilder {
  /// 미해결 과제로 볼 SUD 하한.
  final int unfinishedSudThreshold;

  const RetrievalSummaryBuilder({this.unfinishedSudThreshold = 7});

  /// 거의 모든 상담 발화에 등장하는 감정어. 이것 하나만 겹친다는 이유로
  /// 지난 세션을 같은 주제로 보면, 발표 걱정과 건강 걱정처럼 전혀 다른
  /// 주제도 "걱정"/"불안"이 겹친다는 이유만으로 계속 이어진다고 오인한다.
  /// `MindriumContextBuilder._genericRelevanceKeywords` 와 같은 목록이다.
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

  RetrievalSummary build({
    required String userMessage,
    MindriumCounselingContext? context,
    List<CounselingMessage> recentMessages = const [],
    PreviousSession? previousSession,
    String? carriedUnfinishedIssue,
  }) {
    final used = <String>{};

    final currentThought = _currentThought(userMessage, recentMessages);

    // 지난 상담은 **이번 주제와 관련될 때만** 꺼낸다. 지난 세션이 발표 불안이었고
    // 이번에 인간관계를 이야기하는데 "지난번 발표 이야기를 했었죠"를 꺼내면 안 된다.
    final relevantPrevious = _relevantPreviousSession(
      previousSession,
      userMessage: userMessage,
      currentThought: currentThought,
      context: context,
    );

    if (context == null) {
      return RetrievalSummary(
        currentThought: currentThought,
        previousSessionThought: relevantPrevious?.coreThought,
        previousSessionAlternativeThought: relevantPrevious?.alternativeThought,
        unfinishedIssue: carriedUnfinishedIssue,
        provenanceIds:
            relevantPrevious == null
                ? const []
                : ['session:${relevantPrevious.sessionId}'],
      );
    }

    final diaries =
        context.relevantItems
            .where((item) => item.type == UserContextType.diary)
            .toList();
    final alternatives =
        context.relevantItems
            .where((item) => item.type == UserContextType.alternativeThought)
            .toList();

    // 생각을 추출하지 못했더라도, 사용자가 방금 한 말과 같은 기록을 "과거"로
    // 되돌려주면 안 되므로 발화 원문까지 비교 대상에 넣는다.
    final similarPast = _similarPastThought(
      diaries,
      currentThought ?? userMessage.trim(),
      used,
    );
    final previousAlternative = _previousAlternative(alternatives, used);
    final helpful = UserThoughtExtractor.firstEffective(context);
    if (helpful != null) used.add(helpful.id);

    final unfinished =
        _unfinishedIssue(diaries, alternatives, used) ?? carriedUnfinishedIssue;

    if (relevantPrevious != null) {
      used.add('session:${relevantPrevious.sessionId}');
    }

    return RetrievalSummary(
      currentTheme: _currentTheme(
        diaries,
        context.recurringThemes,
        currentThought: currentThought,
        userMessage: userMessage,
      ),
      currentThought: currentThought,
      similarPastThought: similarPast,
      previousAlternativeThought: previousAlternative,
      recentSud: context.recentSud?.latest,
      sudTrend: context.recentSud?.trend,
      previouslyHelpfulActivity: helpful,
      unfinishedIssue: unfinished,
      previousSessionThought: relevantPrevious?.coreThought,
      previousSessionAlternativeThought: relevantPrevious?.alternativeThought,
      // 순서를 고정해야 같은 입력에 같은 provenance 가 나온다.
      provenanceIds: used.toList()..sort(),
    );
  }

  /// 이번 주제와 관련 있는 지난 세션만 돌려준다.
  ///
  /// 판단 근거는 세 가지다. 하나라도 맞으면 관련 있다고 본다.
  ///   1. 지난 주제(mainConcern)가 이번 발화나 걱정 그룹과 겹친다
  ///   2. 지난 핵심 생각이 이번 발화와 표현을 공유한다
  ///   3. 이번에 고른 일기가 지난 세션에서도 근거로 쓰였다
  PreviousSession? _relevantPreviousSession(
    PreviousSession? session, {
    required String userMessage,
    String? currentThought,
    MindriumCounselingContext? context,
  }) {
    if (session == null) return null;

    final current = _keywords('${currentThought ?? ''} $userMessage');
    if (current.isEmpty) return null;

    // 구체적인 주제어가 있으면 그것만으로 겹침을 판단한다. 감정어뿐인 짧은
    // 발화("걱정돼요")에서는 기존처럼 전체 키워드로 물러선다.
    final topicKeywords =
        current.where((k) => !_genericRelevanceKeywords.contains(k)).toSet();
    final effective = topicKeywords.isEmpty ? current : topicKeywords;

    bool overlaps(String? text) {
      if (text == null || text.trim().isEmpty) return false;
      final other = _keywords(text);
      return effective.any(other.contains);
    }

    if (overlaps(session.mainConcern)) return session;
    if (overlaps(session.coreThought)) return session;

    // 이번에 고른 기록이 지난 세션의 근거와 겹치면 같은 주제로 본다.
    final currentIds =
        context?.relevantItems.map((item) => item.id).toSet() ?? const {};
    if (session.provenanceIds.any(currentIds.contains)) return session;

    return null;
  }

  /// 이번 발화 → 최근 발화 순으로 평가 형태의 생각을 찾는다.
  String? _currentThought(
    String userMessage,
    List<CounselingMessage> recentMessages,
  ) {
    final explicit = UserThoughtExtractor.evaluativeThought(userMessage);
    if (explicit != null) return explicit;

    for (final message in recentMessages.reversed) {
      if (!message.isUser) continue;
      final thought = UserThoughtExtractor.evaluativeThought(message.text);
      if (thought != null) return thought;
    }
    return null;
  }

  /// 걱정 그룹 이름을 우선 쓰고, 없으면 반복 표현을 쓴다.
  /// 지금 이야기 중인 주제를 나타낼 걱정 그룹 이름.
  ///
  /// [diaries] 는 세션 시작 시 한 번 고른 후보 목록이라 **이번 발화와 무관한
  /// 순서**로 올 수 있다. 목록의 첫 항목을 그냥 쓰면, 사용자가 인간관계를
  /// 이야기하는데 후보 1번이 우연히 "학업" 그룹이라는 이유만으로 세션 요약에
  /// "학업"이 찍히는 문제가 생긴다. 그래서 이번 발화·현재 생각과 표현을 공유하는
  /// 일기의 그룹만 후보로 삼는다. 관련 있는 일기가 없으면 주제를 만들어내지
  /// 않고 null 을 돌려준다.
  String? _currentTheme(
    List<UserContextItem> diaries,
    List<String> recurringThemes, {
    String? currentThought,
    required String userMessage,
  }) {
    final current = _keywords('${currentThought ?? ''} $userMessage');
    if (current.isEmpty) return null;

    for (final diary in diaries) {
      if (!_keywords(diary.text).any(current.contains)) continue;
      final group = UserThoughtExtractor.groupFromItem(diary.text);
      if (group != null) return group;
    }

    // 반복 표현도 diaries 전체(관련 없는 것 포함)에서 뽑힌 것이라 같은 문제가
    // 있다. 이번 발화와 겹치는 것만 쓴다.
    for (final theme in recurringThemes) {
      if (current.contains(theme)) return theme;
    }
    return null;
  }

  /// 지금 한 말과 다른, 과거 기록의 생각 하나.
  String? _similarPastThought(
    List<UserContextItem> diaries,
    String? currentUtterance,
    Set<String> used,
  ) {
    for (final diary in diaries) {
      final thought = UserThoughtExtractor.thoughtFromDiary(diary.text);
      if (thought == null) continue;
      // 지금 한 말을 "예전에도 그러셨죠"로 되돌려주면 안 된다.
      if (currentUtterance != null && _sameThought(thought, currentUtterance)) {
        continue;
      }
      used.add(diary.id);
      return thought;
    }
    return null;
  }

  String? _previousAlternative(
    List<UserContextItem> alternatives,
    Set<String> used,
  ) {
    for (final item in alternatives) {
      final text = item.text.replaceFirst(
        RegExp(r'^\s*이전에 찾은 도움이 되는 생각:\s*'),
        '',
      );
      final first = text.split('/').first.trim();
      if (first.isEmpty) continue;
      used.add(item.id);
      return first;
    }
    return null;
  }

  /// 불안이 높았는데 대안적 생각이 남지 않은 기록.
  ///
  /// 같은 일기에서 나온 `alt:` 항목이 있으면 이미 다룬 것으로 본다.
  String? _unfinishedIssue(
    List<UserContextItem> diaries,
    List<UserContextItem> alternatives,
    Set<String> used,
  ) {
    final resolved =
        alternatives.map((item) => item.id.replaceFirst('alt:', '')).toSet();

    for (final diary in diaries) {
      final sud = diary.sud;
      if (sud == null || sud < unfinishedSudThreshold) continue;
      if (resolved.contains(diary.id.replaceFirst('diary:', ''))) continue;

      final thought = UserThoughtExtractor.thoughtFromDiary(diary.text);
      if (thought == null) continue;
      used.add(diary.id);
      return thought;
    }
    return null;
  }

  /// 표현이 조금 달라도 같은 생각이면 중복으로 본다.
  /// 한국어는 조사가 붙어 어절이 그대로 겹치지 않는다.
  /// 어절과 앞 2글자를 함께 봐서 표현 차이를 흡수한다.
  /// LocalCbtKnowledgeRepository / MindriumContextBuilder 와 같은 방식이다.
  Set<String> _keywords(String text) {
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
    return keywords;
  }

  bool _sameThought(String a, String b) {
    String normalize(String value) =>
        value.replaceAll(RegExp(r'[\s.,!?"‘’“”]'), '');
    final left = normalize(a);
    final right = normalize(b);
    return left == right || left.contains(right) || right.contains(left);
  }
}
