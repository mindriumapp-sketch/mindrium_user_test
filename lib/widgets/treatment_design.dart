import 'package:gad_app_team/utils/text_line_material.dart';

/// 🌊 Mindrium 메뉴 디자인 (의미적 색상 시스템 적용)
class TreatmentDesign extends StatelessWidget {
  final List<Map<String, String>> weekContents;
  final List<Widget> weekScreens;
  final List<bool> enabledList;

  const TreatmentDesign({
    super.key,
    required this.weekContents,
    required this.weekScreens,
    required this.enabledList,
  });

  @override
  Widget build(BuildContext context) {
    // ───────────────────────────────
    // 🎨 Mindrium Color System
    // (의미 기반 변수명 + HSL/MaterialColor 톤)
    // ───────────────────────────────
    final mindriumColors = _MindriumColors();

    return Scaffold(
      backgroundColor: mindriumColors.background,
      body: Stack(
        children: [
          /// 🌊 배경 이미지
          Positioned.fill(
            child: Image.asset('assets/image/eduhome.png', fit: BoxFit.cover),
          ),

          /// ✨ 콘텐츠
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'Mindrium 교육 프로그램',
                    style: TextStyle(
                      fontFamily: 'Noto Sans KR',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: mindriumColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '주차별로 나의 성장 여정을 이어가보세요 🌱',
                    style: TextStyle(
                      fontFamily: 'Noto Sans KR',
                      fontSize: 15,
                      color: mindriumColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  /// 📋 주차 카드 리스트
                  Expanded(
                    child: ListView.builder(
                      itemCount: weekContents.length,
                      itemBuilder: (context, index) {
                        final week = weekContents[index];
                        final enabled = enabledList[index];
                        return _buildWeekCard(
                          context,
                          week['title']!,
                          week['subtitle']!,
                          weekScreens[index],
                          enabled,
                          mindriumColors,
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

  /// 🫧 주차별 카드
  Widget _buildWeekCard(
    BuildContext context,
    String title,
    String subtitle,
    Widget screen,
    bool enabled,
    _MindriumColors c,
  ) {
    return GestureDetector(
      onTap:
          enabled
              ? () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => screen),
              )
              : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c.gradientStart, c.gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: c.shadow.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
            child: Row(
              children: [
                Icon(
                  enabled ? Icons.auto_awesome : Icons.lock_outline,
                  color: Colors.white,
                  size: 30,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Noto Sans KR',
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: c.titleText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
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
                Icon(Icons.chevron_right, color: c.iconArrow, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 🎨 Mindrium 컬러 시스템 (Material + HSL 기반)
class _MindriumColors {
  // ─── Core Palette ─────────────────────
  final Color primary = const Color(0xFF6ECFF6); // Mindrium Blue
  final Color secondary = const Color(0xFF7FD8B3); // Mint
  final Color accent = const Color(0xFFFFB5A7); // Coral Pink

  // ─── Backgrounds ──────────────────────
  final Color background = HSLColor.fromAHSL(1, 210, 0.7, 0.98).toColor();
  final Color surface = Colors.white;

  // ─── Text ─────────────────────────────
  final Color textPrimary = const Color(0xFF232323);
  final Color textSecondary = Colors.black54;
  final Color titleText = const Color(0xFF1E355B);

  // ─── Icons / Shadows ──────────────────
  final Color iconArrow = Colors.white70;
  final Color shadow = const Color(0xFF000000);

  // ─── Gradient ─────────────────────────
  final Color gradientStart =
      HSLColor.fromAHSL(1, 205, 0.8, 0.9).toColor(); // 연하늘
  final Color gradientEnd =
      HSLColor.fromAHSL(1, 210, 0.7, 0.98).toColor(); // 흰빛 하늘
}
