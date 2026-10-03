/// 상담 harness 가 주고받는 값 객체들.
///
/// 여기에는 LLM 런타임(llama.cpp 등)이나 네트워크에 의존하는 타입을 두지 않는다.
/// Step 3 에서 실제 온디바이스 모델로 교체할 때 이 파일은 그대로 남아야 한다.
library;

import 'episode_history.dart';

/// 라벨이 붙은 임상 예시. 문단으로 펴면 라벨이 사라지므로 별도 타입으로 둔다.
class CbtExample {
  final String text;
  final String label;
  final String rationale;

  const CbtExample({
    required this.text,
    required this.label,
    required this.rationale,
  });

  factory CbtExample.fromJson(Map<String, dynamic> json) {
    return CbtExample(
      text: json['text'] as String,
      label: json['label'] as String,
      rationale: json['rationale'] as String,
    );
  }
}

/// assets/counseling/knowledge/week*.json 의 항목 하나.
class CbtKnowledgeItem {
  final String id;

  /// 0 은 특정 주차에 속하지 않는 프로그램 공통 지식.
  final int week;

  /// education | technique | example_bank | assessment
  final String type;
  final String title;
  final List<String> paragraphs;
  final List<String> tags;

  /// 원문 출처. 임상 검수용 내부 정보이며 프롬프트에는 넣지 않는다.
  final String source;
  final List<CbtExample> examples;

  /// 상담 중 이 내용을 단계별로 안내해도 되는지. false 면 실행 제안까지만 한다.
  final bool conversationalGuidanceAvailable;

  const CbtKnowledgeItem({
    required this.id,
    required this.week,
    required this.type,
    required this.title,
    required this.paragraphs,
    required this.tags,
    required this.source,
    this.examples = const [],
    this.conversationalGuidanceAvailable = true,
  });

  factory CbtKnowledgeItem.fromJson(Map<String, dynamic> json) {
    return CbtKnowledgeItem(
      id: json['id'] as String,
      week: json['week'] as int,
      type: json['type'] as String,
      title: json['title'] as String,
      paragraphs: List<String>.from(json['paragraphs'] as List),
      tags: List<String>.from(json['tags'] as List),
      source: json['source'] as String,
      examples: (json['examples'] as List?)
              ?.map((e) => CbtExample.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      conversationalGuidanceAvailable:
          json['conversational_guidance_available'] as bool? ?? true,
    );
  }

  /// 검색 대상이 되는 소문자 텍스트. 반복 검색을 대비해 한 번만 만든다.
  String get searchableText {
    final buffer = StringBuffer()
      ..write(title)
      ..write(' ')
      ..writeAll(paragraphs, ' ');
    for (final example in examples) {
      buffer
        ..write(' ')
        ..write(example.text)
        ..write(' ')
        ..write(example.rationale);
    }
    return buffer.toString().toLowerCase();
  }
}

/// 모델이 수행한 발화 행위. harness 가 허용 목록을 정하고 모델은 그 안에서 고른다.
enum DialogueAct {
  /// 사용자의 말을 되비추기
  reflect,

  /// 더 살펴보기 위한 개방형 질문
  explore,

  /// 소크라테스식 질문
  socraticQuestion,

  /// 지금까지의 내용을 정리
  summarize,

  /// CBT 개념/기법 설명
  psychoeducation,

  /// 마무리 인사
  closing,

  /// 파싱 실패 등으로 판별하지 못함
  unknown;

  static DialogueAct fromWire(String? value) {
    switch (value) {
      case 'reflect':
        return DialogueAct.reflect;
      case 'explore':
        return DialogueAct.explore;
      case 'socratic_question':
        return DialogueAct.socraticQuestion;
      case 'summarize':
        return DialogueAct.summarize;
      case 'psychoeducation':
        return DialogueAct.psychoeducation;
      case 'closing':
        return DialogueAct.closing;
      default:
        return DialogueAct.unknown;
    }
  }

