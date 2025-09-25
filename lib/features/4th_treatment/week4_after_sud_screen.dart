import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
// import 'week4_visual_screen.dart'; // Added import for Week4VisualScreen
import 'week4_finish_screen.dart';
import 'week4_skip_choice_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Week4AfterSudScreen extends StatefulWidget {
  final int beforeSud;
  final String currentB;
  final List<String> remainingBList;
  final List<String> allBList;
  final List<String> alternativeThoughts;
  final bool isFromAnxietyScreen;
  final List<String> originalBList;
  final int loopCount; // 추가

  const Week4AfterSudScreen({
    super.key,
    required this.beforeSud,
    required this.currentB,
    required this.remainingBList,
    required this.allBList,
    required this.alternativeThoughts,
    this.isFromAnxietyScreen = false,
    this.originalBList = const [],
    this.loopCount = 1, // 기본값 1
  });

  @override
  State<Week4AfterSudScreen> createState() => _Week4AfterSudScreenState();
}

class _Week4AfterSudScreenState extends State<Week4AfterSudScreen> {
  int _sud = 5;
  List<String> _originalBList = [];
  List<String> _allAlternativeThoughts = [];

  @override
  void initState() {
    super.initState();
    _fetchOriginalBList();
    _collectAllAlternativeThoughts();
  }

  Future<void> _fetchOriginalBList() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('abc_models')
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final belief = data['belief'] as String?;
        if (belief != null && belief.isNotEmpty) {
          final beliefs =
              belief
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
          setState(() {
            _originalBList = beliefs;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching original B list: $e');
    }
  }

  Future<void> _collectAllAlternativeThoughts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 현재 전달받은 대체 생각들 (중복 제거)
      final currentAlternativeThoughts = widget.alternativeThoughts;
      final allAlternativeThoughts = <String>[];

      // 중복을 제거하면서 현재 대체 생각들 추가
      for (final thought in currentAlternativeThoughts) {
        if (!allAlternativeThoughts.contains(thought)) {
          allAlternativeThoughts.add(thought);
        }
      }

      setState(() {
        _allAlternativeThoughts = allAlternativeThoughts;
      });
    } catch (e) {
      debugPrint('Error collecting alternative thoughts: $e');
      // 에러 발생시 현재 전달받은 대체 생각들만 사용 (중복 제거)
      final uniqueThoughts = <String>[];
      for (final thought in widget.alternativeThoughts) {
        if (!uniqueThoughts.contains(thought)) {
          uniqueThoughts.add(thought);
        }
      }
      setState(() {
        _allAlternativeThoughts = uniqueThoughts;
      });
    }
  }

  void _handleNext() {
    if (_sud < widget.beforeSud) {
      // SUD가 낮아졌으면: Week4FinishScreen으로 이동
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder:
              (_, __, ___) => Week4FinishScreen(
                beforeSud: widget.beforeSud,
                afterSud: _sud,
                alternativeThoughts: _allAlternativeThoughts,
                isFromAfterSud: true,
                loopCount: widget.loopCount,
              ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } else {
      // SUD가 낮아지지 않았으면 Week4SkipChoiceScreen으로 이동 (loopCount 증가 X)
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder:
              (_, __, ___) => Week4SkipChoiceScreen(
                allBList: widget.allBList,
                beforeSud: widget.beforeSud,
                remainingBList: widget.remainingBList,
                isFromAfterSud: true,
                existingAlternativeThoughts: _allAlternativeThoughts,
                loopCount: widget.loopCount, // 반드시 그대로 전달
              ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color trackColor =
        _sud <= 2
            ? Colors.green
            : _sud >= 8
            ? Colors.red
            : Colors.amber;
    return Scaffold(
      appBar: const CustomAppBar(title: '4주차 - SUD 평가 (after)'),
      backgroundColor: const Color(0xFFFBF8FF),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: NavigationButtons(
          leftLabel: '이전',
          rightLabel: '다음',
          onBack: () => Navigator.pop(context),
          onNext: _handleNext,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              '지금 느끼는 불안 정도를 슬라이드로 선택해 주세요.',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                '$_sud',
                style: TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.bold,
                  color: trackColor,
                ),
              ),
            ),
            Center(
              child: Icon(
                _sud <= 2
                    ? Icons.sentiment_very_satisfied
                    : _sud >= 8
                    ? Icons.sentiment_very_dissatisfied_sharp
                    : Icons.sentiment_neutral,
                size: 160,
                color: trackColor,
              ),
            ),
            const SizedBox(height: 32),
            Stack(
              alignment: Alignment.center,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: trackColor,
                    thumbColor: trackColor,
                  ),
                  child: Slider(
                    value: _sud.toDouble(),
                    min: 0,
                    max: 10,
                    divisions: 10,
                    label: '$_sud',
                    onChanged: (v) => setState(() => _sud = v.round()),
                  ),
                ),
                const Positioned(
                  left: 0,
                  child: Text(
                    '0',
                    style: TextStyle(fontSize: 20, color: Colors.black54),
                  ),
                ),
                const Positioned(
                  right: 0,
                  child: Text(
                    '10',
                    style: TextStyle(fontSize: 20, color: Colors.black54),
                  ),
                ),
              ],
            ),
            Row(
              children: const [
                SizedBox(width: 12),
                Text('평온', textAlign: TextAlign.center),
                Spacer(),
                Text('보통', textAlign: TextAlign.center),
                Spacer(),
                Text('불안', textAlign: TextAlign.center),
                SizedBox(width: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
