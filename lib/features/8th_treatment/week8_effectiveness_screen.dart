import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/features/7th_treatment/week7_add_display_screen.dart';
import 'package:gad_app_team/features/8th_treatment/week8_schedule_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

// 캘린더 이벤트 모델
class CalendarEvent {
  final String id;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> behaviors;
  final DateTime createdAt;

  CalendarEvent({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.behaviors,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'behaviors': behaviors,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      behaviors: List<String>.from(json['behaviors']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class Week8EffectivenessScreen extends StatefulWidget {
  final List<String> checkedBehaviors;

  const Week8EffectivenessScreen({super.key, required this.checkedBehaviors});

  @override
  State<Week8EffectivenessScreen> createState() =>
      _Week8EffectivenessScreenState();
}

class _Week8EffectivenessScreenState extends State<Week8EffectivenessScreen> {
  final List<String> _addedBehaviors = [];
  final List<String> _newBehaviors = [];
  final List<CalendarEvent> _savedEvents = [];
  bool _isLoading = true;

  // 체크된 행동들
  final List<String> _checkedBehaviors = [];
  final Map<String, Map<String, bool>> _eventBehaviorCheckStates = {};

  // 효과성 평가 상태
  int _currentBehaviorIndex = 0;
  bool? _wasEffective;
  bool? _willContinue;
  String? _userName;
  String? _userCoreValue;

  // 단계 관리
  int _currentStepIndex = 0; // 0: 효과성 평가, 1: 유지 여부 결정

  // 최종 결과
  final List<String> _behaviorsToKeep = [];
  final List<String> _behaviorsToRemove = [];

  // 제거된 행동들 (색상 변경용)
  final Set<String> _removedBehaviors = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _loadPlannedBehaviors();
    await _loadSavedEvents();
    await _loadUserData();
    _filterCheckedBehaviors();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (doc.exists) {
          final data = doc.data();
          if (mounted) {
            setState(() {
              _userName = data?['name'] as String?;
              _userCoreValue = data?['coreValue'] as String?;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('사용자 데이터 로드 실패: $e');
    }
  }

  void _loadPlannedBehaviors() {
    // Week7AddDisplayScreen의 전역 상태에서 추가된 행동들을 가져오기
    final globalBehaviors = Week7AddDisplayScreen.globalAddedBehaviors;
    final globalNewBehaviors = Week7AddDisplayScreen.globalNewBehaviors;

    setState(() {
      _addedBehaviors.clear();
      _addedBehaviors.addAll(globalBehaviors);
      _newBehaviors.clear();
      _newBehaviors.addAll(globalNewBehaviors);
    });
  }

  // 저장된 캘린더 이벤트들을 로드
  Future<void> _loadSavedEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = prefs.getStringList('calendar_events') ?? [];

      setState(() {
        _savedEvents.clear();
        for (final eventJson in eventsJson) {
          try {
            final eventData = jsonDecode(eventJson);
            final event = CalendarEvent.fromJson(eventData);
            _savedEvents.add(event);

            // 이벤트별 행동 체크 상태 초기화
            _eventBehaviorCheckStates[event.id] = {};
            for (final behavior in event.behaviors) {
              _eventBehaviorCheckStates[event.id]![behavior] = false;
            }
          } catch (e) {
            print('이벤트 파싱 오류: $e');
          }
        }
      });

      print('저장된 캘린더 이벤트 로드됨: ${_savedEvents.length}개');
    } catch (e) {
      print('캘린더 이벤트 로드 오류: $e');
    }
  }

  void _filterCheckedBehaviors() {
    // 이전 화면에서 전달받은 체크된 행동들을 사용
    _checkedBehaviors.clear();
    _checkedBehaviors.addAll(widget.checkedBehaviors);

    setState(() {
      _isLoading = false;
    });
  }

  String get _currentBehavior => _checkedBehaviors[_currentBehaviorIndex];

  int get _currentStep {
    return _currentStepIndex; // 명시적 단계 관리
  }

  bool get _isNextEnabled {
    switch (_currentStep) {
      case 0:
        return _wasEffective != null;
      case 1:
        return _willContinue != null;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // 효과성 평가 완료, 유지 여부 질문으로 이동
      _showEffectivenessResultSnackBar(_wasEffective == true);
      setState(() {
        _currentStepIndex = 1; // 유지 여부 질문으로 이동
      });
    } else if (_currentStep == 1 && _willContinue != null) {
      // 유지 여부 결정 완료, 현재 행동 처리
      if (_willContinue == true) {
        _behaviorsToKeep.add(_currentBehavior);
        _showBehaviorResultSnackBar('유지', '이 행동을 계속 실천하시겠습니다.');
      } else {
        _behaviorsToRemove.add(_currentBehavior);
        _showBehaviorResultSnackBar('제거', '이 행동을 계획에서 제거하시겠습니다.');

        // 제거된 행동으로 표시 (색상 변경용)
        _removedBehaviors.add(_currentBehavior);
      }

      // 다음 행동으로 이동
      if (_currentBehaviorIndex < _checkedBehaviors.length - 1) {
        setState(() {
          _currentBehaviorIndex++;
          _wasEffective = null;
          _willContinue = null;
          _currentStepIndex = 0; // 다음 행동의 효과성 평가로 이동
        });
      } else {
        // 모든 행동 평가 완료
        _showCompletionDialog();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        if (_currentStep == 1) {
          _currentStepIndex = 0; // 효과성 평가로 돌아가기
          _wasEffective = null; // 선택 초기화
        }
      });
    } else {
      // 첫 번째 단계에서 이전 버튼을 누르면 이전 화면으로 돌아가기
      Navigator.pop(context);
    }
  }

  void _showEffectivenessResultSnackBar(bool wasEffective) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              wasEffective ? Icons.thumb_up : Icons.thumb_down,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                wasEffective
                    ? '$_currentBehavior - 효과가 있었다고 평가하셨습니다.'
                    : '$_currentBehavior - 효과가 없었다고 평가하셨습니다.',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor:
            wasEffective ? const Color(0xFF2196F3) : const Color(0xFFFF9800),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showBehaviorResultSnackBar(String action, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              action == '유지' ? Icons.check_circle : Icons.remove_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$_currentBehavior - $message',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor:
            action == '유지' ? const Color(0xFF4CAF50) : const Color(0xFFFF5722),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 24),
                SizedBox(width: 12),
                Text(
                  '평가 완료',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_behaviorsToKeep.isNotEmpty) ...[
                  const Text(
                    '계속 유지할 행동:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ..._behaviorsToKeep.map((behavior) => Text('• $behavior')),
                  const SizedBox(height: 16),
                ],
                if (_behaviorsToRemove.isNotEmpty) ...[
                  const Text(
                    '제거할 행동:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ..._behaviorsToRemove.map((behavior) => Text('• $behavior')),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // 스케줄 화면으로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => Week8ScheduleScreen(
                            behaviorsToKeep: _behaviorsToKeep,
                          ),
                    ),
                  );
                },
                child: const Text('확인'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.grey100,
        appBar: const CustomAppBar(title: '8주차 - 효과성 평가'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_checkedBehaviors.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.grey100,
        appBar: const CustomAppBar(title: '8주차 - 효과성 평가'),
        body: const Center(
          child: Text(
            '평가할 행동이 없습니다.',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: const CustomAppBar(title: '8주차 - 효과성 평가'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.padding),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // 진행 표시
              Row(
                children: [
                  Text(
                    '${_currentBehaviorIndex + 1} / ${_checkedBehaviors.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LinearProgressIndicator(
                      value:
                          (_currentBehaviorIndex + 1) /
                          _checkedBehaviors.length,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.indigo500,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // 체크된 계획 표시
              _buildCheckedPlansSection(),

              const SizedBox(height: 32),

              // 현재 행동 표시
              _buildCurrentBehaviorCard(),

              const SizedBox(height: 32),

              // 질문 표시
              _buildQuestionCard(),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildNavigationButtons(),
    );
  }

  Widget _buildCheckedPlansSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.checklist_rounded,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '체크된 계획',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _checkedBehaviors.map((behavior) {
                  final isCurrent = behavior == _currentBehavior;
                  final isRemoved = _removedBehaviors.contains(behavior);

                  // 색상 결정
                  Color backgroundColor;
                  Color borderColor;
                  Color textColor;

                  if (isRemoved) {
                    // 제거된 행동: 빨간색
                    backgroundColor =
                        isCurrent
                            ? const Color(0xFFFF5722)
                            : const Color(0xFFFF5722).withOpacity(0.1);
                    borderColor =
                        isCurrent
                            ? const Color(0xFFFF5722)
                            : const Color(0xFFFF5722).withOpacity(0.3);
                    textColor =
                        isCurrent ? Colors.white : const Color(0xFFFF5722);
                  } else {
                    // 일반 행동: 초록색
                    backgroundColor =
                        isCurrent
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFF4CAF50).withOpacity(0.1);
                    borderColor =
                        isCurrent
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFF4CAF50).withOpacity(0.3);
                    textColor =
                        isCurrent ? Colors.white : const Color(0xFF4CAF50);
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Text(
                      behavior,
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor,
                        fontWeight:
                            isCurrent ? FontWeight.w600 : FontWeight.normal,
                        decoration:
                            isRemoved ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentBehaviorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.3),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  '효과성 평가',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _currentBehavior,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard() {
    String question = '';
    String description = '';
    IconData icon = Icons.help;
    Color color = AppColors.indigo500;

    switch (_currentStep) {
      case 0:
        question = '효과가 있었나요?';
        description =
            _userName != null && _userCoreValue != null
                ? '${_userName}님의 불안을 줄이고, 소중히 여기는 가치 "${_userCoreValue}"를 향상하는 데 도움이 되셨습니까?'
                : '이 행동이 불안을 줄이고 소중히 여기는 가치를 향상하는 데 도움이 되셨습니까?';
        icon = Icons.analytics;
        color = const Color(0xFF2196F3);
        break;
      case 1:
        question = '계속 유지하시겠습니까?';
        description = '이 행동을 앞으로도 계속 실천하시겠습니까?';
        icon = Icons.favorite;
        color = const Color(0xFFFF9800);
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF718096),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _buildYesNoButtons(),
        ],
      ),
    );
  }

  Widget _buildYesNoButtons() {
    bool? currentValue;
    switch (_currentStep) {
      case 0:
        currentValue = _wasEffective;
        break;
      case 1:
        currentValue = _willContinue;
        break;
    }

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                switch (_currentStep) {
                  case 0:
                    _wasEffective = true;
                    break;
                  case 1:
                    _willContinue = true;
                    break;
                }
              });

              // 효과성 평가에서 "예"를 선택한 경우 - 알림 제거
            },
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color:
                    currentValue == true
                        ? const Color(0xFF4CAF50)
                        : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      currentValue == true
                          ? const Color(0xFF4CAF50)
                          : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  '예',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color:
                        currentValue == true
                            ? Colors.white
                            : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                switch (_currentStep) {
                  case 0:
                    _wasEffective = false;
                    break;
                  case 1:
                    _willContinue = false;
                    break;
                }
              });

              // 효과성 평가에서 "아니오"를 선택한 경우 - 알림 제거
            },
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color:
                    currentValue == false
                        ? const Color(0xFFFF5722)
                        : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      currentValue == false
                          ? const Color(0xFFFF5722)
                          : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  '아니오',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color:
                        currentValue == false
                            ? Colors.white
                            : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.padding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FilledButton(
            onPressed: _previousStep,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(AppColors.white),
              foregroundColor: WidgetStateProperty.all(Colors.indigo),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  side: BorderSide(color: Colors.indigo.shade100),
                ),
              ),
            ),
            child: const Text('이전'),
          ),
          FilledButton(
            onPressed: _isNextEnabled ? _nextStep : null,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color?>((
                states,
              ) {
                if (states.contains(WidgetState.disabled)) {
                  return AppColors.grey300;
                }
                return Colors.indigo;
              }),
              foregroundColor: WidgetStateProperty.resolveWith<Color?>((
                states,
              ) {
                if (states.contains(WidgetState.disabled)) {
                  return Colors.grey;
                }
                return AppColors.white;
              }),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                ),
              ),
            ),
            child: Text(_currentStep == 2 ? '완료' : '다음'),
          ),
        ],
      ),
    );
  }
}
