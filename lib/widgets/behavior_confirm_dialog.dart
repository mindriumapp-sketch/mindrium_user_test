import 'package:gad_app_team/utils/text_line_material.dart';

class BehaviorConfirmDialog extends StatelessWidget {
  final String titleText;
  final String highlightText;
  final String messageText;
  final String negativeText;
  final String positiveText;
  final VoidCallback onNegativePressed;
  final VoidCallback onPositivePressed;
  final bool single;

  final String badgeBgAsset;
  final String memoBgAsset;

  // ✅ 추가: 커스텀 위젯 & 타이틀 컬러
  final Widget? customContent;
  final Color titleColor;

  const BehaviorConfirmDialog({
    super.key,
    required this.titleText,
    required this.highlightText,
    required this.messageText,
    required this.onNegativePressed,
    required this.onPositivePressed,
    this.negativeText = '아니요',
    this.positiveText = '예',
    this.badgeBgAsset = 'assets/image/popup1.png',
    this.memoBgAsset = 'assets/image/popup2.png',
    this.single = false,
    this.customContent,
    this.titleColor = const Color(0xFF263C69), // 기본은 기존 색
  });

  factory BehaviorConfirmDialog.singleButton({
    required String titleText,
    required String messageText,
    required VoidCallback onConfirm,
    String badgeBgAsset = 'assets/image/popup1.png',
  }) {
    return BehaviorConfirmDialog(
      titleText: titleText,
      highlightText: '',
      messageText: messageText,
      negativeText: '',
      positiveText: '확인',
      onNegativePressed: () {},
      onPositivePressed: onConfirm,
      memoBgAsset: '',
      badgeBgAsset: badgeBgAsset,
      single: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // 메인 카드
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 60),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔹 타이틀 (색 커스터마이즈 가능)
                Text(
                  titleText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 12),

                // 🔹 메모 띠 (memoBgAsset 없으면 숨김)
                _FoldedMemoTag(
                  text: highlightText,
                  memoBgAsset: memoBgAsset,
                ),

                const SizedBox(height: 22),

                // 🔹 내용 영역: customContent 우선
                if (customContent != null) ...[
                  customContent!,
                ] else if (messageText.isNotEmpty) ...[
                  Text(
                    messageText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF4A5568),
                      height: 1.5,
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                // 🔹 버튼 영역
                if (single) ...[
                  Center(
                    child: SizedBox(
                      width: 140,
                      child: ElevatedButton(
                        onPressed: onPositivePressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5DADEC),
                          foregroundColor: Colors.white,
                          padding:
                          const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          positiveText,
                          style: const TextStyle(
                            fontSize: 16,
                            wordSpacing: 1.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: onNegativePressed,
                          style: TextButton.styleFrom(
                            padding:
                            const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            negativeText,
                            style: const TextStyle(
                              fontSize: 16,
                              wordSpacing: 1.8,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF5DADEC),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onPositivePressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5DADEC),
                            foregroundColor: Colors.white,
                            padding:
                            const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            positiveText,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // 상단 원형 배지
          Positioned(
            top: 0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                Image.asset(
                  badgeBgAsset,
                  width: 105,
                  height: 105,
                  fit: BoxFit.cover,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FoldedMemoTag extends StatelessWidget {
  final String text;
  final String memoBgAsset;

  const _FoldedMemoTag({
    required this.text,
    required this.memoBgAsset,
  });

  @override
  Widget build(BuildContext context) {
    if (memoBgAsset.isEmpty || text.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: 288,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              memoBgAsset,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 58,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF263C69),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
