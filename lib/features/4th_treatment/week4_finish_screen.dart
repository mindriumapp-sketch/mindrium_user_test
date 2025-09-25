import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';

class Week4FinishScreen extends StatelessWidget {
  final int? beforeSud;
  final int? afterSud;
  final List<String>? alternativeThoughts;
  final bool? isFromAfterSud;
  final int? loopCount;

  const Week4FinishScreen({
    super.key,
    this.beforeSud,
    this.afterSud,
    this.alternativeThoughts,
    this.isFromAfterSud,
    this.loopCount,
  });

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<UserProvider>(context, listen: false).userName;
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '4주차 - 인지 왜곡 찾기'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28.0,
                  vertical: 48.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '$userName님',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5B3EFF),
                        letterSpacing: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B3EFF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      isFromAfterSud == true &&
                              beforeSud != null &&
                              afterSud != null &&
                              beforeSud! > afterSud!
                          ? '축하합니다! 불안의 정도가 ${beforeSud}에서 ${afterSud}로 낮아졌네요.\n도움이 되는 생각을 찾아보는 과정을 통해 불안을 줄이는데 성공하셨습니다.'
                          : '아직 불안의 정도가 충분히 낮아지지 않았네요.\n하지만 여기까지 잘 따라와 주신 것만으로도 정말 대단하세요.',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                        height: 1.5,
                        letterSpacing: 0.1,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      '도움이 되는 생각을 찾는 과정이 처음에는 쉽지 않을 수 있어요.\n조금 더 연습하고, 내 마음을 들여다보는 시간을 가져보면 분명 불안이 줄어들 수 있습니다.\n\n고생하셨습니다.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                        height: 1.5,
                        letterSpacing: 0.1,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: NavigationButtons(
          leftLabel: '이전',
          rightLabel: '다음',
          onBack: () => Navigator.pop(context),
          onNext: () async {
            await showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Text(
                      '수고하셨습니다!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    content: const Text(
                      '오늘도 끝까지 잘 따라와 주셔서 감사합니다.\n홈 화면으로 이동합니다.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('확인'),
                      ),
                    ],
                  ),
            );
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
      ),
    );
  }
}
