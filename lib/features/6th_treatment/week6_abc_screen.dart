import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/features/6th_treatment/week6_concentration_screen.dart';

// --- 크레파스 하이라이트 페인터 ---
class _CrayonHighlightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = const Color(0xFFFFF59D).withValues(alpha: 0.8)
          ..style = PaintingStyle.fill;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height * 0.2, size.width, size.height * 0.7),
      const Radius.circular(12),
    );
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Week6AbcScreen extends StatefulWidget {
  const Week6AbcScreen({super.key});

  @override
  State<Week6AbcScreen> createState() => _Week6AbcScreenState();
}

class _Week6AbcScreenState extends State<Week6AbcScreen> {
  Map<String, dynamic>? _abcModel;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLatestAbcModel();
  }

  Future<void> _fetchLatestAbcModel() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('로그인 정보 없음');
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('abc_models')
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();
      if (snapshot.docs.isEmpty) {
        setState(() {
          _abcModel = null;
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _abcModel = snapshot.docs.first.data();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '데이터를 불러오지 못했습니다.';
        _isLoading = false;
      });
    }
  }

  Widget _highlightedText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _CrayonHighlightPainter()),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '6주차 - 불안 직면 VS 회피'),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Builder(
                    builder: (context) {
                      if (_isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (_error != null) {
                        return Center(
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.red),
                          ),
                        );
                      }
                      if (_abcModel == null) {
                        return const Center(
                          child: Text(
                            '최근에 작성한 ABC모델이 없습니다.',
                            style: TextStyle(fontSize: 16),
                          ),
                        );
                      }
                      final a = _abcModel?['activatingEvent'] ?? '';
                      final b = _abcModel?['belief'] ?? '';
                      final cPhysical =
                          _abcModel?['consequence_physical'] ?? '';
                      final cEmotion = _abcModel?['consequence_emotion'] ?? '';
                      final cBehavior =
                          _abcModel?['consequence_behavior'] ?? '';
                      final userName =
                          Provider.of<UserProvider>(
                            context,
                            listen: false,
                          ).userName;

                      // 날짜 포맷팅
                      String formattedDate = '';
                      if (_abcModel?['createdAt'] != null) {
                        final timestamp = _abcModel!['createdAt'] as Timestamp;
                        final date = timestamp.toDate();
                        formattedDate =
                            '${date.year}년 ${date.month}월 ${date.day}일에 작성된 걱정일기';
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 날짜 표시 (우측 상단)
                          if (formattedDate.isNotEmpty)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F0F0),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  formattedDate,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF666666),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Center(
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/image/question_icon.png',
                                  width: 32,
                                  height: 32,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  '최근에 작성하신 ABC 걱정일기를\n확인해 볼까요?',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: "$userName님은 "),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: _highlightedText("'$a'"),
                                ),
                                TextSpan(text: " 상황에서 "),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: _highlightedText("'$b'"),
                                ),
                                TextSpan(text: " 생각을 하였습니다.\n\n"),
                                if (cPhysical.isNotEmpty ||
                                    cEmotion.isNotEmpty ||
                                    cBehavior.isNotEmpty) ...[
                                  TextSpan(text: "그 결과 "),
                                  if (cPhysical.isNotEmpty) ...[
                                    TextSpan(text: "신체적으로 "),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: _highlightedText("'$cPhysical'"),
                                    ),
                                    TextSpan(text: " 증상이 나타났고, "),
                                  ],
                                  if (cEmotion.isNotEmpty) ...[
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: _highlightedText("'$cEmotion'"),
                                    ),
                                    TextSpan(text: " 감정을 느끼셨으며, "),
                                  ],
                                  if (cBehavior.isNotEmpty) ...[
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: _highlightedText("'$cBehavior'"),
                                    ),
                                    const TextSpan(text: "\n"),
                                    TextSpan(
                                      text: "행동을 하였습니다.\n\n",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ],
                      );
                    },
                  ),
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
          onNext: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) {
                  // ABC 모델에서 행동 데이터 추출
                  final behaviorData = _abcModel?['consequence_behavior'] ?? '';
                  List<String> behaviorList = [];

                  if (behaviorData is String && behaviorData.isNotEmpty) {
                    behaviorList =
                        behaviorData
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();
                  }

                  return Week6ConcentrationScreen(
                    behaviorListInput: behaviorList,
                    allBehaviorList: behaviorList,
                  );
                },
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
          },
        ),
      ),
    );
  }
}
