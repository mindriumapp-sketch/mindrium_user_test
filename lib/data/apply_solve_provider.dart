import '../utils/text_line_material.dart';

class AbcDiaryLocation {
  final double latitude;
  final double longitude;
  final String? addressName;

  AbcDiaryLocation({
    required this.latitude,
    required this.longitude,
    this.addressName,
  });
}

class ApplyOrSolveFlow extends ChangeNotifier {
  String? _origin; // 'apply' | 'daily'
  String? _diaryRoute; // 'notification' | 'today_task' | 'solve'
  String? _sessionId;
  String? _diaryId; // = abcId
  String? _groupId;
  int? _beforeSud;
  String? _sudId;
  dynamic _diary; // 'new' or diary summary map
  AbcDiaryLocation? _diaryLocation;

  static String? _normalizeOrigin(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed == 'solve') return 'apply';
    return trimmed;
  }

  // ───── getters ─────
  String get origin => _origin ?? 'edu';
  String? get diaryRoute => _diaryRoute;
  String? get sessionId => _sessionId;
  String? get diaryId => _diaryId;
  String? get groupId => _groupId;
  int? get beforeSud => _beforeSud;
  String? get sudId => _sudId;
  dynamic get diary => _diary;
  AbcDiaryLocation? get diaryLocation => _diaryLocation;

  // ───── 초기화 / 병합 ─────
  /// 전달된 args에서 필요한 값만 채워 넣는다. null이면 무시.
  void syncFromArgs(
    Map<dynamic, dynamic>? args, {
    bool override = false,
    bool notify = true,
  }) {
    if (args == null) return;
    bool changed = false;

    T? castValue<T>(dynamic v) => v is T ? v : null;
    String? asString(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isEmpty) return null;
      if (v is String) return v;
      return v.toString();
    }

    void setValue<T>(T? value, void Function(T) setter) {
      if (value == null) return;
      setter(value);
      changed = true;
    }

    if (override || _origin == null) {
      setValue<String>(
        _normalizeOrigin(
          castValue<String>(args['origin']) ?? asString(args['origin']),
        ),
        (v) => _origin = v,
      );
    }
    if (override || _diaryRoute == null) {
      setValue<String>(
        castValue<String>(args['diaryRoute']) ?? asString(args['diaryRoute']),
        (v) => _diaryRoute = v,
      );
    }
    if (override || _sessionId == null) {
      setValue<String>(castValue<String>(args['sessionId']),
          (v) => _sessionId = v);
    }
    if (override || _diaryId == null) {
      setValue<String>(
        castValue<String>(args['abcId']) ??
            asString(args['abcId']) ??
            castValue<String>(args['diaryId']) ??
            asString(args['diaryId']) ??
            castValue<String>(args['taskId']) ??
            asString(args['taskId']),
        (v) => _diaryId = v,
      );
    }
    if (override || _groupId == null) {
      setValue<String>(
          castValue<String>(args['groupId']) ?? asString(args['groupId']),
          (v) => _groupId = v);
    }
    if (override || _beforeSud == null) {
      final rawSud = args['beforeSud'];
      int? sud;
      if (rawSud is int) {
        sud = rawSud;
      } else if (rawSud is num) {
        sud = rawSud.toInt();
      } else if (rawSud is String) {
        sud = int.tryParse(rawSud);
      }
      setValue<int>(sud, (v) => _beforeSud = v);
    }
    if (override || _sudId == null) {
      setValue<String>(
          castValue<String>(args['sudId']) ?? asString(args['sudId']),
          (v) => _sudId = v);
    }
    if (override || _diary == null) {
      if (args.containsKey('diary')) {
        _diary = args['diary'];
        changed = true;
      }
    }

    if (changed && notify) notifyListeners();
  }

  Map<String, dynamic> toArgs() {
    return {
      'origin': origin,
      if (_diaryRoute != null) 'diaryRoute': _diaryRoute,
      if (_sessionId != null) 'sessionId': _sessionId,
      if (_diaryId != null) 'abcId': _diaryId,
      if (_groupId != null) 'groupId': _groupId,
      if (_beforeSud != null) 'beforeSud': _beforeSud,
      if (_sudId != null) 'sudId': _sudId,
    };
  }

  // 외부에서 강제로 세팅하고 싶을 때 (위치/시간에서 진입 등)
  void setOrigin(String? value) {
    final normalized = _normalizeOrigin(value);
    if (normalized == _origin) return;
    _origin = normalized;
    notifyListeners();
  }

  void setDiaryRoute(String? value) {
    if (value == _diaryRoute) return;
    _diaryRoute = value;
    notifyListeners();
  }

  void setSessionId(String? value) {
    if (value == _sessionId) return;
    _sessionId = value;
    notifyListeners();
  }

  void setDiaryId(String? value) {
    if (value == _diaryId) return;
    _diaryId = value;
    notifyListeners();
  }

  void setGroupId(String? value) {
    if (value == _groupId) return;
    _groupId = value;
    notifyListeners();
  }

  void setBeforeSud(int? value) {
    if (value == _beforeSud || value == null) return;
    _beforeSud = value;
    notifyListeners();
  }

  void setSudId(String? value) {
    if (value == _sudId) return;
    _sudId = value;
    notifyListeners();
  }

  void clear() {
    _origin = null;
    _diaryRoute = null;
    _sessionId = null;
    _diaryId = null;
    _groupId = null;
    _beforeSud = null;
    _sudId = null;
    _diary = null;
    _diaryLocation = null;
    notifyListeners();
  }
}
