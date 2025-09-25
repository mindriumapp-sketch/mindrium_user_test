import 'package:flutter/material.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_group_add.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class DiaryYesOrNo extends StatelessWidget {
  const DiaryYesOrNo({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
    final dynamic diary = args['diary'];
    return Scaffold(
      appBar: const CustomAppBar(title: '걱정 일기 진행'),
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '걱정 일기를 새로 작성 하시겠어요?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 32),
            // 예 버튼: 먼저 SUD(before) 평가로 이동
            SizedBox(
              width: 200,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/abc',
                    arguments: {
                      'origin': 'apply',
                      'abcId': null,
                      if (diary != null) 'diary': diary
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 24),
                  backgroundColor: Colors.indigo,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '예',
                  style: TextStyle(
                    color: Colors.white
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 아니오 버튼
            SizedBox(
              width: 200,
              height: 60,
              child: ElevatedButton(
                onPressed: () async {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid == null) return;

                  Position? pos;
                  try {
                    var perm = await Geolocator.checkPermission();
                    if (perm == LocationPermission.denied) {
                      perm = await Geolocator.requestPermission();
                    }
                    if (perm == LocationPermission.always ||
                        perm == LocationPermission.whileInUse) {
                      pos = await Geolocator.getCurrentPosition(
                        locationSettings:
                            const LocationSettings(accuracy: LocationAccuracy.low),
                      );
                    }
                  } catch (_) {
                    /* 위치 권한 거부 시 그냥 넘어감 */
                  }

                  final data = {
                    'activatingEvent': null,
                    'belief': null,
                    'consequence': null,
                    'createdAt': FieldValue.serverTimestamp(),
                    if (pos != null) 'latitude': pos.latitude,
                    if (pos != null) 'longitude': pos.longitude,
                  };

                  final docRef = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('abc_models')
                      .add(data);

                  if (!context.mounted) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AbcGroupAddScreen(
                        origin: 'apply',
                        abcId: docRef.id,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 24),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '아니오',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
