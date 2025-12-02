import 'package:gad_app_team/utils/text_line_material.dart';

class AbcGroupAddDesign {
  static const Color yellowBg = Color(0xFFFFF7C0);
  static const Color textColor = Color(0xFF222222);
  static const Color blueText = Color(0xFF33A4F0);

  /// 🔹 그룹 카드 (거북이 + 제목 + 점수)
  static Widget buildGroupCard({
    required String title,
    required double avgScore,
    required String imagePath,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final scoreColor =
        avgScore >= 7
            ? const Color(0xFFEC5D5D)
            : avgScore >= 4
            ? const Color(0xFFE6AB36)
            : const Color(0xFF5DADEC);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? blueText : Colors.transparent,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 3,
              offset: const Offset(1.5, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, height: 60),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${avgScore.toStringAsFixed(0)}점',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: scoreColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 “추가하기” 카드
  static Widget buildAddCard({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 3,
              offset: const Offset(1.5, 2),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.add, size: 32, color: Color(0xFF33A4F0)),
        ),
      ),
    );
  }

  /// 🔹 팝업 카드 (선택 그룹 상세)
  static Widget buildPopupCard({
    required String title,
    required double avgScore,
    required int count,
    required String description,
    required VoidCallback onEdit,
  }) {
    final scoreColor =
        avgScore >= 7
            ? const Color(0xFFEC5D5D)
            : avgScore >= 4
            ? const Color(0xFFE6AB36)
            : const Color(0xFF5DADEC);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 5,
            offset: const Offset(1.5, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목 + 수정 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.more_vert, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${avgScore.toStringAsFixed(1)}점 (/10점)',
            style: TextStyle(
              color: scoreColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '일기 $count개',
            style: const TextStyle(fontSize: 14, color: textColor),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(fontSize: 14.5, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
