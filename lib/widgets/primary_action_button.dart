import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/common/constants.dart';

/// 🌊 Mindrium 공통 Primary Action Button
/// - AppColors 기반 일관된 색상 시스템
/// - 외곽 흰색 그라데이션으로 은은한 테두리 효과
/// - 활성/비활성, 애니메이션 모두 지원
class PrimaryActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool withAnimation;

  const PrimaryActionButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.withAnimation = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null;

    //  버튼 내부 (FilledButton)
    final button = SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: isDisabled ? AppColors.grey300 : AppColors.indigo,
          foregroundColor: isDisabled ? AppColors.grey : AppColors.white,
          padding: const EdgeInsets.all(AppSizes.padding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: AppSizes.fontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );

    // 🌤️ 흰색 그라데이션 테두리 컨테이너
    final gradientBorder = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.4),
            Colors.white.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.borderRadius + 2),
      ),
      padding: const EdgeInsets.all(1.5), // 테두리 두께
      child: button,
    );

    //  외곽 은은한 그림자 (부드러운 흰 빛)
    final wrapped = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.borderRadius + 2),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.15),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: gradientBorder,
    );

    //  애니메이션 옵션 (텍스트 변경 시 fade 효과)
    return withAnimation
        ? AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: KeyedSubtree(key: ValueKey(text), child: wrapped),
        )
        : wrapped;
  }
}
