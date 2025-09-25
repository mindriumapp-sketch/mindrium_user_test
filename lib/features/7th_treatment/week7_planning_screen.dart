import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/features/7th_treatment/week7_add_display_screen.dart';
import 'package:gad_app_team/features/7th_treatment/week7_calendar_summary_screen.dart';
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

class Week7PlanningScreen extends StatefulWidget {
  const Week7PlanningScreen({super.key});

  @override
  State<Week7PlanningScreen> createState() => _Week7PlanningScreenState();
}

class _Week7PlanningScreenState extends State<Week7PlanningScreen> {
  final TextEditingController _newBehaviorController = TextEditingController();
  final List<String> _addedBehaviors = [];
  final List<String> _newBehaviors = [];
  final List<CalendarEvent> _savedEvents = [];

  @override
  void initState() {
    super.initState();
    // 전역 상태에서 추가된 행동들을 가져오기
    _loadAddedBehaviors();
    // 저장된 캘린더 이벤트들을 로드
    _loadSavedEvents();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면이 다시 표시될 때마다 최신 상태를 가져오기
    _loadAddedBehaviors();
  }

  void _loadAddedBehaviors() {
    // Week7AddDisplayScreen의 전역 상태를 가져오기
    final globalBehaviors = Week7AddDisplayScreen.globalAddedBehaviors;
    final globalNewBehaviors = Week7AddDisplayScreen.globalNewBehaviors;
    print('=== Week7PlanningScreen _loadAddedBehaviors ===');
    print('전역 상태에서 가져온 행동들: $globalBehaviors (길이: ${globalBehaviors.length})');
    print(
      '전역 상태에서 가져온 새로운 행동들: $globalNewBehaviors (길이: ${globalNewBehaviors.length})',
    );
    print('로컬 상태 업데이트 전: $_addedBehaviors (길이: ${_addedBehaviors.length})');
    print('로컬 새로운 행동들 업데이트 전: $_newBehaviors (길이: ${_newBehaviors.length})');

    setState(() {
      _addedBehaviors.clear();
      _addedBehaviors.addAll(globalBehaviors);
      _newBehaviors.clear();
      _newBehaviors.addAll(globalNewBehaviors);
    });

    print('로컬 상태 업데이트 후: $_addedBehaviors (길이: ${_addedBehaviors.length})');
    print('로컬 새로운 행동들 업데이트 후: $_newBehaviors (길이: ${_newBehaviors.length})');
    print('=== Week7PlanningScreen _loadAddedBehaviors 완료 ===');
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
            _savedEvents.add(CalendarEvent.fromJson(eventData));
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

  // 캘린더 이벤트를 저장
  Future<void> _saveEvent(CalendarEvent event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = prefs.getStringList('calendar_events') ?? [];

      // 새 이벤트 추가
      eventsJson.add(jsonEncode(event.toJson()));

      await prefs.setStringList('calendar_events', eventsJson);

      setState(() {
        _savedEvents.add(event);
      });

      print('캘린더 이벤트 저장됨: ${event.id}');
    } catch (e) {
      print('캘린더 이벤트 저장 오류: $e');
    }
  }

