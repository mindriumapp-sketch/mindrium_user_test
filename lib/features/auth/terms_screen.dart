// File: terms_screen.dart
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/primary_action_button.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool agreedTerms = false;
  bool agreedPrivacy = false;

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white.withValues(alpha: 0.95),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Noto Sans KR',
                fontWeight: FontWeight.bold,
                color: Color(0xFF233B6E),
              ),
            ),
            content: SingleChildScrollView(
              child: Text(
                content,
                style: const TextStyle(
                  fontFamily: 'Noto Sans KR',
                  fontSize: 15,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF233B6E),
                  textStyle: const TextStyle(
                    fontFamily: 'Noto Sans KR',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('닫기'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, String>? ??
        {};
    final email = args['email'] ?? '';
    final password = args['password'] ?? '';
    final allAgreed = agreedTerms && agreedPrivacy;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          /// 🌊 배경 (로그인 화면 동일)
          Positioned.fill(
            child: Image.asset('assets/image/eduhome.png', fit: BoxFit.cover),
          ),

          /// 📜 본문 카드
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '약관 동의',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Noto Sans KR',
                          fontWeight: FontWeight.bold,
                          fontSize: 26,
                          color: Color(0xFF233B6E),
                        ),
                      ),
                      const SizedBox(height: 28),

                      _buildCheckTile(
                        title: '이용약관 동의',
                        value: agreedTerms,
                        onChanged:
                            (v) => setState(() => agreedTerms = v ?? false),
                        onViewPressed:
                            () => _showDialog('이용약관', '이곳에 이용약관 전문을 입력하세요.'),
                      ),
                      const SizedBox(height: 18),

                      _buildCheckTile(
                        title: '개인정보 수집 및 이용 동의',
                        value: agreedPrivacy,
                        onChanged:
                            (v) => setState(() => agreedPrivacy = v ?? false),
                        onViewPressed:
                            () => _showDialog(
                              '개인정보 처리방침',
                              '이곳에 개인정보 처리방침 전문을 입력하세요.',
                            ),
                      ),

                      const SizedBox(height: 28),
                      PrimaryActionButton(
                        text: '다음으로',
                        onPressed:
                            allAgreed
                                ? () => Navigator.pushNamed(
                                  context,
                                  '/signup',
                                  arguments: {
                                    'email': email,
                                    'password': password,
                                  },
                                )
                                : null,
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          '로그인으로 돌아가기',  // 왼쪽 화살표 폰트 인식 안 됨
                          style: TextStyle(
                            fontFamily: 'Noto Sans KR',
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Color(0xFF4A6FA5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 체크 박스 줄
  Widget _buildCheckTile({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required VoidCallback onViewPressed,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12, width: 0.8),
      ),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF233B6E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Noto Sans KR',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          TextButton(
            onPressed: onViewPressed,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF233B6E),
              textStyle: const TextStyle(
                fontFamily: 'Noto Sans KR',
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            child: const Text('보기'),
          ),
        ],
      ),
    );
  }
}
