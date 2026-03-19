import 'package:flutter/material.dart';
import 'package:gad_app_team/features/auth/terms_detail_screen.dart';

class TermsPolicyScreen extends StatelessWidget {
  const TermsPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          '약관 및 정책',
          style: TextStyle(
            color: Color(0xFF1E2F3F),
            fontWeight: FontWeight.w700,
            fontFamily: 'Noto Sans KR',
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: const Color(0xFF1E2F3F),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/image/eduhome.png', fit: BoxFit.cover),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xAAFFFFFF), Color(0x66FFFFFF)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [_buildPolicyCard(context)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyCard(BuildContext context) {
    final items = [
      (
        title: '서비스 이용약관',
        subtitle: '서비스 이용 조건 및 운영 정책',
        content: '서비스 이용약관 전문을 여기에 입력해 주세요.',
      ),
      (
        title: '개인정보 처리방침',
        subtitle: '개인정보 처리 기준과 이용자 권리',
        content: '개인정보 처리방침 전문을 여기에 입력해 주세요.',
      ),
      (
        title: '개인정보 수집 및 이용 동의',
        subtitle: '수집 항목, 목적, 보유 기간 안내',
        content: '개인정보 수집 및 이용 동의 내용을 여기에 입력해 주세요.',
      ),
      (
        title: '민감정보 수집 및 이용 동의',
        subtitle: '민감정보 처리 목적 및 보호 조치',
        content: '민감정보 수집 및 이용 동의 내용을 여기에 입력해 주세요.',
      ),
      (
        title: '개인정보 및 민감정보 제3자 제공 동의',
        subtitle: '제공받는 자, 목적, 제공 항목 안내',
        content: '개인정보 및 민감정보 제3자 제공 동의 내용을 여기에 입력해 주세요.',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      decoration: BoxDecoration(
        color: const Color(0xFCFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5EDF4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ...List.generate(items.length, (index) {
            final item = items[index];
            return Column(
              children: [
                _buildPolicyRow(
                  context: context,
                  title: item.title,
                  subtitle: item.subtitle,
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => TermsDetailScreen(
                                title: item.title,
                                content: item.content,
                                isSignupFlow: false,
                              ),
                        ),
                      ),
                ),
                if (index != items.length - 1)
                  const Divider(
                    height: 12,
                    thickness: 1,
                    color: Color(0xFFE8EEF3),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPolicyRow({
    required BuildContext context,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2C4154),
                        fontFamily: 'Noto Sans KR',
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: Color(0xFF8A97A3),
                        fontFamily: 'Noto Sans KR',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFA0ACB7),
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
