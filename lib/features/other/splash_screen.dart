import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 앱 실행 시 처음 보여지는 스플래시 화면
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  Future<bool> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final result = prefs.getBool('isLoggedIn');
    return result == true;
  }
  
  Future<bool> _initApp() async {
    await createDefaultGroupIfNeeded(); // 그룹 생성 시도
    return await checkLoginStatus();    // 로그인 상태 확인
  }

  /// ✅ 로그인된 사용자 기반으로 기본 그룹 생성
  Future<void> createDefaultGroupIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⚠️ 로그인되지 않았습니다. 기본 그룹 생성을 건너뜁니다.');
      return;
    }

    final userId = user.uid; // ✅ 현재 로그인한 유저 UID
    final groupCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('abc_group');

    // 🔹 group_id == 1 인 문서가 있는지 검색
    final querySnapshot = await groupCollection
        .where('group_id', isEqualTo: "1")
        .get();

    if (querySnapshot.docs.isEmpty) {
      await groupCollection.add({
        'group_id': "1",
        'group_title': '기본그룹',
        'group_contents': '기본그룹 입니다',
        'created_at': DateTime.now(),
      });
      debugPrint('✅ ${user.email ?? user.uid} 의 기본 그룹이 새로 생성되었습니다.');
    } else {
      debugPrint('ℹ️ ${user.email ?? user.uid} 의 기본 그룹이 이미 존재합니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
       future: _initApp(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildSplashUI();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final isLoggedIn = snapshot.data ?? false;
          Navigator.pushReplacementNamed(
            context,
            isLoggedIn ? '/home' : '/login',
          );
        });

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
                Image.asset(
                  'assets/image/logo.png',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: AppSizes.space),
                const Text(
                  'Mindrium',
                  style: TextStyle(
                    fontSize: AppSizes.fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: AppSizes.space),
                const CircularProgressIndicator(color: AppColors.indigo),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(AppSizes.padding),
            child: Text(
              '걱정하지 마세요. 충분히 잘하고있어요.',
              style: TextStyle(fontSize: AppSizes.fontSize, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}