import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/features/4th_treatment/week4_imagination_screen.dart';
import 'package:gad_app_team/features/4th_treatment/week4_concentration_screen.dart';

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

class Week4AbcScreen extends StatefulWidget {
  final String? abcId;
  final int? sud;
  final int loopCount;

  const Week4AbcScreen({super.key, this.abcId, this.sud, this.loopCount = 1});

  @override
  State<Week4AbcScreen> createState() => _Week4AbcScreenState();
}

class _Week4AbcScreenState extends State<Week4AbcScreen> {
  Map<String, dynamic>? _abcModel;
  bool _isLoading = true;
  String? _error;
  List<String> _bList = [];


  @override
  void initState() {
    super.initState();
    // abcId 가 전달되면 해당 문서를, 없으면 최근 문서를 불러온다.
    final id = widget.abcId;
    if (id != null && id.isNotEmpty) {
      _fetchAbcModelById(id);
    } else {
      _fetchLatestAbcModel();
    }
  }

  /// 최신(가장 최근 createdAt) ABC 모델 1건을 불러온다.
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
        _bList = _parseBeliefToList(_abcModel?['belief']);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '데이터를 불러오지 못했습니다.';
        _isLoading = false;
      });
    }
  }

  List<String> _parseBeliefToList(dynamic raw) {
    final s = (raw ?? '').toString();
    return s
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// 특정 abcId 문서를 불러온다.
  /// - 성공: `_abcModel` 에 데이터 저장
  /// - 실패/없음: 에러 메시지 또는 빈 상태 처리
  Future<void> _fetchAbcModelById(String abcId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('로그인 정보 없음');

      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('abc_models')
              .doc(abcId)
              .get();

      if (!doc.exists) {
        if (!mounted) return;
        setState(() {
          _abcModel = null;
          _bList = [];
          _isLoading = false;
          _error = '해당 ABC모델을 찾을 수 없습니다.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _abcModel = doc.data();
        _bList = _parseBeliefToList(_abcModel?['belief']);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
    final sud = widget.sud;
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '4주차 - 인지 왜곡 찾기'),
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
            final id = widget.abcId;

            // abcId 가 없으면: Week4ImaginationScreen 으로 이동
            if (id == null || id.isEmpty) {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const Week4ImaginationScreen(),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              );
              return;
            }

            // abcId 가 있으면: 기존 Concentration 플로우
            setState(() => _isLoading = true);
            final beforeSudValue = sud ?? 0;

            // B(생각) 리스트가 비어 있으면 안내 후 리턴
            if (_bList.isEmpty) {
              setState(() => _isLoading = false);
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('B(생각) 데이터가 없습니다.')));
              return;
            }

            setState(() => _isLoading = false);
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder:
                    (_, __, ___) => Week4ConcentrationScreen(
                      bListInput: _bList,
                      beforeSud: beforeSudValue,
                      allBList: _bList,
                      abcId: widget.abcId,
                      loopCount: widget.loopCount,
                    ),
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
