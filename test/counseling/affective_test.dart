import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/chatbot/affective/affect_signal.dart';
import 'package:gad_app_team/chatbot/affective/affect_signal_detector.dart';
import 'package:gad_app_team/chatbot/affective/affective_adapter.dart';
import 'package:gad_app_team/chatbot/affective/avatar_asset_resolver.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

void main() {
  const detector = AffectSignalDetector();
  const adapter = AffectiveAdapter();
  const resolver = AvatarAssetResolver();

  AvatarExpression adaptFor(
    String message, {
    CounselingState state = CounselingState.explore,
    int? sud,
    AffectSignal? previous,
    SafetyLevel safety = SafetyLevel.normal,
  }) {
    final signal = detector.detect(
      userMessage: message,
      recentSud: sud,
      previous: previous,
    );
    return adapter.adapt(signal: signal, state: state, safetyLevel: safety);
  }

  // ───── 신호 → 태도 ─────

  test('T37 중립 발화는 단계 기본 태도를 따른다', () {
    expect(
      adaptFor('오늘은 그냥 평소랑 비슷했어요', state: CounselingState.checkIn),
      AvatarExpression.warm,
    );
    expect(
      adaptFor('오늘은 그냥 평소랑 비슷했어요', state: CounselingState.explore),
      AvatarExpression.attentive,
    );
  });

  test('T38 불안 신호는 attentive 로 대응한다', () {
    final signal = detector.detect(userMessage: '내일 발표가 너무 걱정돼요');

    expect(signal.label, AffectLabel.anxious);
    expect(
      adapter.adapt(signal: signal, state: CounselingState.explore),
      AvatarExpression.attentive,
    );
  });

  test('T39 높은 괴로움은 concerned 로 대응한다 (미러링하지 않는다)', () {
    final signal = detector.detect(userMessage: '요즘 너무 힘들고 속상해요');

    expect(signal.label, AffectLabel.distressed);
    expect(
      adapter.adapt(signal: signal, state: CounselingState.reflect),
      AvatarExpression.concerned,
    );
    // 사용자 감정 라벨과 상담사 태도는 서로 다른 타입이며, 이름도 겹치지 않는다.
    expect(AvatarExpression.values.map((e) => e.name), isNot(contains('distressed')));
  });

  test('T40 대처에 성공한 발화는 encouraging 으로 대응한다', () {
    final signal = detector.detect(userMessage: '이완을 해보니 훨씬 괜찮아졌어요');

    expect(signal.label, AffectLabel.positive);
    expect(
      adapter.adapt(signal: signal, state: CounselingState.reflect),
      AvatarExpression.encouraging,
    );
  });

  test('높은 SUD 는 담담한 표현도 불안으로 올려 잡는다', () {
    final calm = detector.detect(userMessage: '그냥 그랬어요');
    final withSud = detector.detect(userMessage: '그냥 그랬어요', recentSud: 9);

    expect(calm.label, AffectLabel.neutral);
    expect(withSud.label, AffectLabel.anxious);
  });

  // ───── spike / streak ─────

  test('T41 확신도가 임계 미만이면 단계 기본 태도를 유지한다', () {
    const policy = AffectivePolicy();
    final signal = detector.detect(userMessage: '내일 발표가 걱정돼요');

    // 불안은 0.8 로 임계(0.92) 미만이다.
    expect(signal.confidence, lessThan(policy.spikeThreshold));
    expect(
      adapter.adapt(signal: signal, state: CounselingState.intervention),
      // 단계 기본값(encouraging)이 유지된다.
      AvatarExpression.encouraging,
    );
  });

  test('T42 확신도가 임계를 넘으면 신호를 따라 concerned 로 바뀐다', () {
    const policy = AffectivePolicy();
    final signal = detector.detect(userMessage: '너무 괴로워서 못 견디겠어요');

    expect(signal.confidence, greaterThanOrEqualTo(policy.spikeThreshold));
    expect(
      adapter.adapt(signal: signal, state: CounselingState.intervention),
      AvatarExpression.concerned,
    );
  });

  test('T43 연속 횟수가 임계 미만이면 표정을 바꾸지 않는다', () {
    const signal = AffectSignal(
      label: AffectLabel.neutral,
      confidence: 0.6,
      streak: 2,
    );

    expect(
      adapter.adapt(signal: signal, state: CounselingState.explore),
      AvatarExpression.attentive,
    );
  });

  test('T44 연속 횟수가 임계에 닿으면 표정을 한 번 바꿔 준다', () {
    const signal = AffectSignal(
      label: AffectLabel.neutral,
      confidence: 0.6,
      streak: 3,
    );

    expect(
      adapter.adapt(signal: signal, state: CounselingState.explore),
      // attentive 가 계속되면 warm 으로 풀어 준다.
      AvatarExpression.warm,
    );
  });

  test('T44 concerned 는 연속되어도 억지로 바꾸지 않는다', () {
    const signal = AffectSignal(
      label: AffectLabel.distressed,
      confidence: 0.6,
      streak: 5,
    );

    // 걱정하는 표정이 이어지는 것은 부자연스럽지 않다.
    expect(
      adapter.adapt(signal: signal, state: CounselingState.reflect),
      isNot(AvatarExpression.encouraging),
    );
  });

  test('detector 는 같은 라벨이 이어지면 streak 를 센다', () {
    var signal = detector.detect(userMessage: '걱정돼요');
    expect(signal.streak, 1);

    signal = detector.detect(userMessage: '계속 불안해요', previous: signal);
    expect(signal.streak, 2);

    signal = detector.detect(userMessage: '다행히 좀 괜찮아요', previous: signal);
    expect(signal.streak, 1);
  });

  // ───── 상태 / 안전 ─────

  test('T45 마무리 단계는 warm 을 쓴다', () {
    expect(
      adaptFor('오늘 이야기 고마웠어요', state: CounselingState.closing),
      AvatarExpression.warm,
    );
  });

  test('T46 위기 상황에서는 극적인 표정을 쓰지 않는다', () {
    for (final state in CounselingState.values) {
      expect(
        adaptFor(
          '죽고 싶어요',
          state: state,
          safety: SafetyLevel.crisis,
        ),
        AvatarExpression.attentive,
      );
    }
  });

  test('T46 주의 수준에서도 표정 연출을 늘리지 않는다', () {
    expect(
      adaptFor('공황이 와서 견딜 수 없어요', safety: SafetyLevel.elevated),
      AvatarExpression.attentive,
    );
  });

  // ───── 자산 매핑 ─────

  test('T47 같은 입력은 항상 같은 이미지로 이어진다', () {
    final first = resolver.resolve(adaptFor('너무 힘들어요'));
    final second = resolver.resolve(adaptFor('너무 힘들어요'));

    expect(first, second);
  });

  test('T48 다섯 표정 모두 유효한 이미지 경로를 갖는다', () {
    for (final expression in AvatarExpression.values) {
      final asset = resolver.resolve(expression);
      expect(asset, startsWith('assets/npc_images/'));
      expect(File(asset).existsSync(), isTrue, reason: '$expression → $asset');
    }
  });

  test('T48 변형 인덱스는 순환하며 항상 유효한 경로를 준다', () {
    for (final expression in AvatarExpression.values) {
      for (var i = 0; i < 5; i++) {
        expect(File(resolver.resolve(expression, variantIndex: i)).existsSync(), isTrue);
      }
    }
  });

  test('T49 이미지 경로가 pubspec 자산 등록 범위 안에 있다', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/npc_images/'));

    final referenced = {
      for (final expression in AvatarExpression.values)
        ...AvatarAssetResolver.variants[expression]!,
    };
    for (final asset in referenced) {
      expect(asset, startsWith('assets/npc_images/'));
    }
  });

  test('T49 쓰지 않는 이미지는 명시적으로 표시되어 있다', () {
    // 놀람 표정은 상담사 태도로 쓰지 않는다. 누락이 아니라 의도적 제외임을 남긴다.
    expect(AvatarAssetResolver.unusedAssets, isNotEmpty);
    for (final asset in AvatarAssetResolver.unusedAssets) {
      expect(File(asset).existsSync(), isTrue);
      final used = AvatarAssetResolver.variants.values.expand((e) => e);
      expect(used, isNot(contains(asset)));
    }
  });

  test('T50 ChatPage 는 감정 판단 로직을 직접 갖지 않는다', () {
    final source = File('lib/chatbot/chatbot_main.dart').readAsStringSync();

    // 키워드 매칭, 임계값, 연속 카운트는 전부 affective/ 로 옮겼다.
    expect(source.contains('_pickEmotionAvatar'), isFalse);
    expect(source.contains('_decideEmotionLabel'), isFalse);
    expect(source.contains('kSwitchStrong'), isFalse);
    expect(source.contains('_sameEmotionStreak'), isFalse);
    expect(source.contains('_emotionToAsset'), isFalse);
    // 이미지 경로도 resolver 를 통해서만 얻는다.
    expect(source.contains('counselor_profile_'), isFalse);
  });
}
