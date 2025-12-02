import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/common/constants.dart';

/// 공용 진행도 카드 위젯.
///
/// Mindrium 톤으로 재디자인됨:
/// - 흰색 배경 + 연파랑(#DFFEFF) 라인 + 화이트 글로우 블러
/// - 제목: #141F35, 보조텍스트: #979797, 진행바: #5DADEC
/// - Noto Sans KR 폰트 적용 (기본 폰트 지정되어 있으면 그대로 사용)
class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.title,
    required this.progress,
    this.progressLabel,
    this.footnote,
    this.leading,
    this.actions,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(16),
  });

  final String title;
  final double progress;
  final String? progressLabel;
  final String? footnote;
  final Widget? leading;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final EdgeInsets padding;

  double get _clampedProgress => progress.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color surface = backgroundColor ?? Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        // 🎨 블러 + 테두리 효과 (화이트 글로우)
        border: Border.all(width: 3, color: const Color(0xFFDFFEFF)),
        boxShadow: const [
          // 화이트 블러 느낌의 glow
          BoxShadow(
            color: Color(0xE8FFFFFF),
            blurRadius: 30,
            offset: Offset(0, 0),
          ),
          // 살짝 아래쪽 그림자 추가 (살짝 입체감)
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 제목 + 아이콘
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'Noto Sans KR',
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF141F35),
                        fontSize: 20,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 진행 바 + 퍼센트
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  child: LinearProgressIndicator(
                    value: _clampedProgress,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFD7E8FF),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF5DADEC),
                    ),
                  ),
                ),
              ),
              if (progressLabel != null) ...[
                const SizedBox(width: 12),
                Text(
                  progressLabel!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'Noto Sans KR',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: const Color(0xFFFCBDCB),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          // 보조 설명
          if (footnote != null) ...[
            Text(
              footnote!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'Noto Sans KR',
                color: const Color(0xFF979797),
                height: 1.4,
                fontSize: 14,
              ),
            ),
          ],

          // 액션 (버튼 등)
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: actions!),
          ],
        ],
      ),
    );
  }
}
