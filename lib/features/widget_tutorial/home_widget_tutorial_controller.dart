import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gad_app_team/features/widget_tutorial/home_widget_tutorial_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeWidgetTutorialController {
  static const int unlockWeek = 2;
  static const String _seenKeyPrefix = 'widget_tutorial_seen';

  static const List<HomeWidgetTutorialStep> tutorialSteps = [
    HomeWidgetTutorialStep(
      imageAsset: 'assets/image/widget_tutorial_1.png',
      title: '위젯 추가하기(1)',
      description: '홈 화면 빈 공간을 길게 눌러서 메뉴를 열어주세요.',
    ),
    HomeWidgetTutorialStep(
      imageAsset: 'assets/image/widget_tutorial_2.png',
      title: '위젯 추가하기(2)',
      description: '메뉴에서 Widget(위젯)을 찾아 클릭해 주세요.',
    ),
    HomeWidgetTutorialStep(
      imageAsset: 'assets/image/widget_tutorial_3.png',
      title: 'Mindrium 위젯 찾기',
      description: '위젯 목록에서 Mindrium을 찾아 선택합니다.',
    ),
    HomeWidgetTutorialStep(
      imageAsset: 'assets/image/widget_tutorial_4.png',
      title: '위젯 크기 고르기',
      description: '위젯 크기를 고른 뒤 클릭해 주세요.',
    ),
    HomeWidgetTutorialStep(
      imageAsset: 'assets/image/widget_tutorial_5.png',
      title: '위젯 추가하기',
      description: '[+ Add] 버튼을 눌러 홈 화면에 위젯을 추가해 주세요. ',
    ),
    HomeWidgetTutorialStep(
      imageAsset: 'assets/image/widget_tutorial_6.png',
      title: '위젯 사용하기',
      description: '홈 화면에서 진행 현황을 확인하세요.\n클릭 시 불안 해결하기 활동을 진행할 수 있어요.',
    ),
  ];

  bool _checkScheduled = false;
  bool _shownThisSession = false;

  void scheduleIfEligible({
    required BuildContext context,
    required int completedWeeks,
    required String userId,
  }) {
    final normalizedUserId = userId.trim();
    if (!_isEligible(
      completedWeeks: completedWeeks,
      normalizedUserId: normalizedUserId,
    )) {
      return;
    }

    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showOnceIfNeeded(context: context, userId: normalizedUserId));
    });
  }

  bool _isEligible({
    required int completedWeeks,
    required String normalizedUserId,
  }) {
    if (_shownThisSession || _checkScheduled) return false;
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    if (completedWeeks < unlockWeek) return false;
    if (normalizedUserId.isEmpty) return false;
    return true;
  }

  Future<void> _showOnceIfNeeded({
    required BuildContext context,
    required String userId,
  }) async {
    _checkScheduled = false;
    if (!context.mounted || _shownThisSession) return;

    final prefs = await SharedPreferences.getInstance();
    final seenKey = '$_seenKeyPrefix.$userId';
    final alreadySeen = prefs.getBool(seenKey) ?? false;
    if (alreadySeen || !context.mounted) return;

    await prefs.setBool(seenKey, true);
    if (!context.mounted) return;

    _shownThisSession = true;
    await HomeWidgetTutorialDialog.show(context, steps: tutorialSteps);
  }
}
