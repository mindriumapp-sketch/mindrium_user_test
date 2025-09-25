import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserDatabase {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  static DocumentReference<Map<String, dynamic>> get _userDoc {
    final uid = _uid;
    return _firestore.collection('users').doc(uid);
  }

  static CollectionReference<Map<String, dynamic>> get _surveyCollection {
    return _userDoc.collection('surveys');
  }

  /// 설문 결과 저장
  static Future<void> saveSurveyResult({
    required List<String> worries,
    String? otherWorry,
    required String? sleepHours,
    required String? sleepQuality,
    List<String>? faceSelected,
    List<String>? avoidSelected,
  }) async {
    if (_uid == null) return;

    final surveyData = {
      'worries': worries,
      'otherWorry': otherWorry,
      'sleepHours': sleepHours,
      'sleepQuality': sleepQuality,
      'faceSelected': faceSelected ?? [],
      'avoidSelected': avoidSelected ?? [],
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _surveyCollection.add(surveyData);
    await _setSurveyCompleted();
  }

  /// 설문 완료 여부 true로 설정
  static Future<void> _setSurveyCompleted() async {
    if (_uid == null) return;
    await _userDoc.set({'hasCompletedSurvey': true}, SetOptions(merge: true));
  }

  /// 설문 완료 여부 확인
  static Future<bool> hasCompletedSurvey() async {
    if (_uid == null) return false;
    final snapshot = await _userDoc.get();
    return snapshot.data()?['hasCompletedSurvey'] == true;
  }
}
