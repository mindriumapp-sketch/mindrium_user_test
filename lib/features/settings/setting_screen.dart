import 'package:gad_app_team/utils/text_line_material.dart';

/// 🫧 마인드리움 스타일 설정 화면
/// - 배경: eduhome.png
/// - 카드: 반투명 글라스, 부드러운 그림자
/// - 버튼/스위치: 파스텔 블루 톤
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isTaskReminderOn = true;
  bool _isHomeworkReminderOn = true;
  bool _isReportReminderOn = true;

  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  // 🎨 색상 팔레트 (Mindrium 테마)
  final Color deepSea = const Color(0xFF004C73);
  final Color aquaBlue = const Color(0xFF00B8D9);
  final Color glassWhite = Colors.white.withOpacity(0.75);

  void _sendInquiry() {
    final subject = _subjectController.text;
    final message = _messageController.text;

    if (subject.isNotEmpty && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('문의가 접수되었습니다.'),
          backgroundColor: deepSea,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _subjectController.clear();
      _messageController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('모든 항목을 입력해주세요.'),
          backgroundColor: Colors.redAccent.withOpacity(0.8),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          '설정',
          style: TextStyle(
            fontFamily: 'Noto Sans KR',
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: deepSea.withOpacity(0.6),
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🫧 배경: eduhome.png
          Image.asset('assets/images/eduhome.png', fit: BoxFit.cover),

          // 🌊 내용
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _buildGlassCard(
                  title: '알림 설정',
                  child: Column(
                    children: [
                      _buildSwitchTile(
                        '치료 일정 알림',
                        _isTaskReminderOn,
                        (value) => setState(() => _isTaskReminderOn = value),
                      ),
                      _buildSwitchTile(
                        '숙제 제출 알림',
                        _isHomeworkReminderOn,
                        (value) =>
                            setState(() => _isHomeworkReminderOn = value),
                      ),
                      _buildSwitchTile(
                        '리포트 생성 알림',
                        _isReportReminderOn,
                        (value) => setState(() => _isReportReminderOn = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildGlassCard(
                  title: '고객센터 문의',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInputField('문의 제목', _subjectController),
                      const SizedBox(height: 12),
                      _buildInputField(
                        '문의 내용',
                        _messageController,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 24),
                      _buildAquaButton('전송하기', _sendInquiry),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🩵 카드
  Widget _buildGlassCard({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: glassWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Noto Sans KR',
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF004C73),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // 🩵 토글 스위치
  Widget _buildSwitchTile(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'Noto Sans KR',
              color: Color(0xFF013A56),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: aquaBlue,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white54,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // 🩵 입력 필드
  Widget _buildInputField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 15, fontFamily: 'Noto Sans KR'),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF004C73)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.85),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFBDEAFD), width: 1.2),
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: aquaBlue, width: 1.6),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  // 🩵 버튼
  Widget _buildAquaButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: aquaBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'Noto Sans KR',
        ),
      ),
      onPressed: onPressed,
      child: Text(text),
    );
  }
}
