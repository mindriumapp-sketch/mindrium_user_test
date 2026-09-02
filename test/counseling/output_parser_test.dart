import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/output_parser.dart';

void main() {
  const parser = CounselingOutputParser();

  test('T10 올바른 JSON 을 그대로 읽는다', () {
    final output = parser.parse('''
{
  "reply": "지금 어떤 생각이 떠오르셨나요?",
  "dialogue_act": "socratic_question",
  "referenced_cbt_ids": ["week4_alternative_thought_01"],
  "referenced_user_context_ids": ["diary_82"]
}
''');

    expect(output.parseStatus, ParseStatus.strict);
    expect(output.reply, '지금 어떤 생각이 떠오르셨나요?');
    expect(output.dialogueAct, DialogueAct.socraticQuestion);
    expect(output.referencedCbtIds, ['week4_alternative_thought_01']);
    expect(output.referencedUserContextIds, ['diary_82']);
  });

  test('T11 코드펜스에 감싼 JSON 을 추출한다', () {
    final output = parser.parse('''
좋습니다. 아래와 같이 답합니다.

```json
{
  "reply": "그 상황에서 가장 걱정되는 부분은 무엇이었나요?",
  "dialogue_act": "explore",
  "referenced_cbt_ids": [],
  "referenced_user_context_ids": []
}
```
''');

    expect(output.parseStatus, ParseStatus.extracted);
    expect(output.dialogueAct, DialogueAct.explore);
    expect(output.reply, '그 상황에서 가장 걱정되는 부분은 무엇이었나요?');
  });

  test('T11 중괄호가 문자열 안에 있어도 객체 끝을 바르게 찾는다', () {
    final output = parser.parse(
      '앞말 {"reply": "괄호 } 가 들어간 문장", "dialogue_act": "reflect"} 뒷말',
    );

    expect(output.parseStatus, ParseStatus.extracted);
    expect(output.reply, '괄호 } 가 들어간 문장');
    expect(output.dialogueAct, DialogueAct.reflect);
  });

  test('T12 깨진 JSON 은 평문으로 물러선다', () {
    final output = parser.parse('{ "reply": "따옴표가 닫히지 않았어요');

    expect(output.parseStatus, ParseStatus.fallback);
    expect(output.dialogueAct, DialogueAct.unknown);
    expect(output.referencedCbtIds, isEmpty);
    expect(output.reply, isNotEmpty);
  });

  test('T12 JSON 이 아예 없으면 평문으로 처리한다', () {
    final output = parser.parse('오늘 하루는 어떠셨나요?');

    expect(output.parseStatus, ParseStatus.fallback);
    expect(output.reply, '오늘 하루는 어떠셨나요?');
  });

  test('T12 reply 가 비면 평문으로 물러선다', () {
    final output = parser.parse('{"reply": "", "dialogue_act": "explore"}');

    expect(output.parseStatus, ParseStatus.fallback);
  });

  test('T14 빈 출력은 empty 로 표시한다', () {
    final output = parser.parse('   ');

    expect(output.parseStatus, ParseStatus.empty);
    expect(output.reply, isEmpty);
  });

  test('알 수 없는 dialogue_act 는 unknown 이 된다', () {
    final output = parser.parse(
      '{"reply": "네", "dialogue_act": "prescribe_medication"}',
    );

    expect(output.dialogueAct, DialogueAct.unknown);
  });

  test('id 목록에 문자열이 아닌 값이 섞이면 걸러낸다', () {
    final output = parser.parse(
      '{"reply": "네", "referenced_cbt_ids": ["a", 3, null, ""]}',
    );

    expect(output.referencedCbtIds, ['a']);
  });
}
