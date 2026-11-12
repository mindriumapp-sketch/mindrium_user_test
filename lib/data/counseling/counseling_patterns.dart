/// 기록에서 계산된 사실. 좌표와 주소는 포함하지 않는다.
class CounselingPattern {
  final String id;
  final String kind;
  final String label;
  final String text;
  final String? aiText;
  const CounselingPattern({
    required this.id,
    required this.kind,
    required this.label,
    required this.text,
    this.aiText,
  });

  static CounselingPattern? fromJson(dynamic value) {
    if (value is! Map) return null;
    final id = value['id'];
    final kind = value['kind'];
    final label = value['label'];
    final text = value['text'];
    if (id is! String ||
        kind is! String ||
        label is! String ||
        text is! String ||
        text.isEmpty) {
      return null;
    }
    final aiText = value['ai_text'];
    return CounselingPattern(
      id: id,
      kind: kind,
      label: label,
      text: text,
      aiText: aiText is String && aiText.isNotEmpty ? aiText : null,
    );
  }
}

class CounselingPatterns {
  final int windowDays;
  final int diaryCount;
  final int activeAlarmCount;
  final List<CounselingPattern> patterns;
  final List<String> topics;
  const CounselingPatterns({
    required this.windowDays,
    required this.diaryCount,
    this.activeAlarmCount = 0,
    required this.patterns,
    required this.topics,
  });

  factory CounselingPatterns.fromJson(Map<String, dynamic> json) =>
      CounselingPatterns(
        windowDays: (json['window_days'] as num?)?.toInt() ?? 28,
        diaryCount: (json['diary_count'] as num?)?.toInt() ?? 0,
        activeAlarmCount: (json['active_alarm_count'] as num?)?.toInt() ?? 0,
        patterns:
            (json['patterns'] as List? ?? const [])
                .map(CounselingPattern.fromJson)
                .whereType<CounselingPattern>()
                .toList(),
        topics:
            (json['topics'] as List? ?? const []).whereType<String>().toList(),
      );

  /// 기록을 바탕으로 분석해 달라는 요청을 구분한다. 상담 중 감정 표현이나
  /// 분석 기능의 사용법을 묻는 문장은 별도의 분석 요청으로 처리하지 않는다.
  static bool explicitlyRequested(String message) {
    final text = message.trim();
    if (text.isEmpty || rejectsAnalysis(text)) return false;

    // 분석하지 말라는 요청과 메뉴의 사용법을 묻는 질문은 우선 제외한다.
    if (RegExp(
          r'(분석|패턴|통계|경향).{0,12}(하지\s*마|하지\s*않|하지\s*말|하지\s*못|원하지\s*않|싫|그만)',
        ).hasMatch(text) ||
        RegExp(
          r'(분석|패턴|통계|경향).{0,12}(기능|메뉴|화면|버튼|사용법).{0,15}(어디|어떻게|사용|찾|들어|보는\s*법|쓰는\s*법)',
        ).hasMatch(text)) {
      return false;
    }

    const subject = r'(불안|걱정|일기|기록|알림|알람|상태|감정|기분|마음|스트레스|심리|증상)';
    const analysis = r'(패턴|분석|경향|통계)';
    if (RegExp(
      '$subject.{0,25}$analysis|$analysis.{0,25}$subject',
    ).hasMatch(text)) {
      return true;
    }

    // "내 상태가 어떤지", "요즘 불안이 언제 심한지"처럼 분석이라는
    // 단어 없이 기록을 확인하고 싶어 하는 표현도 허용한다.
    const perspective = r'(내|나의|제|저의|요즘|최근|그동안|지금까지|평소|기록)';
    const inquiry =
        r'(어때|어떻|어떤지|어떤\s*(것|거)\s*같|알려|살펴|정리|확인|알아|살펴봐|보여|봐\s*줘|봐주세요|언제|어디|시간대|점수)';
    final hasSubject = RegExp(subject).hasMatch(text);
    final hasPerspective = RegExp(perspective).hasMatch(text);
    final hasInquiry = RegExp(inquiry).hasMatch(text);
    return hasSubject && hasPerspective && hasInquiry;
  }

  static bool optedOut(String message) => RegExp(
    r'(과거|이전|지난|기록|일기|패턴).{0,20}(언급|꺼내|말하|말해|보지|쓰지|사용하|참고하).{0,10}(말|마|않|싫|원하지)|(?:과거|이전|지난|기록|일기|패턴).{0,15}(말하지|언급하지|참고하지|꺼내지|말고)',
  ).hasMatch(message);

  static bool rejectsAnalysis(String message) => optedOut(message) || RegExp(
    r'(분석|패턴|통계|경향|기록|상태).{0,12}(하지\s*마|하지\s*않|하지\s*말|원하지\s*않|싫|그만)',
  ).hasMatch(message);

  List<CounselingPattern> relevant(String message, {bool explicit = false}) {
    if (explicit) {
      final kind =
          RegExp(r'알림|알람').hasMatch(message)
              ? 'alarm'
              : RegExp(r'점수').hasMatch(message)
              ? 'score'
              : RegExp(r'장소|위치|어디').hasMatch(message)
              ? 'place'
              : RegExp(r'요일').hasMatch(message)
              ? 'weekday'
              : RegExp(r'시간|언제').hasMatch(message)
              ? 'time'
              : null;
      if (kind != null) {
        return patterns.where((p) => p.kind == kind).take(3).toList();
      }
      // A broad analysis should represent time, place and score rather than
      // returning the first three entries from one category.
      final selected = <CounselingPattern>[];
      for (final group in ['time', 'place', 'score', 'topic']) {
        final matches = patterns.where((p) => p.kind == group);
        if (matches.isNotEmpty) selected.add(matches.first);
      }
      if (selected.isEmpty) return patterns.take(3).toList();
      return selected;
    }
    final normalized = message.replaceAll(RegExp(r'\s+'), '');
    final direct =
        patterns
            .where(
              (p) =>
                  p.label.replaceAll(' ', '').length >= 2 &&
                  normalized.contains(p.label.replaceAll(' ', '')),
            )
            .toList();
    if (direct.isNotEmpty) return direct.take(2).toList();
    // Only use topic-linked data when a repeated situation appears in this turn.
    bool topicMatches(String topic) {
      final words = topic
          .split(RegExp(r'\s+'))
          .where(
            (w) => w.length >= 2 && !const {'걱정', '불안', '마음', '상황'}.contains(w),
          );
      return words.any((w) => normalized.contains(w));
    }
    return patterns
        .where((p) => p.kind == 'topic' && topicMatches(p.label))
        .take(1)
        .toList();
  }
}
