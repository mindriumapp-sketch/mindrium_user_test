/// 안전 관문. 상담 pipeline 의 첫 번째 단계이며 LLM 앞에 선다.
///
/// Step 1 의 목표는 임상적으로 완성된 위험 분류기가 아니라, 위험 신호가 있을 때
/// **모델을 호출하지 않는 구조**를 코드로 고정하는 것이다. 실제 분류기는 Step 4 에서
/// 규칙 + 소형 분류기 + LLM 보조 신호를 합쳐 이 인터페이스 뒤에 넣는다.
library;

enum SafetyLevel {
  normal,

  /// 주의가 필요하지만 일반 상담을 이어갈 수 있는 수준.
  elevated,

  /// 즉시 위기 대응이 필요한 수준. 일반 상담을 중단한다.
  crisis,
}

class SafetyResult {
  final SafetyLevel level;

  /// 어떤 규칙에 걸렸는지. 감사 로그와 지표 집계에 쓴다.
  final String? reasonCode;

  const SafetyResult({required this.level, this.reasonCode});

  static const SafetyResult ok = SafetyResult(level: SafetyLevel.normal);

  bool get isNormal => level == SafetyLevel.normal;
}

abstract class SafetyGate {
  Future<SafetyResult> evaluate(String message);
}

/// 키워드 규칙만 쓰는 임시 구현.
///
/// 재현율/정밀도를 주장하지 않는다. 임상 검수를 거친 분류기로 반드시 교체해야 한다.
class KeywordSafetyGate implements SafetyGate {
  /// 즉시 위기 대응으로 보내는 표현.
  static const List<String> crisisKeywords = [
    '자살',
    '죽고 싶',
    '죽고싶',
    '살기 싫',
    '살기싫',
    '자해',
    '목숨을 끊',
    '사라지고 싶',
  ];

  /// 주의가 필요한 표현.
  static const List<String> elevatedKeywords = [
    '견딜 수 없',
    '견딜수없',
    '숨을 못',
    '공황',
    '아무 의미 없',
    '희망이 없',
  ];

  const KeywordSafetyGate();

  @override
  Future<SafetyResult> evaluate(String message) async {
    final normalized = message.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

    for (final keyword in crisisKeywords) {
      if (normalized.contains(keyword)) {
        return const SafetyResult(
          level: SafetyLevel.crisis,
          reasonCode: 'keyword_crisis',
        );
      }
    }

    for (final keyword in elevatedKeywords) {
      if (normalized.contains(keyword)) {
        return const SafetyResult(
          level: SafetyLevel.elevated,
          reasonCode: 'keyword_elevated',
        );
      }
    }

    return SafetyResult.ok;
  }
}

/// 위험 수준별 고정 응답.
///
/// 이 문구는 임상 검수 대상이며 모델이 생성하지 않는다. 배포 국가에 맞는 연락처는
/// 임상팀이 확정한 뒤 여기에 넣는다.
class SafetyResponseFactory {
  const SafetyResponseFactory();

  String create(SafetyResult result) {
    switch (result.level) {
      case SafetyLevel.crisis:
        return '지금 많이 힘드신 것 같아요. 이런 이야기를 꺼내 주셔서 감사합니다.\n'
            '지금은 상담 연습을 이어가기보다 사람의 도움을 받는 것이 더 안전해요.\n'
            '자살예방 상담전화 109번에서 24시간 상담을 받을 수 있고, '
            '지금 당장 위험하다고 느끼신다면 119에 연락해 주세요.\n'
            '가까운 사람에게 지금 상태를 알리는 것도 도움이 됩니다.';
      case SafetyLevel.elevated:
        return '지금 많이 버거우신 것 같아요. 잠시 멈추고 호흡을 고르는 것부터 해볼까요?\n'
            '앱의 이완 활동을 실행해 볼 수 있고, 힘든 상태가 이어진다면 '
            '정신건강 상담전화 1577-0199에서 도움을 받을 수 있어요.';
      case SafetyLevel.normal:
        // 정상 입력은 이 factory 를 거치지 않는다.
        throw StateError('normal 수준에는 안전 응답을 만들지 않습니다');
    }
  }
}
