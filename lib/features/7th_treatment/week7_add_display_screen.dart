import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/features/7th_treatment/week7_reason_input_screen.dart';
import 'package:gad_app_team/features/7th_treatment/week7_planning_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Week7AddDisplayScreen extends StatefulWidget {
  final String? initialBehavior;

  const Week7AddDisplayScreen({super.key, this.initialBehavior});

  @override
  State<Week7AddDisplayScreen> createState() => _Week7AddDisplayScreenState();

  // 전역 상태에 접근하기 위한 static getter
  static Set<String> get globalAddedBehaviors {
    final result = Set<String>.from(
      _Week7AddDisplayScreenState._globalAddedBehaviors,
    );
    print('=== globalAddedBehaviors getter 호출됨 ===');
    print('반환할 전역 상태: $result (길이: ${result.length})');
    print('=== globalAddedBehaviors getter 완료 ===');
    return result;
  }

  // 전역 상태를 업데이트하기 위한 static 메서드
  static void updateGlobalAddedBehaviors(Set<String> behaviors) {
    print('=== updateGlobalAddedBehaviors 호출됨 ===');
    print(
      '업데이트 전 전역 상태: ${_Week7AddDisplayScreenState._globalAddedBehaviors} (길이: ${_Week7AddDisplayScreenState._globalAddedBehaviors.length})',
    );
    print('새로운 상태: $behaviors (길이: ${behaviors.length})');

    // 새로운 상태로 교체
    _Week7AddDisplayScreenState._globalAddedBehaviors.clear();
    _Week7AddDisplayScreenState._globalAddedBehaviors.addAll(behaviors);

    print(
      '업데이트 후 전역 상태: ${_Week7AddDisplayScreenState._globalAddedBehaviors} (길이: ${_Week7AddDisplayScreenState._globalAddedBehaviors.length})',
    );
    print('=== updateGlobalAddedBehaviors 완료 ===');
  }

  // 새로운 행동들에 접근하기 위한 static getter
  static List<String> get globalNewBehaviors {
    final result = List<String>.from(
      _Week7AddDisplayScreenState._globalNewBehaviors,
    );
    print('=== globalNewBehaviors getter 호출됨 ===');
    print('반환할 새로운 행동들: $result (길이: ${result.length})');
    print('=== globalNewBehaviors getter 완료 ===');
    return result;
  }

  // 새로운 행동들을 업데이트하기 위한 static 메서드
  static void updateGlobalNewBehaviors(List<String> behaviors) {
    print('=== updateGlobalNewBehaviors 호출됨 ===');
    print(
      '업데이트 전 새로운 행동들: ${_Week7AddDisplayScreenState._globalNewBehaviors} (길이: ${_Week7AddDisplayScreenState._globalNewBehaviors.length})',
    );
    print('새로운 상태: $behaviors (길이: ${behaviors.length})');

    // 새로운 상태로 교체
    _Week7AddDisplayScreenState._globalNewBehaviors.clear();
    _Week7AddDisplayScreenState._globalNewBehaviors.addAll(behaviors);

    print(
      '업데이트 후 새로운 행동들: ${_Week7AddDisplayScreenState._globalNewBehaviors} (길이: ${_Week7AddDisplayScreenState._globalNewBehaviors.length})',
    );
    print('=== updateGlobalNewBehaviors 완료 ===');
  }
}

