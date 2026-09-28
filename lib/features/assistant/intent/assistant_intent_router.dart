import '../app_guide/app_guide_repository.dart';
import '../assistant_intent.dart';

/// 사용자 발화가 상담/앱 안내 중 무엇을 필요로 하는지 판정한다.
///
/// **핵심 원칙(Phase 7)**: 이 판정은 [AppGuideKnowledgeResult.hasMatch]와
/// 완전히 분리되어야 한다. "영상 통화 상담 어디서 해?"는 실제 KB에 없는
/// 기능이라도(hasMatch=false) 분명 앱 사용법을 묻는 질문이므로
/// `needsAppGuidance=true`여야 한다. Intent는 "무엇을 원하는가"만 답하고,
/// "답할 근거가 있는가"는 이후 retriever 단계의 책임이다.
abstract interface class AssistantIntentRouter {
  /// [counselingInProgress]: the user is already mid-session. Then only an
  /// explicit usage question ("어디서 봐?", "어떻게 바꿔?") routes to the app
  /// guide; a word that merely overlaps a feature name does not.
  AssistantIntent detect(String userMessage, {bool counselingInProgress = false});
}

/// Phase 7 production 구현. GPT/외부 API를 쓰지 않는 규칙 기반 분류다.
///
/// App Guide 신호는 두 경로를 모두 본다:
/// 1. Catalog에 실제로 있는 기능/화면/매뉴얼 이름·alias와의 키워드 overlap
///    (KB 어휘를 재사용 — 중복 vocabulary를 만들지 않는다).
/// 2. "어디서/어떻게 하나" 같은 사용법-질문 패턴. KB에 없는 기능을 물어도
///    이 패턴만으로 appGuide 의도를 잡아낼 수 있어야 한다(위 핵심 원칙).
///
/// 상담 신호는 감정/걱정 어휘 어간을 본다. 다만 "걱정 기록"처럼 안내성
/// 명사(기록/보관함/설정 등)를 바로 뒤에 동반하는 경우는 감정 표현이
/// 아니라 기능 이름의 일부로 보고 상담 신호에서 제외한다("지난 걱정
/// 기록은 어디서 봐?" → counseling=false, appGuide=true).
///
/// 두 신호 모두 없으면 상담으로 fallback한다 — 지금까지 이 시스템은
/// 모든 발화를 상담 대화의 일부로 다뤄 왔으므로, 애매한 문장을 아무도
/// 처리하지 않는 상태로 두는 것보다 안전하다.
class DeterministicAssistantIntentRouter implements AssistantIntentRouter {
  final AppGuideRepository? repository;

  const DeterministicAssistantIntentRouter({this.repository});

  static const List<String> _counselingStems = [
    '불안',
    '걱정',
    '무섭',
    '두렵',
    '힘들',
    '긴장',
    '초조',
    '불편',
    '답답',
  ];

  /// 위 어간 뒤에 곧바로 이 단어들이 오면 감정 표현이 아니라 기능 이름의
  /// 일부로 본다(예: "걱정 기록", "불안 완화 알림 설정").
  static const List<String> _guideNounsAfterStem = [
    '기록',
    '보관함',
    '보관',
    '설정',
    '메뉴',
    '화면',
    '기능',
    '위젯',
    '알림',
    '평가',
  ];

  static final List<RegExp> _appGuideUsagePatterns = [
    RegExp(r'어디(서|에)?\s*(있|봐|보나|확인|찾|들어가|하|해|할)'),
    RegExp(r'어떻게\s*(바꿔|바꾸|추가|설정|들어가|써|사용|찾|보나|봐|확인|여는|열어|하나|해)'),
    RegExp(r'(설정|메뉴|위젯|알림|리포트|보관함|기록)\s*(은|는|을|를)?\s*(어떻게|어디)'),
    RegExp(r'사용법'),
    RegExp(r'mindrium', caseSensitive: false),
  ];

  bool _hasCounselingSignal(String text) {
    for (final stem in _counselingStems) {
      var searchFrom = 0;
      while (true) {
        final idx = text.indexOf(stem, searchFrom);
        if (idx == -1) break;
        final afterStart = idx + stem.length;
        final after = text
            .substring(afterStart, (afterStart + 4).clamp(0, text.length))
            .trimLeft();
        final followedByGuideNoun = _guideNounsAfterStem.any(
          after.startsWith,
        );
        if (!followedByGuideNoun) return true;
        searchFrom = idx + stem.length;
      }
    }
    return false;
  }

  bool _hasUsagePatternSignal(String text) =>
      _appGuideUsagePatterns.any((pattern) => pattern.hasMatch(text));

  bool _hasEntitySignal(String text) {
    final repo = repository;
    if (repo == null) return false;

    final queryWords = _keywords(text);
    if (queryWords.isEmpty) return false;

    bool overlapsAny(Iterable<String> names) => names.any(
      (name) => _keywords(name).any(queryWords.contains),
    );

    return repo.features.any(
          (f) => overlapsAny([f.name, ...f.aliases]),
        ) ||
        repo.screens.any((s) => overlapsAny([s.displayName])) ||
        repo.manualEntries.any((m) => overlapsAny([m.title]));
  }

  Set<String> _keywords(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^0-9a-z가-힣]+'))
      .where((word) => word.length >= 2)
      .toSet();

  @override
  AssistantIntent detect(String userMessage, {bool counselingInProgress = false}) {
    final needsCounseling = _hasCounselingSignal(userMessage);
    // Phase 12.3 (N4): mid-session, entity overlap alone is too weak. Device
    // dogfood sent "…논문 작성… 할게 진짜 많아" to the app guide because
    // "작성" matched a feature name, cutting the counseling turn short.
    final usageQuestion = _hasUsagePatternSignal(userMessage);
    final needsAppGuidance = counselingInProgress
        ? usageQuestion
        : usageQuestion || _hasEntitySignal(userMessage);

    if (!needsCounseling && !needsAppGuidance) {
      // Fallback 정책: 상담/앱 안내 신호가 모두 없는 애매한 발화는 상담
      // 대화의 일부로 본다(지금까지의 유일한 production 경로와 동일).
      return AssistantIntent.counselingOnly;
    }

    return AssistantIntent(
      needsCounseling: needsCounseling,
      needsAppGuidance: needsAppGuidance,
    );
  }
}
