// Phase 14.2A-4: 의미 분류기 그림자 관찰.
//
// 분류 결과는 기록만 하고 상담 결정에는 절대 쓰지 않는다. 이 파일의 어떤
// 값도 CounselingSessionState, 메시지, 정책 입력에 들어가지 않는다.
// 원문은 기록하지 않는다(라벨, 일치 여부, 지연, 실패 사유만).
// docs/counseling/phase14_2a_results.md 4절, phase14_dialogue_moves.md 11절.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:gad_app_team/data/api/counseling_classify_api.dart';

const _contentTypes = {
  'situation', 'worry_thought', 'meaningful_answer', 'low_information',
  'emotion_expression', 'meta_interaction', 'app_guide', 'mixed',
};
const _signals = {
  'none', 'repeated_question', 'stop_questioning', 'assistant_not_understood',
  'process_resistance', 'closing_accept', 'closing_continue',
};
const _openContents = {'none', 'elaboration', 'new_worry', 'new_evidence'};

/// 모델이 낸 라벨. 형식이 하나라도 어긋나면 만들지 않는다.
class ModelUserAct {
  final String contentType;
  final String interactionSignal;
  final String openContent;

  const ModelUserAct(this.contentType, this.interactionSignal, this.openContent);

  /// 백엔드 응답의 `labels`. 모르는 값이 있으면 null(대체 사유: invalid_labels).
  static ModelUserAct? tryParse(Object? labels) {
    if (labels is! Map) return null;
    final c = labels['content_type'], s = labels['interaction_signal'], o = labels['open_content'];
    if (!_contentTypes.contains(c) || !_signals.contains(s) || !_openContents.contains(o)) {
      return null;
    }
    return ModelUserAct(c as String, s as String, o as String);
  }
}

/// 라벨별 결정론 guard를 거친 그림자 신호. 후보 3개 신호만 값을 가진다.
class GuardedSignals {
  /// 챗봇의 말을 이해 못함. guard를 통과했을 때만 true.
  final bool assistantNotUnderstood;

  /// 질문 중단 요청(14.2B). guard를 통과했을 때만 true.
  final bool stopQuestioning;

  /// 열린 내용 후보: 'new_worry' | 'new_evidence' | null.
  final String? openContent;

  /// 모델 신호를 버린 이유(통과했으면 빈 목록).
  final List<String> guardReasons;

  const GuardedSignals({
    required this.assistantNotUnderstood,
    this.stopQuestioning = false,
    required this.openContent,
    required this.guardReasons,
  });
}

/// 라벨별 guard. 메타 신호 guard와 내용 신호 guard는 서로 다르다.
class ShadowGuards {
  const ShadowGuards._();

  // 제3자 주어: 남이 한 말이나 남에 대한 걱정이지 챗봇에 대한 말이 아니다.
  static final RegExp _thirdParty = RegExp(
    r'(교수|(?<![가-힣])형|선생|선배|후배|친구|팀장|부장|과장|차장|대리|상사|사장|면접관|엄마|아빠|부모|동료|사람들|걔|쟤|그\s*사람|남친|여친|남자\s*친구|여자\s*친구|강사|손님|고객|의사|동생|언니|오빠|누나)(님)?\s*(이|가|께서|은|는|도|한테|이랑|랑)',
  );

  // 앱 사용법 혼동: 챗봇의 말이 아니라 앱 기능을 모른다. 14.2B: 위치·진입
  // 질문("어디서 다시 해?", "어떻게 들어가")도 앱 안내다(frozen_v1 진단).
  static final RegExp _appUsage = RegExp(
    r'(앱|어플|기능|메뉴|화면|버튼|설정|알림|일기|리포트|보관함|이완|기록\s*(보|어디|찾)|어디서|어딨|어디\s*있|어디에|어떻게\s*들어가)',
  );

  /// 메타 신호 guard: `assistant_not_understood`, `stop_questioning`. 제3자의
  /// 말이나 앱 사용법이면 챗봇에 대한 말이 아니다.
  static List<String> metaVetoes(String userText) => [
    if (_thirdParty.hasMatch(userText)) 'third_party',
    if (_appUsage.hasMatch(userText)) 'app_usage',
  ];

