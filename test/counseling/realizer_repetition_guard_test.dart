// Phase 12.3 (N2): in 3/3 dogfood sessions the Remote Realizer ignored
// the plan's question and copied the previous assistant turn, and
// validation accepted it. Fixtures below are the real device transcripts.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/api/counseling_realize_api.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';
import 'package:gad_app_team/features/counseling/remote_llm_realizer.dart';
import 'package:gad_app_team/features/counseling/response_realizer.dart';

class _FixedApi implements CounselingRealizeApi {
  final String reply;
  _FixedApi(this.reply);

  @override
  Future<Map<String, dynamic>> realize({
    required String requestId,
    required String deterministicDraft,
    required String reflectionTarget,
    required String questionGoal,
    required String requiredAct,
    List<String> allowedActs = const [],
    String? affect,
    String tone = 'warm, calm, concise',
    List<Map<String, String>> recentConversation = const [],
    List<String> allowedCbtFacts = const [],
    List<String> forbiddenBehaviors = const [],
    String promptVersion = 'remote-realizer-v1',
    Duration timeout = const Duration(seconds: 8),
    int? sudRatingValue,
  }) async => {
    'request_id': requestId,
    'reply': reply,
    'chosen_act': requiredAct,
    'model': 'gpt-4o-mini',
    'prompt_version': promptVersion,
    'latency_ms': 10,
  };
}

CounselingMessage _m(String role, String text, int i) => CounselingMessage(
  id: '$role$i',
  role: role,
  text: text,
  createdAt: DateTime(2026, 9, 28),
);

RealizationRequest _req({
  required String draft,
  required List<CounselingMessage> recent,
  DialogueAct act = DialogueAct.explore,
}) => RealizationRequest(
  deterministicDraft: draft,
  reflectionTarget: 'x',
  questionGoal: 'x',
  requiredAct: act,
  retrievalSummary: RetrievalSummary.empty,
  recentConversation: recent,
);

Future<RealizationResult> _run(String reply, RealizationRequest r) =>
    RemoteLlmRealizer(api: _FixedApi(reply)).realize(r);

void main() {
  group('rejects copying the previous assistant question (dogfood)', () {
    test('session 3: identical reply to the previous turn', () async {
      const prev =
          '내일 시험이 있다는 사실이 불안을 느끼게 하는 것 같네요. 그 상황에서 느끼는 불안의 구체적인 계기는 무엇인가요?';
      final result = await _run(
        prev,
        _req(
          draft:
              '“내일 시험을 잘 못보면 어떡하지”라고 말씀해 주셨네요. 지금 마음에 가장 걸리는 부분을 조금 더 구체적으로 이야기해 주실 수 있을까요?',
          recent: [_m('user', '4', 0), _m('assistant', prev, 0)],
        ),
      );
      expect(result.validationResult.isValid, isFalse);
      expect(result.validationResult.violations, contains('repeats_previous_question'));
    });

    test('session 2: reworded reflection, same question as previous turn', () async {
      final result = await _run(
        '다음주에 여행이 계획되어 있는데, 친구들과의 어색함이 마음에 걸리시는 것 같아요. 그 상황에서 가장 걱정되는 순간은 언제인가요?',
        _req(
          draft:
              '“재밌게 놀아야하는데 어색해서 서로 조금 불편하게 놀까봐 걱정돼”라고 말씀해 주셨네요. 지금 마음에 가장 걸리는 부분을 조금 더 구체적으로 이야기해 주실 수 있을까요?',
          recent: [
            _m('user', '6', 0),
            _m(
              'assistant',
              '다음주에 여행이 계획 되어있는데 같이가는 친구들이랑 어색해 부분이 마음에 걸리시는 것 같아요. 그 상황에서 가장 걱정되는 순간은 언제인가요?',
              0,
            ),
          ],
          act: DialogueAct.reflect,
        ),
      );
      expect(result.validationResult.violations, contains('repeats_previous_question'));
    });

    test('ignores whitespace and punctuation differences', () async {
      final result = await _run(
        '그렇군요.  그 상황에서 가장 걱정되는 순간은 언제인가요 ?',
        _req(
          draft: '그렇군요. 어떤 생각이 스쳐 지나갔나요?',
          recent: [_m('assistant', '음. 그 상황에서 가장 걱정되는 순간은 언제인가요?', 0)],
        ),
      );
      expect(result.validationResult.violations, contains('repeats_previous_question'));
    });
  });

  group('does not reject legitimate replies', () {
    test('a new question passes', () async {
      final result = await _run(
        '그런 경험이 있었군요. 그때 어떤 생각이 스쳐 지나갔나요?',
        _req(
          draft: '그렇군요. 어떤 생각이 스쳐 지나갔나요?',
          recent: [_m('assistant', '그 상황에서 가장 걱정되는 순간은 언제인가요?', 0)],
        ),
      );
      expect(result.validationResult.isValid, isTrue);
    });

    test('following the plan passes even if the plan repeats itself', () async {
      const q = '그 상황에서 가장 걱정되는 순간은 언제인가요?';
      final result = await _run(
        '말씀 잘 들었어요. $q',
        _req(draft: '그렇군요. $q', recent: [_m('assistant', '음. $q', 0)]),
      );
      expect(result.validationResult.isValid, isTrue);
    });

    test('no previous assistant message: nothing to compare', () async {
      final result = await _run(
        '그렇군요. 어떤 순간이 가장 걱정되나요?',
        _req(draft: '그렇군요. 어떤 순간이 가장 걱정되나요?', recent: const []),
      );
      expect(result.validationResult.isValid, isTrue);
    });

    test('only the immediately previous assistant turn counts', () async {
      const old = '그 상황에서 가장 걱정되는 순간은 언제인가요?';
      final result = await _run(
        '그렇군요. $old',
        _req(
          draft: '그렇군요. 어떤 생각이 스쳐 지나갔나요?',
          recent: [
            _m('assistant', old, 0),
            _m('user', 'a', 1),
            _m('assistant', '다른 관점에서 본다면 어떻게 볼 수 있을까요?', 1),
          ],
        ),
      );
      expect(result.validationResult.violations, isNot(contains('repeats_previous_question')));
    });
  });
}
