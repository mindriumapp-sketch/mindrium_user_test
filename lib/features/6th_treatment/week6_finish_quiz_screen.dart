import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'week6_behavior_reflection_screen.dart';

class Week6FinishQuizScreen extends StatefulWidget {
  final List<Map<String, dynamic>>
  mismatchedBehaviors; // [{behavior: ..., userChoice: ..., actualResult: ...}]

  const Week6FinishQuizScreen({super.key, required this.mismatchedBehaviors});

  @override
  State<Week6FinishQuizScreen> createState() => _Week6FinishQuizScreenState();
}

class _Week6FinishQuizScreenState extends State<Week6FinishQuizScreen> {
  int _currentIdx = 0;
  Map<int, String> _answers = {};
  Map<String, dynamic>? _abcModel;
  String? _abcModelId; // ABC 모델의 문서 ID를 저장
  bool _isLoading = true;
  String? _error;
  List<String> _behaviorList = [];
  String _currentBehavior = '';

  @override
  void initState() {
    super.initState();
    _fetchLatestAbcModel();
  }

  void _initBehaviorList() {
    if (_abcModel != null && _abcModel!['consequence_behavior'] != null) {
      // consequence_behavior는 쉼표로 구분된 문자열이므로 분리
      String consequenceBehavior = _abcModel!['consequence_behavior'];
      _behaviorList =
          consequenceBehavior.split(', ').map((e) => e.trim()).toList();
      if (_behaviorList.isNotEmpty) {
        _currentBehavior = _behaviorList.first;
      } else {
        _behaviorList = [];
        _currentBehavior = '';
      }
    } else {
      _behaviorList = [];
      _currentBehavior = '';
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
        _abcModelId = snapshot.docs.first.id; // 문서 ID 저장
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

  Future<void> _saveBehaviorClassifications() async {
    try {
      print('=== 저장 시작 ===');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('로그인 정보 없음');
      print('사용자 ID: ${user.uid}');

      // 행동 분류 결과를 맵으로 변환
      Map<String, String> behaviorClassifications = {};
      print('답변 맵: $_answers');
      print('행동 리스트: $_behaviorList');

      for (int i = 0; i < _behaviorList.length; i++) {
        if (_answers.containsKey(i)) {
          String behavior = _behaviorList[i];
          String classification = _answers[i] == 'face' ? '직면' : '회피';
          behaviorClassifications[behavior] = classification;
          print('행동 $i: $behavior -> $classification');
        }
      }

      print('최종 분류 결과: $behaviorClassifications');

      // Firebase에 저장
      print('ABC 모델 ID: $_abcModelId');
      print('저장할 데이터: $behaviorClassifications');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('abc_models')
          .doc(_abcModelId)
          .update({
            'behavior_classifications': behaviorClassifications,
            'week6_completed': true,
            'week6_completed_at': FieldValue.serverTimestamp(),
          });

      print('=== 저장 완료 ===');

      // 저장 완료 후 홈으로 이동
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } catch (e) {
      print('=== 저장 에러 ===');
      print('에러 내용: $e');
      // 에러 발생 시에도 홈으로 이동 (사용자 경험을 위해)
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<UserProvider>(context, listen: false).userName;
    final bool hasBehavior = _currentBehavior.isNotEmpty;
    final isLast = hasBehavior ? _currentIdx == _behaviorList.length - 1 : true;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '6주차 - 마무리 퀴즈'),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Card(
                    color: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              )
              : _abcModel == null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Card(
                    color: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        '최근에 작성한 ABC모델이 없습니다.',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              )
              : Padding(
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
                            child: Column(
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
                                  hasBehavior ? _currentBehavior : '행동이 없습니다.',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (hasBehavior) ...[
                                  const Spacer(),
                                  Text(
                                    '${_currentIdx + 1} / ${_behaviorList.length}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF8888AA),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                "지금은 위 행동이 어느 쪽에 가까워 보이시나요? 아래 버튼을 눌러 선택해주세요.",
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
                                    _answers[_currentIdx] != null
                                        ? Container(
                                          width: double.infinity,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF2F3FE),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
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
                                                  _answers[_currentIdx] ==
                                                          'face'
                                                      ? '불안을 직면하는 행동이라고 선택하셨습니다.'
                                                      : '불안을 회피하는 행동이라고 선택하셨습니다.',
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
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 140,
                                      child: ElevatedButton(
                                        onPressed:
                                            hasBehavior
                                                ? () {
                                                  setState(
                                                    () =>
                                                        _answers[_currentIdx] =
                                                            'face',
                                                  );
                                                }
                                                : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF2962F6,
                                          ),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
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
                                        onPressed:
                                            hasBehavior
                                                ? () {
                                                  setState(
                                                    () =>
                                                        _answers[_currentIdx] =
                                                            'avoid',
                                                  );
                                                }
                                                : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color.fromARGB(
                                            255,
                                            226,
                                            86,
                                            86,
                                          ),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
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
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    NavigationButtons(
                      onBack:
                          _currentIdx > 0
                              ? () {
                                setState(() {
                                  _currentIdx--;
                                  _currentBehavior = _behaviorList[_currentIdx];
                                });
                              }
                              : () => Navigator.pop(context),
                      onNext:
                          hasBehavior && _answers[_currentIdx] != null
                              ? () {
                                if (!isLast) {
                                  setState(() {
                                    _currentIdx++;
                                    _currentBehavior =
                                        _behaviorList[_currentIdx];
                                    // 다음 행동으로 이동할 때 현재 답변 초기화
                                    _answers.remove(_currentIdx);
                                  });
                                } else {
                                  // 마지막 행동까지 완료했을 때 Firebase에 저장
                                  _saveBehaviorClassifications();
                                }
                              }
                              : null,
                    ),
                  ],
                ),
              ),
    );
  }
}
