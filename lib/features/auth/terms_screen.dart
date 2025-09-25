import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';

/// 약관 동의 화면
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
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, String>;
    final email = args['email']!;
    final password = args['password']!;
    final allAgreed = agreedTerms && agreedPrivacy;

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text('약관 동의'),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(AppSizes.padding),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () {Navigator.pop(context);},
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: Column(
          children: [
            const SizedBox(height: AppSizes.space),
            const Icon(Icons.verified_user, size: 100, color: AppColors.indigo),
            const SizedBox(height: AppSizes.space),

            _buildCheckTile(
              title: '이용약관 동의',
              value: agreedTerms,
              onChanged: (v) => setState(() => agreedTerms = v ?? false),
              onViewPressed: () {
                _showDialog('이용약관', '여기에 이용약관의 자세한 내용을 입력하세요.');
              },
            ),
            const SizedBox(height: AppSizes.space),

            _buildCheckTile(
              title: '개인정보 수집 및 이용 동의',
              value: agreedPrivacy,
              onChanged: (v) => setState(() => agreedPrivacy = v ?? false),
              onViewPressed: () {
                _showDialog('개인정보 처리방침', '여기에 개인정보 처리방침 내용을 입력하세요.');
              },
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: allAgreed
                    ? () {
                        Navigator.pushNamed(context, '/signup', arguments: {
                          'email': email,
                          'password': password,
                        });
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  ),
                  minimumSize: const Size.fromHeight(54), // 6×9
                ),
                child: const Text('다음으로'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 약관 동의 항목 위젯 (체크박스 + 텍스트 + 더보기)
  Widget _buildCheckTile({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required VoidCallback onViewPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        boxShadow: const [
          BoxShadow(color: AppColors.black12, blurRadius: 6),
        ],
      ),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.indigo,
          ),
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: AppSizes.fontSize)),
          ),
          TextButton(
            onPressed: onViewPressed,
            child: const Text('더보기', style: TextStyle(color: AppColors.indigo)),
          ),
        ],
      ),
    );
  }
}