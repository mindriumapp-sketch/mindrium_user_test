import 'package:gad_app_team/utils/text_line_material.dart';

/// 🌊 Mindrium 메뉴 디자인 (의미적 색상 시스템 적용)
class TreatmentDesign extends StatelessWidget {
  final String? appBarTitle;
  final int currentWeek;
  final int? lastCompleted;
  final List<Map<String, String>> weekContents;
  final List<Widget> weekScreens;
  final List<bool> enabledList;
  final Set<int> completedWeeks;
  final Set<int> cbtCompletedWeeks;
  final Set<int> relaxationCompletedWeeks;
  final Set<int> expandedWeeks;
  final ValueChanged<int>? onToggleWeek;
  final ScrollController? scrollController;
  /// true면 모든 주차를 활성화 (미래 주차 잠금 해제)
  final bool unlockAllWeeks;

  const TreatmentDesign({
    super.key,
    this.appBarTitle,
    required this.currentWeek,
    this.lastCompleted,
    required this.weekContents,
    required this.weekScreens,
    required this.enabledList,
    this.completedWeeks = const <int>{},
    this.cbtCompletedWeeks = const <int>{},
    this.relaxationCompletedWeeks = const <int>{},
    this.expandedWeeks = const <int>{},
    this.onToggleWeek,
    this.scrollController,
    this.unlockAllWeeks = false,
  }) : assert(
         weekContents.length == weekScreens.length,
         'weekContents와 weekScreens 길이가 다릅니다.',
       ),
       assert(
         weekContents.length == enabledList.length,
         'weekContents와 enabledList 길이가 다릅니다.',
       );

