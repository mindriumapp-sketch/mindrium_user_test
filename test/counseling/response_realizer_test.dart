import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';
import 'package:gad_app_team/features/counseling/response_realizer.dart';

void main() {
  test('deterministic realizer는 draft와 construction contract를 보존한다', () async {
    const request = RealizationRequest(
      deterministicDraft: '마음이 많이 쓰이셨겠어요. 어떤 점이 가장 걱정되나요?',
      reflectionTarget: '마음이 쓰인다',
      questionGoal: '핵심 걱정을 확인한다',
      requiredAct: DialogueAct.explore,
      retrievalSummary: RetrievalSummary.empty,
      forbiddenBehaviors: ['조언하지 않는다'],
    );

    final result = await const DeterministicResponseRealizer().realize(request);

    expect(result.reply, request.deterministicDraft);
    expect(result.source, RealizationSource.deterministic);
    expect(result.latency, Duration.zero);
    expect(result.validationResult.isValid, isTrue);
  });
}
