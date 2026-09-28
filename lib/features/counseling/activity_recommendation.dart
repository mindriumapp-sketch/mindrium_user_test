import 'package:gad_app_team/data/counseling/counseling_models.dart';

import 'intervention_registry.dart';

/// 상담 중 **추천**할 수 있는 앱 활동.
///
/// 화면 이동 명령이 아니다. 상담은 "이런 활동이 도움이 될 수 있다"고 알려줄 뿐이고,
/// 실제 수행 여부와 시점은 사용자가 앱에서 스스로 정한다. 상담 중 화면을 강제로
/// 전환하면 대화가 끊기고, 기존 주차 플로우를 전제로 만들어진 화면들이 상담
/// 경로에서 깨질 수 있다.
enum CounselingActivity {
  /// 걱정 일기(ABC) 작성
  abcDiary,

  /// 대안적 생각 찾기
  alternativeThought,

  /// 이완 활동
  relaxation,

  /// 불안 점수 기록
  sudRecord;

  /// 사용자에게 보여줄 활동 이름.
  String get label {
    switch (this) {
      case CounselingActivity.abcDiary:
        return '걱정 일기';
      case CounselingActivity.alternativeThought:
        return '대안적 생각 작성 활동';
      case CounselingActivity.relaxation:
        return '이완 활동';
      case CounselingActivity.sudRecord:
        return '불안 점수 기록';
    }
  }
}

/// 개입 한 건의 결과를 세 갈래로 나눈 것.
///
/// 상담 문장과 앱 활동을 섞어두면 "그 생각을 바꿔볼까요? 일기를 열어볼게요"처럼
/// 한 문장에 두 가지가 들어가 사용자가 무엇을 해야 할지 흐려진다.
class ActivityRecommendation {
  /// 승인된 CBT 원문에서 그대로 가져온 짧은 설명. 지어내지 않는다.
  final String? microcontent;

  /// [microcontent] 의 출처 id.
  final String? microcontentCbtId;

  /// 추천할 활동. 마땅한 활동이 없으면 null.
  final CounselingActivity? activity;

  /// 왜 이 활동을 추천했는지. 로그와 검수용이며 사용자 문구가 아니다.
  final String? rationale;

  const ActivityRecommendation({
    this.microcontent,
    this.microcontentCbtId,
    this.activity,
    this.rationale,
  });

  static const ActivityRecommendation none = ActivityRecommendation();

  bool get isEmpty => microcontent == null && activity == null;

  /// 이 추천을 만드는 데 사용한 승인 CBT 근거.
  List<String> get provenanceIds =>
      microcontentCbtId == null ? const [] : [microcontentCbtId!];

  /// 상담 메시지에 덧붙일 추천 문구. 활동이 없으면 null.
  ///
  /// 화면 이동을 지시하지 않고 "원하시면"으로 여지를 남긴다.
  String? get suggestionSentence {
    final target = activity;
    if (target == null) return null;
    return '원하시면 Mindrium의 ${target.label}에서 이어서 정리해보셔도 좋아요.';
  }
}

/// 승인된 개입을 앱 활동과 교육 문구로 잇는다.
///
/// **매핑이 분명한 것만 잇는다.** 화면이 없거나 대응이 애매한 개입은 활동 없이
/// 상담 문장만 남긴다. 억지로 다른 주차 화면을 붙이면 승인되지 않은 개입을
/// 실행시키는 것과 같다.
class ActivityRecommendationPolicy {
  /// 교육 문구로 쓸 최대 길이. 길면 상담 문장을 덮는다.
  static const int microcontentMaxLength = 80;

  const ActivityRecommendationPolicy();

  ActivityRecommendation recommend({
    required InterventionType type,
    CbtKnowledgeItem? source,
  }) {
    final activity = _activityFor(type);
    final microcontent = _microcontentFrom(source);

    if (activity == null && microcontent == null) {
      return ActivityRecommendation.none;
    }

    return ActivityRecommendation(
      microcontent: microcontent,
      microcontentCbtId: microcontent == null ? null : source!.id,
      activity: activity,
      rationale: activity == null ? null : '${type.name} 개입과 연결됨',
    );
  }

  CounselingActivity? _activityFor(InterventionType type) {
    switch (type) {
      case InterventionType.balancedThought:
        return CounselingActivity.alternativeThought;
      case InterventionType.behaviorPatternReview:
      case InterventionType.consequenceReview:
        // 행동과 결과는 걱정 일기에 기록한다.
        return CounselingActivity.abcDiary;
      case InterventionType.gainLossReview:
      case InterventionType.valueBasedChoice:
      case InterventionType.maintenanceReview:
        // 7~8주차 생활 습관/유지 계획은 단독 진입 화면이 없다.
        // 없는 화면을 억지로 붙이지 않는다.
        return null;
    }
  }

  /// 승인된 CBT 항목의 첫 문단을 한 문장까지만 쓴다.
  String? _microcontentFrom(CbtKnowledgeItem? source) {
    if (source == null || source.paragraphs.isEmpty) return null;

    final first = source.paragraphs.first.trim();
    if (first.isEmpty) return null;

    final sentenceEnd = RegExp(r'[.!?]').firstMatch(first);
    var sentence = sentenceEnd == null
        ? first
        : first.substring(0, sentenceEnd.end).trim();

    if (sentence.length > microcontentMaxLength) {
      sentence = '${sentence.substring(0, microcontentMaxLength).trimRight()}…';
    }
    return sentence;
  }
}