  /// 내용 신호 guard: `new_worry` / `new_evidence`. 걱정 내용인 것이 정상이므로
  /// 걱정 판정으로 막지 않는다. 상담 영역(상담 또는 혼합)이 아니면 버린다.
  static List<String> openContentVetoes(ModelUserAct act) => [
    if (act.contentType == 'app_guide') 'app_guide_domain',
    if (act.contentType == 'meta_interaction') 'no_content',
    if (act.contentType == 'low_information') 'no_content',
  ];

  static GuardedSignals apply(ModelUserAct act, String userText) {
    final reasons = <String>[];
    var notUnderstood = false;
    var stop = false;
    if (act.interactionSignal == 'assistant_not_understood') {
      final v = metaVetoes(userText);
      reasons.addAll(v.map((r) => 'not_understood:$r'));
      notUnderstood = v.isEmpty;
    }
    if (act.interactionSignal == 'stop_questioning') {
      final v = metaVetoes(userText);
      reasons.addAll(v.map((r) => 'stop:$r'));
      stop = v.isEmpty;
    }
    String? open;
    if (act.openContent == 'new_worry' || act.openContent == 'new_evidence') {
      final v = openContentVetoes(act);
      reasons.addAll(v.map((r) => '${act.openContent}:$r'));
      if (v.isEmpty) open = act.openContent;
    }
    return GuardedSignals(
      assistantNotUnderstood: notUnderstood,
      stopQuestioning: stop,
      openContent: open,
      guardReasons: reasons,
    );
  }
}

/// 그림자 관찰 한 건. 원문 필드가 없다.
class ShadowPerceptionEvent {
  final String sessionHash;
  final int turnIndex;
  final String ruleSignal;
  final ModelUserAct? modelRaw;
  final GuardedSignals? guarded;
  final int? latencyMs;
  final String? fallbackReason;

  /// 14.2B: 이 분류 결과를 정책 입력 후보로 썼는지(false면 그림자).
  final bool causal;

  /// 14.2B 인과 모드 기록. 분류기 상태: success | timeout | http_error |
  /// schema_reject | skipped. 시간 초과는 모델이 none이라고 한 것과 다르다.
  final String? classifierStatus;

  /// 실제로 정책에 들어간 복구 신호(규칙 OR guard 통과 모델). 없으면 null.
  final String? effectiveSignal;

  /// 미리 만든(투기적) 응답이 원격 표현을 요청했는지, 최종 응답에 쓰였는지,
  /// 버렸다면 그 이유(causal_repair_override).
  final bool? remoteRequested;
  final bool? remoteUsed;
  final String? discardReason;

  const ShadowPerceptionEvent({
    required this.sessionHash,
    required this.turnIndex,
    required this.ruleSignal,
    this.modelRaw,
    this.guarded,
    this.latencyMs,
    this.fallbackReason,
    this.causal = false,
    this.classifierStatus,
    this.effectiveSignal,
    this.remoteRequested,
    this.remoteUsed,
    this.discardReason,
  });

  String? get _guardedSignal => guarded == null
      ? null
      : guarded!.assistantNotUnderstood
      ? 'assistant_not_understood'
      : 'none';

  Map<String, Object?> toLogEntry() => {
    'session': sessionHash,
    'turn': turnIndex,
    'rule_signal': ruleSignal,
    'model_raw_signal': modelRaw?.interactionSignal,
    'model_raw_content': modelRaw?.contentType,
    'model_raw_open': modelRaw?.openContent,
    'model_guarded_not_understood': guarded?.assistantNotUnderstood,
    'model_guarded_stop': guarded?.stopQuestioning,
    'causal': causal,
    'model_guarded_open': guarded?.openContent,
    'guard_reasons': guarded?.guardReasons,
    'agree_rule_raw': modelRaw == null ? null : modelRaw!.interactionSignal == ruleSignal,
    'agree_rule_guarded_not_understood': guarded == null
        ? null
        : (_guardedSignal == 'assistant_not_understood') ==
            (ruleSignal == 'assistant_not_understood'),
    'latency_ms': latencyMs,
    'fallback_reason': fallbackReason,
    if (causal) ...{
      'classifier_status': classifierStatus,
      'effective_signal': effectiveSignal,
      'used_causally': effectiveSignal != null && ruleSignal == 'none',
      'remote_requested': remoteRequested,
      'remote_used': remoteUsed,
      'discard_reason': discardReason,
    },
  };
}

typedef ShadowPerceptionSink = void Function(ShadowPerceptionEvent event);

const String shadowPerceptionLogName = 'mindrium.counseling.shadow_perception';

