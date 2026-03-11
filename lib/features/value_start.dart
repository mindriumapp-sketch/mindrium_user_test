import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';
// import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/blue_white_card.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';

class ValueStartScreen extends StatefulWidget {
  final int weekNumber;
  final String weekTitle;
  final String weekDescription;
  final Widget Function() nextPageBuilder;

  const ValueStartScreen({
    super.key,
    required this.weekNumber,
    required this.weekTitle,
    required this.weekDescription,
    required this.nextPageBuilder,
  });

  @override
  State<ValueStartScreen> createState() => _ValueStartScreenState();
}

class _ValueStartScreenState extends State<ValueStartScreen> {
  static const Color _navy = Color(0xFF263C69);
  static const Color _blue = Color(0xFF339DF1);

  void _goNextOrStart() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => widget.nextPageBuilder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final double maxCardWidth = MediaQuery.of(context).size.width - 34 * 2;

    // ✅ 아직 유저 정보 안 들어온 케이스 방어
    if (!user.isUserLoaded) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // TODO: 핵심 가치 수정은 마이페이지에서만 가능하게 둘지 여부 (설명 문구 추가할지 등)
    final String valueGoal = (user.valueGoal != null &&
        user.valueGoal!.trim().isNotEmpty)
        ? user.valueGoal!.trim()
        : '행복 가족 건강';

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      appBar: CustomAppBar(title: '${widget.weekNumber}주차 - 시작하기'),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.65,
              child: Image.asset(
                'assets/image/eduhome.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: _WelcomePage(
                    maxWidth: maxCardWidth,
                    navy: _navy,
                    blue: _blue,
                    value: valueGoal,
                    weekDescription: widget.weekDescription,
                    guideTitle: '${widget.weekNumber}주차 활동 안내',
                    weekNumber: widget.weekNumber,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(34, 0, 34, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.5,
                            ),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            '이 전',
                            style: TextStyle(
                              color: Colors.black38,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _goNextOrStart,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            '다 음',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
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
    );
  }
}

class _OutlinedCard extends StatelessWidget {
  final Widget child;
  const _OutlinedCard({required this.child});

  static const double _radius = 22;
  static const double _borderWidth = 4.0;
  static const Color _borderColor = Color(0xFF7EB9FF);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _borderColor, width: _borderWidth),
        boxShadow: const [
          BoxShadow(
            color: Color(0x29000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: child,
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final double maxWidth;
  final Color navy;
  final Color blue;
  final String value;
  final String weekDescription;
  final String guideTitle;
  final int weekNumber;

  const _WelcomePage({
    required this.maxWidth,
    required this.navy,
    required this.blue,
    required this.value,
    required this.weekDescription,
    required this.guideTitle,
    required this.weekNumber,
  });

  static const double _badgeWidth = 254.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 0, 34, 0),
      child: Center(
        child: _OutlinedCard(
          child: BlueWhiteCard(
            maxWidth: maxWidth,
            title: guideTitle,
            titleStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF263C69),
            ),
            outerColor: Colors.transparent,
            outerRadius: 22,
            outerExpand: EdgeInsets.zero,
            innerColor: Colors.white,
            innerRadius: 20,
            innerPadding:
            const EdgeInsets.fromLTRB(28, 26, 28, 26),
            dividerColor: const Color(0xFFE8EDF4),
            dividerWidth: 240,
            titleTopGap: 10,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 36,
                      child: Container(
                        width: _badgeWidth,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1F000000),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: navy,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: _badgeWidth,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: blue,
                        borderRadius: BorderRadius.zero,
                      ),
                      child: const Text(
                        '당신의 핵심 가치',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 80),
                Image.asset(
                  weekNumber == 8
                      ? 'assets/image/jellyfish_8th.png'
                      : 'assets/image/pink3.png',
                  height: 150,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Text(
                  protectKoreanWords(weekDescription),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: navy,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}
