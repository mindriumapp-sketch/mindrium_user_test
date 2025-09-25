import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/features/7th_treatment/week7_add_display_screen.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';

class Week7Screen extends StatefulWidget {
  const Week7Screen({super.key});

  @override
  State<Week7Screen> createState() => _Week7ScreenState();
}

class _Week7ScreenState extends State<Week7Screen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '7주차 - 생활 습관 개선'),
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
              '첫화면: 안내 화면?',
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
                  '$displayName님: To do list-내용',
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
                    pageBuilder: (_, __, ___) => const Week7AddDisplayScreen(),
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
