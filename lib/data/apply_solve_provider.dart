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
  String? _origin;      // 'apply' | 'solve' | 'daily'
  String? _sessionId;
  String? _diaryId;     // = abcId
  int? _beforeSud;
  String? _sudId;
  AbcDiaryLocation? _diaryLocation;

  // ───── getters ─────
  String? get origin => _origin;
  String? get sessionId => _sessionId;
  String? get diaryId => _diaryId;
  int? get beforeSud => _beforeSud;
  String? get sudId => _sudId;
  AbcDiaryLocation? get diaryLocation => _diaryLocation;

  // ───── 초기화 ─────
  void init({
    String? origin,
    String? sessionId,
    String? diaryId,
  }) {
    // 이미 값 있으면 유지하고, 없을 때만 채우기
    _origin ??= origin;
    _sessionId ??= sessionId;
    _diaryId ??= diaryId;
    notifyListeners();
  }

  // 외부에서 강제로 세팅하고 싶을 때 (알림에서 진입 등)
  void setOrigin(String? value) {
    _origin = value;
    notifyListeners();
  }

  void setSessionId(String? value) {
    _sessionId = value;
    notifyListeners();
  }

  void setDiaryId(String value) {
    _diaryId = value;
    notifyListeners();
  }

  void setBeforeSud(int value) {
    _beforeSud = value;
    notifyListeners();
  }

  void setSudId(String value) {
    _sudId = value;
    notifyListeners();
  }

  void setDiaryLocation(AbcDiaryLocation value) {
    _diaryLocation = value;
    notifyListeners();
  }

  void clear() {
    _origin = null;
    _sessionId = null;
    _diaryId = null;
    _beforeSud = null;
    _sudId = null;
    _diaryLocation = null;
    notifyListeners();
  }
}
