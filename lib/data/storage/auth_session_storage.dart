import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 로그인 세션 식별 정보(토큰 제외)를 안전하게 저장합니다.
class AuthSessionStorage {
  static const _kUid = 'auth_uid';
  static const _kPatientId = 'auth_patient_id';
  static const _kEmail = 'auth_email';
  static const _kLoggedIn = 'auth_is_logged_in';

  static const _legacyUid = 'uid';
  static const _legacyPatientId = 'patient_id';
  static const _legacyEmail = 'email';
  static const _legacyLoggedIn = 'isLoggedIn';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> save({
    required String uid,
    required String patientId,
    required String email,
  }) async {
    await _storage.write(key: _kUid, value: uid);
    await _storage.write(key: _kPatientId, value: patientId);
    await _storage.write(key: _kEmail, value: email);
    await _storage.write(key: _kLoggedIn, value: 'true');
    await _clearLegacyPrefs();
  }

  Future<bool> get isLoggedIn async {
    final flag = await _storage.read(key: _kLoggedIn);
    return flag == 'true';
  }

  Future<String?> get userId async {
    final secure = await _storage.read(key: _kUid);
    if (secure != null && secure.isNotEmpty) return secure;
    return _migrateLegacyString(_legacyUid, _kUid);
  }

  Future<String?> get patientId async {
    final secure = await _storage.read(key: _kPatientId);
    if (secure != null && secure.isNotEmpty) return secure;
    return _migrateLegacyString(_legacyPatientId, _kPatientId);
  }

  Future<String?> get email async {
    final secure = await _storage.read(key: _kEmail);
    if (secure != null && secure.isNotEmpty) return secure;
    return _migrateLegacyString(_legacyEmail, _kEmail);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kUid);
    await _storage.delete(key: _kPatientId);
    await _storage.delete(key: _kEmail);
    await _storage.delete(key: _kLoggedIn);
    await _clearLegacyPrefs();
  }

  Future<String?> _migrateLegacyString(String legacyKey, String secureKey) async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(legacyKey)?.trim();
    if (legacy == null || legacy.isEmpty) return null;
    await _storage.write(key: secureKey, value: legacy);
    await prefs.remove(legacyKey);
    return legacy;
  }

  Future<void> _clearLegacyPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyUid);
    await prefs.remove(_legacyPatientId);
    await prefs.remove(_legacyEmail);
    await prefs.remove(_legacyLoggedIn);
  }
}
