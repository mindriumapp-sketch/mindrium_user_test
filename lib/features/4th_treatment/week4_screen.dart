import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/features/4th_treatment/week4_abc_screen.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';

class Week4Screen extends StatefulWidget {
  final int loopCount;

  const Week4Screen({super.key, this.loopCount = 1});

  @override
  State<Week4Screen> createState() => _Week4ScreenState();
}

class _Week4ScreenState extends State<Week4Screen> {
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
    final String? abcId = args['abcId'] as String?;
    final int? sud = args['sud'] as int?;
    debugPrint('[week4] abcId: $abcId');

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '4주차 - 인지 왜곡 찾기'),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(),
            const Icon(Icons.lightbulb, size: 72, color: Color(0xFF3F51B5)),
            const SizedBox(height: 32),
            const Text(
              '걱정일기를 통해 알아볼까요?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final userName =
                    Provider.of<UserProvider>(context, listen: false).userName;
                final displayName = (userName.isNotEmpty) ? userName : '사용자';
                return Text(
                  '$displayName님께서 작성하신 걱정일기의 내용을 살펴볼게요.',
                  style: TextStyle(fontSize: 20, color: Colors.black87),
                  textAlign: TextAlign.center,
                );
              },
            ),
            const Spacer(),
            NavigationButtons(
              onBack: () => Navigator.pop(context),
              onNext: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder:
                        (_, __, ___) => Week4AbcScreen(
                          abcId: abcId,
                          sud: sud,
                          loopCount: widget.loopCount,
                        ),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
