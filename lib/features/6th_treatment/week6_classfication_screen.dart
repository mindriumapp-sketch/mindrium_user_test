import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'week6_next_relieve_screen.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';

class Week6ClassificationScreen extends StatefulWidget {
  final List<String> behaviorListInput;
  final List<String> allBehaviorList;

  const Week6ClassificationScreen({
    super.key,
    required this.behaviorListInput,
    required this.allBehaviorList,
  });

  @override
  Week6ClassificationScreenState createState() =>
      Week6ClassificationScreenState();
}

class Week6ClassificationScreenState extends State<Week6ClassificationScreen> {
  Map<String, dynamic>? _abcModel;
  bool _isLoading = true;
  String? _error;
  // C(행동) 관련 변수
  String? _selectedFeedback;
  late List<String> _behaviorList;
  late String _currentBehavior;
  final Map<String, double> _behaviorScores = {};

  @override
  void initState() {
    super.initState();
    _fetchLatestAbcModel();
  }

  void _initBehaviorList() {
    if (widget.behaviorListInput.isNotEmpty) {
      _behaviorList = widget.behaviorListInput;
      _currentBehavior = _behaviorList.first;
    } else {
      _behaviorList = [];
      _currentBehavior = '';
    }
  }

  void _onNext() {
    // 현재 행동에 대한 점수 저장
    if (_behaviorScores.containsKey(_currentBehavior)) {
      // 남은 행동 목록 계산 (현재 행동 이후의 모든 행동)
      List<String> remainingBehaviors = [];
      final currentIndex = widget.allBehaviorList.indexOf(_currentBehavior);
      if (currentIndex >= 0 &&
          currentIndex < widget.allBehaviorList.length - 1) {
        remainingBehaviors = widget.allBehaviorList.sublist(currentIndex + 1);
      }

      // 결과 화면으로 이동
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder:
              (_, __, ___) => Week6NextRelieveScreen(
                selectedBehavior: _currentBehavior,
                behaviorType:
                    _behaviorScores[_currentBehavior] == 0.0 ? 'face' : 'avoid',
                sliderValue: 5.0, // 기본값으로 5.0 전달
                remainingBehaviors:
                    remainingBehaviors.isNotEmpty ? remainingBehaviors : null,
                allBehaviorList: widget.allBehaviorList,
              ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
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
        _initBehaviorList();
      });
    } catch (e) {
      setState(() {
        _error = '데이터를 불러오지 못했습니다.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '6주차 - 불안 직면 VS 회피'),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 상단 카드
            Expanded(
              child: SizedBox(
                width: double.infinity,
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
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (_error != null) {
                          return Center(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
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
                        // 현재 행동 표시
                        final currentBehavior = _currentBehavior;
                        final userName =
                            Provider.of<UserProvider>(
                              context,
                              listen: false,
                            ).userName;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Image.asset(
                              'assets/image/question_icon.png',
                              width: 32,
                              height: 32,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '$userName님께서 걱정일기에 작성해주신 행동을 보며 진행해주세요.',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              currentBehavior.isNotEmpty
                                  ? currentBehavior
                                  : '행동이 없습니다.',
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // 하단 카드
            Expanded(
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
                      if (_isLoading || _abcModel == null) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            "위 행동에 대해 어떤 행동인지 선택하고\n다음을 눌러주세요.",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 16),
                          // 피드백 영역
                          SizedBox(
                            height: 56,
                            child:
                                _selectedFeedback != null
                                    ? Container(
                                      width: double.infinity,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF2F3FE),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.04,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          const Text(
                                            '💡',
                                            style: TextStyle(fontSize: 22),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              _selectedFeedback!,
                                              style: const TextStyle(
                                                color: Color(0xFF8888AA),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    : Container(
                                      width: double.infinity,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF2F3FE),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.04,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: const [
                                          Text(
                                            '💡',
                                            style: TextStyle(fontSize: 22),
                                          ),
                                          SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              '선택하신 행동이 표시됩니다.',
                                              style: TextStyle(
                                                color: Color(0xFF8888AA),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 140,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _behaviorScores[_currentBehavior] = 0.0;
                                        _selectedFeedback =
                                            '불안을 직면하는 행동이라고 선택하셨습니다.';
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2962F6),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      '불안을 직면하는 행동',
                                      style: TextStyle(fontSize: 20),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: SizedBox(
                                  height: 140,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _behaviorScores[_currentBehavior] =
                                            10.0;
                                        _selectedFeedback =
                                            '불안을 회피하는 행동이라고 선택하셨습니다.';
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromARGB(
                                        255,
                                        226,
                                        86,
                                        86,
                                      ),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      '불안을 회피하는 행동',
                                      style: TextStyle(fontSize: 20),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            NavigationButtons(
              onBack: () => Navigator.pop(context),
              onNext: _onNext,
            ),
          ],
        ),
      ),
    );
  }
}
