import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/user_data_api.dart';
import 'package:gad_app_team/data/api/users_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/utils/text_line_material.dart';
import 'daycounter.dart';

/// ✅ 앱 전체에서 공통으로 쓰는 "유저 상태 + 진행도 + 핵심 가치 캐시" Provider
///
/// - /users/me             → 기본 프로필 정보 (이름, 이메일, 가입일, user_id 등)
/// - /users/me/progress    → 설문 완료 여부, current_week, last_completed_week, 일기/이완 개수, value_goal
class UserProvider extends ChangeNotifier {
  // ───────────────────── 내부 클라이언트 구성 ─────────────────────
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _client = ApiClient(tokens: _tokens);
  late final UsersApi _usersApi = UsersApi(_client);
  late final UserDataApi _userDataApi = UserDataApi(_client);

  // ───────────────────── 상태 플래그 ─────────────────────
  bool _hasError = false;
  bool get hasError => _hasError;

  bool _isLoadingUser = false;
  bool get isLoadingUser => _isLoadingUser;

  bool _isUserLoaded = false;
  bool get isUserLoaded => _isUserLoaded; // 기존 이름 유지 (HomeScreen 등 호환)

  // 여러 비동기 요청이 섞여 들어올 때 가장 마지막 요청만 유효하게 만들기 위한 ID
  int _requestId = 0;
  bool _notifyScheduled = false;

  // ───────────────────── 기본 프로필 정보 (/users/me) ─────────────────────
  String _userName = '사용자';
  String get userName => _userName;

  String _userEmail = '';
  String get userEmail => _userEmail;

  String _uid = '';
  String get userId => _uid;

  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;

  // ───────────────────── 진행도 / 설문 상태 (/users/me/progress) ─────────────────────
  bool _surveyCompleted = false;
  bool get surveyCompleted => _surveyCompleted;

  /// 서버에서 계산한 "현재 주차"
  int _currentWeek = 1;
  int get currentWeek => _currentWeek;

  int _lastCompletedWeek = 0;
  int get lastCompletedWeek => _lastCompletedWeek;

  DateTime? _lastCompletedAt;
  DateTime? get lastCompletedAt => _lastCompletedAt;

  int _totalDiaries = 0;
  int get totalDiaries => _totalDiaries;

  int _totalRelaxations = 0;
  int get totalRelaxations => _totalRelaxations;

  // ───────────────────── 핵심 가치 캐시 (progress에서 같이 내려옴) ─────────────────────
  String? _valueGoal;
  String? get valueGoal => _valueGoal;

  /// 진행도 정보가 로딩되었는지 여부 (선택적으로 사용할 수 있음)
  bool get isProgressLoaded =>
      _lastCompletedWeek != 0 ||
          _surveyCompleted ||
          _lastCompletedAt != null ||
          _totalDiaries > 0 ||
          _totalRelaxations > 0 ||
          _valueGoal != null;

  @override
  void notifyListeners() => _notifyListenersSafely();

