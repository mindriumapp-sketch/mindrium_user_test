import 'package:flutter/material.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';

class SudRatingTone {
  const SudRatingTone({
    required this.accent,
    required this.caption,
    required this.icon,
  });

  final Color accent;
  final String caption;
  final IconData icon;

  static const _green = Color(0xFF4CAF50);
  static const _yellow = Color(0xFFFFC107);
  static const _red = Color(0xFFF44336);

  factory SudRatingTone.fromValue(int value, {bool pastTense = false}) {
    if (value <= 2) {
      return SudRatingTone(
        accent: _green,
        caption: pastTense ? '평온했어요' : '평온해요',
        icon: Icons.sentiment_very_satisfied,
      );
    }
    if (value <= 4) {
      return SudRatingTone(
        accent: _yellow,
        caption: pastTense ? '약간 불안했어요' : '약간 불안해요',
        icon: Icons.sentiment_neutral,
      );
    }
    if (value <= 6) {
      return SudRatingTone(
        accent: _yellow,
        caption: pastTense ? '조금 불안했어요' : '조금 불안해요',
        icon: Icons.sentiment_neutral,
      );
    }
    if (value <= 8) {
      return SudRatingTone(
        accent: _yellow,
        caption: pastTense ? '불안했어요' : '불안해요',
        icon: Icons.sentiment_neutral,
      );
    }
    return SudRatingTone(
      accent: _red,
      caption: pastTense ? '많이 불안했어요' : '많이 불안해요',
      icon: Icons.sentiment_very_dissatisfied_sharp,
    );
  }
}

class SudRatingContent extends StatelessWidget {
  const SudRatingContent({
    super.key,
    required this.value,
    required this.onChanged,
    this.isPastTense = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool isPastTense;

  @override
  Widget build(BuildContext context) {
    final tone = SudRatingTone.fromValue(value, pastTense: isPastTense);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w900,
            color: tone.accent,
          ),
        ),
        const SizedBox(height: 8),
        Icon(tone.icon, size: 120, color: tone.accent),
        const SizedBox(height: 6),
        Text(
          protectKoreanWords(tone.caption),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackShape: const RoundedRectSliderTrackShape(),
                trackHeight: 14,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 13,
                  elevation: 2,
                  pressedElevation: 4,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
                tickMarkShape: SliderTickMarkShape.noTickMark,
                activeTickMarkColor: Colors.transparent,
                inactiveTickMarkColor: Colors.transparent,
                activeTrackColor: tone.accent,
                inactiveTrackColor: tone.accent.withValues(alpha: 0.22),
                thumbColor: tone.accent,
                overlayColor: tone.accent.withValues(alpha: 0.16),
                showValueIndicator: ShowValueIndicator.onDrag,
                valueIndicatorColor: tone.accent,
                valueIndicatorTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Slider(
                value: value.toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                label: '$value',
                onChanged: (nextValue) => onChanged(nextValue.round()),
              ),
            ),
            const Row(
              children: [
                Text('불안하지 않음', style: TextStyle(color: Colors.black87)),
                Spacer(),
                Text('불안함', style: TextStyle(color: Colors.black87)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
