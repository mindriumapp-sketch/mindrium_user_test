// 두 박자 표정: 보낸 직후 듣는 얼굴, 최종 응답 확정 시 사용자 단서 × 실제로 나간 응답 행동.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/chatbot/affective/affect_signal.dart';
import 'package:gad_app_team/chatbot/affective/affect_signal_detector.dart';
import 'package:gad_app_team/chatbot/affective/affective_adapter.dart';
import 'package:gad_app_team/chatbot/affective/response_move.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

void main() {
  const detector = AffectSignalDetector();
  const adapter = AffectiveAdapter();
  AvatarExpression face(String user, ResponseMove move,
          {CounselingState state = CounselingState.explore, SafetyLevel safety = SafetyLevel.normal}) =>
      adapter.respond(signal: detector.detect(userMessage: user), move: move, state: state, safetyLevel: safety);

  test('listening face while the reply is pending', () => expect(adapter.listening(), AvatarExpression.attentive));

  test('affect × final move', () {
    expect(face('발표 때문에 너무 걱정돼', ResponseMove.empathize), AvatarExpression.warm);
    expect(face('실수할까 봐 두려워', ResponseMove.empathize), AvatarExpression.warm);
    expect(face('요즘 너무 지치고 아무것도 하기 싫어', ResponseMove.empathize), AvatarExpression.concerned);
    expect(face('친구한테 너무 서운했어', ResponseMove.empathize), AvatarExpression.concerned);
    expect(face('해 보니까 덜 불안했어요', ResponseMove.integrate), AvatarExpression.encouraging);
    expect(face('준비한 건 설명할 수 있을 것 같아', ResponseMove.integrate), AvatarExpression.encouraging);
    expect(face('왜 똑같은 말만 해', ResponseMove.repair), AvatarExpression.concerned);
    expect(face('걱정 일기는 어디서 봐요?', ResponseMove.appGuide), AvatarExpression.warm);
    expect(face('오늘은 여기까지', ResponseMove.closing, state: CounselingState.closing), AvatarExpression.warm);
  });

  test('reply tone decides only when user affect × move did not', () {
    AvatarExpression withReply(String user, String reply) => adapter.respond(
        signal: detector.detect(userMessage: user), move: ResponseMove.other,
        state: CounselingState.explore, replyText: reply);
    expect(withReply('음', '그런 일이 있었다니 안타깝네요. 어떤 점이 가장 컸나요?'), AvatarExpression.concerned);
    expect(withReply('음', '잘하셨어요. 그때 어떤 생각이 드셨나요?'), AvatarExpression.encouraging);
    expect(withReply('음', '그럴 수 있어요. 조금 더 이야기해 주실래요?'), AvatarExpression.warm);
    expect(withReply('음', '언제 그런 생각이 드셨나요?'), AvatarExpression.attentive);
    // the user's distress outranks a cheerful reply tone
    expect(adapter.respond(signal: detector.detect(userMessage: '너무 힘들어'), move: ResponseMove.other,
        state: CounselingState.explore, replyText: '잘하셨어요.'), AvatarExpression.concerned);
  });

  test('crisis is always attentive', () {
    expect(face('너무 힘들어', ResponseMove.empathize, safety: SafetyLevel.crisis), AvatarExpression.attentive);
  });

  test('unknown affect falls back to the stage default', () {
    expect(face('음', ResponseMove.other, state: CounselingState.explore), AvatarExpression.attentive);
    expect(face('음', ResponseMove.other, state: CounselingState.intervention), AvatarExpression.encouraging);
  });

  test('a repeated situation keeps its meaning (no change for variety)', () {
    final faces = [for (var i = 0; i < 4; i++) face('계속 너무 힘들어', ResponseMove.empathize)];
    expect(faces.toSet(), {AvatarExpression.concerned});
  });

  test('B rejected → A answered: only the committed A message decides the move', () {
    // A's committed message: a plain explore question (no repair), even if B's discarded output had "repair"
    final a = CounselingMessage(id: 'a', role: 'assistant', text: '어떤 부분이 걱정되세요?', createdAt: DateTime(2026),
        dialogueAct: DialogueAct.explore);
    expect(ResponseMove.fromMessage(a), ResponseMove.other);
    expect(ResponseMove.fromMessage(a, appGuide: true), ResponseMove.appGuide);
    final repairA = CounselingMessage(id: 'r', role: 'assistant', text: 'x', createdAt: DateTime(2026),
        interactionRepairReason: InteractionRepairReason.repeatedQuestion);
    expect(ResponseMove.fromMessage(repairA), ResponseMove.repair);
  });

  test('B accepted output moves', () {
    expect(ResponseMove.fromLlmLed(domain: 'counseling', moves: ['acknowledge', 'reflect_emotion'], sessionAction: 'continue'),
        ResponseMove.empathize);
    expect(ResponseMove.fromLlmLed(domain: 'app_guide', moves: ['answer_app'], sessionAction: 'continue'), ResponseMove.appGuide);
    expect(ResponseMove.fromLlmLed(domain: 'counseling', moves: ['acknowledge', 'repair'], sessionAction: 'continue'),
        ResponseMove.repair);
    expect(ResponseMove.fromLlmLed(domain: 'counseling', moves: ['integrate'], interventionStep: 'integration', sessionAction: 'continue'),
        ResponseMove.integrate);
    expect(ResponseMove.fromLlmLed(domain: 'counseling', moves: ['summarize', 'finalize'], sessionAction: 'finalize'),
        ResponseMove.closing);
  });
}
