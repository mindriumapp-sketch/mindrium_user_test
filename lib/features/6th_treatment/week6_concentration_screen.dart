import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/features/6th_treatment/week6_classfication_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Week6ConcentrationScreen extends StatefulWidget {
  final List<String> behaviorListInput;
  final List<String> allBehaviorList;

  const Week6ConcentrationScreen({
    super.key,
    required this.behaviorListInput,
    required this.allBehaviorList,
  });

  @override
  State<Week6ConcentrationScreen> createState() =>
      _Week6ConcentrationScreenState();
}

class _Week6ConcentrationScreenState extends State<Week6ConcentrationScreen> {
  bool _isNextEnabled = false;
  int _secondsLeft = 10;
  Map<String, dynamic>? _abcModel;
  bool _isLoading = true;
  bool _showSituation = true; // 상황(검정) → 안내(검정) 순서로

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _fetchLatestAbcModel();
  }

  Future<void> _fetchLatestAbcModel() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('로그인 정보 없음');

      print('Fetching ABC model for user: ${user.uid}'); // 디버깅용

      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('abc_models')
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();

      print('Snapshot docs count: ${snapshot.docs.length}'); // 디버깅용

      if (snapshot.docs.isEmpty) {
        print('No ABC models found'); // 디버깅용
        setState(() {
          _abcModel = null;
          _isLoading = false;
        });
        return;
      }

      final data = snapshot.docs.first.data();
      print('ABC model data: $data'); // 디버깅용

      setState(() {
        _abcModel = data;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching ABC model: $e'); // 디버깅용
      setState(() {
        _abcModel = null;
        _isLoading = false;
      });
    }
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

  String _getFirstBehavior(dynamic behavior) {
    if (behavior == null) return '';

    // 문자열인 경우 쉼표로 분리하여 첫번째 요소 반환
    if (behavior is String) {
      final parts =
          behavior
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
      return parts.isNotEmpty ? parts.first : '';
    }

    // 리스트인 경우 첫번째 요소 반환
    if (behavior is List) {
      return behavior.isNotEmpty ? behavior.first.toString() : '';
    }

    // 기타 타입은 문자열로 변환 후 처리
    final behaviorStr = behavior.toString();
    final parts =
        behaviorStr
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    return parts.isNotEmpty ? parts.first : '';
  }

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<UserProvider>(context, listen: false).userName;
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '6주차 - 불안 직면 VS 회피'),
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
                        color: Color(0xFF5B3EFF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      Column(
                        children: [
                          if (_showSituation)
                            Text(
                              _abcModel != null
                                  ? '"${_abcModel!['activatingEvent'] ?? ''}" (이)라는 상황에서 "${_getFirstBehavior(_abcModel!['consequence_behavior'])}"(이)라고 행동을 하였습니다.\n당시의 상황에 대해 잠시 집중해보겠습니다.'
                                  : '이때의 상황을\n자세하게 집중해 보세요.',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                                height: 1.5,
                                letterSpacing: 0.1,
                              ),
                              textAlign: TextAlign.left,
                            )
                          else
                            Text(
                              '앞서 보셨던 행동에 대해 불안을 직면하는 행동인지 회피하는 행동인지 알아볼게요.',
                              style: const TextStyle(
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
                              (_, __, ___) => Week6ClassificationScreen(
                                behaviorListInput: widget.allBehaviorList,
                                allBehaviorList: widget.allBehaviorList,
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
