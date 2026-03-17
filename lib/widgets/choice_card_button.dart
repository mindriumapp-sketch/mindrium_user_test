// lib/widgets/choice_card_button.dart

import 'package:gad_app_team/utils/text_line_material.dart';

enum ChoiceType {
  healthy,
  anxious,
  helpful, // Week3: 도움이 되는 생각
  unhelpful, // Week3: 도움이 되지 않는 생각
  other,
  another,
}

class ChoiceCardButton extends StatelessWidget {
  final ChoiceType type;
  final VoidCallback onPressed;
  final String? othText;
  final String? anoText;
  final double height; // nullable 제거: 항상 명확한 높이

  const ChoiceCardButton({
    super.key,
    required this.type,
    required this.onPressed,
    this.othText,
    this.anoText,
    this.height = 54, // ✅ ThoughtBubble 과 비슷한 두께 (기본 54)
  });

  String get _text {
    switch (type) {
      case ChoiceType.healthy:
        return '불안 직면';
      case ChoiceType.anxious:
        return '불안 회피';
      case ChoiceType.helpful:
        return '도움이 되는 생각';
      case ChoiceType.unhelpful:
        return '도움이 되지 않는 생각';
      case ChoiceType.other:
        return othText ?? '';
      case ChoiceType.another:
        return anoText ?? '';
    }
  }

  Color get _backgroundColor {
    switch (type) {
      case ChoiceType.healthy:
      case ChoiceType.helpful:
      case ChoiceType.other:
        return const Color(0xFF329CF1); // 파랑
      case ChoiceType.anxious:
      case ChoiceType.unhelpful:
      case ChoiceType.another:
        return const Color(0xFFFDB0B5); // 핑크
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(height / 2),
            child: Center(
              child: Text(
                _text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  fontFamily: 'Noto Sans KR',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SelectableChoiceCardButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final bool isSelected;
  final bool isDimmed;
  final VoidCallback onPressed;
  final double height;

  const SelectableChoiceCardButton({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.isSelected,
    required this.isDimmed,
    required this.onPressed,
    this.height = 58,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBackground =
        isDimmed ? const Color(0xFFDCE5EB) : backgroundColor;
    final shadowColor =
        isSelected
            ? backgroundColor.withValues(alpha: 0.34)
            : Colors.black.withValues(alpha: 0.08);
    final scale = isSelected ? 1.0 : 0.985;
    final borderWidth = isSelected ? 2.0 : 0.0;
    final borderColor =
        isSelected ? Colors.white.withValues(alpha: 0.9) : Colors.transparent;

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: effectiveBackground,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: isSelected ? 18 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onPressed,
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDimmed ? const Color(0xFF7C8D99) : Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Noto Sans KR',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
