import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ValueStartScreen extends StatefulWidget {
  final int weekNumber;
  final String weekTitle;
  final String weekDescription;
  final Widget Function() nextPageBuilder;

  const ValueStartScreen({
    super.key,
    required this.weekNumber,
    required this.weekTitle,
    required this.weekDescription,
    required this.nextPageBuilder,
  });

  @override
  State<ValueStartScreen> createState() => _ValueStartScreenState();
}

class _ValueStartScreenState extends State<ValueStartScreen> {
  String? _userName;
  String? _userCoreValue;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
          final data = doc.data()!;
          if (mounted) {
            setState(() {
              _userName = data['name'] as String?;
              _userCoreValue = data['coreValue'] as String?;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('사용자 데이터 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startWeek() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => widget.nextPageBuilder()),
    );
  }

  String _getWeekIcon(int weekNumber) {
    switch (weekNumber) {
      case 2:
        return '🧠';
      case 3:
        return '💭';
      case 4:
        return '🔍';
      case 5:
        return '⚡';
      case 6:
        return '🎯';
      case 7:
        return '📅';
      case 8:
        return '🏆';
      default:
        return '📚';
    }
  }

  Color _getWeekColor(int weekNumber) {
    switch (weekNumber) {
      case 2:
        return Colors.blue;
      case 3:
        return Colors.green;
      case 4:
        return Colors.orange;
      case 5:
        return Colors.purple;
      case 6:
        return Colors.red;
      case 7:
        return Colors.teal;
      case 8:
        return Colors.amber;
      default:
        return AppColors.indigo500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekColor = _getWeekColor(widget.weekNumber);
    final weekIcon = _getWeekIcon(widget.weekNumber);

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: CustomAppBar(title: '${widget.weekNumber}주차 - 시작하기'),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSizes.space),

                    // 환영 메시지
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSizes.padding),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          AppSizes.borderRadius,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                weekIcon,
                                style: const TextStyle(fontSize: 32),
                              ),
                              const SizedBox(width: AppSizes.space),
                              Expanded(
                                child: Text(
                                  _userName != null
                                      ? '${_userName}님, ${widget.weekNumber}주차에 오신 것을 환영합니다!'
                                      : '${widget.weekNumber}주차에 오신 것을 환영합니다!',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: weekColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.space),
                          Text(
                            widget.weekDescription,
                            style: const TextStyle(
                              fontSize: AppSizes.fontSize,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSizes.space * 2),

                    // 사용자 가치 표시
                    if (_userCoreValue != null) ...[
                      const Text(
                        '당신의 핵심 가치',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: AppSizes.space),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSizes.padding),
                        decoration: BoxDecoration(
                          color: weekColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            AppSizes.borderRadius,
                          ),
                          border: Border.all(
                            color: weekColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.favorite,
                                  color: weekColor,
                                  size: 20,
                                ),
                                const SizedBox(width: AppSizes.space),
                                Text(
                                  '${_userName ?? '사용자'}님이 소중히 여기는 가치',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: weekColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.space),
                            Text(
                              _userCoreValue!,
                              style: const TextStyle(
                                fontSize: AppSizes.fontSize,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSizes.space * 2),
                    ],

                    // 주차별 안내
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSizes.padding),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          AppSizes.borderRadius,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: weekColor,
                                size: 20,
                              ),
                              const SizedBox(width: AppSizes.space),
                              Text(
                                '${widget.weekNumber}주차 활동 안내',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: weekColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.space),
                          Text(
                            widget.weekTitle,
                            style: const TextStyle(
                              fontSize: AppSizes.fontSize,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSizes.space * 3),

                    // 시작 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _startWeek,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: weekColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.borderRadius,
                            ),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          '${widget.weekNumber}주차 시작하기',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSizes.space),

                    // 안내 메시지
                    Container(
                      padding: const EdgeInsets.all(AppSizes.padding),
                      decoration: BoxDecoration(
                        color: weekColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          AppSizes.borderRadius,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: weekColor,
                            size: 20,
                          ),
                          const SizedBox(width: AppSizes.space),
                          Expanded(
                            child: Text(
                              '이번 주차 활동을 통해 ${_userName ?? '당신'}의 핵심 가치를 더욱 실현해보세요.',
                              style: TextStyle(fontSize: 12, color: weekColor),
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
}
