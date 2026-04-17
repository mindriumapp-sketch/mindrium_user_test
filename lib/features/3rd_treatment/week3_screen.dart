import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/session_start.dart';
// week3_screen.dart
import 'package:flutter/material.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/features/3rd_treatment/week3_classification_screen.dart';

class Week3Screen extends StatefulWidget {
  final String? sessionId;
  final bool isReviewMode;
  const Week3Screen({super.key, this.sessionId, this.isReviewMode = false});

  @override
  State<Week3Screen> createState() => _Week3ScreenState();
}

class _Week3ScreenState extends State<Week3Screen> {
  bool _creatingSession = false;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.isReviewMode) {
        _maybeCreateEduSession();
      }
    });
  }

  Future<void> _maybeCreateEduSession() async {
    if (!mounted) return;

    // ✅ async 이전에만 context.read 사용 → "across async gap" 경고 대상 아님
    final user = context.read<UserProvider>();

    // 아직 유저 정보 안 들어왔으면 그냥 패스
    if (!user.isUserLoaded) return;
    if (widget.isReviewMode) return;

    // 이미 이 위젯 생명주기에서 한 번 만들었으면 또 안 함
    if (_sessionId != null && _sessionId!.isNotEmpty) {
      debugPrint('[Week1Screen] 기존 sessionId 그대로 사용: $_sessionId');
      return;
    }

    if (_creatingSession) return;
    setState(() => _creatingSession = true);

    try {
      final tokens = TokenStorage();
      final access = await tokens.access;
      if (access == null) {
        // 로그인 안 되어 있으면 그냥 로그만 찍고 교육은 계속 진행
        debugPrint('[Week3Screen] access token 없음 → edu-session 생성 스킵');
        setState(() => _creatingSession = false);
        return;
      }

      final client = ApiClient(tokens: tokens);
      final eduApi = EduSessionsApi(client);

      // ⚠️ 총 화면 수는 실제 week3 플로우에 맞게 바꿔도 됨.
      const int totalStages = 12;

      final res = await eduApi.createWeek3or5Session(
        weekNumber: 3,
        totalStages: totalStages,
        lastStageIndex: 1, // Week3Screen 진입 시점 = 1번 화면
        completed: false, // 아직 미완료
        startTime: DateTime.now(), // 지금 시간
        endTime: null,
      );

      if (!mounted) return;
      setState(() {
        _creatingSession = false;
        _sessionId = res['session_id'];
      });

      debugPrint('[Week3Screen] edu-sessions create 성공 (week=3)');
    } catch (e) {
      if (!mounted) return;
      debugPrint('[Week3Screen] edu-sessions create 실패: $e');
      setState(() => _creatingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekDescription =
        widget.isReviewMode
            ? '3주차에서는 어떤 생각이 불안에 도움이 되는지를 배우고, 내 생각을 도움이 되는 방향으로 바꾸는 연습을 했어요.\n이번에는 그 내용을 복습해보겠습니다.'
            : '이번 주차에서는 어떤 생각이 불안에 도움 되는지를 배우고, 내 생각을 도움이 되는 방향으로 바꿔보겠습니다.';

    // 👉 UI/분기는 기존이랑 동일하게 유지
    return SessionStartScreen(
      weekNumber: 3,
      isReviewMode: widget.isReviewMode,
      weekTitle: '불안에 도움이 되는 생각을\n알아보겠습니다.',
      weekDescription: weekDescription,
      nextPageBuilder: () => Week3ClassificationScreen(sessionId: _sessionId),
    );
  }
}
