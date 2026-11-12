// Phase 14.X: Bounded LLM-led path — context, output, validator, mapping.
// docs/counseling/phase14x_bounded_llm_led.md.
//
// Code narrows the world before the call (approved techniques up to this
// week, retrieved user facts, the app catalog, all with ids) and checks the
// answer after it. Anything the validator rejects falls back to the
// deterministic path for that turn.
import 'package:gad_app_team/data/counseling/cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/counseling_patterns.dart';
import 'package:gad_app_team/data/counseling/user_thought_extractor.dart';
import 'package:gad_app_team/features/assistant/app_guide/app_guide_repository.dart';

import '../counseling_session_state.dart';
import '../counseling_state.dart';
import '../intervention_registry.dart';
import '../policy/selectors/closing_decision_selector.dart';
import 'package:gad_app_team/data/counseling/episode_history.dart';
import 'package:gad_app_team/data/counseling/previous_session.dart';
import 'term_glossary.dart';

part 'llm_led_context.dart';
part 'llm_led_output.dart';
part 'llm_led_validator.dart';
part 'llm_led_mapping.dart';

const _domains = {'counseling', 'app_guide', 'mixed'};
const _moves = {
  'acknowledge',
  'restate',
  'reflect_emotion',
  'clarify',
  'open_question',
  'ask_evidence',
  'ask_alternative',
  'ask_probability',
  'connect_past_record',
  'summarize',
  'listen',
  'repair',
  'intervention_question',
  'integrate',
  'answer_app',
  'offer_close',
  'finalize',
};
const _sessionActions = {'continue', 'offer_close', 'finalize'};

String _clip(String s, int n) => s.length <= n ? s : s.substring(0, n);
