import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/today_task_draft_progress.dart';
import 'package:gad_app_team/data/api/user_data_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/features/alarm/alarm_notification_service.dart';
import 'package:gad_app_team/utils/server_datetime.dart';

/// 홈 화면 '오늘의 할 일' 전용 Provider.
///
/// 백엔드: GET /users/me/todaytask
///
class TodayTaskProvider extends ChangeNotifier {
  // ───────────────────── 내부 클라이언트 ─────────────────────
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _client = ApiClient(tokens: _tokens);
  late final UserDataApi _userDataApi = UserDataApi(_client);
  late final DiariesApi _diariesApi = DiariesApi(_client);

  // ───────────────────── 상태 필드 ─────────────────────
  DateTime? _date; // 서버가 내려준 "오늘" 날짜 (KST 기준 string 을 parse)
  DateTime? get date => _date;

  bool _diaryDone = false;
  bool get diaryDone => _diaryDone;

  int _diaryDraftProgress = TodayTaskDraftProgress.none;
  int get diaryDraftProgress => _effectiveDiaryProgress;
  bool get diaryAnxietyDone =>
      _effectiveDiaryProgress >= TodayTaskDraftProgress.anxietyEvaluated;
  bool get diaryAbcDone =>
      _effectiveDiaryProgress >= TodayTaskDraftProgress.diaryWritten;
  bool get diaryLocTimeDone =>
      _effectiveDiaryProgress >= TodayTaskDraftProgress.locTimeRecorded;
  bool get diaryGroupDone =>
      _effectiveDiaryProgress >= TodayTaskDraftProgress.groupCompleted;

  bool _relaxationDone = false;
  bool get relaxationDone => _relaxationDone;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Object? _lastError;
  Object? get lastError => _lastError;

  bool get hasError => _lastError != null;
  int _requestId = 0;
  bool _notifyScheduled = false;

  bool get isLoaded => _date != null;

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

