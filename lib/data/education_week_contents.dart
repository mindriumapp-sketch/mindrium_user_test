import 'package:gad_app_team/data/today_task_provider.dart';
import 'package:gad_app_team/data/user_provider.dart';

/// 교육 탭 주차별 콘텐츠 (TreatmentScreen, MyInfoScreen 등에서 공유)
const List<Map<String, String>> educationWeekContents = [
  {
    'title': '1주차',
    'summary': '불안을 이해하고, 이완을 천천히 시작해요',
    'session1Name': '불안에 대한 교육',
    'session1Duration': '약 10분',
    'session2Name': '점진적 이완',
    'session2Duration': '약 20분',
  },
  {
    'title': '2주차',
    'summary': 'ABC로 마음을 기록하고, 이완을 복습해요',
    'session1Name': 'ABC 일기 쓰기',
    'session1Duration': '약 12분',
    'session2Name': '점진적 이완',
    'session2Duration': '약 20분',
  },
  {
    'title': '3주차',
    'summary': '불안한 생각을 구별하고, 긴장 없이 이완해요',
    'session1Name': '생각 구별하는 연습',
    'session1Duration': '약 10분',
    'session2Name': '이완만 하는 이완',
    'session2Duration': '약 10분',
  },
  {
    'title': '4주차',
    'summary': '내 생각을 바꿔보고, 신호에 맞춰 이완해요',
    'session1Name': '내 생각 점검하기',
    'session1Duration': '약 20분',
    'session2Name': '신호 조절 이완',
    'session2Duration': '약 5분',
  },
  {
    'title': '5주차',
    'summary': '불안을 마주하는 행동을 익히고, 움직이며 이완해요',
    'session1Name': '행동 구별하는 연습',
    'session1Duration': '약 10분',
    'session2Name': '차등 이완',
    'session2Duration': '약 10분',
  },
  {
    'title': '6주차',
    'summary': '내 행동을 돌아보고, 움직이며 이완을 복습해요',
    'session1Name': '내 행동 점검하기',
    'session1Duration': '약 20분',
    'session2Name': '차등 이완',
    'session2Duration': '약 10분',
  },
  {
    'title': '7주차',
    'summary': '불안할 때의 행동을 개선하고, 빠르게 이완해요',
    'session1Name': '내 행동 개선하기',
    'session1Duration': '약 20분',
    'session2Name': '신속 이완',
    'session2Duration': '약 2분',
  },
  {
    'title': '8주차',
    'summary': '8주 간의 여정을 정리하고, 빠른 이완을 복습해요',
    'session1Name': '여정 돌아보기',
    'session1Duration': '약 15분',
    'session2Name': '신속 이완',
    'session2Duration': '약 10분',
  },
];

/// 마이페이지 진행 카드용 표시 텍스트 계산
class EducationProgressDisplay {
  EducationProgressDisplay._();

  static const int totalWeeks = 8;

  /// 최근 프로그램: 완료한 주차의 교육·이완 표시
  static String recentProgram(
    UserProvider user,
    TodayTaskProvider todayTask,
  ) {
    final lastCompleted = user.lastCompletedWeek.clamp(0, totalWeeks);
    if (lastCompleted >= 1) {
      final idx = (lastCompleted - 1).clamp(0, educationWeekContents.length - 1);
      final s1 = educationWeekContents[idx]['session1Name'] ?? '교육';
      final s2 = educationWeekContents[idx]['session2Name'] ?? '이완';
      return '$lastCompleted주차\n$s1 · $s2';
    }
    return '시작 전';
  }

  /// 진행 단계: 현재 주차 + 교육·이완 완료 여부
  static String progressStage(
    UserProvider user,
    TodayTaskProvider todayTask,
  ) {
    final currentWeek = user.currentWeek.clamp(1, totalWeeks);
    final lastCompleted = user.lastCompletedWeek.clamp(0, totalWeeks);

    if (currentWeek < 1 || currentWeek > totalWeeks) return '1주차';

    final bothDoneByServer = currentWeek <= lastCompleted;
    final cbtDone = bothDoneByServer || todayTask.isCbtDoneWeek(currentWeek);
    final relaxDone =
        bothDoneByServer || todayTask.isRelaxationDoneWeek(currentWeek);

    if (cbtDone && relaxDone) return '$currentWeek주차 완료';
    if (cbtDone || relaxDone) {
      final parts = <String>[];
      if (cbtDone) parts.add('교육');
      if (relaxDone) parts.add('이완');
      return '$currentWeek주차 (${parts.join('·')} 완료)';
    }
    return '$currentWeek주차';
  }
}
