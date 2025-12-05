import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gad_app_team/data/daycounter.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/data/today_task_provider.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/common/constants.dart';

/// 앱 실행 시 처음 보여지는 스플래시 화면
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final Future<bool> _initFuture;

  /// 앱 초기화:
  /// - 토큰 조회
  /// - 있으면 /users/me + /users/me/progress 로딩
  /// - UserDayCounter + TodayTask까지 세팅
  Future<bool> _initApp() async {
    final tokens = TokenStorage();

    final userProvider = context.read<UserProvider>();
    final dayCounter = context.read<UserDayCounter>();
    final todayTaskProvider = context.read<TodayTaskProvider>();

    // 항상 가장 먼저: 모든 관련 Provider를 깨끗한 상태로 리셋
    userProvider.reset();
    todayTaskProvider.reset();
    dayCounter.reset();

    final access = await tokens.access;
    if (access == null) return false;

    try {
      // 1) /users/me + /users/me/progress + value-goal + dayCounter 세팅
      await userProvider.loadUserData(dayCounter: dayCounter);
      // 2) 오늘의 할 일 초기 로딩
      await todayTaskProvider.loadTodayTask();

      return userProvider.isUserLoaded;
    } catch (e) {
      // 토큰은 있는데 서버 쪽 문제 / 401 등 → 토큰 정리 후 로그인으로 돌린다
      await tokens.clear();

      // 프로바이더들도 다시 초기화
      userProvider.reset();
      todayTaskProvider.reset();
      dayCounter.reset();

      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _initFuture = _initApp();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _initFuture,
      builder: (context, snapshot) {
        // 아직 로딩 중
        if (!snapshot.hasData) {
          return _buildSplashUI();
        }

        // 로딩 끝난 뒤 화면 전환
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final isLoggedIn = snapshot.data ?? false;

          if (!isLoggedIn) {
            // 토큰 없음 또는 초기화 실패 → 로그인 화면
            Navigator.pushReplacementNamed(context, '/login');
            return;
          }

          // 토큰 있고, UserProvider에 loadUserData까지 끝난 상태
          final userProvider = context.read<UserProvider>();
          final surveyDone = userProvider.surveyCompleted;

          if (surveyDone) {
            // 설문까지 끝낸 유저만 홈으로
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            // 설문 아직 안 한 유저는 무조건 사전 설문으로
            Navigator.pushReplacementNamed(context, '/before_survey');
          }
        });

        // 전환되기 전까지는 스플래시 유지
        return _buildSplashUI();
      },
    );
  }

  Widget _buildSplashUI() {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: Column(
              children: [
                Image.asset('assets/image/logo.png', width: 100, height: 100),
                const SizedBox(height: AppSizes.space),
                const CircularProgressIndicator(color: AppColors.indigo),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(AppSizes.padding),
            child: Text(
              '걱정하지 마세요. 충분히 잘하고있어요.',
              style: TextStyle(
                fontSize: AppSizes.fontSize,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
