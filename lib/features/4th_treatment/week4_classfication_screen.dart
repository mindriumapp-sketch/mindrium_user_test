import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'week4_classfication_result_screen.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';

class Week4ClassificationScreen extends StatefulWidget {
  final List<String> bListInput;
  final int? beforeSud;
  final List<String> allBList;
  final List<String>? alternativeThoughts;
  final bool isFromAnxietyScreen;
  final List<String>? existingAlternativeThoughts;
  final String? abcId;
  final int loopCount;

  const Week4ClassificationScreen({
    super.key,
    required this.bListInput,
    this.beforeSud,
    required this.allBList,
    this.alternativeThoughts,
    this.isFromAnxietyScreen = false,
    this.existingAlternativeThoughts,
    this.abcId,
    this.loopCount = 1,
  });

  @override
  Week4ClassificationScreenState createState() =>
      Week4ClassificationScreenState();
}

class Week4ClassificationScreenState extends State<Week4ClassificationScreen> {
  Map<String, dynamic>? _abcModel;
  bool _isLoading = true;
  String? _error;
  double _sliderValue = 5.0;
  late List<String> _bList;
  late String _currentB;
  final Map<String, double> _bScores = {};

  @override
  void initState() {
    super.initState();
    // abcId가 전달되면 해당 문서를, 없으면 기존(최신) 로직으로 불러온다.
    final id = widget.abcId;
    if (id != null && id.isNotEmpty) {
      _fetchAbcModelById(id);
    } else {
      _fetchLatestAbcModel();
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
        _initBList();
      });
    } catch (e) {
      setState(() {
        _error = '데이터를 불러오지 못했습니다.';
        _isLoading = false;
      });
    }
  }

  /// 특정 abcId의 ABC 모델 문서를 불러온다.
  /// 성공 시: `_abcModel` 세팅 및 `_initBList()` 호출
  /// 실패 시: 에러 메시지 노출
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
          _isLoading = false;
          _error = '해당 ABC모델을 찾을 수 없습니다.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _abcModel = doc.data();
        _isLoading = false;
        _initBList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '데이터를 불러오지 못했습니다.';
        _isLoading = false;
      });
    }
  }

  void _initBList() {
    if (widget.bListInput.isNotEmpty) {
      // 건너뛴 생각들만 처리하되, allBList에서 건너뛴 생각들을 찾아서 처리
      final skippedThoughts = widget.bListInput;
      _bList = skippedThoughts;
      _currentB = _bList.first;
    } else if (_abcModel != null) {
      final bRaw = (_abcModel?['belief'] ?? '') as String;
      _bList =
          bRaw
              .split(',')
              .map((e) => e.trim())
              .whereType<String>()
              .where((e) => e.isNotEmpty)
              .toList();
      final remainB = _bList.where((b) => !_bScores.containsKey(b)).toList();
      _currentB =
          remainB.isNotEmpty
              ? remainB.first
              : (_bList.isNotEmpty ? _bList.first : '');
    } else {
      _bList = [];
      _currentB = '';
    }
    _sliderValue = 5.0;
  }

  void _onNext() {
    setState(() {
      _bScores[_currentB] = _sliderValue;
    });
    // 평가되지 않은 B만 remainingBList에 포함
    final List<String> remainingBList =
        _bList.where((b) => !_bScores.containsKey(b)).toList();

    // 불안 화면에서 추가한 생각인지 확인
    final bool isFromAnxietyScreen = widget.isFromAnxietyScreen;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (_, __, ___) => Week4ClassificationResultScreen(
              bScores: _bScores.values.toList(),
              bList: _bScores.keys.toList(),
              beforeSud: widget.beforeSud ?? 0,
              remainingBList: remainingBList,
              allBList: widget.allBList, // 모든 B 생각들 (건너뛴 생각들 포함)
              alternativeThoughts: widget.alternativeThoughts,
              isFromAnxietyScreen: isFromAnxietyScreen,
              existingAlternativeThoughts: widget.existingAlternativeThoughts,
              abcId: widget.abcId,
              loopCount: widget.loopCount,
            ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<UserProvider>(context, listen: false).userName;
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '4주차 - 인지 왜곡 찾기'),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
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
                              style: TextStyle(color: Colors.red),
                            ),
                          );
                        }
                        if ((_abcModel == null || _currentB.isEmpty) &&
                            (widget.bListInput.isEmpty)) {
                          return const Center(
                            child: Text(
                              '최근에 작성한 ABC모델이 없습니다.',
                              style: TextStyle(fontSize: 16),
                            ),
                          );
                        }
                        final displayB =
                            (_currentB.isNotEmpty)
                                ? _currentB
                                : (widget.bListInput.isNotEmpty)
                                ? widget.bListInput.first
                                : '';
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
                              '$userName님께서 걱정일기에 작성해주신 생각을 보며 진행해주세요.',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              displayB,
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '현재 위 생각에 대해 얼마나 강하게 믿고 계시나요?\n아래 슬라이더를 조정하고 다음을 눌러주세요.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        Slider(
                          value: _sliderValue,
                          min: 0,
                          max: 10,
                          divisions: 10,
                          label: _sliderValue.round().toString(),
                          activeColor: Color.lerp(
                            Color(0xFF4CAF50),
                            Color(0xFFFF5252),
                            _sliderValue / 10,
                          ),
                          inactiveColor: Colors.grey[300],
                          onChanged: (v) => setState(() => _sliderValue = v),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_sliderValue.round()}점',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '0점: 전혀 믿지 않음',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF4CAF50),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '10점: 매우 믿음',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFFFF5252),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
