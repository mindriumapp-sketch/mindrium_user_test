// 🪸 Mindrium TreatmentDesign — 앱바 제거 + 깔끔한 배경 + 완료/잠금 스티커 & 단일 오픈 주차 대응
import 'package:gad_app_team/utils/text_line_material.dart';

class TreatmentDesign extends StatelessWidget {
  final String appBarTitle;
  final List<Map<String, String>> weekContents;
  final List<Widget> weekScreens;

  /// ✅ 잠금/해제 상태 및 완료 주차
  final List<bool> enabledList;
  final Set<int> completedWeeks;

  const TreatmentDesign({
    super.key,
    required this.appBarTitle,
    required this.weekContents,
    required this.weekScreens,
    required this.enabledList,
    this.completedWeeks = const <int>{},
  })  : assert(weekContents.length == weekScreens.length,
          'weekContents와 weekScreens 길이가 다릅니다.'),
        assert(weekContents.length == enabledList.length,
          'weekContents와 enabledList 길이가 다릅니다.');

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          /// 🌊 배경 (HomeScreen과 동일)
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/image/eduhome.png',
                  fit: BoxFit.cover,
                ),
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

          /// 💎 본문 컨텐츠
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: size.width > 480 ? 420 : double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      /// 🪸 주차별 카드 리스트
                      for (int i = 0; i < weekContents.length; i++) ...[
                        _buildWeekCard(
                          context,
                          weekNumber: i + 1,
                          title: weekContents[i]['title'] ?? '',
                          subtitle: weekContents[i]['subtitle'] ?? '',
                          enabled: enabledList[i],                      // ✅ 잠금/해제
                          isDone: completedWeeks.contains(i + 1),       // ✅ 완료 여부
                          onTap: () {
                            // 클릭 가능 여부는 카드 내부에서 처리
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => weekScreens[i]),
                            );
                          },
                        ),
                        if (i < weekContents.length - 1)
                          const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🪸 주차별 카드 (깔끔한 흰색 + 완료/잠금 스티커/비활성화)
  Widget _buildWeekCard(
    BuildContext context, {
    required int weekNumber,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool enabled,
    bool isDone = false,
  }) {
    // ✅ 완료되었거나 잠겨있으면 클릭 불가 + 흐리게
    final bool isEnabled = enabled;
    final bool isLocked = !enabled; // 미래 주차

    // 부제목 분리(한/영)
    final parts = subtitle.split(' / ');
    final koreanText = parts.length > 1 ? parts[1] : parts[0];
    final englishText = parts.length > 1 ? parts[0] : '';

    return GestureDetector(
      onTap: isEnabled ? onTap : null, // ✅ 완료/잠금이면 탭 막기
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.45, // ✅ 흐리게
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white, // 깔끔한 흰색
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE3F2FD),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              /// 좌측: 주차 아이콘 + ✅ 완료/잠금 스티커
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildWeekCircle(title),
                  if (isDone)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha:0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 14),
                      ),
                    ),
                  if (isLocked)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha:0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.lock, color: Colors.white, size: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              /// 중앙: subtitle (한글 + 영어)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      koreanText,
                      style: const TextStyle(
                        color: Color(0xFF254B69),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (englishText != '') ...[
                      const SizedBox(height: 2),
                      Text(
                        englishText,
                        style: const TextStyle(
                          color: Color(0xFF254B69),
                          fontSize: 13,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              /// 우측: 화살표 → 열려있을 때만 표시
              if (isEnabled)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF5B9FD3),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ 주차 동그라미 아이콘
  Widget _buildWeekCircle(String title) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFC9E7FF), // 부드러운 파스텔 블루
        border: Border.all(
          color: const Color(0xFF9DD4FF),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA0CEF0).withValues(alpha:0.15),
            blurRadius: 5.5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          title, // 예: '1주차'
          style: const TextStyle(
            color: Color(0xFF4F93D6), // 은은한 블루
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}