  String get wireName {
    switch (this) {
      case DialogueAct.reflect:
        return 'reflect';
      case DialogueAct.explore:
        return 'explore';
      case DialogueAct.socraticQuestion:
        return 'socratic_question';
      case DialogueAct.summarize:
        return 'summarize';
      case DialogueAct.psychoeducation:
        return 'psychoeducation';
      case DialogueAct.closing:
        return 'closing';
      case DialogueAct.unknown:
        return 'unknown';
    }
  }
}

/// Phase 11.1/11.2: names *why* a turn is being redirected into
/// interaction-repair mode, instead of continuing ordinary worry-content
/// selection. Lives alongside [DialogueAct] (not in `features/counseling/
/// policy/`) for the same reason [DialogueAct] does: it needs to appear on
/// both [CounselingTurnPlan] (features layer) and [CounselingMessage]
/// (this file), so the data layer can't depend on features/ to define it.
/// See `docs/counseling/chatbot_system.md` (tag counseling-handover-v1).
enum InteractionRepairReason {
  /// "왜 똑같은 말을 반복하지?" / "아까도 물어봤잖아" — the complaint is
  /// specifically that the same thing keeps being asked. Distinct from
  /// [stopQuestioning]: the user isn't asking to stop, they're pointing
  /// out non-progress. Detected starting Phase 11.2
  /// (`DeterministicProcessSignalTurnPlanner`'s `_repeatsInteraction`).
  repeatedQuestion,

  /// "질문 그만해" / "그만 물어" / "그냥 얘기 좀 들어주세요". Detected
  /// since before Phase 11 via `_requestsEmpathy`.
  stopQuestioning,

  /// "뭐가 달라질까" / "소용 없어" / "의미 없어". Detected since before
  /// Phase 11 via `_showsProcessResistance`.
  processFrustration,

  /// Phase 13.8 (P1): "무슨 말이야" / "뭐라는거야" / "너가 무슨말 하는지
  /// 모르겠어" — the user didn't understand what the counselor said.
  /// Distinct from a low-information answer ("잘 모르겠어"), which is about
  /// the user's own worry, not the counselor's words.
  assistantNotUnderstood,
}

/// Phase 11.1/11.3: names the recovery actions available once every
/// `ReflectQuestionGoal` has been asked
/// (`ReflectDecisionSelector._selectGoalOrRecover`'s exhaustion case).
/// [summarize] and [listenWithoutQuestion] are implemented (Phase 11.3);
/// [revisitPreviousIssue] and [transition] are frozen contract members not
/// yet selectable — see each member's doc.
enum GoalExhaustionRecovery {
  /// Hand off to a closing-style summary of what's been covered, without
  /// asking anything new.
  summarize,

  /// The process-signal-style "no question this turn" response shape.
  listenWithoutQuestion,

  /// Not selectable yet (Phase 11.3 scope freeze): pulling a different
  /// topic into `reflectionTarget` instead of the exhausted one needs a
  /// same-session "other topics raised earlier this session" tracker that
  /// does not exist yet — see the design doc before implementing this.
  revisitPreviousIssue,

  /// Not selectable yet (Phase 11.3 scope freeze): ending reflect early
  /// and moving to intervention/closing is not this recovery's job —
  /// `CounselingStatePolicy`'s turn budget already advances state on its
  /// own schedule (confirmed in Phase 11.2), and a recovery selection must
  /// not bypass that authority.
  transition,

  /// Pre-Phase-11.3 legacy behavior (`ReflectDecisionSelector` used to
  /// silently fall through to `goalOrder.last` and keep asking it forever).
  /// Kept as an explicit enum member for that history, but no longer
  /// selected by anything — [summarize]/[listenWithoutQuestion] replaced
  /// it as of Phase 11.3.
  repeatLast,
}

/// Phase 13.3: what a planned turn contributes to finishing its stage.
/// Read by `CounselingStatePolicy`, which advances on completion instead of
/// a fixed turn count for stages that report it (reflect, intervention,
/// closing). `null` means "no stage signal"; checkIn/explore keep their
/// fixed budget, and repair turns don't count toward completion.
enum StageProgress {
  /// The stage's goal isn't met yet (e.g. the intervention question was just
  /// asked). Advance only at the stage's maximum turns.
  inProgress,

  /// The stage's goal is met (e.g. the user's answer was integrated). May
  /// advance once the stage's minimum turns are reached.
  complete,

  /// Closing only: the user wants to keep talking. One controlled return
  /// to reflect.
  reopen,

  /// Phase 13.8 (P4): the user can't engage right now (see [EarlyWrapUp]).
  /// The turn proposed wrapping up, so the session goes to closing from any
  /// stage.
  wrapUp,
}

/// Phase 13.3: where an intervention turn sits in ask → answer → integrate.
enum InterventionStep {
  /// The technique's question was asked. Not complete: the answer is pending.
  prompt,

  /// The user's answer to the prompt was acknowledged and integrated.
  integration,

  /// No approved technique fits (Phase 13.2). A normal wrap-up.
  noEligible,
}

/// Phase 13.5: the closing handshake.
enum ClosingStep {
  /// The session wrap-up was proposed; waiting for the user's answer.
  proposed,

