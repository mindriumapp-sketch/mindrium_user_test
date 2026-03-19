import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:gad_app_team/utils/text_line_material.dart';

class UserDayCounter extends ChangeNotifier {
  DateTime? _createdAt;
  Timer? _timer;
  bool _notifyScheduled = false;

  @override
  void notifyListeners() => _notifyListenersSafely();

  void setCreatedAt(DateTime date) {
    _createdAt = date;
    _startDailyTimer();
    _notifyListenersSafely();
  }

  bool get isUserLoaded => _createdAt != null;

  void reset() {
    _timer?.cancel();
    _timer = null;
    _createdAt = null;
    _notifyListenersSafely();
  }

  int get daysSinceJoin {
    if (_createdAt == null) return 0;
    return daysBetween(DateTime.now(), _createdAt!).clamp(0, 999) + 1;
  }

  int daysBetween(DateTime a, DateTime b) {
    final da = DateTime(a.year, a.month, a.day);
    final db = DateTime(b.year, b.month, b.day);
    return da.difference(db).inDays;
  }

  int getWeekNumberFromJoin(DateTime targetDate) {
    if (_createdAt == null) return 0;

    final daysDiff = targetDate.difference(_createdAt!).inDays;
    return daysDiff < 0 ? 0 : (daysDiff ~/ 7) + 1;
  }

  void _startDailyTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(hours: 24), (_) {
      _notifyListenersSafely(); // 하루마다 갱신
    });
  }

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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
