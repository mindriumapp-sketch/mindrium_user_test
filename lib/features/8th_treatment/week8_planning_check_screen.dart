import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/features/7th_treatment/week7_add_display_screen.dart';
import 'package:gad_app_team/features/8th_treatment/week8_effectiveness_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class Week8PlanningCheckScreen extends StatefulWidget {
  const Week8PlanningCheckScreen({super.key});

  @override
  State<Week8PlanningCheckScreen> createState() =>
      _Week8PlanningCheckScreenState();
}

class _Week8PlanningCheckScreenState extends State<Week8PlanningCheckScreen> {
  final List<String> _addedBehaviors = [];
  final List<String> _newBehaviors = [];
  final List<CalendarEvent> _savedEvents = [];
  bool _isLoading = true;

  // 행동 체크 상태 관리
  final Map<String, bool> _behaviorCheckStates = {};
  final Map<String, Map<String, bool>> _eventBehaviorCheckStates = {};

  @override
  void initState() {
    super.initState();
    _loadPlannedBehaviors();
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
      _isLoading = false;

      // 모든 행동의 체크 상태 초기화
      _behaviorCheckStates.clear();
      for (final behavior in [...globalBehaviors, ...globalNewBehaviors]) {
        _behaviorCheckStates[behavior] = false;
      }
    });

    _loadSavedEvents();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.grey100,
        appBar: const CustomAppBar(title: '8주차 - 계획 점검'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final allBehaviors = [..._addedBehaviors, ..._newBehaviors];

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: const CustomAppBar(title: '8주차 - 계획 점검'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSizes.space),

            // 안내 카드
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
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
                          Icons.checklist_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          '7주차 계획 점검',
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
                  const Text(
                    '7주차에서 계획하신 건강한 생활 습관들을\n실제로 실천하셨는지 점검해보세요.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSizes.space * 2),

            // 계획된 행동들
            if (allBehaviors.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: const Text(
                  '계획된 건강한 생활 습관',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 안내 메시지
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF667EEA).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667EEA).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.checklist_rounded,
                        color: Color(0xFF667EEA),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '실제로 실천하신 행동에 체크해주세요.\n체크된 행동은 효과를 평가하고 유지 여부를 결정합니다.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF667EEA),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...allBehaviors.asMap().entries.map((entry) {
                final index = entry.key;
                final behavior = entry.value;
                final isChecked = _behaviorCheckStates[behavior] ?? false;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          isChecked
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFE2E8F0),
                      width: isChecked ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        spreadRadius: 0,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // 체크박스
                      InkWell(
                        onTap: () {
                          setState(() {
                            _behaviorCheckStates[behavior] = !isChecked;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color:
                                isChecked
                                    ? const Color(0xFF4CAF50)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  isChecked
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFCBD5E0),
                              width: 2,
                            ),
                          ),
                          child:
                              isChecked
                                  ? const Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  )
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // 번호 배지
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF667EEA).withOpacity(0.1),
                              const Color(0xFF764BA2).withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF667EEA),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // 행동 텍스트
                      Expanded(
                        child: Text(
                          behavior,
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                isChecked
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFF2D3748),
                            height: 1.5,
                            decoration:
                                isChecked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      // 상태 아이콘
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              isChecked
                                  ? const Color(0xFF4CAF50).withOpacity(0.1)
                                  : const Color(0xFF667EEA).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isChecked
                              ? Icons.check_circle_rounded
                              : Icons.favorite_rounded,
                          color:
                              isChecked
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFF667EEA),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 24),
            ],

            // 저장된 캘린더 이벤트들
            if (_savedEvents.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: const Text(
                  '캘린더에 추가된 일정',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 캘린더 이벤트 안내 메시지
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF9800).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        color: Color(0xFFFF9800),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '캘린더에 등록된 일정의 행동들을 보고\n실천 여부를 체크해주세요.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFFF9800),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ..._savedEvents.map((event) {
                final duration =
                    event.endDate.difference(event.startDate).inDays + 1;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
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
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.calendar_today_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              '${event.startDate.month}월 ${event.startDate.day}일 ~ ${event.endDate.month}월 ${event.endDate.day}일',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3748),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9800).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$duration일',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF9800),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 행동 리스트
                      ...event.behaviors.map((behavior) {
                        final isChecked =
                            _eventBehaviorCheckStates[event.id]?[behavior] ??
                            false;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  isChecked
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFE2E8F0),
                              width: isChecked ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // 체크박스
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _eventBehaviorCheckStates[event
                                            .id]![behavior] =
                                        !isChecked;
                                  });
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color:
                                        isChecked
                                            ? const Color(0xFF4CAF50)
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color:
                                          isChecked
                                              ? const Color(0xFF4CAF50)
                                              : const Color(0xFFCBD5E0),
                                      width: 2,
                                    ),
                                  ),
                                  child:
                                      isChecked
                                          ? const Icon(
                                            Icons.check_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // 행동 텍스트
                              Expanded(
                                child: Text(
                                  behavior,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        isChecked
                                            ? const Color(0xFF4CAF50)
                                            : const Color(0xFF718096),
                                    decoration:
                                        isChecked
                                            ? TextDecoration.lineThrough
                                            : null,
                                  ),
                                ),
                              ),
                              // 상태 아이콘
                              Icon(
                                isChecked
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color:
                                    isChecked
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFFCBD5E0),
                                size: 16,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 24),
            ],

            // 계획이 없는 경우
            if (allBehaviors.isEmpty && _savedEvents.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
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
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        size: 40,
                        color: Color(0xFF718096),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '7주차에서 계획한 건강한 생활 습관이 없습니다.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF718096),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF667EEA).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFF667EEA),
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '다음 단계로 진행하여 8주간의 여정을 정리해보세요.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF667EEA),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            const SizedBox(height: AppSizes.space * 2),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
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
              onPressed: () {
                // 체크된 행동이 있는지 확인
                final hasCheckedBehaviors =
                    _behaviorCheckStates.values.any((checked) => checked) ||
                    _eventBehaviorCheckStates.values.any(
                      (eventStates) =>
                          eventStates.values.any((checked) => checked),
                    );

                if (hasCheckedBehaviors) {
                  // 체크된 행동들 수집
                  final checkedBehaviors = <String>[];

                  // 일반 행동들에서 체크된 것들 수집
                  for (final entry in _behaviorCheckStates.entries) {
                    if (entry.value) {
                      checkedBehaviors.add(entry.key);
                    }
                  }

                  // 캘린더 이벤트 행동들에서 체크된 것들 수집
                  for (final eventEntry in _eventBehaviorCheckStates.entries) {
                    for (final behaviorEntry in eventEntry.value.entries) {
                      if (behaviorEntry.value &&
                          !checkedBehaviors.contains(behaviorEntry.key)) {
                        checkedBehaviors.add(behaviorEntry.key);
                      }
                    }
                  }

                  // 효과성 평가 화면으로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => Week8EffectivenessScreen(
                            checkedBehaviors: checkedBehaviors,
                          ),
                    ),
                  );
                } else {
                  // TODO: 다음 화면으로 이동 (로드맵 화면)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('다음 화면으로 이동합니다.'),
                      backgroundColor: AppColors.indigo500,
                    ),
                  );
                }
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.indigo),
                foregroundColor: WidgetStateProperty.all(AppColors.white),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  ),
                ),
              ),
              child: const Text('다음'),
            ),
          ],
        ),
      ),
    );
  }
}