    // 혹시 프레임이 없으면 하나 예약
    SchedulerBinding.instance.scheduleFrame();
  }

  // ───────────────────── 서버 로딩 ─────────────────────

  /// 앱 시작 후, 홈 화면 진입 시 한 번 호출해주는 걸 권장.
  ///
  /// - 이미 불러온 상태면 그냥 덮어쓰기(최신 서버 기준으로 맞추기)
  Future<void> loadTodayTask() async {
    final myRequest = ++_requestId;
    _isLoading = true;
    _lastError = null;
    _notifyListenersSafely();

    try {
      await _loadFromServer(requestId: myRequest);
    } catch (e) {
      if (myRequest == _requestId) {
        _lastError = e;
        debugPrint('TodayTaskProvider.loadTodayTask 실패: $e');
      }
    } finally {
      if (myRequest == _requestId) {
        _isLoading = false;
        _notifyListenersSafely();
      }
    }
  }

  /// 명시적으로 오늘 할일만 새로고침하고 싶을 때 사용.
  ///
  /// 예: 일기 작성 완료 후 → 서버로 저장 API 호출 성공 → 그 다음에
  ///     `todayTaskProvider.refresh()` 호출해서 서버 기준으로 다시 맞추기.
  Future<void> refresh() async {
    final myRequest = ++_requestId;
    _lastError = null;

    try {
      await _loadFromServer(requestId: myRequest);
    } catch (e) {
      if (myRequest == _requestId) {
        _lastError = e;
        debugPrint('TodayTaskProvider.refresh 실패: $e');
      }
    } finally {
      if (myRequest == _requestId) {
        _notifyListenersSafely();
      }
    }
  }

  Future<void> _loadFromServer({required int requestId}) async {
    final data = await _userDataApi.getTodayTask();
    if (requestId != _requestId) return;

    // 날짜 필드 (예: "2025-12-03")
    final dateRaw = data['date'];
    if (dateRaw is String) {
      // "2025-12-03" -> DateTime(2025,12,3) 정도로만 쓰면 됨 (시간대 의미 없음)
      _date = parseServerDateOnly(dateRaw);
    } else {
      _date = null;
    }

    // 오늘 일기 작성 여부
    final diaryFlag = data['has_diary_today'];
    _diaryDone = diaryFlag == true;

    // 오늘 이완 여부
    final relaxFlag = data['has_relaxation_today'];
    _relaxationDone = relaxFlag == true;

    await _loadDiaryDraftProgress(requestId: requestId);

    await _syncTodayTaskReminderState();
  }

  int get _effectiveDiaryProgress =>
      _diaryDone ? TodayTaskDraftProgress.groupCompleted : _diaryDraftProgress;

  Future<void> _loadDiaryDraftProgress({required int requestId}) async {
    try {
      final draft = await _diariesApi.getLatestTodayTaskDraft();
      if (requestId != _requestId) return;
      if (draft != null) {
        // 미완성 초안이 있으면 서버 플래그보다 초안 상태를 우선한다.
        _diaryDone = false;
        _diaryDraftProgress = TodayTaskDraftProgress.normalize(
          draft['draft_progress'],
        );
      } else {
        _diaryDraftProgress =
            _diaryDone
                ? TodayTaskDraftProgress.groupCompleted
                : TodayTaskDraftProgress.none;
      }
    } catch (e) {
      if (requestId != _requestId) return;
      _diaryDraftProgress =
          _diaryDone
              ? TodayTaskDraftProgress.groupCompleted
              : TodayTaskDraftProgress.none;
      debugPrint('TodayTaskProvider._loadDiaryDraftProgress 실패: $e');
    }
  }

  // ───────────────────── 로컬에서만 살짝 건드릴 때 ─────────────────────

  /// 일기/이완/교육 완료 직후, 서버에 저장은 이미 했다고 가정하고
  /// 네트워크 없이 UI만 먼저 맞추고 싶을 때 사용.
  ///
  /// 나중에 꼬린 것 같으면 `refresh()`로 서버 기준으로 리셋하면 됨.
  void setTodayTaskLocally({
    bool? diaryDone,
    int? diaryDraftProgress,
    bool? relaxationDone,
  }) {
    final normalizedDiaryProgress =
        diaryDraftProgress == null
            ? null
            : TodayTaskDraftProgress.normalize(diaryDraftProgress);

    if (diaryDone != null) {
      _diaryDone = diaryDone;
    }
    if (normalizedDiaryProgress != null) {
      final shouldResetDiaryProgress =
          diaryDone == false &&
          normalizedDiaryProgress == TodayTaskDraftProgress.none;
      _diaryDraftProgress =
          shouldResetDiaryProgress
              ? TodayTaskDraftProgress.none
              : (_diaryDraftProgress >= normalizedDiaryProgress
                  ? _diaryDraftProgress
                  : normalizedDiaryProgress);
    }
    if (_diaryDone) {
      _diaryDraftProgress = TodayTaskDraftProgress.groupCompleted;
    }
    if (relaxationDone != null) {
      _relaxationDone = relaxationDone;
    }
    _notifyListenersSafely();
    unawaited(_syncTodayTaskReminderState());
  }

  /// 로그아웃 등에서 상태 싹 초기화.
  void reset() {
    _requestId++;
    _date = null;
    _diaryDone = false;
    _diaryDraftProgress = TodayTaskDraftProgress.none;
    _relaxationDone = false;
    _isLoading = false;
    _lastError = null;
    _notifyListenersSafely();
  }

  Future<void> _syncTodayTaskReminderState() {
    return AlarmNotificationService.instance.syncTodayTaskInactivityReminder(
      todayDate: _date,
      diaryDone: _diaryDone,
      relaxationDone: _relaxationDone,
    );
  }

  // 기존 clear() 호출하는 코드가 있을 수 있으니 alias로 남겨두기
  void clear() => reset();
}
