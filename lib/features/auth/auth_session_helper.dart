import 'package:gad_app_team/data/daycounter.dart';
import 'package:gad_app_team/data/storage/auth_session_storage.dart';
import 'package:gad_app_team/data/today_task_provider.dart';
import 'package:gad_app_team/data/user_provider.dart';

/// 로그인·가입 성공 후 공통 세션 저장 및 초기 데이터 로딩.
class AuthSessionHelper {
  AuthSessionHelper._();

  static Future<void> completeSession({
    required UserProvider userProvider,
    required UserDayCounter dayCounter,
    required TodayTaskProvider todayTaskProvider,
    required String email,
  }) async {
    await userProvider.loadUserData(dayCounter: dayCounter);
    await todayTaskProvider.loadTodayTask();

    final session = AuthSessionStorage();
    await session.save(
      uid: userProvider.userId,
      patientId: userProvider.patientId,
      email: userProvider.userEmail.isNotEmpty ? userProvider.userEmail : email,
    );
  }
}
