// lib/services/agents.dart
import 'dart:convert';
import 'gpt_api.dart';
import 'daily_context.dart';

enum AgentRole { validator, corrector, summarizer, proceeder }

class Agents {
  Agents(this.api);
  final GptApi api;

  // =========================================================
  // 🗓️ 주차별 단계 프롬프트 (DailyContext.weekActivityMap과 연동)
  // =========================================================
  static const Map<int, Map<String, String>> weekStagePrompts = {
    1: {
      'define': '1주차는 디지털 치료기기 적응 및 자기관리 단계입니다. '
          '최근 루틴, 수면시간, 혹은 기기 사용 경험을 구체적으로 묻습니다.',
      'wrapup': '“시작이 어렵지만, 이미 첫걸음을 잘 내디뎠어요.”로 마무리하세요.'
    },
    2: {
      'define': '2주차는 걱정 일기(ABC 모델)를 중심으로 감정과 생각을 탐색하는 단계입니다. '
          '최근 일기에서 떠오른 감정(A-C)을 구체적으로 묻습니다.',
      'reframe': '기록된 생각(B)의 근거를 함께 살피며 “다른 시각에서 보면 어떨까요?”처럼 질문하세요.',
      'wrapup': '감정과 생각의 연결을 인식하도록 돕습니다.'
    },
    3: {
      'define': '3주차는 자동사고 탐색 단계입니다. 반복적으로 떠오른 생각이나 믿음을 구체적으로 물어보세요.',
      'reframe': '“그 생각이 꼭 사실일까요?”로 사고를 전환시킵니다.',
    },
    4: {
      'experiment': '4주차는 새로운 생각을 행동으로 옮겨보는 단계입니다. '
          '“그때 다르게 시도해본 행동이 있었나요?”를 사용하세요.',
      'wrapup': '변화의 순간을 인식하도록 피드백합니다.'
    },
    5: {
      'define': '5주차는 불안을 직면하는 단계입니다. 최근 회피했던 행동을 떠올리고 감정을 탐색하세요.',
      'experiment': '“작게라도 새로 해본 행동이 있었나요?”를 묻습니다.'
    },
    6: {
      'experiment': '6주차는 도전 행동 피드백 단계입니다. “최근 시도 중 가장 기억에 남는 경험이 있나요?”로 시작하세요.'
    },
    7: {
      'define': '7주차는 생활습관 루틴 점검 단계입니다. 수면, 운동, 명상 중 유지가 잘 된 부분을 묻습니다.',
      'wrapup': '꾸준히 노력 중임을 인정하며 지속 가능성을 강조합니다.'
    },
    8: {
      'define': '8주차는 회고 단계입니다. 지난 변화 중 가장 인상 깊은 순간을 이야기하게 하세요.',
      'wrapup': '자기이해와 성장 포인트를 요약하며 마무리합니다.'
    },
  };

  // =========================================================
  // 1️⃣ 인지 왜곡 검증 에이전트
  // =========================================================
  static const _validatorSystem = '''
당신은 CBT 기반 "입력 검증 상담사"입니다.
역할: 사용자의 발화에 인지왜곡이 포함되었는지 판별합니다.
판정 기준: 일반화, 극단화, 파국화, 개인화 등.
출력은 반드시 JSON만 사용하세요:
{
  "valid": true|false,
  "distortions": ["과도한 일반화","흑백논리"],
  "why": "간단 근거 (한국어)",
  "suggestion": "교정 유도를 위한 1~2개 질문 (한국어)"
}
''' ;

  // =========================================================
  // 2️⃣ 교정 상담사
  // =========================================================
  static const _correctorSystem = '''
당신은 CBT 기반 "교정 상담사"입니다.
역할: 인지왜곡 가능성이 있는 발화를 공감적으로 재구성하고,
사용자가 스스로 인식을 전환하도록 탐색 질문을 던집니다.
규칙:
- 첫 문장은 공감 (“그 상황이 정말 힘드셨을 것 같아요.”)
- 두 번째는 탐색 질문 (“그때 떠올랐던 생각의 근거를 함께 살펴볼까요?”)
- 3문장 이내, 판단·지시·충고 금지.
''' ;

  // =========================================================
  // 3️⃣ 탐색 상담사
  // =========================================================
//   static const _proceedSystem = '''
// 당신은 CBT 기반 "탐색 상담사"입니다.
// 대화는 단계적으로 진행됩니다:
// anchor → define → evidence → reframe → experiment → wrapup

// 원칙:
// - 각 단계에 맞게 1~2개의 질문만 던지세요.
// - 공감 1문장 + 탐색 질문 1~2문장 (총 3문장 이내)
// - 감정, 생각, 행동 중 균형 유지
// - define: 감정/신체반응 묻기
// - evidence: 사고 근거 탐색
// - reframe: 대안적 사고 제안
// - experiment: 실천 계획 제안
// - wrapup: 통찰 요약 + 다음 목표 제안
// - 인간적이고 따뜻한 어조 유지
// ''' ;

  // =========================================================
  // 4️⃣ 세션 요약 상담사
  // =========================================================
  static const _summarizerSystem = '''
당신은 오늘 세션을 요약하는 "상담 요약 상담사"입니다.
출력 형식(4줄 이내):
1) 상황/핵심걱정: (A)
2) 자동사고/감정(SUD): (B-C)
3) 오늘의 통찰/변화:
4) 다음 실천/활동:
짧고 명확하게.
''' ;

