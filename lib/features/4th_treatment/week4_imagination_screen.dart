import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/features/4th_treatment/week4_before_sud_screen.dart';

class Week4ImaginationScreen extends StatefulWidget {
  final int loopCount;
  const Week4ImaginationScreen({super.key, this.loopCount = 1});

  @override
  State<Week4ImaginationScreen> createState() => _Week4ImaginationScreenState();
}

class _Week4ImaginationScreenState extends State<Week4ImaginationScreen> {
  bool _isNextEnabled = false;
  int _secondsLeft = 10;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      if (_secondsLeft > 0) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return false;
        setState(() {
          _secondsLeft--;
        });
        return true;
      } else {
        setState(() {
          _isNextEnabled = true;
        });
        return false;
      }
    });
  }

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
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Color(0xFF5B3EFF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '이때의 상황을\n자세하게 상상해 보세요.',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (!_isNextEnabled)
                      Text(
                        '$_secondsLeft초 후에 다음 버튼이 활성화됩니다',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFFB0B0B0),
                          fontWeight: FontWeight.w400,
                        ),
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
          onBack: () => Navigator.pop(context),
          onNext:
              _isNextEnabled
                  ? () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder:
                            (_, __, ___) => const Week4BeforeSudScreen(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  }
                  : null,
        ),
      ),
    );
  }
}
