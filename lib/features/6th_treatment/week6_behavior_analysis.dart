import 'package:flutter/material.dart';

class Week6BehaviorInsight {
  final String resultLabel;
  final Color resultBackground;
  final Color resultForeground;
  final String summary;
  final String shortTermInsight;
  final String longTermInsight;
  final List<String> reminders;

  const Week6BehaviorInsight({
    required this.resultLabel,
    required this.resultBackground,
    required this.resultForeground,
    required this.summary,
    required this.shortTermInsight,
    required this.longTermInsight,
    required this.reminders,
  });

  factory Week6BehaviorInsight.fromValues({
    required double shortTermValue,
    required double longTermValue,
  }) {
    final isShortTermHigh = shortTermValue == 10;
    final isLongTermHigh = longTermValue == 10;

    if (isShortTermHigh && !isLongTermHigh) {
      return const Week6BehaviorInsight(
        resultLabel: '회피에 가까운 행동',
        resultBackground: Color(0xFFFFF0EF),
        resultForeground: Color(0xFFC6544F),
        summary: '당장은 편해질 수 있지만, 장기적으로는 불안을 해결하는 데 큰 도움이 되지 않을 수 있어요.',
        shortTermInsight: '지금 이 행동은 불안을 빠르게 낮춰주는 것처럼 느껴질 가능성이 높아요.',
        longTermInsight: '하지만 같은 불안을 다시 만나면 또 피하고 싶어질 수 있어요.',
        reminders: [
          '당장의 안도감이 있다고 해서 항상 도움이 되는 행동은 아니에요.',
          '이 행동 없이도 버틸 수 있는 연습이 함께 필요할 수 있어요.',
        ],
      );
    }

    if (!isShortTermHigh && isLongTermHigh) {
      return const Week6BehaviorInsight(
        resultLabel: '직면에 가까운 행동',
        resultBackground: Color(0xFFE8F7F1),
        resultForeground: Color(0xFF2E7D5B),
        summary: '당장은 불편할 수 있지만, 시간이 지나면 불안을 다루는 데 더 도움이 되는 행동일 가능성이 커요.',
        shortTermInsight: '지금은 긴장되거나 덜 편안하게 느껴질 수 있어요.',
        longTermInsight: '그래도 반복할수록 불안을 견디는 힘을 기르는 데 도움이 될 수 있어요.',
        reminders: [
          '처음엔 어렵게 느껴져도 직면 행동은 장기적으로 의미가 있을 수 있어요.',
          '당장의 불편함과 장기적 도움은 서로 다를 수 있다는 점을 기억해 주세요.',
        ],
      );
    }

    if (isShortTermHigh && isLongTermHigh) {
      return const Week6BehaviorInsight(
        resultLabel: '다시 점검이 필요한 행동',
        resultBackground: Color(0xFFFFF8E7),
        resultForeground: Color(0xFF9A6B00),
        summary: '단기와 장기 모두 도움이 된다고 느껴졌지만, 실제로는 안전장치에 기대는 행동일 수도 있어요.',
        shortTermInsight: '당장은 편안함을 크게 줄 수 있어요.',
        longTermInsight: '하지만 이 행동이 없을 때도 괜찮은지 확인하지 않으면 도움이 과대평가될 수 있어요.',
        reminders: [
          '정말 장기적으로 도움인지, 아니면 익숙해서 편한 것인지 나눠서 보세요.',
          '이 행동 없이도 불안을 견딜 수 있는지 떠올려보면 판단이 더 쉬워져요.',
        ],
      );
    }

    return const Week6BehaviorInsight(
      resultLabel: '효과가 낮은 행동일 수 있어요',
      resultBackground: Color(0xFFF3F4F6),
      resultForeground: Color(0xFF5F6B77),
      summary: '당장도, 시간이 지나서도 불안을 줄이는 데 큰 도움이 되지 않을 가능성이 있어요.',
      shortTermInsight: '바로 편안해지는 느낌이 거의 없을 수 있어요.',
      longTermInsight: '계속 반복해도 불안을 다루는 데 이어지지 않을 수 있어요.',
      reminders: [
        '효과가 약한 행동이라면 다른 직면 행동을 찾아보는 편이 나을 수 있어요.',
        '불안을 줄이기보다 유지시키는 방식은 아닌지 같이 살펴보면 좋아요.',
      ],
    );
  }
}

class Week6BehaviorAnalysis {
  const Week6BehaviorAnalysis._();

  static String userChoiceLabel(String behaviorType) {
    return behaviorType == 'face' ? '직면하는 행동' : '회피하는 행동';
  }

  static Week6BehaviorInsight buildInsight({
    required double shortTermValue,
    required double longTermValue,
  }) {
    return Week6BehaviorInsight.fromValues(
      shortTermValue: shortTermValue,
      longTermValue: longTermValue,
    );
  }

  // 행동 돌아보기 화면에서는 안내 톤을 짧게 유지하기 위해
  // 애매한 경우를 하나의 라벨로 묶어서 보여줍니다.
  static String reflectionResultLabel({
    required double shortTermValue,
    required double longTermValue,
  }) {
    final isShortTermHigh = shortTermValue == 10;
    final isLongTermHigh = longTermValue == 10;

    if (isShortTermHigh && !isLongTermHigh) {
      return '회피에 가까운 행동';
    }
    if (!isShortTermHigh && isLongTermHigh) {
      return '직면에 가까운 행동';
    }
    return '다시 점검이 필요한 행동';
  }

  static bool isReflectionMatch({
    required String behaviorType,
    required String actualResultLabel,
  }) {
    final userChoice = userChoiceLabel(behaviorType);
    return userChoice.contains('직면') == actualResultLabel.contains('직면') ||
        userChoice.contains('회피') == actualResultLabel.contains('회피');
  }
}
