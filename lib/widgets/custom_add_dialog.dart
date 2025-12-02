import 'package:gad_app_team/utils/text_line_material.dart';

/// 🌊 Mindrium-style 팝업 다이얼로그 (popup1/popup2 이미지 반영)
class CustomAddDialog extends StatelessWidget {
  final String title;
  final String hintText;
  final String firstSuffix;
  final String secondSuffix;
  final TextEditingController controller;
  final VoidCallback onConfirm;
  final String confirmText;
  final String? errorText;

  const CustomAddDialog({
    super.key,
    required this.title,
    required this.hintText,
    required this.firstSuffix,
    required this.secondSuffix,
    required this.controller,
    required this.onConfirm,
    this.confirmText = '추가',
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width * 0.9;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      child: Container(
        width: screenWidth,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🌸 상단 원형 장식 (asset 이미지 두 겹)
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage('assets/image/popup1.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Container(
                  width: 79,
                  height: 79,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage('assets/image/popup2.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 🪸 제목
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF232323),
                  fontSize: 22,
                  fontFamily: 'Noto Sans KR',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 🫧 입력창
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(
                        color: Color(0xFF232323),
                        fontSize: 18,
                        fontFamily: 'Noto Sans KR',
                      ),
                      decoration: InputDecoration(
                        hintText: hintText,
                        hintStyle: const TextStyle(
                          color: Color(0xFF636363),
                          fontSize: 18,
                          fontFamily: 'Noto Sans KR',
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 🪞 문장 조합
            Text(
              '$firstSuffix $secondSuffix',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF232323),
                fontSize: 16,
                fontFamily: 'Noto Sans KR',
              ),
            ),

            if (errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  errorText!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 14,
                    fontFamily: 'Noto Sans KR',
                  ),
                ),
              ),

            const SizedBox(height: 28),

            // 🐚 추가 버튼
            SizedBox(
              width: 160,
              height: 50,
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF232323),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 3,
                ),
                child: Text(
                  confirmText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: 'Noto Sans KR',
                    letterSpacing: 8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
