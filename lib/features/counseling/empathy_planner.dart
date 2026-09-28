import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';

import 'surface_variation.dart';

/// 직전 턴 대비 정서 변화. 아직 근거가 없으면 [unknown] 이다.
enum AffectChange { unknown, improved, steady, worsened }

/// 즉시 공감 문장 한 개와 그 근거.
class EmpathyPlan {
  final String sentence;

  /// 과거 기록을 실제로 언급했는지.
  final bool referencedPast;

  /// 문장을 만드는 데 사용한 기록 id.
  final List<String> provenanceIds;

  const EmpathyPlan({
    required this.sentence,
    this.referencedPast = false,
    this.provenanceIds = const [],
  });
}

/// 사용자 발화와 검색 요약으로 공감 문장을 만든다. LLM 을 쓰지 않는다.
///
/// 모델이 답을 만드는 동안 먼저 보여주는 문장이라 즉시성이 가장 중요하다.
/// 동시에 **근거 없는 과거 언급을 하지 않는 것**이 안전상 더 중요하다.
/// "지난번에도" 같은 표현은 [RetrievalSummary.hasPastReference] 가 참일 때만 쓴다.
class EmpathyPlanner {
  final DeterministicSurfaceVariation surfaceVariation;

  const EmpathyPlanner({
    this.surfaceVariation = const DeterministicSurfaceVariation(),
  });

  EmpathyPlan plan({
    required String userMessage,
    RetrievalSummary summary = RetrievalSummary.empty,
    AffectChange change = AffectChange.unknown,
    List<CounselingMessage> recentMessages = const [],
  }) {
    final continuityRequested = _requestsContinuity(userMessage);

    // 1. 나아지고 있다는 근거가 있으면 그것을 먼저 알아준다.
    final improving =
        _mentionsImprovement(userMessage) || change == AffectChange.improved
            ? _improvingPlan(summary, change)
            : null;
    if (improving != null) return improving;

    // 2. 지난 상담과 이어지는 주제면 그 연속성을 먼저 알아준다.
    //    일기 한 건보다 "지난 상담에서 함께 본 것"이 이어짐을 더 잘 드러낸다.
    final continued =
        continuityRequested ? _previousSessionPlan(summary) : null;
    if (continued != null) return continued;

    // 3. 과거에 비슷한 걱정을 기록해 둔 경우에만 이어서 말한다.
    final personalized =
        continuityRequested ? _personalizedPlan(summary) : null;
    if (personalized != null) return personalized;

    // 4. 근거가 없으면 현재 발화만 보고 일반 공감으로 물러선다.
    return EmpathyPlan(
      sentence: _generalEmpathy(userMessage, recentMessages: recentMessages),
    );
  }

  /// 불안이 낮아졌고 도움이 된 활동이 확인된 경우.
  EmpathyPlan? _improvingPlan(RetrievalSummary summary, AffectChange change) {
    final helpful = summary.previouslyHelpfulActivity;
    final decreasing = summary.sudTrend == 'decreasing';
    if (!decreasing && change != AffectChange.improved) return null;
    if (helpful == null) return null;

    return EmpathyPlan(
      sentence:
          '지난번에는 ${helpful.label} 뒤에 불안이 조금 가라앉았었죠. '
          '지금은 어떤 상태인지 같이 살펴볼게요.',
      referencedPast: true,
      provenanceIds: [helpful.id],
    );
  }

  /// 지난 상담과 이번 걱정을 잇는다.
  ///
  /// [RetrievalSummary] 가 이번 주제와 관련 있다고 판단한 세션만 여기 들어온다.
  /// 관련 없는 세션을 꺼내면 "지난번 발표 이야기를 했었죠" 같은 엉뚱한 말이 된다.
  ///
  /// **질문을 넣지 않는다.** 공감 뒤에 planner 가 질문 하나를 붙이므로,
  /// 여기서 물으면 한 턴에 질문이 둘이 된다.
  EmpathyPlan? _previousSessionPlan(RetrievalSummary summary) {
    if (!summary.hasPreviousSessionReference) return null;

    final ids =
        summary.provenanceIds.where((id) => id.startsWith('session:')).toList();

    // 지난번에 찾은 대안적 생각이 있으면 그것을 먼저 상기시킨다.
    final alternative = summary.previousSessionAlternativeThought;
    if (alternative != null && alternative.trim().isNotEmpty) {
      return EmpathyPlan(
        sentence:
            '지난 상담에서 “${_trim(alternative)}”는 생각을 함께 찾으셨었죠. '
            '오늘도 비슷한 부분이 마음에 걸리시는 것 같아요.',
        referencedPast: true,
        provenanceIds: ids,
      );
    }

    final thought = summary.previousSessionThought;
    if (thought == null || thought.trim().isEmpty) return null;

    return EmpathyPlan(
      sentence:
          '지난 상담에서도 “${_trim(thought)}”는 생각을 함께 살펴봤었죠. '
          '오늘도 비슷한 걱정이 이어지고 있는 것 같아요.',
      referencedPast: true,
      provenanceIds: ids,
    );
  }

