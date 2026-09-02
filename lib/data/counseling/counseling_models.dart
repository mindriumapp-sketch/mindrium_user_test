/// 상담 harness 가 주고받는 값 객체들.
///
/// 여기에는 LLM 런타임(llama.cpp 등)이나 네트워크에 의존하는 타입을 두지 않는다.
/// Step 3 에서 실제 온디바이스 모델로 교체할 때 이 파일은 그대로 남아야 한다.
library;

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

  const MindriumCounselingContext({
    required this.currentWeek,
    this.relevantItems = const [],
    this.recentSud,
    this.recurringThemes = const [],
    this.effectiveInterventions = const [],
    this.degraded = false,
  });

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
