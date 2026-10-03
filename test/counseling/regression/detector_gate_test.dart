// Phase 12.3B — F2 detector gate, FROZEN BEFORE THE DETECTOR CHANGE.
//
// Sets:
//   design       — real dogfood utterances (12.1). Used to derive cue
//                  families; not a generalization claim.
//   verification — (a) the 12.2 "unseen" expressions, never encoded as
//                  strings in the detector; (b) a holdback set written
//                  before implementation and not tuned against afterwards.
//   negatives    — worry content that uses repetition/speech words.
//
// Gates (fixed here, before results exist):
//   G1  negatives: false positives == 0
//   G2  verification explicit items: recall >= 80%
//   G3  design explicit items: all detected
//   implicit items: reported only (not decidable without context)
//
// Caveat: holdback was written by the same author as the detector. It is
// the best available proxy until more real dogfood data exists.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

const _r = InteractionRepairReason.repeatedQuestion;
const _s = InteractionRepairReason.stopQuestioning;

class _Case {
  final String text;
  final Set<InteractionRepairReason> accept;
  const _Case(this.text, this.accept);
}

const _design = [
  _Case('아까 말했잖아 지금 준비를 못해서 불안하다고', {_r}),
  _Case('방금 말했잖아', {_r}),
  _Case('왜 똑같은 말을해?', {_r}),
  _Case('왜 똑같은 말 하냐고', {_r}),
];
const _designImplicit = ['서로 불편할까봐 걱정된다고'];

const _verificationExplicit = [
  // 12.2 unseen (explicit)
  _Case('우리 이 얘기 아까 하지 않았어요?', {_r}),
  _Case('계속 비슷한 것만 묻는 느낌인데요', {_r}),
  _Case('그 질문 또 하는 거예요?', {_r}),
  _Case('이거 전에 대답했던 것 같은데', {_r}),
  _Case('아까랑 질문이 거의 같은데요', {_r}),
  _Case('또 그 질문이에요?', {_r}),
  _Case('이제 질문은 좀 안 했으면 좋겠어요', {_s}),
  _Case('그냥 제 얘기만 들어주면 안 돼요?', {_s}),
  _Case('더 물어보는 건 지금 부담돼요', {_s}),
  // holdback (written before implementation)
  _Case('아까 대답했잖아요', {_r}),
  _Case('이미 말씀드렸는데요', {_r}),
  _Case('그거 벌써 얘기했어', {_r}),
  _Case('전에 말했다니까', {_r}),
  _Case('왜 자꾸 같은 질문이야', {_r}),
  _Case('또 똑같은 거 물어보네', {_r}),
  _Case('계속 같은 소리만 하시네요', {_r}),
  _Case('질문이 또 반복되네요', {_r}),
  _Case('같은 질문 다시 하지 마세요', {_r, _s}),
  _Case('방금 대답한 건데요', {_r}),
  _Case('질문 좀 그만해 주세요', {_s}),
  _Case('이제 그만 물어봐', {_s}),
  _Case('질문 말고 그냥 들어줘', {_s}),
  _Case('더 묻지 말아 주세요', {_s}),
  _Case('들어만 주면 돼요', {_s}),
];

const _verificationImplicit = [
  '계속 같은 데서 맴도는 느낌이에요',
  '굳이 답을 찾기보다 그냥 말하고 싶어요',
  '그러니까 불안하다고요',
  '그게 걱정이라고 했잖아',
];

const _negatives = [
  // 12.2
  '요즘 같은 생각이 계속 반복돼요',
  '또 그런 실수를 할까 봐 걱정돼요',
  '매일 똑같은 일이 생기는 것 같아요',
  '아까도 그 사람이 비슷하게 말했어요',
  '계속 같은 장면이 떠올라요',
  '같은 생각이 계속 반복돼요.',
  '매일 똑같은 걱정을 해요.',
  '또 실수할까 봐 걱정돼요.',
  '같은 일이 다시 생길 것 같아요.',
  '계속 비슷한 상황이 반복돼요.',
  // holdback
  '면접에서 같은 질문을 또 받을까 봐 걱정돼요',
  '친구가 아까 말했던 게 계속 신경 쓰여요',
  '엄마가 방금 전화로 똑같은 말을 했어요',
  '선생님이 전에 말했잖아, 늦으면 안 된다고',
  '계속 같은 꿈을 꿔요',
  '사람들이 제 얘기를 안 들어줘요',
  '발표 때 질문을 그만 받고 싶어요',
  '또 같은 실수를 반복할까 봐 무서워요',
  '같은 얘기를 친구한테 계속 하게 돼요',
  '제가 왜 같은 말을 자꾸 하는지 모르겠어요',
  '아까도 그 얘기 들었는데 또 걱정돼요',
];

InteractionRepairReason? _detect(String m, CounselingState state) =>
    const DeterministicProcessSignalTurnPlanner()
        .plan(TurnPlanningContext(state: state, userMessage: m, knowledge: const []))
        ?.interactionRepairReason;

const _states = [
  CounselingState.checkIn,
  CounselingState.explore,
  CounselingState.reflect,
  CounselingState.intervention,
];

// Baseline before the change (commit dcd1ca4): recall 2/24 (8.3%), FP 0.
// First and only run after the change: recall 24/24, FP 0, design 4/4,
// implicit 0/5. The holdback was not tuned against after this run.

void main() {
  test('G1 negatives: zero false positives in every Hard Guard state', () {
    final fp = <String>[
      for (final state in _states)
        for (final m in _negatives)
          if (_detect(m, state) != null) '${state.name}: $m',
    ];
    expect(fp, isEmpty);
  });

  test('G2 verification explicit recall >= 80%', () {
    final missed = [
      for (final c in _verificationExplicit)
        if (!c.accept.contains(_detect(c.text, CounselingState.reflect))) c.text,
    ];
    final recall = 1 - missed.length / _verificationExplicit.length;
    // ignore: avoid_print
    print('PHASE12_3B verification recall=${(recall * 100).toStringAsFixed(1)}% '
        '(${_verificationExplicit.length - missed.length}/${_verificationExplicit.length}) '
        'missed=$missed');
    expect(recall, greaterThanOrEqualTo(0.8));
  });

  test('G3 design explicit items all detected', () {
    for (final c in _design) {
      expect(c.accept, contains(_detect(c.text, CounselingState.reflect)), reason: c.text);
    }
  });

  test('implicit items (reported, not gated)', () {
    final hits = [
      for (final m in [..._designImplicit, ..._verificationImplicit])
        '${_detect(m, CounselingState.reflect)?.name ?? '-'} | $m',
    ];
    // ignore: avoid_print
    print('PHASE12_3B implicit: $hits');
  });
}
