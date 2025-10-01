import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class SessionLogger {
  final String taskId;
  final int weekNumber;

  final DateTime _sessionStart = DateTime.now();
  final List<Map<String, dynamic>> _logEntries = [];
  Position? _startPosition; // 시작 위치 저장용

  SessionLogger({
    required this.taskId,
    required this.weekNumber,
  }) {
    _captureStartLocation(); // 생성자에서 위치 가져오기
  }

  Future<void> _captureStartLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _startPosition = pos;
    } catch (e) {
      print("위치 가져오기 실패: $e");
    }
  }

  void logEvent(String action) {
    final now = DateTime.now();
    final elapsed = now.difference(_sessionStart).inSeconds;

    _logEntries.add({
      "action": action,
      "timestamp": now.toIso8601String(),
      "elapsed_seconds": elapsed,
    });
  }

  Future<void> saveLogs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection("relaxation_tasks")
        .add({
      "taskId": taskId,
      "weekNumber": weekNumber,
      "startTime": _sessionStart.toIso8601String(),
      "endTime": DateTime.now().toIso8601String(),
      "latitude": _startPosition?.latitude,
      "longitude": _startPosition?.longitude,
      "logs": _logEntries,
    });
  }
}
