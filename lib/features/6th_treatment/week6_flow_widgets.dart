import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/choice_card_button.dart';

class Week6ProgressHeader extends StatelessWidget {
  final String stageLabel;
  final int currentIndex;
  final int totalCount;
  final String title;
  final String subtitle;

  const Week6ProgressHeader({
    super.key,
    required this.stageLabel,
    required this.currentIndex,
    required this.totalCount,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Week6HeaderChip(
              label: stageLabel,
              backgroundColor: const Color(0xFFE8F3FF),
              foregroundColor: const Color(0xFF2C6AA0),
            ),
            _Week6HeaderChip(
              label: '행동 $currentIndex/$totalCount',
              backgroundColor: const Color(0xFFF1F4F7),
              foregroundColor: const Color(0xFF5C6E80),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: Color(0xFF263C69),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7D90),
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class Week6StatusPill extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const Week6StatusPill({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }
}

class Week6InfoCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final IconData? icon;

  const Week6InfoCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE7F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F3FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: const Color(0xFF2C6AA0)),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF284867),
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Color(0xFF6B7D90),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

enum Week6ChoicePalette { blue, coral, mint, amber }

class Week6ChoiceOptionCard extends StatelessWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final Week6ChoicePalette palette;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showSelectionIndicator;

  const Week6ChoiceOptionCard({
    super.key,
    required this.title,
    this.description,
    this.icon,
    required this.palette,
    required this.isSelected,
    required this.onTap,
    this.showSelectionIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _Week6ChoicePaletteData.from(palette);
    final backgroundColor =
        isSelected
            ? colors.accent.withValues(alpha: 0.22)
            : colors.accent.withValues(alpha: 0.08);
    final borderColor =
        isSelected
            ? colors.accent.withValues(alpha: 0.96)
            : colors.accent.withValues(alpha: 0.24);
    final titleColor = isSelected ? colors.titleColor : colors.bodyColor;
    final boxShadow =
        isSelected
            ? [
              BoxShadow(
                color: colors.accent.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ]
            : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2.2 : 1.2,
            ),
            boxShadow: boxShadow,
          ),
          transform: Matrix4.translationValues(0, isSelected ? -2 : 0, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? colors.accent.withValues(alpha: 0.16)
                            : const Color(0xFFF2F6FA),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? colors.accent : const Color(0xFF6B7D90),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                        height: 1.35,
                      ),
                    ),
                    if (description != null &&
                        description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        description!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          fontWeight: FontWeight.w500,
                          color:
                              isSelected
                                  ? colors.bodyColor
                                  : const Color(0xFF6B7D90),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showSelectionIndicator) ...[
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isSelected ? colors.accent : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          isSelected ? colors.accent : const Color(0xFFC9D6E3),
                      width: 1.5,
                    ),
                  ),
                  child:
                      isSelected
                          ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          )
                          : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class Week6SelectionHint extends StatelessWidget {
  final String title;
  final String message;
  final bool isComplete;
  final Color? accentColor;

  const Week6SelectionHint({
    super.key,
    required this.title,
    required this.message,
    this.isComplete = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent =
        accentColor ??
        (isComplete ? const Color(0xFF2E7D5B) : const Color(0xFF5C6E80));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color:
            isComplete
                ? effectiveAccent.withValues(alpha: 0.10)
                : const Color(0xFFF5F8FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isComplete
                  ? effectiveAccent.withValues(alpha: 0.28)
                  : const Color(0xFFDCE7F2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color:
                  isComplete
                      ? effectiveAccent.withValues(alpha: 0.14)
                      : const Color(0xFFEAF1F7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isComplete ? Icons.check_rounded : Icons.touch_app_rounded,
              size: 18,
              color: effectiveAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color:
                        isComplete ? effectiveAccent : const Color(0xFF3C556E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                    color:
                        isComplete
                            ? effectiveAccent.withValues(alpha: 0.92)
                            : const Color(0xFF6B7D90),
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

class Week6BehaviorTypeSelector extends StatelessWidget {
  final String? selectedType;
  final ValueChanged<String> onSelected;
  final double buttonHeight;
  final String faceLabel;
  final String avoidLabel;

  const Week6BehaviorTypeSelector({
    super.key,
    required this.selectedType,
    required this.onSelected,
    this.buttonHeight = 58,
    this.faceLabel = '불안 직면',
    this.avoidLabel = '불안 회피',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SelectableChoiceCardButton(
          label: faceLabel,
          height: buttonHeight,
          backgroundColor: const Color(0xFF1FA4F0),
          isSelected: selectedType == 'face',
          isDimmed: selectedType != null && selectedType != 'face',
          onPressed: () => onSelected('face'),
        ),
        const SizedBox(height: 12),
        SelectableChoiceCardButton(
          label: avoidLabel,
          height: buttonHeight,
          backgroundColor: const Color(0xFFF3A2AD),
          isSelected: selectedType == 'avoid',
          isDimmed: selectedType != null && selectedType != 'avoid',
          onPressed: () => onSelected('avoid'),
        ),
      ],
    );
  }
}

class Week6BulletList extends StatelessWidget {
  final List<String> items;

  const Week6BulletList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children:
          items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF5B9FD3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: Color(0xFF355676),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
    );
  }
}

class _Week6ChoicePaletteData {
  final Color accent;
  final Color titleColor;
  final Color bodyColor;

  const _Week6ChoicePaletteData({
    required this.accent,
    required this.titleColor,
    required this.bodyColor,
  });

  factory _Week6ChoicePaletteData.from(Week6ChoicePalette palette) {
    switch (palette) {
      case Week6ChoicePalette.blue:
        return const _Week6ChoicePaletteData(
          accent: Color(0xFF3BA2E8),
          titleColor: Color(0xFF225D87),
          bodyColor: Color(0xFF2F6E9D),
        );
      case Week6ChoicePalette.coral:
        return const _Week6ChoicePaletteData(
          accent: Color(0xFFE57C75),
          titleColor: Color(0xFF9C4E4A),
          bodyColor: Color(0xFFAD5B56),
        );
      case Week6ChoicePalette.mint:
        return const _Week6ChoicePaletteData(
          accent: Color(0xFF43B78B),
          titleColor: Color(0xFF247356),
          bodyColor: Color(0xFF2C7F60),
        );
      case Week6ChoicePalette.amber:
        return const _Week6ChoicePaletteData(
          accent: Color(0xFFDBA63B),
          titleColor: Color(0xFF8B6518),
          bodyColor: Color(0xFF9A731E),
        );
    }
  }
}

class _Week6HeaderChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const _Week6HeaderChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }
}