/// 기기 로그에 한 줄로 남긴다(`adb logcat | grep SHADOW_PERCEPTION`). 원문이 없는
/// 라벨·지연 기록뿐이다. 분석: tools/classifier_eval/analyze_shadow.py.
void logShadowPerceptionLocally(ShadowPerceptionEvent event) {
  final line = jsonEncode(event.toLogEntry());
  developer.log(line, name: shadowPerceptionLogName);
  debugPrint('SHADOW_PERCEPTION $line');
}

/// 세션 id를 기록용 가명으로 바꾼다(FNV-1a 32비트). 되돌릴 수 없다.
String pseudonymize(String sessionId) {
  var h = 0x811c9dc5;
  for (final unit in utf8.encode(sessionId)) {
    h ^= unit;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

/// 매 사용자 턴마다 분류를 요청하고 결과를 기록한다. 실패해도 예외를 밖으로
/// 내지 않는다.
///
/// - [observe]: 그림자. 호출하는 쪽은 기다리지 않고(unawaited), 결과를 어디에도
///   쓰지 않는다.
/// - [classifyOnly]: 14.2B. 분류 결과와 상태만 돌려준다. 정책 반영과 기록은 호출하는
///   쪽(CounselingProvider)이 커밋 지점에서 한다.
class ShadowPerception {
  final CounselingClassifyApi api;
  final ShadowPerceptionSink sink;
  final Duration timeout;

  const ShadowPerception({
    required this.api,
    this.sink = logShadowPerceptionLocally,
    this.timeout = const Duration(seconds: 6),
  });

  Future<void> observe({
    required String sessionId,
    required int turnIndex,
    required String userText,
    required String? assistantPrev,
    required String ruleSignal,
  }) async {
    final o = await classifyOnly(
      sessionId: sessionId,
      turnIndex: turnIndex,
      userText: userText,
      assistantPrev: assistantPrev,
    );
    emit(ShadowPerceptionEvent(
      sessionHash: pseudonymize(sessionId),
      turnIndex: turnIndex,
      ruleSignal: ruleSignal,
      modelRaw: o.raw,
      guarded: o.guarded,
      latencyMs: o.latencyMs,
      fallbackReason: o.status == 'success' ? null : o.status,
    ));
  }

  /// 분류만 한다(기록하지 않음). 실패해도 예외를 내지 않고 상태로 돌려준다.
  Future<PerceptionOutcome> classifyOnly({
    required String sessionId,
    required int turnIndex,
    required String userText,
    required String? assistantPrev,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final res = await api
          .classify(
            requestId: '${pseudonymize(sessionId)}_$turnIndex',
            userText: userText,
            assistantPrev: assistantPrev,
            timeout: timeout,
          )
          .timeout(timeout);
      final act = ModelUserAct.tryParse(res['labels']);
      if (act == null) {
        return PerceptionOutcome(status: 'schema_reject', latencyMs: sw.elapsedMilliseconds);
      }
      return PerceptionOutcome(
        status: 'success',
        latencyMs: sw.elapsedMilliseconds,
        raw: act,
        guarded: ShadowGuards.apply(act, userText),
      );
    } on TimeoutException {
      return PerceptionOutcome(status: 'timeout', latencyMs: sw.elapsedMilliseconds);
    } on Object {
      return PerceptionOutcome(status: 'http_error', latencyMs: sw.elapsedMilliseconds);
    }
  }

  void emit(ShadowPerceptionEvent event) {
    try {
      sink(event);
    } on Object {
      // 기록 실패도 상담에 영향을 주지 않는다.
    }
  }
}

/// 한 번의 분류 결과.
class PerceptionOutcome {
  /// success | timeout | http_error | schema_reject
  final String status;
  final int latencyMs;
  final ModelUserAct? raw;
  final GuardedSignals? guarded;

  const PerceptionOutcome({required this.status, required this.latencyMs, this.raw, this.guarded});

  /// 정책에 쓸 신호. 우선순위: 질문 중단 > 챗봇 말을 못 알아들음.
  SemanticRepairSignal? get signal => guarded == null
      ? null
      : guarded!.stopQuestioning
      ? SemanticRepairSignal.stopQuestioning
      : guarded!.assistantNotUnderstood
      ? SemanticRepairSignal.assistantNotUnderstood
      : null;
}

/// 14.2B에서 정책 입력으로 쓰는 두 신호.
enum SemanticRepairSignal { stopQuestioning, assistantNotUnderstood }