  @override
  Widget build(BuildContext context) {
    final mindriumColors = _MindriumColors();
    const totalWeeks = 8;
    final doneCount = (lastCompleted ?? completedWeeks.length).clamp(
      0,
      totalWeeks,
    );

    return Scaffold(
      backgroundColor: mindriumColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/image/eduhome.png', fit: BoxFit.cover),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xAAFFFFFF), Color(0x66FFFFFF)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    (appBarTitle?.isNotEmpty ?? false)
                        ? appBarTitle!
                        : '마인드리움 교육 활동',
                    style: const TextStyle(
                      fontFamily: 'Noto Sans KR',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildProgressHeader(
                    c: mindriumColors,
                    doneCount: doneCount,
                    totalWeeks: totalWeeks,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 120),
                      itemCount: weekContents.length,
                      itemBuilder: (context, index) {
                        final week = weekContents[index];
                        final enabled = enabledList[index];
                        final weekNo = index + 1;
                        final isCurrent = weekNo == currentWeek;
                        final isFuture = weekNo > currentWeek;
                        final summary =
                            week['summary'] ?? week['subtitle'] ?? '';
                        final session1Name =
                            week['session1Name'] ?? '불안에 대한 교육';
                        final session1Duration =
                            week['session1Duration'] ?? '약 10분';
                        final session2Name = week['session2Name'] ?? '점진적 이완';
                        final session2Duration =
                            week['session2Duration'] ?? '약 20분';

                        return _buildWeekCard(
                          context,
                          title: week['title']!,
                          summary: summary,
                          session1Name: session1Name,
                          session1Duration: session1Duration,
                          session2Name: session2Name,
                          session2Duration: session2Duration,
                          screen: weekScreens[index],
                          enabled: enabled,
                          c: mindriumColors,
                          weekNo: weekNo,
                          isCurrentWeek: isCurrent,
                          isExpanded: expandedWeeks.contains(weekNo),
                          isFutureWeek: unlockAllWeeks ? false : isFuture,
                          appliedDone: relaxationCompletedWeeks.contains(
                            weekNo,
                          ),
                          cbtDone: cbtCompletedWeeks.contains(weekNo),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekCard(
    BuildContext context, {
    required String title,
    required String summary,
    required String session1Name,
    required String session1Duration,
    required String session2Name,
    required String session2Duration,
    required Widget screen,
    required bool enabled,
    required _MindriumColors c,
    required int weekNo,
    required bool isCurrentWeek,
    required bool isExpanded,
    required bool isFutureWeek,
    required bool appliedDone,
    required bool cbtDone,
  }) {
    final canOpenWeek = !isFutureWeek;
    final continueLabel =
        (!isCurrentWeek || (appliedDone && cbtDone)) ? '복습하기' : '이어하기';
    final weekGap = weekNo - currentWeek;
    final actionLabel = isFutureWeek ? '$weekGap주 후에 하기' : continueLabel;

    return GestureDetector(
      onTap: () => onToggleWeek?.call(weekNo),
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color:
                isFutureWeek
                    ? const Color(0xFFE8ECF1)
                    : Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isFutureWeek
                      ? const Color(0xFFD1D8E0)
                      : const Color(0xFFE3F2FD),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: c.shadow.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Noto Sans KR',
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: c.titleText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            summary,
                            style: TextStyle(
                              fontFamily: 'Noto Sans KR',
                              fontSize: 14,
                              color: c.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color:
                          isFutureWeek
                              ? const Color(0xFF8D98A5)
                              : const Color(0xFF5B9FD3),
                      size: 22,
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap:
                        canOpenWeek
                            ? () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => screen),
                            )
                            : null,
                    child: _buildSessionRow(
                      c: c,
                      title: session1Name,
                      duration: session1Duration,
                      done: cbtDone,
                      enabled: isCurrentWeek,
                      showStatusBadge: canOpenWeek,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap:
                        canOpenWeek
                            ? () => Navigator.pushNamed(
                              context,
                              '/relaxation_education',
                              arguments: {
                                'taskId': 'week${weekNo}_education',
                                'weekNumber': weekNo,
                                'mp3Asset': 'week$weekNo.mp3',
                                'riveAsset': 'week$weekNo.riv',
                              },
                            )
                            : null,
                    child: _buildSessionRow(
                      c: c,
                      title: session2Name,
                      duration: session2Duration,
                      done: appliedDone,
                      enabled: canOpenWeek,
                      showStatusBadge: canOpenWeek,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          canOpenWeek
                              ? () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => screen),
                              )
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isFutureWeek
                                ? const Color(0xFF8D98A5)
                                : const Color(0xFF5B9FD3),
                        disabledBackgroundColor: const Color(0xFF8D98A5),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        actionLabel,
                        style: const TextStyle(
                          fontFamily: 'Noto Sans KR',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressHeader({
    required _MindriumColors c,
    required int doneCount,
    required int totalWeeks,
  }) {
    final progress = totalWeeks == 0 ? 0.0 : doneCount / totalWeeks;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3F2FD), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: c.shadow.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$doneCount/$totalWeeks주 진행 중',
                  style: TextStyle(
                    fontFamily: 'Noto Sans KR',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: c.titleText,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontFamily: 'Noto Sans KR',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF5B9FD3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionRow({
    required _MindriumColors c,
    required String title,
    required String duration,
    required bool done,
    required bool enabled,
    required bool showStatusBadge,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFF7FCFF) : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3F2FD), width: 1.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$title · $duration',
              style: TextStyle(
                fontFamily: 'Noto Sans KR',
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: enabled ? c.textPrimary : const Color(0xFF7F8895),
              ),
            ),
          ),
          if (showStatusBadge)
            _buildBadge(
              text: done ? '완료' : '미완료',
              bg:
                  done
                      ? Colors.green.withValues(alpha: 0.16)
                      : Colors.orange.withValues(alpha: 0.16),
              fg: done ? Colors.green.shade900 : Colors.orange.shade900,
            ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required String text,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Noto Sans KR',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _MindriumColors {
  final Color background = HSLColor.fromAHSL(1, 210, 0.7, 0.98).toColor();
  final Color textPrimary = const Color(0xFF232323);
  final Color textSecondary = Colors.black54;
  final Color titleText = const Color(0xFF1E355B);
  final Color shadow = const Color(0xFF000000);
}
