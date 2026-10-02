import 'dart:convert';

import 'package:gad_app_team/data/counseling/counseling_models.dart';

/// 모델 원문을 CounselingModelOutput 으로 바꾼다.
///
/// grammar 제약 디코딩을 전제하지 않는다. Flutter 래퍼가 GBNF 를 노출할지 아직 모르고,
/// 노출하더라도 작은 모델은 형식을 깨뜨린다. 그래서 3단계로 물러선다.
///   1. 전체를 그대로 JSON 파싱
///   2. 코드펜스/잡담을 걷어내고 JSON 객체만 추출해 파싱
///   3. 평문으로 취급
class CounselingOutputParser {
  const CounselingOutputParser();

  CounselingModelOutput parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const CounselingModelOutput(
        reply: '',
        dialogueAct: DialogueAct.unknown,
        referencedCbtIds: [],
        referencedUserContextIds: [],
        parseStatus: ParseStatus.empty,
      );
    }

    final strict = _tryDecode(trimmed);
    if (strict != null) {
      return _fromMap(strict, ParseStatus.strict) ??
          _plainText(trimmed, ParseStatus.fallback);
    }

    final extracted = _extractJsonObject(trimmed);
    if (extracted != null) {
      final decoded = _tryDecode(extracted);
      if (decoded != null) {
        return _fromMap(decoded, ParseStatus.extracted) ??
            _plainText(trimmed, ParseStatus.fallback);
      }
    }

    // max token에서 JSON 닫힘이 잘려도 reply 문자열 자체는 복구한다. 절대로
    // 구현용 JSON/provenance 원문을 사용자에게 그대로 보여주지 않는다.
    final partialReply = _extractPartialReply(trimmed);
    if (partialReply != null) {
      return CounselingModelOutput(
        reply: partialReply,
        dialogueAct: DialogueAct.unknown,
        referencedCbtIds: const [],
        referencedUserContextIds: const [],
        parseStatus: ParseStatus.fallback,
      );
    }

    return _plainText(trimmed, ParseStatus.fallback);
  }

  String? _extractPartialReply(String source) {
    final match = RegExp(
      r'''["']reply["']\s*:\s*["']((?:\\.|[^"'])*)''',
      dotAll: true,
    ).firstMatch(source);
    final value = match?.group(1);
    if (value == null || value.trim().isEmpty) return null;
    return value
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\"', '"')
        .replaceAll(r"\'", "'")
        .trim();
  }

  Map<String, dynamic>? _tryDecode(String source) {
    try {
      final decoded = jsonDecode(source);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// 코드펜스를 벗기고 첫 번째 균형 잡힌 { ... } 를 찾는다.
  String? _extractJsonObject(String source) {
    var text = source;

    final fence = RegExp(
      r'```(?:json)?\s*(.*?)\s*```',
      dotAll: true,
    ).firstMatch(text);
    if (fence != null) text = fence.group(1)!.trim();

    final start = text.indexOf('{');
    if (start < 0) return null;

    var depth = 0;
    var inString = false;
    var escaped = false;

    for (var i = start; i < text.length; i++) {
      final char = text[i];

      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == r'\') {
        escaped = true;
        continue;
      }
      if (char == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;

      if (char == '{') depth++;
      if (char == '}') {
        depth--;
        if (depth == 0) return text.substring(start, i + 1);
      }
    }

    return null;
  }

  CounselingModelOutput? _fromMap(
    Map<String, dynamic> json,
    ParseStatus status,
  ) {
    final reply = json['reply'];
    if (reply is! String || reply.trim().isEmpty) return null;

    return CounselingModelOutput(
      reply: reply.trim(),
      dialogueAct: DialogueAct.fromWire(json['dialogue_act'] as String?),
      referencedCbtIds: _stringList(json['referenced_cbt_ids']),
      referencedUserContextIds: _stringList(
        json['referenced_user_context_ids'],
      ),
      parseStatus: status,
    );
  }

  /// 프롬프트 표기를 그대로 베낀 형태를 정리한다.
  ///
  /// 프롬프트가 근거를 `[id=diary:abc123]` 로 표시하다 보니 작은 모델은
  /// JSON 에도 `id=diary:abc123` 또는 `[id=diary:abc123]` 을 그대로 넣는다.
  /// 이걸 그냥 두면 harness 의 provenance 검증에서 전부 걸러져, 모델이 근거를
  /// 제대로 골랐는데도 사용하지 않은 것처럼 기록된다.
  static final RegExp _idNoise = RegExp(r'^\[?\s*id\s*=\s*|\]$');

  List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((s) => s.replaceAll(_idNoise, '').trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// JSON 을 못 읽었을 때. 원문에서 코드펜스만 걷어내 사용자에게 보여준다.
  CounselingModelOutput _plainText(String raw, ParseStatus status) {
    final sanitized =
        raw
            .replaceAll(RegExp(r'```(?:json)?'), '')
            .replaceAll('```', '')
            .trim();

    return CounselingModelOutput(
      reply: sanitized,
      dialogueAct: DialogueAct.unknown,
      referencedCbtIds: const [],
      referencedUserContextIds: const [],
      parseStatus: status,
    );
  }
}