  /// The user agreed (or the session had to end). The session is complete.
  finalized,

  /// The user wanted to keep talking. Used at most once per session.
  continued,
}

/// Phase 13.8 (P4): why a closing proposal came before any intervention
/// outcome. Asking the same kind of question again was what made the device
/// user angry in session 4, so after two such turns in a row the counselor
/// offers to wrap up instead.
enum EarlyWrapUp {
  /// Two low-information answers in a row ("잘 모르겠어", "모르겠어").
  lowInformation,

  /// Two "I don't understand you" turns in a row.
  notUnderstood,

  /// Phase 13.9C (S3): two clarify questions in a row got nothing to work
  /// with, whatever the user said — a net for non-answers the detector
  /// doesn't recognize.
  noProgress,
}

/// 모델 출력을 어떤 경로로 읽어냈는지. 실제 모델 벤치에서 평가 지표가 된다.
enum ParseStatus {
  /// 응답 전체가 그대로 JSON
  strict,

  /// 코드펜스/잡담을 걷어내고 JSON 객체를 추출
  extracted,

  /// JSON 을 못 찾아 평문으로 처리
  fallback,

  /// 출력이 비어 있음
  empty,
}

/// 파싱과 검증을 마친 모델 출력.
class CounselingModelOutput {
  final String reply;
  final DialogueAct dialogueAct;

  /// 모델이 근거로 든 CBT 지식 id. harness 가 실제 제공한 id 로 걸러진 뒤의 값.
  final List<String> referencedCbtIds;

  /// 모델이 참조했다고 밝힌 사용자 데이터 id. CBT 근거와 provenance 가 다르므로 분리한다.
  final List<String> referencedUserContextIds;
  final ParseStatus parseStatus;

  const CounselingModelOutput({
    required this.reply,
    required this.dialogueAct,
    required this.referencedCbtIds,
    required this.referencedUserContextIds,
    required this.parseStatus,
  });
}

/// 채팅 화면에 그려지는 메시지 한 줄.
class CounselingMessage {
  final String id;

  /// 'user' | 'assistant'
  final String role;
  final String text;
  final DateTime createdAt;

  /// assistant 메시지에만 채워지는 감사 로그용 정보.
  final DialogueAct? dialogueAct;
  final List<String> referencedCbtIds;
  final List<String> referencedUserContextIds;
  final ParseStatus? parseStatus;
  final Duration? latency;

  /// 이번 턴이 다룬 대화 목표의 안정적인 ID(예: reflect 단계의
  /// `ReflectQuestionGoal.name`). 문장 표현이 모델(GPT)마다 달라져도 "이미
  /// 물은 목표인가"를 텍스트가 아니라 이 ID로 추적하기 위한 필드다. 목표
  /// 개념이 없는 턴(예: explore, closing)에는 null이다.
  final String? dialogueGoalId;

  /// Phase 11.2: 이번 턴이 interaction-repair(반복 지적/질문 중단 요청/
  /// 과정 저항 인정)였다면 그 사유. 다음 턴 selector가 "직전 턴이 repair
  /// 였는가"를 텍스트가 아니라 이 값으로 판단할 수 있게 한다(Phase 11.3의
  /// goal exhaustion recovery가 이 신호를 쓸 가능성이 높다 — 아직은 아무
  /// selector도 읽지 않는다). 일반 상담 턴에는 null이다.
  final InteractionRepairReason? interactionRepairReason;

  /// Phase 11.3: 이번 턴이 reflect의 모든 `ReflectQuestionGoal`이 소진된
  /// 뒤의 recovery 턴이었다면 그 종류(summarize/listenWithoutQuestion 등).
  /// [ReflectDecisionSelector]가 다음 턴에서 "직전 턴이 recovery였는가"를
  /// 판단할 수 있게 한다 — [interactionRepairReason]과 같은 이유로 이
  /// 파일에 둔다. 일반 상담 턴/goal이 아직 남아있는 턴에는 null이다.
  final GoalExhaustionRecovery? goalExhaustionRecovery;

  /// Phase 13.3: this assistant turn's place in the intervention
  /// ask → answer → integrate sequence, if it was an intervention turn.
  final InterventionStep? interventionStep;

  /// Phase 13.5: this assistant turn's place in the closing handshake.
  final ClosingStep? closingStep;

  /// Phase 13.8 (P4): set when this turn proposed wrapping up early.
  final EarlyWrapUp? earlyWrapUp;

