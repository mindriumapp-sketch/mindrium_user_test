import 'package:gad_app_team/utils/text_line_material.dart';

Color week4BeliefTrackColor(double value) {
  if (value <= 2) return const Color(0xFF41A665);
  if (value >= 8) return const Color(0xFFE66A57);
  return const Color(0xFFF0AF3D);
}

class Week4BeliefContextPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final String situationText;
  final String beliefText;
  final String? badgeText;
  final String footerText;

  const Week4BeliefContextPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.situationText,
    required this.beliefText,
    this.badgeText,
    required this.footerText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF263C69),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Color(0xFF708399),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF6FBFF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFCFE3F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '지금 떠올릴 장면',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF34577A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _BeliefContextLine(label: '상황', value: situationText),
              const SizedBox(height: 10),
              _BeliefContextLine(
                label: '생각',
                value: beliefText,
                emphasize: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          footerText,
          style: const TextStyle(
            fontSize: 14,
            height: 1.55,
            color: Color(0xFF6C7F92),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class Week4BeliefSliderPanel extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const Week4BeliefSliderPanel({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final trackColor = week4BeliefTrackColor(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          decoration: BoxDecoration(
            color: trackColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: trackColor.withValues(alpha: 0.22)),
          ),
          child: Column(
            children: [
              Text(
                '${value.round()}',
                style: TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                  color: trackColor,
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackShape: const RoundedRectSliderTrackShape(),
            trackHeight: 12,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 14,
              elevation: 2,
              pressedElevation: 4,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            tickMarkShape: SliderTickMarkShape.noTickMark,
            activeTickMarkColor: Colors.transparent,
            inactiveTickMarkColor: Colors.transparent,
            activeTrackColor: trackColor,
            inactiveTrackColor: trackColor.withValues(alpha: 0.25),
            thumbColor: trackColor,
            overlayColor: trackColor.withValues(alpha: 0.22),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 10,
            divisions: 10,
            label: value.round().toString(),
            activeColor: trackColor,
            inactiveColor: trackColor.withValues(alpha: 0.25),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 4),
        const Row(
          children: [
            Expanded(
              child: _BeliefScaleMark(
                score: '0',
                label: '전혀 안 믿음',
                alignment: TextAlign.left,
              ),
            ),
            Expanded(
              child: _BeliefScaleMark(
                score: '5',
                label: '반반',
                alignment: TextAlign.center,
              ),
            ),
            Expanded(
              child: _BeliefScaleMark(
                score: '10',
                label: '매우 강함',
                alignment: TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BeliefContextLine extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _BeliefContextLine({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6E86A0),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 18 : 16,
            height: 1.55,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color:
                emphasize ? const Color(0xFF263C69) : const Color(0xFF395B7F),
          ),
        ),
      ],
    );
  }
}

class _BeliefScaleMark extends StatelessWidget {
  final String score;
  final String label;
  final TextAlign alignment;

  const _BeliefScaleMark({
    required this.score,
    required this.label,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignment == TextAlign.left
              ? CrossAxisAlignment.start
              : alignment == TextAlign.right
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.center,
      children: [
        Text(
          score,
          textAlign: alignment,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF48627D),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: alignment,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF7A8DA1),
          ),
        ),
      ],
    );
  }
}