  // =========================================================
  // 5️⃣ 감정 판정기 (아바타 표정)
  // =========================================================
  static const _emotionSystem = '''
당신은 상담사의 표정을 결정하는 "감정 판정기"입니다.
출력은 반드시 JSON으로만:
{
  "emotion": "공감슬픔|난처조심|놀람|따뜻한미소|따뜻한공감|무표정|생각중|안심격려|안타까움",
  "confidence": 0.0,
  "why": "짧은 근거 (<=40자)"
}
''' ;

  // =========================================================
  // ✅ 에이전트 주요 기능
  // =========================================================

  /// 1️⃣ 인지왜곡 검증
  Future<Map<String, dynamic>> validate(
    List<Map<String, String>> history,
    String userMessage, {
    String? attachedDiary,
    Map<String, dynamic>? weekContext,
  }) async {
    final h = [
      {'role': 'system', 'content': _validatorSystem},
      ...history,
    ];

    final ctx = '''
사용자 발화: $userMessage
${attachedDiary != null ? "\n연결된 기록:\n$attachedDiary" : ''}
${weekContext != null ? "\n최근 주차 요약 데이터:\n${jsonEncode(weekContext['contextItems'])}" : ''}
''';

    final resp = await api.chat(h, ctx);
    final data = _tryParseJson(resp);

    return {
      'valid': data?['valid'] ?? true,
      'distortions': data?['distortions'] ?? [],
      'why': data?['why'] ?? '',
      'suggestion': data?['suggestion'] ?? '',
    };
  }

  /// 2️⃣ 교정
  Future<String> correct(
    List<Map<String, String>> history,
    String userMessage,
    Map<String, dynamic> verdict, {
    String ragReference = '',
  }) async {
    final h = [
      {'role': 'system', 'content': _correctorSystem},
      ...history,
    ];

    final ctx = '''
[사용자 발화]
$userMessage

[인지왜곡 판정 결과]
${jsonEncode(verdict)}

$ragReference
''';

    return await api.chat(h, ctx);
  }

  /// 3️⃣ 탐색 진행 (주차/단계 기반)
  Future<String> proceed(
    List<Map<String, String>> history,
    String userMessage, {
    required int currentWeek,
    required String stage,
    Map<String, dynamic>? weekContext,
    String? ragReference,
  }) async {
    final weekConcept = DailyContext.weekActivityMap[currentWeek] ?? 'CBT 단계 대화';
    final toneHint =
        weekStagePrompts[currentWeek]?[stage] ?? '감정과 생각을 균형 있게 탐색하세요.';

    final contextItems =
        (weekContext?['contextItems'] as List?)?.join(', ') ?? '(관련 데이터 없음)';

    final prompt = '''
당신은 따뜻하고 공감적인 CBT 상담사입니다.
현재 세션은 $currentWeek주차 ($weekConcept)이며 단계는 "$stage"입니다.

[사용자 최근 데이터 요약]
${contextItems.isNotEmpty ? contextItems : '(데이터 없음)'}

[최근 사용자 발화]
$userMessage

조건:
- 공감 1문장 + 탐색 질문 1~2문장 (총 3문장 이내)
- ‘과제’ 대신 ‘활동’, ‘시도’, ‘연습’ 등의 표현
- 감정, 생각, 행동을 균형 있게 다루기
- 존댓말, 따뜻한 어조
- 인용부호, 번호, 해시태그 금지
---
$toneHint
${ragReference ?? ''}
''';

    return await api.chat([], prompt);
  }

  /// 4️⃣ 세션 요약
  Future<String> summarize(
    List<Map<String, String>> history,
    String lastUserMessage,
    String lastAssistantReply,
  ) async {
    final h = [
      {'role': 'system', 'content': _summarizerSystem},
      ...history.take(12),
    ];

    final ctx = '''
[최근 사용자 입력]
$lastUserMessage

[상담사 마지막 응답]
$lastAssistantReply
''';

    return await api.chat(h, ctx);
  }

  /// 5️⃣ 감정 판정 (아바타 표정용)
  Future<Map<String, dynamic>> analyzeEmotion(String assistantText) async {
    final sample = assistantText.length > 600
        ? '${assistantText.substring(0, 300)} … ${assistantText.substring(assistantText.length - 200)}'
        : assistantText;

    final h = [
      {'role': 'system', 'content': _emotionSystem},
      {
        'role': 'user',
        'content': '다음 상담사 발화의 감정 톤을 JSON으로만 판단:\n\n$sample'
      },
    ];

    final raw = await api.chat(h, '');
    final parsed = _tryParseJson(raw) ??
        {'emotion': '무표정', 'confidence': 0.5, 'why': '기본값'};

    return {
      'emotion': parsed['emotion'] ?? '무표정',
      'confidence': (parsed['confidence'] is num)
          ? (parsed['confidence'] as num).toDouble()
          : 0.5,
      'why': parsed['why'] ?? '',
    };
  }

  // =========================================================
  // 공통 JSON 파서 (GPT 출력 안전 파싱)
  // =========================================================
  Map<String, dynamic>? _tryParseJson(String raw) {
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) return v;
    } catch (_) {
      final m = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
      if (m != null) {
        try {
          final v2 = jsonDecode(m.group(0)!);
          if (v2 is Map<String, dynamic>) return v2;
        } catch (_) {}
      }
    }
    return null;
  }
}
