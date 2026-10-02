// Phase 14.2A: the current rule detectors' labels for a classifier eval set,
// so the model classifier is compared against the rules on the same items.
// Runs only when RULE_LABEL_IN / RULE_LABEL_OUT are set:
//
//   RULE_LABEL_IN=test/counseling/evaluation/fixtures/phase14_2_classifier_dev.json \
//   RULE_LABEL_OUT=build/classifier_eval/dev_rules.json \
//   flutter test test/counseling/evaluation/phase14_2_rule_labels_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/user_thought_extractor.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/policy/production_turn_planner.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

const _closingProposal = '오늘은 여기까지 정리해 볼까요, 아니면 조금 더 이야기하고 싶으신가요?';

CounselingState _state(String? s) => switch (s) {
  'checkIn' => CounselingState.checkIn,
  'intervention' => CounselingState.intervention,
  'closing' => CounselingState.closing,
  _ => CounselingState.reflect,
};

Map<String, String> ruleLabels(String user, String? assistantPrev, String? ruleState,
    [List<String> tags = const []]) {
  final closing = ruleState == 'closing' ||
      tags.contains('closing') ||
      (assistantPrev != null && assistantPrev.contains('여기까지 정리'));
  final state = closing ? CounselingState.closing : _state(ruleState);
  final recent = <CounselingMessage>[
    if (assistantPrev != null)
      CounselingMessage(
        id: 'prev',
        role: 'assistant',
        text: closing ? _closingProposal : assistantPrev,
        createdAt: DateTime(2026),
        closingStep: closing ? ClosingStep.proposed : null,
      ),
  ];
  final plan = const PolicyPipelineTurnPlanner().plan(TurnPlanningContext(
    state: state,
    userMessage: user,
    knowledge: const [],
    recentMessages: recent,
  ));

  var signal = switch (plan?.interactionRepairReason) {
    InteractionRepairReason.repeatedQuestion => 'repeated_question',
    InteractionRepairReason.stopQuestioning => 'stop_questioning',
    InteractionRepairReason.processFrustration => 'process_resistance',
    InteractionRepairReason.assistantNotUnderstood => 'assistant_not_understood',
    _ => 'none',
  };
  if (closing && signal == 'none') {
    signal = switch (plan?.closingStep) {
      ClosingStep.finalized => 'closing_accept',
      ClosingStep.continued => 'closing_continue',
      _ => 'none',
    };
  }

  final eligibility = UserThoughtExtractor.targetEligibility(user);
  final meta = signal != 'none' && !signal.startsWith('closing');
  final String content;
  if (meta) {
    content = eligibility == TargetEligibility.worryThought ? 'mixed' : 'meta_interaction';
  } else if (UserThoughtExtractor.isLowInformation(user)) {
    content = 'low_information';
  } else {
    content = switch (eligibility) {
      TargetEligibility.worryThought => 'worry_thought',
      TargetEligibility.situation => 'situation',
      TargetEligibility.lowInformation => 'low_information',
      TargetEligibility.interaction => 'meta_interaction',
    };
  }
  // The rules have no notion of new content; they always say none.
  return {'content_type': content, 'interaction_signal': signal, 'open_content': 'none'};
}

void main() {
  final input = Platform.environment['RULE_LABEL_IN'];
  final output = Platform.environment['RULE_LABEL_OUT'];

  test('rule labels for a classifier eval set', () {
    final data = jsonDecode(File(input!).readAsStringSync()) as Map<String, dynamic>;
    final out = <String, Map<String, String>>{};
    for (final item in (data['items'] as List).cast<Map<String, dynamic>>()) {
      out[item['id'] as String] = ruleLabels(
        item['user'] as String,
        item['assistant_prev'] as String?,
        item['rule_state'] as String?,
        ((item['tags'] as List?) ?? const []).cast<String>(),
      );
    }
    File(output!)
      ..createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
  }, skip: input == null || output == null ? 'set RULE_LABEL_IN and RULE_LABEL_OUT' : false);
}
