// ─────────────────────────  FLUTTER  ─────────────────────────
import 'package:flutter/material.dart';

// ────────────────────────  PACKAGES  ────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

// ───────────────────────────  LOCAL  ────────────────────────
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';

/// SUD(0‒10)을 입력받아 저장하고, 점수에 따라 후속 행동을 안내하는 화면
class BeforeSudRatingScreen extends StatefulWidget {
  final String? abcId;
  const BeforeSudRatingScreen({super.key, this.abcId});

  @override
  State<BeforeSudRatingScreen> createState() => _BeforeSudRatingScreenState();
}

class _BeforeSudRatingScreenState extends State<BeforeSudRatingScreen> {
  @override
  void initState() {
    super.initState();
    _abcId = widget.abcId; // may be null
    debugPrint('[SUD] arguments = $_abcId');
  }

  late final String? _abcId;
  int _sud = 0; // 슬라이더 값 (0‒10)

  // ────────────────────── Firestore 저장 ──────────────────────
  Future<void> _saveSud() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return; // 로그인하지 않은 경우
    if (_abcId == null || _abcId.isEmpty) return; // abcId 없으면 저장 생략

    final pos = await _getCurrentPosition(); // 위치 권한 없으면 null

    await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('abc_models')
      .doc(_abcId)
      .collection('sud_score')
      .add({
        'before_sud': _sud,
        'after_sud': _sud,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (pos != null) 'latitude': pos.latitude,
        if (pos != null) 'longitude': pos.longitude,
      });
  }

  /// 현재 위치 가져오기 (권한 거부 시 null)
  Future<Position?> _getCurrentPosition() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        return Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.low),
        );
      }
    } catch (_) {
      // 위치를 얻지 못해도 무시
    }
    return null;
  }

  Future<String> _loadGroupId(String uid, String abcId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('abc_models')
          .doc(abcId)
          .get();
      final data = doc.data();
      if (data == null) return '';
      final dynamic raw = data['group_id'] ?? data['groupId'];
      return raw == null ? '' : raw.toString();
    } catch (_) {
      return '';
    }
  }

  // ────────────────────────── UI ──────────────────────────
  @override
  Widget build(BuildContext context) {
    // 라우트 인자
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final String? origin = args?['origin'] as String?;
    final dynamic diary = args?['diary'];

    // 슬라이더·숫자·아이콘과 동일한 색 계열
    final Color trackColor = _sud <= 2 ? Colors.green : Colors.red;
    return Scaffold(
      appBar: const CustomAppBar(title: 'SUD 평가 (before)'),
      backgroundColor: Colors.grey.shade100,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.padding, vertical: 8),
          child: NavigationButtons(
            leftLabel: '이전',
            rightLabel: '저장',
            onBack: () => Navigator.pop(context),
            onNext: () async {
              await _saveSud();
              if (!context.mounted) return;

              final abcId = _abcId;

              if ((abcId == null || abcId.isEmpty) && origin == 'apply') {
                Navigator.pushReplacementNamed(
                  context,
                  '/diary_yes_or_no',
                  arguments: {
                    'origin': 'apply',
                    if (diary != null) 'diary': diary,
                    'beforeSud': _sud,
                  },
                );
                return;
              }

              if (_sud > 2) {
                if (abcId == null || abcId.isEmpty) {
                  Navigator.pushReplacementNamed(
                    context,
                    '/diary_yes_or_no',
                    arguments: {
                      'origin': 'apply',
                      if (diary != null) 'diary': diary,
                      'beforeSud': _sud,
                    },
                  );
                  return;
                }

                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('로그인 정보가 없습니다.')),
                  );
                  return;
                }

                final String ensuredAbcId = abcId;
                final groupId = await _loadGroupId(uid, ensuredAbcId);
                if (!context.mounted) return;
                Navigator.pushReplacementNamed(
                  context,
                  '/similar_activation',
                  arguments: {
                    'abcId': ensuredAbcId,
                    'groupId': groupId,
                    'sud': _sud,
                  },
                );
                return;
              }

              // TODO: 이완 애니메이션을 넣었으나 확실치 않음...(세현님 도와주세요..)
              // TODO: 일단 4주차 고정. 만약 주차별로 달라지는 이완이 필요한 거면 수정필요..
              if (abcId == null || abcId.isEmpty) {
                Navigator.pushReplacementNamed(
                  context,
                  '/relaxation_noti',
                  arguments: {
                    'taskId': abcId,
                    'weekNumber': 4,
                    'mp3Asset': 'week4.mp3',
                    'riveAsset': 'week4.riv',
                    'nextPage': '/relaxation_score',
                  },
                );
                return;
              }

              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('로그인 정보가 없습니다.')),
                );
                return;
              }

              final String ensuredAbcId = abcId;
              final groupId = await _loadGroupId(uid, ensuredAbcId);
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(
                context,
                '/diary_relax_home',
                arguments: {
                  'abcId': ensuredAbcId,
                  'groupId': groupId,
                  'sud': _sud,
                  'origin': origin,
                },
              );
            },
          ),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '지금 느끼는 불안 정도를 슬라이드로 선택해 주세요.',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),

                // ── 현재 점수 (숫자) ──
                Center(
                  child: Text(
                    '$_sud',
                    style: TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      color: trackColor
                    ),
                  ),
                ),

                // ── 큰 이모티콘 ──
                Icon(
                  _sud <= 2
                      ? Icons.sentiment_satisfied
                      : Icons.sentiment_very_dissatisfied_sharp,
                  size: 160,
                  color: trackColor,
                ),

                const SizedBox(height: 32),

                // ── 슬라이더 ──
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: trackColor,
                        thumbColor: trackColor,
                      ),
                      child: Slider(
                        value: _sud.toDouble(),
                        min: 0,
                        max: 10,
                        divisions: 10,
                        label: '$_sud',
                        onChanged: (v) => setState(() => _sud = v.round()),
                      ),
                    ),
                    const Positioned(
                      left: 0,
                      child: Text('0',
                          style:
                              TextStyle(fontSize: 20, color: Colors.black54)),
                    ),
                    const Positioned(
                      right: 0,
                      child: Text('10',
                          style:
                              TextStyle(fontSize: 20, color: Colors.black54)),
                    ),
                  ],
                ),

                // ── 작은 참조 이모티콘 ──
                Row(
                  children: const [
                    SizedBox(width: 12),
                    Text(
                      '평온',
                      textAlign: TextAlign.center,
                    ),
                    Spacer(),
                    Text(
                      '약한\n불안',
                      textAlign: TextAlign.center,
                    ),
                    Spacer(),
                    Text(
                      '중간\n불안',
                      textAlign: TextAlign.center,
                    ),
                    Spacer(),
                    Text(
                      '강한\n불안',
                      textAlign: TextAlign.center,
                    ),
                    Spacer(),
                    Text(
                      '극도의\n불안',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(width: 12),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
