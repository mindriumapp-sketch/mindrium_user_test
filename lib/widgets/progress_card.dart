import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
/// 공용 진행도 카드 위젯.
///
/// `ProgressCard`는 제목과 진행률, 부가 설명을 한 번에 보여주고 싶을 때 사용합니다.
/// 기본적으로 가로폭 전체를 차지하는 카드이며, 진행률 라벨이나 버튼 등을
/// 하단에 배치할 수 있도록 `actions` 슬롯을 제공합니다.
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
  /// 카드 상단에 표시되는 제목.
  final String title;
  /// 0.0 ~ 1.0 사이의 진행률 값. 범위를 넘어도 적당히 보정된다.
  final double progress;

  /// 진행 막대 오른쪽에 표시할 문자 라벨. 예: `"3 / 8주 완료"`.
  final String? progressLabel;
  /// 카드 하단의 보충 설명 텍스트.
  final String? footnote;
  /// 제목 왼쪽에 놓일 리딩 위젯. (ex. 아이콘)
  final Widget? leading;
  /// 진행률 아래에 배치할 버튼/링크 등 복수의 위젯.
  final List<Widget>? actions;
  /// 배경색. 미지정 시 살짝 반투명한 인디고 톤을 사용.
  final Color? backgroundColor;
  /// 카드 내부 패딩.
  final EdgeInsets padding;
  double get _clampedProgress => progress.clamp(0.0, 1.0);


  @override
  Widget build(BuildContext context) {
    final Color surface = backgroundColor ?? AppColors.white;
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 8)],
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  child: LinearProgressIndicator(
                    value: _clampedProgress,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.indigo),
                  ),
                ),
              ),
              if (progressLabel != null) ...[
                const SizedBox(width: 12),
                Text(
                  progressLabel!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.indigo,
                      ),
                ),
              ],
            ],
          ),
          if (footnote != null) ...[
            Text(
              footnote!,
              style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                    height: 1.4,
                  ),
            ),
          ],
          if (actions != null && actions!.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions!,
            ),
          ],
        ],
      ),
    );
  }
}