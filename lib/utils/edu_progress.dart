import 'package:shared_preferences/shared_preferences.dart';

class EduLocalProgress {
  static const _nsPrefix = 'edu';
  static const _lastUidKey = 'edu.__last_uid';

  static String _nsKey(String userId, String raw) =>
      '$_nsPrefix.$userId.$raw';

  static String _readKey(String userId, String routeOrKey) =>
      _nsKey(userId, 'read.$routeOrKey');

  static String _lastRouteKey(String userId) =>
      _nsKey(userId, 'last_route');

  // ─────────────────────────────
  // 진행도 저장/조회
  // ─────────────────────────────
  static Future<void> saveRead(
      String userId,
      String routeOrKey,
      int read,
      ) async {
    final p = await SharedPreferences.getInstance();
    final key = _readKey(userId, routeOrKey);
    await p.setInt(key, read);
  }

  static Future<int> getRead(
      String userId,
      String routeOrKey,
      ) async {
    final p = await SharedPreferences.getInstance();
    final key = _readKey(userId, routeOrKey);
    return p.getInt(key) ?? 0;
  }

  static Future<void> setLastRoute(
      String userId,
      String route,
      ) async {
    final p = await SharedPreferences.getInstance();
    final key = _lastRouteKey(userId);
    await p.setString(key, route);
  }

  static Future<String?> getLastRoute(String userId) async {
    final p = await SharedPreferences.getInstance();
    final key = _lastRouteKey(userId);
    return p.getString(key);
  }

  // ─────────────────────────────
  // ✅ 유저 전환 감지 + 로컬 초기화 (선택)
  // ─────────────────────────────
  static Future<void> clearLocalIfUserSwitched(String currentUserId) async {
    final p = await SharedPreferences.getInstance();
    final lastUid = p.getString(_lastUidKey);

    // 최초 실행: 그냥 현재 uid만 기록
    if (lastUid == null) {
      await p.setString(_lastUidKey, currentUserId);
      return;
    }

    if (lastUid == currentUserId) {
      // 같은 유저 → 아무 것도 안 함
      return;
    }

    // 🔁 여기까지 왔으면 유저가 바뀐 것
    // 정책 1: 데이터는 네임스페이스로 이미 분리돼 있으니,
    //         그냥 last_uid만 업데이트(정합성에는 문제 없음)
    // await p.setString(_lastUidKey, currentUserId);

    // 정책 2: 이전 유저의 edu.* 데이터는 아예 지우고 싶다 → 아래 같이 prefix로 삭제
    final keys = p.getKeys();
    for (final key in keys) {
      if (key.startsWith('$_nsPrefix.$lastUid.')) {
        await p.remove(key);
      }
    }

    // 마지막으로 현재 uid 기록
    await p.setString(_lastUidKey, currentUserId);
  }
}

/// Backwards-compatible wrapper used across education screens.
class EduProgress {
  static const _nsPrefix = 'edu.global';
  static const _readPrefix = '$_nsPrefix.read.';
  static const _lastRouteKey = '$_nsPrefix.last_route';

  static Future<void> save(String key, int read) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('$_readPrefix$key', read);
  }

  static Future<int> getRead(String key) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt('$_readPrefix$key') ?? 0;
  }

  static Future<void> setLastRoute(String route) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_lastRouteKey, route);
  }

  static Future<String?> getLastRoute() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_lastRouteKey);
  }
}
