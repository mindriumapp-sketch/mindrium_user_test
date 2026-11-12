import 'package:gad_app_team/data/counseling/counseling_models.dart';

import 'counseling_state.dart';

/// 현재 상담의 대화와 진행 상태.
class CounselingSessionState {
  final String sessionId;

  /// 사용자가 현재 진행 중인 프로그램 주차.
  final int currentWeek;

  /// 세션 시작 시 한 번 만들어 두는 사용자 컨텍스트.
  /// 턴마다 다시 조회하지 않고, 새 기록이 생긴 경우에만 명시적으로 갈아끼운다.
  MindriumCounselingContext? userContext;

  CounselingState state;
  int turnsInCurrentState;
  int totalTurns;
  final List<CounselingMessage> messages;
  String? summary;

  CounselingSessionState({
    required this.sessionId,
    required this.currentWeek,
    this.userContext,
    this.state = CounselingState.checkIn,
    this.turnsInCurrentState = 0,
    this.totalTurns = 0,
    List<CounselingMessage>? messages,
    this.summary,
  }) : messages = messages ?? [];
}
