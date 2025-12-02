import 'package:gad_app_team/utils/text_line_material.dart';

/// 🎨 알림 관련 팝업/바텀시트의 시각적 디자인 전용 위젯
class NotificationAlertDesign {
  // 색상 팔레트 (독립)
  static const Color bgLight = Color(0xFFF5F7FA);
  static const Color cardWhite = Colors.white;
  static const Color borderGrey = Color(0xFFDADADA);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color accentBlue = Color(0xFF5DADEC);
  static const Color shadowLight = Color(0x14000000);

  // 🔔 다시 알림 바텀시트
  static Widget reminderPickerLayout({
    required Widget hourPicker,
    required Widget minutePicker,
    required Widget buttons,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: bgLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 248,
            decoration: BoxDecoration(
              color: cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderGrey),
              boxShadow: const [
                BoxShadow(
                  color: shadowLight,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(child: hourPicker),
                Container(width: 1, color: borderGrey),
                Expanded(child: minutePicker),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: cardWhite,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: shadowLight,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: buttons,
          ),
        ],
      ),
    );
  }

  // ❓ 도움말 다이얼로그
  static AlertDialog helpDialogLayout({
    required Widget content,
    required VoidCallback onClose,
  }) {
    return AlertDialog(
      backgroundColor: cardWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(20),
      contentPadding: const EdgeInsets.all(20),
      content: Container(
        decoration: BoxDecoration(
          color: bgLight,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: content,
      ),
      actions: [
        Center(
          child: TextButton(
            onPressed: onClose,
            style: TextButton.styleFrom(
              foregroundColor: accentBlue,
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            child: const Text('닫기'),
          ),
        ),
      ],
    );
  }
}
