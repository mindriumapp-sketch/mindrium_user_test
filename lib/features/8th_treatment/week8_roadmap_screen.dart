import 'package:flutter/material.dart';
import 'package:gad_app_team/data/user_data_storage.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/features/8th_treatment/week8_user_journey_screen.dart';

class Week8RoadmapScreen extends StatefulWidget {
  const Week8RoadmapScreen({super.key});

  @override
  State<Week8RoadmapScreen> createState() => _Week8RoadmapScreenState();
}

class _Week8RoadmapScreenState extends State<Week8RoadmapScreen> {
  String _userName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userName = await UserDataStorage.getUserName();
      setState(() {
        _userName = userName ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _userName = '';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: const CustomAppBar(title: '8주차 - 여정 로드맵'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 카드
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF4E6), Color(0xFFFFF8E1)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF9800).withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.map_outlined,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '8주간의 여정 로드맵',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D3748),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _userName.isNotEmpty
                        ? '$_userName님의 8주간 여정을 되돌아보세요'
                        : '8주간의 여정을 되돌아보세요',
                    style: TextStyle(
                      fontSize: 16,
                      color: const Color(0xFF718096).withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 로드맵 내용
            ...List.generate(7, (index) {
              final weekData = _getWeekData(index + 1);
              return _buildWeekCard(
                weekData['title']!,
                weekData['description']!,
                index + 1,
              );
            }),

            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: NavigationButtons(
          onBack: () => Navigator.pop(context),
          onNext: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Week8UserJourneyScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  Map<String, String> _getWeekData(int week) {
    switch (week) {
      case 1:
        return {
          'title': '1주차: 불안에 대한 교육',
          'description': '~님께서 소중히 여기는 가치를 생각해보고, 불안에 대해 알아보기',
        };
      case 2:
        return {
          'title': '2주차: ABC 모델',
          'description': '걱정일기 연습 및 작성, 위치와 시간 알림 설정하기, 걱정 그룹으로 분류하기',
        };
      case 3:
        return {
          'title': '3주차: Self Talk',
          'description': '예시로써 도움이 되는 생각과 도움이 되지 않는 생각 구분해보기',
        };
      case 4:
        return {
          'title': '4주차: 인지 왜곡 찾기',
          'description': '걱정일기 속 생각에 대해 도움이 되는 생각을 떠올려보는 연습하기',
        };
      case 5:
        return {
          'title': '5주차: 불안 직면 행동과 회피 행동에 대해 알아보기',
          'description': '예시로써 불안을 직면하는 행동인지 회피하는 행동인지 구분해보기',
        };
      case 6:
        return {
          'title': '6주차: 불안 직면 행동과 회피 행동에 대해 구분하기',
          'description': '걱정일기 속 행동에 대해 불안을 직면하는 행동인지 회피하는 행동인지 생각해보기',
        };
      case 7:
        return {
          'title': '7주차: 건강한 생활 습관',
          'description': '한 주 동안 실천할 건강한 생활 습관 세우기',
        };
      default:
        return {'title': '', 'description': ''};
    }
  }

  Widget _buildWeekCard(String title, String description, int weekNumber) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF9800).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9800).withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 주차 번호 아이콘
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$weekNumber',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // 내용
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF718096).withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