  // 캘린더 이벤트 삭제
  Future<void> _deleteEvent(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = prefs.getStringList('calendar_events') ?? [];

      // 해당 이벤트 제거
      eventsJson.removeWhere((eventJson) {
        try {
          final eventData = jsonDecode(eventJson);
          return eventData['id'] == eventId;
        } catch (e) {
          return false;
        }
      });

      await prefs.setStringList('calendar_events', eventsJson);

      setState(() {
        _savedEvents.removeWhere((event) => event.id == eventId);
      });

      print('캘린더 이벤트 삭제됨: $eventId');
    } catch (e) {
      print('캘린더 이벤트 삭제 오류: $e');
    }
  }

  void _addNewBehavior() {
    final behavior = _newBehaviorController.text.trim();
    if (behavior.isNotEmpty) {
      // 새로운 전역 상태 생성
      final newGlobalBehaviors = List<String>.from(_newBehaviors);
      newGlobalBehaviors.add(behavior);

      // 전역 상태 업데이트
      Week7AddDisplayScreen.updateGlobalNewBehaviors(newGlobalBehaviors);

      // 로컬 상태 업데이트
      setState(() {
        _newBehaviors.add(behavior);
        _newBehaviorController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$behavior"이(가) 추가되었습니다.'),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _removeAddedBehavior(String behavior) {
    print('=== Week7PlanningScreen _removeAddedBehavior 시작 ===');
    print('제거할 행동: $behavior');
    print('제거 전 로컬 상태: $_addedBehaviors (길이: ${_addedBehaviors.length})');
    print(
      '제거 전 전역 상태: ${Week7AddDisplayScreen.globalAddedBehaviors} (길이: ${Week7AddDisplayScreen.globalAddedBehaviors.length})',
    );

    // 새로운 전역 상태 생성
    final newGlobalBehaviors = Set<String>.from(_addedBehaviors);
    newGlobalBehaviors.remove(behavior);

    // 전역 상태 업데이트 (다른 화면에서 참조할 수 있도록)
    Week7AddDisplayScreen.updateGlobalAddedBehaviors(newGlobalBehaviors);

    // 로컬 상태 업데이트
    setState(() {
      _addedBehaviors.remove(behavior);
    });

    print('제거 후 로컬 상태: $_addedBehaviors (길이: ${_addedBehaviors.length})');
    print(
      '제거 후 전역 상태: ${Week7AddDisplayScreen.globalAddedBehaviors} (길이: ${Week7AddDisplayScreen.globalAddedBehaviors.length})',
    );
    print('Week7PlanningScreen에서 행동 제거됨: $behavior, 남은 행동들: $_addedBehaviors');
    print('=== Week7PlanningScreen _removeAddedBehavior 완료 ===');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$behavior"이(가) 제거되었습니다.'),
        backgroundColor: const Color(0xFFFF5722),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _removeNewBehavior(String behavior) {
    // 새로운 전역 상태 생성
    final newGlobalBehaviors = List<String>.from(_newBehaviors);
    newGlobalBehaviors.remove(behavior);

    // 전역 상태 업데이트
    Week7AddDisplayScreen.updateGlobalNewBehaviors(newGlobalBehaviors);

    // 로컬 상태 업데이트
    setState(() {
      _newBehaviors.remove(behavior);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$behavior"이(가) 제거되었습니다.'),
        backgroundColor: const Color(0xFFFF5722),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showCalendarDialog() {
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                      Icons.calendar_today,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '캘린더에 추가',
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
                  const Text(
                    '선택한 건강한 생활 습관들을\n캘린더에 추가하시겠습니까?',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF718096),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 시작 기간 선택
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '시작 기간',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: startDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null) {
                              setState(() {
                                startDate = date;
                                // 종료일이 시작일보다 이전이면 종료일을 시작일로 설정
                                if (endDate.isBefore(startDate)) {
                                  endDate = startDate;
                                }
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${startDate.year}년 ${startDate.month}월 ${startDate.day}일',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                                const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Color(0xFF718096),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 종료 기간 선택
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '종료 기간',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: endDate,
                              firstDate: startDate, // 시작일 이후만 선택 가능
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null) {
                              setState(() {
                                endDate = date;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${endDate.year}년 ${endDate.month}월 ${endDate.day}일',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                                const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Color(0xFF718096),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
                          _addToCalendar(startDate, endDate);
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
      },
    );
  }

  void _addToCalendar(DateTime startDate, DateTime endDate) async {
    // 선택된 행동들 가져오기
    final allBehaviors = [..._addedBehaviors, ..._newBehaviors];

    if (allBehaviors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('추가할 행동이 없습니다.'),
          backgroundColor: Color(0xFFFF5722),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          margin: EdgeInsets.all(16),
        ),
      );
      return;
    }

    // 기간 계산
    final duration = endDate.difference(startDate).inDays + 1;

    // 캘린더 이벤트 생성
    final event = CalendarEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startDate: startDate,
      endDate: endDate,
      behaviors: allBehaviors,
      createdAt: DateTime.now(),
    );

    // 로컬에 저장
    await _saveEvent(event);

    print(
      '캘린더에 추가될 이벤트: $startDate ~ $endDate ($duration일), 행동들: $allBehaviors',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${allBehaviors.length}개의 행동이 ${startDate.month}월 ${startDate.day}일부터 ${endDate.month}월 ${endDate.day}일까지 (${duration}일간) 캘린더에 추가되었습니다.',
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '7주차 - 계획 세우기'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.padding),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // 상단 카드: 추가된 행동들과 새로운 행동 추가
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목
                    Row(
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
                            Icons.health_and_safety,
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
                                '건강한 생활 습관',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '추가된 행동들과 새로운 행동을 관리하세요',
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

                    const SizedBox(height: 24),

                    // 추가된 행동들
                    if (_addedBehaviors.isNotEmpty) ...[
                      const Text(
                        '추가된 행동들',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...(_addedBehaviors.map((behavior) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF4CAF50).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFF4CAF50),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  behavior,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _removeAddedBehavior(behavior),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF5722),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.remove,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList()),
                      const SizedBox(height: 16),
                    ],

                    // 새로운 행동 추가
                    const Text(
                      '새로운 행동 추가',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newBehaviorController,
                            decoration: InputDecoration(
                              hintText: '새로운 건강한 생활 습관을 입력하세요',
                              hintStyle: const TextStyle(
                                color: Color(0xFFA0AEC0),
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: const Color(0xFF667EEA),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _addNewBehavior,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 새로 추가된 행동들
                    if (_newBehaviors.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ...(_newBehaviors.map((behavior) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF2196F3).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.add_circle,
                                color: Color(0xFF2196F3),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  behavior,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _removeNewBehavior(behavior),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF5722),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.remove,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList()),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 하단 카드: 캘린더 추가
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFF8E1), Color(0xFFFFFDE7)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
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
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.calendar_today,
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
                                '캘린더에 추가',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '선택한 행동들을 일정에 추가하세요',
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

                    const SizedBox(height: 20),

                    const Text(
                      '현재 선택된 행동들:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 선택된 행동들 표시
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFF9800).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_addedBehaviors.isEmpty &&
                                _newBehaviors.isEmpty)
                              const Center(
                                child: Text(
                                  '아직 선택된 행동이 없습니다.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFFA0AEC0),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            else ...[
                              ...(_addedBehaviors + _newBehaviors).map((
                                behavior,
                              ) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFF9800),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          behavior,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF2D3748),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 저장된 캘린더 이벤트들
                    if (_savedEvents.isNotEmpty) ...[
                      const Text(
                        '저장된 캘린더 이벤트',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...(_savedEvents.map((event) {
                        final duration =
                            event.endDate.difference(event.startDate).inDays +
                            1;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFF9800).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${event.startDate.month}월 ${event.startDate.day}일 ~ ${event.endDate.month}월 ${event.endDate.day}일 ($duration일)',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2D3748),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _deleteEvent(event.id),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF5722),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '행동: ${event.behaviors.join(', ')}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF718096),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList()),
                      const SizedBox(height: 16),
                    ],

                    // 캘린더 추가 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            (_addedBehaviors.isNotEmpty ||
                                    _newBehaviors.isNotEmpty)
                                ? _showCalendarDialog
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9800),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '캘린더에 추가하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: NavigationButtons(
          onBack: () => Navigator.pop(context),
          onNext: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const Week7CalendarSummaryScreen(),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _newBehaviorController.dispose();
    super.dispose();
  }
}
