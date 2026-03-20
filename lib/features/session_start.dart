import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';
// import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/blue_white_card.dart';

class SessionStartScreen extends StatefulWidget {
  final int weekNumber;
  final String weekTitle;
  final String weekDescription;
  final bool mergeValueAndGuide;
  final VoidCallback? onPrevious;
  final Widget Function() nextPageBuilder;

  const SessionStartScreen({
    super.key,
    required this.weekNumber,
    required this.weekTitle,
    required this.weekDescription,
    this.mergeValueAndGuide = false,
    this.onPrevious,
    required this.nextPageBuilder,
  });

  @override
  State<SessionStartScreen> createState() => _SessionStartScreenState();
}

class _SessionStartScreenState extends State<SessionStartScreen> {
  static const Color _blue = Color(0xFF339DF1);
  static const Color _navy = Color(0xFF263C69);

  void _goNext() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => widget.nextPageBuilder()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double maxCardWidth = MediaQuery.of(context).size.width - 34 * 2;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: '${widget.weekNumber}주차 - 시작하기',
        onBack: widget.onPrevious,
      ),
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
                  child: _GuidePage(
                    maxWidth: maxCardWidth,
                    navy: _navy,
                    title: '${widget.weekNumber}주차 활동 안내',
                    subtitle: widget.weekTitle,
                    description: widget.weekDescription,
                    weekNumber: widget.weekNumber,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(34, 0, 34, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onPrevious,
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
                              color:
                                  widget.onPrevious == null
                                      ? Colors.black38
                                      : const Color(0xFF2A5D8F),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _goNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            '다 음',
                            style: TextStyle(fontWeight: FontWeight.w700),
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

class _GuidePage extends StatelessWidget {
  final double maxWidth;
  final Color navy;
  final String title;
  final String subtitle;
  final String description;
  final int weekNumber;

  const _GuidePage({
    required this.maxWidth,
    required this.navy,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.weekNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 0, 34, 0),
      child: Center(
        child: _OutlinedCard(
          child: BlueWhiteCard(
            maxWidth: maxWidth,
            title: title,
            titleStyle: TextStyle(
              color: navy,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            outerColor: Colors.transparent,
            outerRadius: 22,
            outerExpand: EdgeInsets.zero,
            innerColor: Colors.white,
            innerRadius: 20,
            innerPadding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
            dividerColor: const Color(0xFFE8EDF4),
            dividerWidth: 240,
            titleTopGap: 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Image.asset(
                  weekNumber == 8
                      ? 'assets/image/jellyfish_8th.png'
                      : 'assets/image/pink3.png',
                  height: 150,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Text(
                  protectKoreanWords(subtitle),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    decoration: TextDecoration.none,
                  ),
                ),
                if (description.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    protectKoreanWords(description),
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: navy.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