  void _notifyListenersSafely() {
    if (!hasListeners) return;
    if (_notifyScheduled) return;
    _notifyScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!hasListeners) return;
      super.notifyListeners();
    });

    // 프레임이 없을 수도 있으니 보장
    SchedulerBinding.instance.scheduleFrame();
  }

  // ───────────────────── public API ─────────────────────

  /// /users/me + /users/me/progress 를 모두 불러서
  /// 프로필 + 진행도 + 핵심 가치 + dayCounter까지 한 번에 세팅.
  ///
  /// - 앱 시작 시(Splash 이후) 또는 로그인 직후에 1번 호출하는 걸 권장.
  Future<void> loadUserData({UserDayCounter? dayCounter}) async {
    final myRequest = ++_requestId;
    _isLoadingUser = true;
    _hasError = false;
    _notifyListenersSafely();

    try {
      // 1) 기본 프로필: /users/me
      final me = await _usersApi.me();

      // 만약 이 사이에 더 새로운 요청이 들어왔으면 이 응답은 무시
      if (myRequest != _requestId) return;

      _userName = (me['name'] as String?)?.trim().isNotEmpty == true
          ? (me['name'] as String)
          : '사용자';

      _userEmail = (me['email'] as String?) ?? '';
      _uid = (me['user_id'] as String?) ?? (me['_id'] as String? ?? '');

      // created_at 파싱
      final createdAtRaw = me['created_at'];
      DateTime? parsedCreatedAt;
      if (createdAtRaw is String) {
        parsedCreatedAt = DateTime.tryParse(createdAtRaw);
      } else if (createdAtRaw is DateTime) {
        parsedCreatedAt = createdAtRaw;
      }

      if (parsedCreatedAt != null) {
        _createdAt = parsedCreatedAt;
        // 가입일 기반 dayCounter 세팅
        dayCounter?.setCreatedAt(parsedCreatedAt);
      }

      // 2) 진행도 + 핵심 가치: /users/me/progress
      await _loadProgressFromServer(requestId: myRequest);

      // 여기까지 무사히 왔으면 "유저 로딩 완료" 상태로 간주
      if (myRequest == _requestId) {
        _isUserLoaded = _uid.isNotEmpty;
        _hasError = false;
      }
    } catch (e) {
      if (myRequest == _requestId) {
        _hasError = true;
        debugPrint('UserProvider.loadUserData 실패: $e');
      }
    } finally {
      if (myRequest == _requestId) {
        _isLoadingUser = false;
        _notifyListenersSafely();
      }
    }
  }

  /// 서버의 /users/me/progress 값을 다시 읽어서
  /// 진행도 + 핵심 가치 캐시만 새로 세팅.
  ///
  /// - 예: "주차 완료 API 호출 후, 서버 기준으로 다시 맞추고 싶을 때".
  Future<void> refreshProgress() async {
    final myRequest = ++_requestId;
    _hasError = false;

    try {
      await _loadProgressFromServer(requestId: myRequest);
      if (myRequest == _requestId) {
        _isUserLoaded = _uid.isNotEmpty;
      }
    } catch (e) {
      if (myRequest == _requestId) {
        _hasError = true;
        debugPrint('UserProvider.refreshProgress 실패: $e');
      }
    } finally {
      if (myRequest == _requestId) {
        _notifyListenersSafely();
      }
    }
  }

  /// 서버의 /users/me/value-goal 값을 다시 읽어서
  /// 핵심 가치 캐시만 새로 세팅.
  Future<void> refreshValueGoal() async {
    final myRequest = ++_requestId;
    _hasError = false;

    try {
      await _loadValueGoalFromServer(requestId: myRequest);
    } catch (e) {
      if (myRequest == _requestId) {
        _hasError = true;
        debugPrint('UserProvider.refreshValueGoal 실패: $e');
      }
    } finally {
      if (myRequest == _requestId) {
        _notifyListenersSafely();
      }
    }
  }

  /// 로그아웃 / 계정 전환 / 토큰 만료 후 재로그인 등에서
  /// 유저 관련 상태를 완전히 초기화할 때 사용.
  void reset() {
    _hasError = false;
    _isLoadingUser = false;
    _isUserLoaded = false;
    _requestId++;

    _userName = '사용자';
    _userEmail = '';
    _uid = '';
    _createdAt = null;

    _surveyCompleted = false;
    _currentWeek = 1;
    _lastCompletedWeek = 0;
    _lastCompletedAt = null;
    _totalDiaries = 0;
    _totalRelaxations = 0;
    _valueGoal = null;

    _notifyListenersSafely();
  }

  // ───────────────────── 내부 헬퍼 ─────────────────────

  /// /users/me/value-goal 응답을 읽어서 _valueGoal 갱신
  Future<void> _loadValueGoalFromServer({required int requestId}) async {
    final res = await _userDataApi.getValueGoal();
    if (requestId != _requestId) return;

    if (res == null) {
      _valueGoal = null;
    } else {
      final vg = res['value_goal'];
      if (vg is String) {
        _valueGoal = vg;
      } else {
        _valueGoal = null;
      }
    }
  }

  /// /users/me/progress 응답을 읽어서
  /// - surveyCompleted
  /// - currentWeek
  /// - lastCompletedWeek
  /// - lastCompletedAt
  /// - totalDiaries
  /// - totalRelaxations
  /// - valueGoal
  /// 전부 갱신
  Future<void> _loadProgressFromServer({required int requestId}) async {
    final progress = await _userDataApi.getProgress();
    if (requestId != _requestId) return;

    // 설문 완료 여부
    final surveyFlag = progress['survey_completed'];
    _surveyCompleted = surveyFlag is bool ? surveyFlag : false;

    // current_week
    final cwRaw = progress['current_week'];
    if (cwRaw is int) {
      _currentWeek = cwRaw;
    } else if (cwRaw is num) {
      _currentWeek = cwRaw.toInt();
    } else {
      _currentWeek = 1;
    }

    // 마지막 완료 주차
    final rawWeek = progress['last_completed_week'];
    if (rawWeek is int) {
      _lastCompletedWeek = rawWeek;
    } else if (rawWeek is num) {
      _lastCompletedWeek = rawWeek.toInt();
    } else {
      _lastCompletedWeek = 0;
    }

    // 마지막 완료 시각
    final rawAt = progress['last_completed_at'];
    DateTime? parsed;
    if (rawAt is String) {
      parsed = DateTime.tryParse(rawAt);
    } else if (rawAt is DateTime) {
      parsed = rawAt;
    }
    _lastCompletedAt = parsed;

    // 총 다이어리 수
    final totalDiariesRaw = progress['total_diaries'];
    if (totalDiariesRaw is int) {
      _totalDiaries = totalDiariesRaw;
    } else if (totalDiariesRaw is num) {
      _totalDiaries = totalDiariesRaw.toInt();
    } else {
      _totalDiaries = 0;
    }

    // 총 이완 훈련 수
    final totalRelaxRaw = progress['total_relaxations'];
    if (totalRelaxRaw is int) {
      _totalRelaxations = totalRelaxRaw;
    } else if (totalRelaxRaw is num) {
      _totalRelaxations = totalRelaxRaw.toInt();
    } else {
      _totalRelaxations = 0;
    }

    // 핵심 가치
    final vg = progress['value_goal'];
    if (vg is String) {
      _valueGoal = vg;
    } else {
      _valueGoal = null;
    }
  }

  // ───────────────────── 로컬 캐시만 조정하는 유틸 ─────────────────────

  /// 진행도 / 설문 상태를 "로컬에서만" 갱신할 때 쓰는 유틸.
  ///
  /// - 보통은 어떤 API를 이미 호출해서 서버에 반영한 뒤,
  ///   그 결과(또는 파라미터)를 그대로 넣어서 로컬 캐시를 맞춰줄 때 사용.
  void setProgressManually({
    bool? surveyCompleted,
    int? currentWeek,
    int? lastCompletedWeek,
    DateTime? lastCompletedAt,
    int? totalDiaries,
    int? totalRelaxations,
  }) {
    if (surveyCompleted != null) {
      _surveyCompleted = surveyCompleted;
    }
    if (currentWeek != null) {
      _currentWeek = currentWeek;
    }
    if (lastCompletedWeek != null) {
      _lastCompletedWeek = lastCompletedWeek;
    }
    if (lastCompletedAt != null) {
      _lastCompletedAt = lastCompletedAt;
    }
    if (totalDiaries != null) {
      _totalDiaries = totalDiaries;
    }
    if (totalRelaxations != null) {
      _totalRelaxations = totalRelaxations;
    }
    _notifyListenersSafely();
  }

  /// 핵심 가치를 "로컬에서만" 갱신할 때 쓰는 유틸.
  ///
  /// - 예: updateValueGoal API 성공 후, 응답의 value_goal을 그대로 반영.
  void setValueGoalLocally(String? valueGoal) {
    _valueGoal = valueGoal;
    _notifyListenersSafely();
  }

  /// 유저 이름을 로컬에서만 변경 (서버 PATCH는 별도 API가 담당)
  void updateUserName(String name) {
    _userName = name;
    _notifyListenersSafely();
  }
}