class _Week7AddDisplayScreenState extends State<Week7AddDisplayScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _abcModel;
  bool _isLoading = true;
  String? _error;
  List<Map<String, String>> _behaviorCards = [];
  Set<String> _addedBehaviors = {}; // 추가된 행동들을 추적
  late AnimationController _fadeController;
  late AnimationController _slideController;

  // 추가된 행동들을 전역적으로 관리하기 위한 static 변수
  static final Set<String> _globalAddedBehaviors = {};
  // 새로운 행동들을 전역적으로 관리하기 위한 static 변수
  static final List<String> _globalNewBehaviors = [];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fetchLatestAbcModel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('=== Week7AddDisplayScreen didChangeDependencies 호출됨 ===');
    // 화면이 다시 표시될 때마다 전역 상태와 동기화
    _syncWithGlobalState();
  }

  @override
  void didUpdateWidget(Week7AddDisplayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('=== Week7AddDisplayScreen didUpdateWidget 호출됨 ===');
    // 위젯이 업데이트될 때도 전역 상태와 동기화
    _syncWithGlobalState();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _syncWithGlobalState() {
    // 전역 상태와 로컬 상태를 동기화
    if (mounted) {
      final globalBehaviors = Set.from(_globalAddedBehaviors);
      print('=== _syncWithGlobalState 호출됨 ===');
      print('동기화 전 - 로컬: $_addedBehaviors (길이: ${_addedBehaviors.length})');
      print('동기화 전 - 전역: $globalBehaviors (길이: ${globalBehaviors.length})');

      // 항상 전역 상태를 기준으로 로컬 상태 업데이트
      print('전역 상태를 기준으로 로컬 상태 업데이트');
      setState(() {
        _addedBehaviors = globalBehaviors.cast<String>();
      });
      print('동기화 완료 - 로컬: $_addedBehaviors, 전역: $_globalAddedBehaviors');
      print('=== _syncWithGlobalState 완료 ===');
    }
  }

  Future<void> _fetchLatestAbcModel() async {
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
          _error = 'ABC 모델을 찾을 수 없습니다.';
        });
        return;
      }

      final data = snapshot.docs.first.data();
      setState(() {
        _abcModel = data;
        _isLoading = false;
        _initBehaviorCards();
      });

      // 애니메이션 시작
      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      setState(() {
        _error = '데이터를 불러오지 못했습니다: $e';
        _isLoading = false;
      });
    }
  }

  void _initBehaviorCards() {
    if (_abcModel == null) return;

    final behaviorClassifications =
        _abcModel!['behavior_classifications'] as Map<String, dynamic>?;
    if (behaviorClassifications == null) return;

    _behaviorCards =
        behaviorClassifications.entries.map((entry) {
          return {
            'behavior': entry.key,
            'classification': entry.value as String,
          };
        }).toList();

    // initialBehavior가 있으면 전역 상태에 추가
    if (widget.initialBehavior != null) {
      _globalAddedBehaviors.add(widget.initialBehavior!);
    }

    // 전역 상태에서 추가된 행동들을 가져오기 (항상 동기화)
    _addedBehaviors = Set.from(_globalAddedBehaviors);
  }

  String _getClassificationText(String classification) {
    switch (classification) {
      case '직면':
        return '불안 직면';
      case '회피':
        return '불안 회피';
      default:
        return '미분류';
    }
  }

  Color _getClassificationColor(String classification) {
    switch (classification) {
      case '직면':
        return const Color(0xFF00C853); // 밝은 초록색
      case '회피':
        return const Color(0xFFFF6F00); // 밝은 주황색
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  Color _getTagBackgroundColor(String classification) {
    switch (classification) {
      case '직면':
        return const Color(0xFFE8F5E8).withOpacity(0.8);
      case '회피':
        return const Color(0xFFFFF3E0).withOpacity(0.8);
      default:
        return Colors.grey.shade100.withOpacity(0.8);
    }
  }

  LinearGradient _getCardGradient(String classification) {
    switch (classification) {
      case '직면':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8F5E8), Color(0xFFF1F8E9), Color(0xFFF9FBE7)],
        );
      case '회피':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3E0), Color(0xFFFFF8E1), Color(0xFFFFFDE7)],
        );
      default:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5F5F5), Color(0xFFFAFAFA), Color(0xFFFEFEFE)],
        );
    }
  }

  void _showAddConfirmationDialog(String behavior) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '행동 추가',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"$behavior"',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '정말로 추가할까요?',
                style: TextStyle(fontSize: 16, color: Color(0xFF718096)),
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                          color: Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                    ),
                    child: const Text(
                      '취소',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF718096),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (_, __, ___) =>
                                  Week7ReasonInputScreen(behavior: behavior),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667EEA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '추가',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        );
      },
    );
  }

  void _showRemoveConfirmationDialog(String behavior) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF5722), Color(0xFFFF7043)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '행동 제거',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"$behavior"',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '건강한 생활 습관에서\n제거하시겠습니까?',
                style: TextStyle(fontSize: 16, color: Color(0xFF718096)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                          color: Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                    ),
                    child: const Text(
                      '취소',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF718096),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _removeFromHealthyHabits(behavior);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5722),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '제거',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        );
      },
    );
  }

  void _removeFromHealthyHabits(String behavior) {
    // 새로운 전역 상태 생성
    final newGlobalBehaviors = Set<String>.from(_globalAddedBehaviors);
    newGlobalBehaviors.remove(behavior);

    // 전역 상태 업데이트 (다른 화면에서 참조할 수 있도록)
    Week7AddDisplayScreen.updateGlobalAddedBehaviors(newGlobalBehaviors);

    // 로컬 상태 업데이트
    setState(() {
      _addedBehaviors.remove(behavior);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$behavior"이(가) 건강한 생활 습관에서 제거되었습니다.'),
        backgroundColor: const Color(0xFFFF5722),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showAddToHealthyHabitsDialog(String behavior) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.health_and_safety,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '건강한 생활 습관 추가',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '이 행동을 건강한 생활 습관에\n추가하시겠습니까?',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF718096),
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                          color: Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                    ),
                    child: const Text(
                      '아니요',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF718096),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _addBehaviorDirectly(behavior);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '예',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        );
      },
    );
  }

  void _addBehaviorDirectly(String behavior) {
    print('_addBehaviorDirectly 시작: $behavior');
    print('추가 전 로컬 상태: $_addedBehaviors');
    print('추가 전 전역 상태: $_globalAddedBehaviors');

    // 새로운 전역 상태 생성
    final newGlobalBehaviors = Set<String>.from(_globalAddedBehaviors);
    newGlobalBehaviors.add(behavior);

    // 전역 상태 업데이트 (다른 화면에서 참조할 수 있도록)
    Week7AddDisplayScreen.updateGlobalAddedBehaviors(newGlobalBehaviors);

    // 로컬 상태 업데이트
    setState(() {
      _addedBehaviors.add(behavior);
    });

    print('추가 후 로컬 상태: $_addedBehaviors');
    print('추가 후 전역 상태: $_globalAddedBehaviors');
    print('전역 상태 업데이트 완료');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$behavior"이(가) 건강한 생활 습관에 추가되었습니다.'),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 화면이 빌드될 때마다 전역 상태와 동기화 (setState 없이)
    final globalBehaviors = Set.from(_globalAddedBehaviors);
    if (_addedBehaviors != globalBehaviors) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _addedBehaviors = globalBehaviors.cast<String>();
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '7주차 - 생활 습관 개선'),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: Column(
          children: [
            // 제목 섹션
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FF)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.psychology,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '행동 분석 결과',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '6주차에서 분류한 행동들을 확인해보세요',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF718096),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 카드 목록
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF667EEA),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '데이터를 불러오는 중...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF718096),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFFE53E3E),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_behaviorCards.isEmpty)
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '분류된 행동이 없습니다',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF718096),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _behaviorCards.length,
                  itemBuilder: (context, index) {
                    final card = _behaviorCards[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildBehaviorCard(card, index),
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),
            NavigationButtons(
              onBack: () => Navigator.pop(context),
              onNext: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const Week7PlanningScreen(),
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

  Widget _buildBehaviorCard(Map<String, String> card, int index) {
    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        final delay = index * 0.1;
        final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _slideController,
            curve: Interval(delay, 1.0, curve: Curves.easeOutCubic),
          ),
        );

        return Transform.translate(
          offset: Offset(0, 30 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: _getCardGradient(card['classification'] ?? ''),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _getClassificationColor(
                      card['classification'] ?? '',
                    ).withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card['behavior'] ?? '',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _getTagBackgroundColor(
                                        card['classification'] ?? '',
                                      ),
                                      _getTagBackgroundColor(
                                        card['classification'] ?? '',
                                      ).withOpacity(0.6),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: _getClassificationColor(
                                      card['classification'] ?? '',
                                    ).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: _getClassificationColor(
                                          card['classification'] ?? '',
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: _getClassificationColor(
                                              card['classification'] ?? '',
                                            ).withOpacity(0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _getClassificationText(
                                        card['classification'] ?? '',
                                      ),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _getClassificationColor(
                                          card['classification'] ?? '',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_addedBehaviors.contains(
                                card['behavior'],
                              )) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '추가됨',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        if (_addedBehaviors.contains(card['behavior'])) {
                          // 이미 추가된 행동이면 제거 다이얼로그 표시
                          _showRemoveConfirmationDialog(card['behavior'] ?? '');
                        } else if (card['classification'] == '회피') {
                          // 회피 행동이고 추가되지 않았으면 추가 다이얼로그 표시
                          _showAddConfirmationDialog(card['behavior'] ?? '');
                        } else {
                          // 직면 행동이고 추가되지 않았으면 바로 추가 다이얼로그 표시
                          print('불안 직면 행동 클릭됨: ${card['behavior']}');
                          _showAddToHealthyHabitsDialog(card['behavior'] ?? '');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient:
                              _addedBehaviors.contains(card['behavior'])
                                  ? const LinearGradient(
                                    colors: [
                                      Color(0xFF4CAF50),
                                      Color(0xFF66BB6A),
                                    ],
                                  )
                                  : const LinearGradient(
                                    colors: [
                                      Color(0xFF667EEA),
                                      Color(0xFF764BA2),
                                    ],
                                  ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: (_addedBehaviors.contains(card['behavior'])
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFF667EEA))
                                  .withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _addedBehaviors.contains(card['behavior'])
                                  ? Icons.remove_circle_outline
                                  : Icons.add_circle_outline,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _addedBehaviors.contains(card['behavior'])
                                  ? '제거하기'
                                  : '추가하기',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
