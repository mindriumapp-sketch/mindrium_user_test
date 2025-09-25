import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// 캘린더 이벤트 모델 (week7_planning_screen.dart와 동일)
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

class Week7CalendarSummaryScreen extends StatefulWidget {
  const Week7CalendarSummaryScreen({super.key});

  @override
  State<Week7CalendarSummaryScreen> createState() =>
      _Week7CalendarSummaryScreenState();
}

class _Week7CalendarSummaryScreenState
    extends State<Week7CalendarSummaryScreen> {
  List<CalendarEvent> _savedEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
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
            _savedEvents.add(CalendarEvent.fromJson(eventData));
          } catch (e) {
            print('이벤트 파싱 오류: $e');
          }
        }
        _isLoading = false;
      });

      print('저장된 캘린더 이벤트 로드됨: ${_savedEvents.length}개');
    } catch (e) {
      print('캘린더 이벤트 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 모든 행동들을 중복 제거하여 가져오기
  List<String> _getAllUniqueBehaviors() {
    final allBehaviors = <String>{};
    for (final event in _savedEvents) {
      allBehaviors.addAll(event.behaviors);
    }
    return allBehaviors.toList()..sort();
  }

  // 특정 행동이 특정 이벤트에 포함되어 있는지 확인
  bool _isBehaviorInEvent(String behavior, CalendarEvent event) {
    return event.behaviors.contains(behavior);
  }

  // 완료 다이얼로그 표시
  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FF)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 성공 아이콘
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.celebration,
                    color: Colors.white,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 24),

                // 제목
                const Text(
                  '계획 완료!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3748),
                  ),
                ),

                const SizedBox(height: 16),

                // 메시지
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E8).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF4CAF50).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '계획 세운 일정을',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '한번 열심히 실천해보세요!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '건강한 생활 습관을 꾸준히 실천하여\n더 나은 나를 만들어가세요 💪',
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF718096).withOpacity(0.8),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 확인 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // 다이얼로그 닫기
                      _navigateToHome();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '홈으로 돌아가기',
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
        );
      },
    );
  }

  // 홈 화면으로 이동
  void _navigateToHome() {
    // 모든 화면을 제거하고 홈으로 이동
    // Navigator.pop을 여러 번 호출하여 스택을 정리
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '7주차 - 캘린더 요약'),
      body: SafeArea(
        child:
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF667EEA),
                    ),
                  ),
                )
                : _savedEvents.isEmpty
                ? _buildEmptyState()
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSizes.padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // 제목 섹션
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FF)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                            BoxShadow(
                              color: const Color(0xFF667EEA).withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF667EEA),
                                    Color(0xFF764BA2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF667EEA,
                                    ).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.calendar_view_month,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '캘린더 요약',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2D3748),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '계획된 건강한 생활 습관들을 확인하세요',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: const Color(
                                        0xFF718096,
                                      ).withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4CAF50),
                                    Color(0xFF66BB6A),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF4CAF50,
                                    ).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_savedEvents.length}개 이벤트',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Matrix 테이블
                      _buildMatrixTable(),

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
            _showCompletionDialog();
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FF)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: const Color(0xFF667EEA).withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE3F2FD), Color(0xFFF3E5F5)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                size: 48,
                color: const Color(0xFF1976D2).withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '저장된 캘린더 이벤트가 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3748),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '이전 화면에서 캘린더에 추가해보세요',
              style: TextStyle(
                fontSize: 15,
                color: const Color(0xFF718096).withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667EEA).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    '이전 화면으로 돌아가기',
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
        ),
      ),
    );
  }

  Widget _buildMatrixTable() {
    final allBehaviors = _getAllUniqueBehaviors();

    if (allBehaviors.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FF)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.table_chart,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '계획된 행동 일정표',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${allBehaviors.length}개 행동',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 행동별 행들
          ...allBehaviors.asMap().entries.map((entry) {
            final index = entry.key;
            final behavior = entry.value;
            final isLast = index == allBehaviors.length - 1;

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: index % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                borderRadius:
                    isLast
                        ? const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        )
                        : null,
                border:
                    !isLast
                        ? Border(
                          bottom: BorderSide(
                            color: const Color(0xFFE2E8F0).withOpacity(0.5),
                            width: 1,
                          ),
                        )
                        : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 행동명 섹션
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            behavior,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // 기간 섹션
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:
                          _savedEvents
                              .where(
                                (event) => _isBehaviorInEvent(behavior, event),
                              )
                              .map((event) {
                                final duration =
                                    event.endDate
                                        .difference(event.startDate)
                                        .inDays +
                                    1;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFE3F2FD),
                                        Color(0xFFF3E5F5),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF2196F3,
                                      ).withOpacity(0.2),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF2196F3,
                                        ).withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF2196F3,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.schedule,
                                          size: 14,
                                          color: Color(0xFF1976D2),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${event.startDate.month}월 ${event.startDate.day}일 ~ ${event.endDate.month}월 ${event.endDate.day}일',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF1976D2),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF1976D2,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '${duration}일',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF1976D2),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              })
                              .toList(),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
