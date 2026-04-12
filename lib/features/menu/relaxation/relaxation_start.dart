import 'package:flutter/material.dart';
import 'package:gad_app_team/features/menu/education/education_page.dart';
import 'package:gad_app_team/features/menu/relaxation/relaxation_education.dart';
import 'package:gad_app_team/features/session_start.dart';
import 'package:gad_app_team/widgets/custom_popup_design.dart';

const Map<int, String> kRelaxationWeekDescriptions = {
  1: '점진적 이완으로 몸의 긴장을 천천히 풀어보겠습니다.',
  2: '점진적 이완을 복습하며 이완 감각을 안정적으로 익혀보겠습니다.',
  3: '긴장 유도 없이 이완만 하는 연습을 해보겠습니다.',
  4: '신호를 통해 이완 전환하는 법을 익혀보겠습니다.',
  5: '차등 이완으로 움직임 속에서도 이완을 유지해보겠습니다.',
  6: '차등 이완을 복습하며 일상 속 이완을 연습해보겠습니다.',
  7: '신속 이완으로 짧은 시간 안에 몸과 호흡을 안정시켜보겠습니다.',
  8: '신속 이완을 복습하며 전체 이완 루틴을 정리해보겠습니다.',
};

String relaxationDescriptionForWeek(int weekNumber) {
  return kRelaxationWeekDescriptions[weekNumber] ?? '이번 주차 이완 훈련을 시작해요.';
}

class RelaxationStartScreen extends StatelessWidget {
  final String? sessionId;
  final String taskId;
  final int weekNumber;
  final String mp3Asset;
  final String riveAsset;

  const RelaxationStartScreen({
    super.key,
    this.sessionId,
    required this.taskId,
    required this.weekNumber,
    required this.mp3Asset,
    required this.riveAsset,
  });

  @override
  Widget build(BuildContext context) {
    final useEducationBridge = weekNumber == 1 || weekNumber == 2;
    final jsonPrefix = 'week${weekNumber}_relaxation_';

    return SessionStartScreen(
      weekNumber: weekNumber,
      weekTitle: relaxationTitleForWeek(weekNumber),
      weekDescription: relaxationDescriptionForWeek(weekNumber),
      onPrevious: () {
        Navigator.pushNamedAndRemoveUntil(context, '/home_edu', (_) => false);
      },
      nextPageBuilder:
          () =>
              useEducationBridge
                  ? _RelaxationEducationBridge(
                    sessionId: sessionId,
                    taskId: taskId,
                    weekNumber: weekNumber,
                    mp3Asset: mp3Asset,
                    riveAsset: riveAsset,
                    jsonPrefix: jsonPrefix,
                  )
                  : PracticePlayer(
                    sessionId: sessionId,
                    taskId: taskId,
                    weekNumber: weekNumber,
                    mp3Asset: mp3Asset,
                    riveAsset: riveAsset,
                  ),
    );
  }
}

class _RelaxationEducationBridge extends StatelessWidget {
  final String? sessionId;
  final String taskId;
  final int weekNumber;
  final String mp3Asset;
  final String riveAsset;
  final String jsonPrefix;

  const _RelaxationEducationBridge({
    required this.sessionId,
    required this.taskId,
    required this.weekNumber,
    required this.mp3Asset,
    required this.riveAsset,
    required this.jsonPrefix,
  });

  @override
  Widget build(BuildContext context) {
    return EducationPage(
      title: '점진적 이완',
      jsonPrefixes: [jsonPrefix],
      isRelax: true,
      sessionId: sessionId,
      nextPageBuilder:
          () => _RelaxationVolumeGuideScreen(
            sessionId: sessionId,
            taskId: taskId,
            weekNumber: weekNumber,
            mp3Asset: mp3Asset,
            riveAsset: riveAsset,
          ),
    );
  }
}

class _RelaxationVolumeGuideScreen extends StatefulWidget {
  final String? sessionId;
  final String taskId;
  final int weekNumber;
  final String mp3Asset;
  final String riveAsset;

  const _RelaxationVolumeGuideScreen({
    required this.sessionId,
    required this.taskId,
    required this.weekNumber,
    required this.mp3Asset,
    required this.riveAsset,
  });

  @override
  State<_RelaxationVolumeGuideScreen> createState() =>
      _RelaxationVolumeGuideScreenState();
}

class _RelaxationVolumeGuideScreenState
    extends State<_RelaxationVolumeGuideScreen> {
  bool _dialogShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dialogShown) return;
    _dialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nav = Navigator.of(context);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (_) => CustomPopupDesign(
              title: '이완 음성 안내 시작',
              message: '잠시 후, 이완을 위한 음성 안내가 시작됩니다. 주변 소리와 음량을 조절해보세요.',
              positiveText: '확인',
              negativeText: null,
              backgroundAsset: null,
              iconAsset: null,
              onPositivePressed: () {
                nav.pop();
                nav.pushReplacement(
                  MaterialPageRoute(
                    builder:
                        (_) => PracticePlayer(
                          sessionId: widget.sessionId,
                          taskId: widget.taskId,
                          weekNumber: widget.weekNumber,
                          mp3Asset: widget.mp3Asset,
                          riveAsset: widget.riveAsset,
                        ),
                  ),
                );
              },
            ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
