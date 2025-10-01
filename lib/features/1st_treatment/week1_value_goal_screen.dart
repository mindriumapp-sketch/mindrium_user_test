import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/data/user_data_model.dart';
import 'package:gad_app_team/data/user_data_storage.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/features/menu/education/education_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Week1ValueGoalScreen extends StatefulWidget {
  const Week1ValueGoalScreen({super.key});

  @override
  State<Week1ValueGoalScreen> createState() => _Week1ValueGoalScreenState();
}

class _Week1ValueGoalScreenState extends State<Week1ValueGoalScreen> {
  final TextEditingController _valueController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
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
          final name = data?['name'] as String?;

          if (mounted) {
            setState(() {
              _userName = name ?? '사용자';
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _userName = '사용자';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _userName = '사용자';
          });
        }
      }
    } catch (e) {
      debugPrint('사용자 이름 로드 실패: $e');
      if (mounted) {
        setState(() {
          _userName = '사용자';
        });
      }
    }
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Firebase에 가치 데이터 저장
      final userData = UserData(
        name: _userName ?? '사용자',
        coreValue: _valueController.text.trim(),
        createdAt: DateTime.now(),
      );

      await UserDataStorage.saveUserData(userData);

      if (mounted) {
        _showEducationDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('데이터 저장 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showEducationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('1주차 교육 시작'),
            content: Text(
              _userName != null
                  ? '${_userName}님, 1주차 불안에 대해 배워보겠습니다.'
                  : '1주차 불안에 대해 배워보겠습니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => const EducationPage(
                            title: '1주차 - 불안에 대한 교육',
                            jsonPrefixes: [
                              'week1_part1_',
                              'week1_part2_',
                              'week1_part3_',
                              'week1_part4_',
                              'week1_part5_',
                              'week1_part6_',
                            ],
                          ),
                    ),
                  );
                },
                child: const Text('시작하기'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: const CustomAppBar(title: '1주차 - 시작하기'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: Form(
          key: _formKey,
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
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
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
                    Text(
                      _userName != null
                          ? '${_userName}님, 환영합니다! 🎉'
                          : '환영합니다! 🎉',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.indigo500,
                      ),
                    ),
                    const SizedBox(height: AppSizes.space),
                    Text(
                      _userName != null
                          ? 'Mindrium 교육 프로그램에 오신 것을 환영합니다.\n\n이 프로그램을 통해 불안을 관리하고 더 나은 삶을 만들어가시길 바랍니다.'
                          : 'Mindrium 교육 프로그램에 오신 것을 환영합니다.\n\n이 프로그램을 통해 불안을 관리하고 더 나은 삶을 만들어가시길 바랍니다.',
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

              // 가치 입력
              Text(
                _userName != null
                    ? '${_userName}님, 삶에서 가장 중요하게 생각하는\n가치는 무엇인가요?'
                    : '삶에서 가장 중요하게 생각하는 가치는 무엇인가요?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: AppSizes.space),
              const Text(
                '예: 가족, 건강, 성장, 자유, 사랑, 평화 등',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: AppSizes.space),
              TextFormField(
                controller: _valueController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '여러분이 가장 소중하게 여기는 가치를 자유롭게 적어주세요...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    borderSide: BorderSide(
                      color: AppColors.indigo500,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(AppSizes.padding),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '가치를 입력해주세요';
                  }
                  if (value.trim().length < 2) {
                    return '가치를 더 자세히 적어주세요';
                  }
                  return null;
                },
              ),

              const SizedBox(height: AppSizes.space * 3),

              // 저장 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveUserData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.indigo500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSizes.borderRadius,
                      ),
                    ),
                    elevation: 2,
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text(
                            '시작하기',
                            style: TextStyle(
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
                  color: AppColors.indigo500.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.indigo500,
                      size: 20,
                    ),
                    SizedBox(width: AppSizes.space),
                    Expanded(
                      child: Text(
                        '입력하신 정보는 프로그램 진행 중에 참고되며, 언제든지 수정하실 수 있습니다.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.indigo500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