  /// 과거 기록과 지금 걱정을 잇는다.
  ///
  /// 주제·과거 생각·현재 생각이 모두 있어야 한다. 하나라도 없으면 "지난번에도"가
  /// 근거 없는 말이 되므로 만들지 않는다.
  EmpathyPlan? _personalizedPlan(RetrievalSummary summary) {
    if (!summary.hasPastReference) return null;

    final theme = summary.currentTheme;
    final past = summary.similarPastThought;
    final current = summary.currentThought;
    if (theme == null || past == null || current == null) return null;

    return EmpathyPlan(
      sentence:
          '지난번에도 $theme 상황에서 비슷한 걱정을 적으셨는데, '
          '이번에는 특히 “${_trim(current)}”는 생각이 더 크게 느껴지는 것 같아요.',
      referencedPast: true,
      provenanceIds: summary.provenanceIds,
    );
  }

  /// 현재 발화만 보고 만드는 공감. 과거를 언급하지 않는다.
  String _generalEmpathy(
    String message, {
    List<CounselingMessage> recentMessages = const [],
  }) {
    final text = message.toLowerCase();

    final score = RegExp(r'(?<!\d)(10|[0-9])\s*(?:정도|점)?').firstMatch(text);
    if (score != null) {
      final value = int.tryParse(score.group(1)!);
      if (value != null && value >= 7) return '지금 불안이 꽤 크게 느껴지고 있군요.';
      if (value != null && value >= 4) return '마음의 불편함이 분명히 느껴지고 있군요.';
      return '지금 느끼는 정도를 알려주셔서 고마워요.';
    }
    if (text.contains('무서') || text.contains('두려')) {
      return '그 상황이 많이 두렵게 느껴지시는군요.';
    }
    if (text.contains('불안') || text.contains('걱정')) {
      return surfaceVariation.select(
        candidates: const [
          '그 일 때문에 마음이 불안하고 신경 쓰이시는군요.',
          '그 일이 계속 마음에 걸려 편하지 않으셨겠어요.',
          '걱정이 커지면 마음을 놓기 어려워지지요.',
        ],
        recentMessages: recentMessages,
        seed: message,
      );
    }
    if (text.contains('힘들') || text.contains('지치') || text.contains('피곤')) {
      return '그동안 많이 버티느라 마음도 몸도 지치셨겠어요.';
    }
    if (text.contains('슬프') || text.contains('우울') || text.contains('속상')) {
      return '그 일을 겪으며 마음이 많이 무거우셨겠어요.';
    }
    if (text.contains('화나') || text.contains('짜증') || text.contains('억울')) {
      return '그 상황에서 답답하고 속상한 마음이 드셨겠어요.';
    }
    if (text.contains('외롭') || text.contains('혼자')) {
      return '혼자 감당하는 것처럼 느껴져 많이 외로우셨겠어요.';
    }
    return '말씀하신 일이 마음에 계속 걸리고 계시는군요.';
  }

  String _trim(String value) =>
      value.trim().replaceFirst(RegExp(r'[.!?]+$'), '');

  bool _requestsContinuity(String message) {
    final text = message.replaceAll(RegExp(r'\s+'), '');
    return const [
      '지난번',
      '저번',
      '전에',
      '이어서',
      '또',
      '다시',
      '여전히',
      '계속',
    ].any(text.contains);
  }

  bool _mentionsImprovement(String message) {
    final text = message.replaceAll(RegExp(r'\s+'), '');
    return const [
      '나아졌',
      '나아진',
      '좋아졌',
      '괜찮아졌',
      '덜불안',
      '조금괜찮',
      '아까보다',
    ].any(text.contains);
  }
}
