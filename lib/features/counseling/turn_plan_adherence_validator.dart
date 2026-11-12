part of 'turn_plan.dart';

/// P2-L 출력이 Harness가 만든 핵심 의미와 hard constraint를 보존했는지 검사한다.
class TurnPlanAdherenceValidator {
  static final RegExp _advice = RegExp(r'(해보세요|하세요|도움이 될|권합니다|추천|연습해|준비해)');

  final bool requireDraftVerbatim;

  const TurnPlanAdherenceValidator({this.requireDraftVerbatim = true});

  bool isAdherent(String reply, CounselingTurnPlan plan) {
    final text = reply.trim();
    if (text.isEmpty) return false;
    final questionCount = '?'.allMatches(text).length;
    if (plan.constraints.contains(TurnConstraint.requireNoQuestion)) {
      if (questionCount != 0) return false;
    } else if (plan.constraints.contains(
      TurnConstraint.requireExactlyOneQuestion,
    )) {
      if (questionCount != 1) return false;
    }
    if (_advice.hasMatch(text)) return false;
    // 작은 모델의 의미 보존 여부를 추측하지 않는다. Harness가 확정한 두 문장이
    // 모두 그대로 남은 경우만 surface realization을 채택하고, 그 외에는 P2-D로
    // 물러난다. 특정 fixture 단어에 의존하지 않아 다른 reflect 계획에도 적용된다.
    if (requireDraftVerbatim) {
      if (!text.contains(plan.reflectionSentence)) return false;
      if (plan.questionSentence.isNotEmpty &&
          !text.contains(plan.questionSentence)) {
        return false;
      }
    }
    return true;
  }
}
