// File: terms_screen.dart
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/auth/terms_detail_screen.dart';
import 'package:gad_app_team/widgets/primary_action_button.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool agreedAll = false;
  bool agreedServiceTerms = false;
  bool agreedPrivacyPolicy = false;
  bool agreedPersonalInfo = false;
  bool agreedSensitiveInfo = false;
  bool agreedThirdParty = false;

  bool get requiredAgreed =>
      agreedServiceTerms &&
      agreedPrivacyPolicy &&
      agreedPersonalInfo &&
      agreedSensitiveInfo &&
      agreedThirdParty;

  void _toggleAll(bool checked) {
    setState(() {
      agreedAll = checked;
      agreedServiceTerms = checked;
      agreedPrivacyPolicy = checked;
      agreedPersonalInfo = checked;
      agreedSensitiveInfo = checked;
      agreedThirdParty = checked;
    });
  }

  Future<void> _openTermsDetail({
    required String termKey,
    required String title,
    required String content,
  }) async {
    final agreed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (_) => TermsDetailScreen(
              title: title,
              content: content,
              isSignupFlow: true,
            ),
      ),
    );

    if (agreed != true || !mounted) return;

    setState(() {
      switch (termKey) {
        case 'service':
          agreedServiceTerms = true;
          break;
        case 'privacy_policy':
          agreedPrivacyPolicy = true;
          break;
        case 'personal_info':
          agreedPersonalInfo = true;
          break;
        case 'sensitive_info':
          agreedSensitiveInfo = true;
          break;
        case 'third_party':
          agreedThirdParty = true;
          break;
      }
      agreedAll = requiredAgreed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, String>? ??
        {};
    final email = args['email'] ?? '';
    final password = args['password'] ?? '';
    final allAgreed = requiredAgreed;

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
                  horizontal: 25,
                  vertical: 24,
                ),
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                        '서비스 약관 동의',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Noto Sans KR',
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          color: Color(0xFF233B6E),
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        '각 항목을 확인하고 동의해 주세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Noto Sans KR',
                          fontSize: 14,
                          color: Color(0xFF5D6B87),
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildAllAgreeTile(
                        value: agreedAll,
                        onChanged: (v) => _toggleAll(v ?? false),
                      ),
                      const SizedBox(height: 2),

                      _buildCheckTile(
                        title: '서비스 이용약관 동의',
                        value: agreedServiceTerms,
                        onChanged: (v) {
                          setState(() {
                            agreedServiceTerms = v ?? false;
                            agreedAll = requiredAgreed;
                          });
                        },
                        onViewPressed:
                            () => _openTermsDetail(
                              termKey: 'service',
                              title: '서비스 이용약관',
                              content:
                                  '서비스 이용약관 전문을 여기에 입력해 주세요.\n\n'
                                  '- 목적\n- 이용 조건\n- 책임 및 면책',
                            ),
                      ),

                      _buildCheckTile(
                        title: '개인정보 처리방침 확인',
                        value: agreedPrivacyPolicy,
                        onChanged: (v) {
                          setState(() {
                            agreedPrivacyPolicy = v ?? false;
                            agreedAll = requiredAgreed;
                          });
                        },
                        onViewPressed:
                            () => _openTermsDetail(
                              termKey: 'privacy_policy',
                              title: '개인정보 처리방침',
                              content:
                                  '개인정보 처리방침 전문을 여기에 입력해 주세요.\n\n'
                                  '- 처리 목적\n- 처리 항목\n- 보유 기간',
                            ),
                      ),

                      _buildCheckTile(
                        title: '개인정보 수집 및 이용 동의',
                        value: agreedPersonalInfo,
                        onChanged: (v) {
                          setState(() {
                            agreedPersonalInfo = v ?? false;
                            agreedAll = requiredAgreed;
                          });
                        },
                        onViewPressed:
                            () => _openTermsDetail(
                              termKey: 'personal_info',
                              title: '개인정보 수집 및 이용 동의',
                              content:
                                  '개인정보 수집 및 이용 동의 내용을 여기에 입력해 주세요.\n\n'
                                  '- 수집 항목\n- 이용 목적\n- 보유 기간\n- 거부권 및 불이익',
                            ),
                      ),

                      _buildCheckTile(
                        title: '민감정보 수집 및 이용 동의',
                        value: agreedSensitiveInfo,
                        onChanged: (v) {
                          setState(() {
                            agreedSensitiveInfo = v ?? false;
                            agreedAll = requiredAgreed;
                          });
                        },
                        onViewPressed:
                            () => _openTermsDetail(
                              termKey: 'sensitive_info',
                              title: '민감정보 수집 및 이용 동의',
                              content:
                                  '민감정보 수집 및 이용 동의 내용을 여기에 입력해 주세요.\n\n'
                                  '- 수집 항목\n- 이용 목적\n- 보유 기간\n- 거부권 및 불이익',
                            ),
                      ),

                      _buildCheckTile(
                        title: '개인정보 및 민감정보 제3자 제공 동의',
                        value: agreedThirdParty,
                        onChanged: (v) {
                          setState(() {
                            agreedThirdParty = v ?? false;
                            agreedAll = requiredAgreed;
                          });
                        },
                        onViewPressed:
                            () => _openTermsDetail(
                              termKey: 'third_party',
                              title: '개인정보 및 민감정보 제3자 제공 동의',
                              content:
                                  '개인정보 및 민감정보 제3자 제공 동의 내용을 여기에 입력해 주세요.\n\n'
                                  '- 제공받는 자\n- 제공 목적\n- 제공 항목\n- 보유 기간',
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
                          '로그인으로 돌아가기', // 왼쪽 화살표 폰트 인식 안 됨
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

  Widget _buildAllAgreeTile({
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFDDE3EF), width: 1)),
      ),
      child: Row(
        children: [
          Transform.scale(
            scale: 0.9,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF233B6E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          const SizedBox(width: 2),
          const Expanded(
            child: Text(
              '전체 동의',
              style: TextStyle(
                fontFamily: 'Noto Sans KR',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF233B6E),
              ),
            ),
          ),
          const SizedBox(width: 4),
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE3E8F3), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Transform.scale(
            scale: 0.88,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF233B6E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Noto Sans KR',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2E4D),
              ),
            ),
          ),
          TextButton(
            onPressed: onViewPressed,
            style: TextButton.styleFrom(
              minimumSize: const Size(52, 30),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: const Color(0xFF233B6E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
