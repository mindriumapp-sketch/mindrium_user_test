// 📊 Mindrium ReportScreen — 치료 진행 상황 리포트
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: CustomAppBar(
        title: '리포트',
        showHome: true,
        titleTextStyle: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 전체 진행률 카드
            _buildProgressCard(),
            const SizedBox(height: 24),

            // 일기 작성 요약 카드 (클릭 가능)
            _buildSummaryCard(
              context,
              title: '일기 작성 통계',
              icon: Icons.edit_note_rounded,
              mainValue: '42개',
              subValue: '이번 주 5개',
              color: const Color(0xFFFFD93D),
              onTap: () => _showDiaryDetailSheet(context),
            ),
            const SizedBox(height: 16),

            // SUD 점수 요약 카드 (클릭 가능)
            _buildSummaryCard(
              context,
              title: 'SUD 점수 분석',
              icon: Icons.bar_chart_rounded,
              mainValue: '6.2점',
              subValue: '지난 주 대비 -18%',
              color: const Color(0xFFEF4444),
              onTap: () => _showSudDetailSheet(context),
            ),
            const SizedBox(height: 16),

            // 칩 사용 요약 카드 (클릭 가능)
            _buildSummaryCard(
              context,
              title: '사용한 칩 통계',
              icon: Icons.psychology_rounded,
              mainValue: '187개',
              subValue: '가장 많이 사용: 걱정',
              color: const Color(0xFF6EE7B7),
              onTap: () => _showChipDetailSheet(context),
            ),
            const SizedBox(height: 16),

            // 이완 훈련 요약 카드 (클릭 가능)
            _buildSummaryCard(
              context,
              title: '이완 훈련 통계',
              icon: Icons.self_improvement_rounded,
              mainValue: '28회',
              subValue: '총 3시간 24분',
              color: const Color(0xFF93C5FD),
              onTap: () => _showRelaxationDetailSheet(context),
            ),
            const SizedBox(height: 16),

            // 걸정 그룹 요약 카드 (클릭 가능)
            _buildSummaryCard(
              context,
              title: '걱정 그룹 통계',
              icon: Icons.folder_rounded,
              mainValue: '8개',
              subValue: '보관함 3개',
              color: const Color(0xFFFBBF24),
              onTap: () => _showWorryGroupDetailSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F2937), Color(0xFF374151)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '전체 진행률',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '5주차 / 8주차',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: 5 / 8,
                        minHeight: 12,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFFD93D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD93D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '62.5%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 요약 카드 위젯
  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String mainValue,
    required String subValue,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD1D5DB),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    mainValue,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subValue,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: color.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // 일기 상세 바텀시트
  void _showDiaryDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder:
                (context, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF1F2937),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4B5563),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              color: Color(0xFFFFD93D),
                              size: 28,
                            ),
                            SizedBox(width: 12),
                            Text(
                              '일기 작성 상세',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            _buildStatRow(
                              '총 작성한 일기',
                              '42개',
                              Icons.edit_note_rounded,
                              Colors.white,
                              const Color(0xFFFFD93D),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              '주차별 작성 현황',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildWeeklyDiaryGraph(),
                            const SizedBox(height: 24),
                            const Text(
                              '추가 통계',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildStatRow(
                              '평균 작성 시간',
                              '8분 23초',
                              Icons.timer_rounded,
                              Colors.white,
                              const Color(0xFFFFD93D),
                            ),
                            const SizedBox(height: 16),
                            _buildStatRow(
                              '가장 많이 작성한 요일',
                              '화요일',
                              Icons.event_rounded,
                              Colors.white,
                              const Color(0xFFFFD93D),
                            ),
                            const SizedBox(height: 16),
                            _buildStatRow(
                              '연속 작성 일수',
                              '12일',
                              Icons.local_fire_department_rounded,
                              Colors.white,
                              const Color(0xFFFFD93D),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  // 칩 상세 바텀시트
  void _showChipDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder:
                (context, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF1F2937),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4B5563),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.psychology_rounded,
                              color: Color(0xFF6EE7B7),
                              size: 28,
                            ),
                            SizedBox(width: 12),
                            Text(
                              '사용한 칩 상세',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            _buildStatRow(
                              '총 사용한 칩',
                              '187개',
                              Icons.analytics_rounded,
                              Colors.white,
                              const Color(0xFF6EE7B7),
                            ),
                            const SizedBox(height: 24),
                            // A (Activation)
                            const Text(
                              'A - 활성화 사건',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFFD93D),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildChipStatRow(
                              '학업',
                              '18회',
                              const Color(0xFFFFD93D),
                            ),
                            const SizedBox(height: 8),
                            _buildChipStatRow(
                              '대인관계',
                              '15회',
                              const Color(0xFFFFD93D),
                            ),
                            const SizedBox(height: 8),
                            _buildChipStatRow(
                              '건강',
                              '12회',
                              const Color(0xFFFFD93D),
                            ),
                            const SizedBox(height: 20),
                            // B (Belief)
                            const Text(
                              'B - 생각/신념',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF93C5FD),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildChipStatRow(
                              '걱정',
                              '32회',
                              const Color(0xFF93C5FD),
                            ),
                            const SizedBox(height: 8),
                            _buildChipStatRow(
                              '불안',
                              '28회',
                              const Color(0xFF93C5FD),
                            ),
                            const SizedBox(height: 8),
                            _buildChipStatRow(
                              '두려움',
                              '21회',
                              const Color(0xFF93C5FD),
                            ),
                            const SizedBox(height: 20),
                            // C (Consequence)
                            const Text(
                              'C - 결과 (감정/신체/행동)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6EE7B7),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildChipStatRow(
                              '초조함',
                              '24회',
                              const Color(0xFF6EE7B7),
                            ),
                            const SizedBox(height: 8),
                            _buildChipStatRow(
                              '긴장',
                              '18회',
                              const Color(0xFF6EE7B7),
                            ),
                            const SizedBox(height: 8),
                            _buildChipStatRow(
                              '회피',
                              '19회',
                              const Color(0xFF6EE7B7),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  // SUD 상세 바텀시트
  void _showSudDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder:
                (context, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF1F2937),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4B5563),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.bar_chart_rounded,
                              color: Color(0xFFEF4444),
                              size: 28,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'SUD 점수 상세',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            _buildStatRow(
                              '전체 평균 SUD 점수',
                              '6.2점',
                              Icons.bar_chart_rounded,
                              Colors.white,
                              const Color(0xFFEF4444),
                            ),
                            const SizedBox(height: 20),
                            _buildStatRow(
                              '최고 SUD 점수',
                              '9점',
                              Icons.arrow_upward_rounded,
                              Colors.white,
                              const Color(0xFFEF4444),
                            ),
                            const SizedBox(height: 20),
                            _buildStatRow(
                              '최저 SUD 점수',
                              '2점',
                              Icons.arrow_downward_rounded,
                              Colors.white,
                              const Color(0xFF6EE7B7),
                            ),
                            const SizedBox(height: 24),
                            // 주차별 평균 SUD 그래프
                            const Text(
                              '주차별 평균 SUD 점수',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildWeeklySudGraph(),
                            const SizedBox(height: 24),
                            const Text(
                              'SUD 점수 변동 추이',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildSudTrendGraph(),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF059669),
                                    Color(0xFF10B981),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.trending_down_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'SUD 점수 감소율',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          '지난 주 대비 -18%',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '치료가 효과적으로 진행되고 있어요!',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white.withValues(
                                              alpha: 0.8,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  // 이완 훈련 상세 바텀시트
  void _showRelaxationDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder:
                (context, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF1F2937),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4B5563),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.self_improvement_rounded,
                              color: Color(0xFF93C5FD),
                              size: 28,
                            ),
                            SizedBox(width: 12),
                            Text(
                              '이완 훈련 상세',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            _buildStatRow(
                              '총 훈련 횟수',
                              '28회',
                              Icons.self_improvement_rounded,
                              Colors.white,
                              const Color(0xFF93C5FD),
                            ),
                            const SizedBox(height: 20),
                            _buildStatRow(
                              '이번 주 훈련',
                              '4회',
                              Icons.calendar_today_rounded,
                              Colors.white,
                              const Color(0xFF93C5FD),
                            ),
                            const SizedBox(height: 20),
                            _buildStatRow(
                              '총 훈련 시간',
                              '3시간 24분',
                              Icons.timer_rounded,
                              Colors.white,
                              const Color(0xFF93C5FD),
                            ),
                            const SizedBox(height: 20),
                            _buildStatRow(
                              '평균 훈련 시간',
                              '7분 17초',
                              Icons.timelapse_rounded,
                              Colors.white,
                              const Color(0xFF93C5FD),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _buildChipStatRow(String label, String value, Color accentColor) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFFD1D5DB),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: accentColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(
    String label,
    String value,
    IconData icon,
    Color labelColor,
    Color accentColor,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: accentColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: labelColor,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: accentColor,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyDiaryGraph() {
    final weeklyData = [6, 8, 7, 9, 7, 5, 4, 3];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 170,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(8, (index) {
                final count = weeklyData[index];
                final height = (count / 10.0) * 120;
                final color = const Color(0xFFFFD93D);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$count개',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 32,
                      height: height,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${index + 1}주',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // SUD 추이 그래프 (라인 그래프 느낌)
  Widget _buildSudTrendGraph() {
    final weeklyData = [7.8, 7.2, 6.9, 6.5, 6.0, 5.6];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              final score = weeklyData[index];
              final height = (score / 10.0) * 120;
              final color =
                  score >= 7.0
                      ? const Color(0xFFEF4444)
                      : score >= 5.0
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFF6EE7B7);

              return Column(
                children: [
                  Text(
                    score.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 32,
                    height: height,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${index + 1}주',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // 걱정 그룹 상세 바텀시트
  void _showWorryGroupDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder:
                (context, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF1F2937),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4B5563),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.folder_rounded,
                              color: Color(0xFFFBBF24),
                              size: 28,
                            ),
                            SizedBox(width: 12),
                            Text(
                              '걱정 그룹 상세',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            _buildStatRow(
                              '총 걱정 그룹',
                              '8개',
                              Icons.folder_rounded,
                              Colors.white,
                              const Color(0xFFFBBF24),
                            ),
                            const SizedBox(height: 20),
                            _buildStatRow(
                              '활성 그룹',
                              '5개',
                              Icons.folder_open_rounded,
                              Colors.white,
                              const Color(0xFFFBBF24),
                            ),
                            const SizedBox(height: 20),
                            _buildStatRow(
                              '보관함 그룹',
                              '3개',
                              Icons.archive_rounded,
                              Colors.white,
                              const Color(0xFF6EE7B7),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              '그룹별 일기 수',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildGroupDiaryRow(
                              '학업 스트레스',
                              12,
                              const Color(0xFFFBBF24),
                            ),
                            const SizedBox(height: 12),
                            _buildGroupDiaryRow(
                              '대인관계',
                              9,
                              const Color(0xFFFBBF24),
                            ),
                            const SizedBox(height: 12),
                            _buildGroupDiaryRow(
                              '건강 걱정',
                              8,
                              const Color(0xFFFBBF24),
                            ),
                            const SizedBox(height: 12),
                            _buildGroupDiaryRow(
                              '진로 고민',
                              7,
                              const Color(0xFFFBBF24),
                            ),
                            const SizedBox(height: 12),
                            _buildGroupDiaryRow(
                              '기타',
                              6,
                              const Color(0xFFFBBF24),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              '보관함 그룹',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildArchivedGroupCard('시험 불안', '2024.11.05'),
                            const SizedBox(height: 12),
                            _buildArchivedGroupCard('발표 두려움', '2024.10.28'),
                            const SizedBox(height: 12),
                            _buildArchivedGroupCard('과제 스트레스', '2024.10.15'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _buildGroupDiaryRow(String groupName, int count, Color color) {
    return Row(
      children: [
        Expanded(
          child: Text(
            groupName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFFD1D5DB),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count개',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArchivedGroupCard(String groupName, String date) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF374151),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6EE7B7).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.archive_rounded,
              color: Color(0xFF6EE7B7),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  groupName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklySudGraph() {
    final weeklyData = [
      {'week': '1주', 'score': 7.8},
      {'week': '2주', 'score': 7.2},
      {'week': '3주', 'score': 6.9},
      {'week': '4주', 'score': 6.5},
      {'week': '5주', 'score': 6.0},
      {'week': '6주', 'score': 5.6},
    ];

    final maxScore = 10.0;

    return Column(
      children:
          weeklyData.map((data) {
            final week = data['week'] as String;
            final score = data['score'] as double;
            final progress = score / maxScore;
            final color =
                score >= 7.0
                    ? const Color(0xFFEF4444)
                    : score >= 5.0
                    ? const Color(0xFFFBBF24)
                    : const Color(0xFF6EE7B7);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 45,
                    child: Text(
                      week,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD1D5DB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 20,
                        backgroundColor: const Color(0xFF374151),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 35,
                    child: Text(
                      score.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }
}
