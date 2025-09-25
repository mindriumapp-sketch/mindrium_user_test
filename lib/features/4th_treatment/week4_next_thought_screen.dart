import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/features/4th_treatment/week4_classfication_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Week4NextThoughtScreen extends StatefulWidget {
  final List<String> remainingBList;
  final int beforeSud;
  final List<String> allBList;
  final List<String>? alternativeThoughts;
  final bool isFromAnxietyScreen;
  final List<String> addedAnxietyThoughts;
  final List<String>? existingAlternativeThoughts;
  final String? abcId;
  final int loopCount;

  const Week4NextThoughtScreen({
    super.key,
    required this.remainingBList,
    required this.beforeSud,
    required this.allBList,
    this.alternativeThoughts,
    this.isFromAnxietyScreen = false,
    this.addedAnxietyThoughts = const [],
    this.existingAlternativeThoughts,
    this.abcId,
    this.loopCount = 1,
  });

  @override
  State<Week4NextThoughtScreen> createState() => _Week4NextThoughtScreenState();
}

class _Week4NextThoughtScreenState extends State<Week4NextThoughtScreen> {
  bool _isNextEnabled = false;
  int _secondsLeft = 5;
  bool _showSituation = true; // 상황 안내 먼저, 이후 보라 안내
  String? _activatingEvent;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _fetchActivatingEvent();
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

  Future<void> _fetchActivatingEvent() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('로그인 정보 없음');
      DocumentSnapshot<Map<String, dynamic>>? doc;
      if (widget.abcId != null && widget.abcId!.isNotEmpty) {
        doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('abc_models')
                .doc(widget.abcId)
                .get();
      } else {
        final snap =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('abc_models')
                .orderBy('createdAt', descending: true)
                .limit(1)
                .get();
        if (snap.docs.isNotEmpty) doc = snap.docs.first;
      }
      setState(() {
        _activatingEvent = doc?.data()?['activatingEvent'] as String?;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<UserProvider>(context, listen: false).userName;
    final nextThought =
        widget.remainingBList.isNotEmpty ? widget.remainingBList.first : '';

    // 안내문 텍스트
    final situationText =
        _activatingEvent != null && _activatingEvent!.isNotEmpty
            ? "잘 따라오고 계십니다!\n 다시 '$_activatingEvent' (라)는 상황을 자세하게 상상해 보세요."
            : '이때의 상황을 자세하게 상상해 보세요.';
    final nextThoughtText = "일기에 작성하셨던 또 다른 생각인 '$nextThought'에 대해 계속 진행해보겠습니다.";

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '4주차 - 인지 왜곡 찾기'),
      body: Center(
        child:
            _isLoading
                ? const CircularProgressIndicator()
                : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
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
                                color: Color(
                                  0xFF5B3EFF,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 32),
                            if (_showSituation)
                              Text(
                                situationText,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              )
                            else
                              Text(
                                nextThoughtText,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                  height: 1.4,
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
                    if (_showSituation) {
                      setState(() => _showSituation = false);
                    } else {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (_, __, ___) => Week4ClassificationScreen(
                                bListInput:
                                    widget.isFromAnxietyScreen
                                        ? widget.addedAnxietyThoughts
                                        : widget.remainingBList,
                                beforeSud: widget.beforeSud,
                                allBList: widget.allBList,
                                alternativeThoughts: widget.alternativeThoughts,
                                isFromAnxietyScreen: widget.isFromAnxietyScreen,
                                existingAlternativeThoughts:
                                    widget.existingAlternativeThoughts,
                                abcId: widget.abcId,
                                loopCount: widget.loopCount,
                              ),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                        ),
                      );
                    }
                  }
                  : null,
        ),
      ),
    );
  }
}