  /// Phase 13.9C (S3): this reflect turn asked a clarify question because no
  /// usable thought was found yet.
  final bool isClarify;

  /// Integration turns only: true when the answer earned the technique's
  /// outcome sentence, false when it was only acknowledged. Becomes the
  /// episode's `intervention_outcome`.
  final bool? interventionCredited;

  const CounselingMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.dialogueAct,
    this.referencedCbtIds = const [],
    this.referencedUserContextIds = const [],
    this.parseStatus,
    this.latency,
    this.dialogueGoalId,
    this.interactionRepairReason,
    this.goalExhaustionRecovery,
    this.interventionStep,
    this.closingStep,
    this.earlyWrapUp,
    this.isClarify = false,
    this.interventionCredited,
  });

  bool get isUser => role == 'user';
}

/// 사용자 데이터에서 뽑아온 컨텍스트 항목의 종류.
enum UserContextType {
  /// 걱정 일기 (ABC)
  diary,

  /// 대안적 생각
  alternativeThought,

  /// 걱정 그룹
  worryGroup,

  /// 이완 등 개입 기록
  intervention,
}

/// LLM 에 전달 가능한 사용자 데이터 한 조각.
///
/// 반드시 id 를 갖는다. 모델이 `referenced_user_context_ids` 로 돌려준 값이
/// 실제로 이번 턴에 제공한 항목인지 검증하는 근거가 된다.
class UserContextItem {
  /// `diary:68f0...` 처럼 타입 접두사가 붙은 식별자.
  final String id;
  final UserContextType type;

  /// 프롬프트에 넣을 한 줄 요약. 원본 전체가 아니다.
  final String text;
  final DateTime? occurredAt;

  /// 이 항목이 속한 걱정 그룹. 같은 그룹 항목을 묶을 때 쓴다.
  final String? groupId;

  /// 관련된 SUD 점수(있는 경우).
  final int? sud;

  const UserContextItem({
    required this.id,
    required this.type,
    required this.text,
    this.occurredAt,
    this.groupId,
    this.sud,
  });
}

/// 최근 SUD 추이.
class SudContext {
  final int? latest;
  final double? weeklyAverage;

  /// 'increasing' | 'decreasing' | 'stable'
  final String trend;

  const SudContext({this.latest, this.weeklyAverage, required this.trend});
}

/// 효과가 있었던 개입 기록.
class EffectiveIntervention {
  final String id;

  /// 'relaxation' 등 개입 종류.
  final String type;
  final String label;
  final int? preSud;
  final int? postSud;

  const EffectiveIntervention({
    required this.id,
    required this.type,
    required this.label,
    this.preSud,
    this.postSud,
  });

  /// 전후 SUD 가 모두 있고 낮아졌으면 효과가 있었다고 본다.
  bool get improved =>
      preSud != null && postSud != null && postSud! < preSud!;
}

/// 한 세션에 쓰는 사용자 컨텍스트 전체.
class MindriumCounselingContext {
  final int currentWeek;
  final List<UserContextItem> relevantItems;
  final SudContext? recentSud;

  /// 여러 기록에서 반복되는 표현.
  final List<String> recurringThemes;
  final List<EffectiveIntervention> effectiveInterventions;

  /// 컨텍스트를 만들 때 서버 조회가 실패했는지. 실패해도 상담은 이어간다.
  final bool degraded;

  /// 지난 상담 에피소드(개인화 결정 근거). 결정론 정책만 읽는다.
  final EpisodeHistory episodes;

  const MindriumCounselingContext({
    required this.currentWeek,
    this.relevantItems = const [],
    this.recentSud,
    this.recurringThemes = const [],
    this.effectiveInterventions = const [],
    this.degraded = false,
    this.episodes = EpisodeHistory.empty,
  });

  MindriumCounselingContext withEpisodes(EpisodeHistory history) =>
      MindriumCounselingContext(
        currentWeek: currentWeek,
        relevantItems: relevantItems,
        recentSud: recentSud,
        recurringThemes: recurringThemes,
        effectiveInterventions: effectiveInterventions,
        degraded: degraded,
        episodes: history,
      );

  static const MindriumCounselingContext empty = MindriumCounselingContext(
    currentWeek: 1,
  );

  /// 이번 턴에 모델에 제공한 사용자 데이터 id 전체.
  Set<String> get offeredIds => {
    ...relevantItems.map((item) => item.id),
    ...effectiveInterventions.map((item) => item.id),
  };

  bool get isEmpty =>
      relevantItems.isEmpty &&
      effectiveInterventions.isEmpty &&
      recentSud == null;
}
