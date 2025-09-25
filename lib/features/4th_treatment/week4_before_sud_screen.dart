import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/features/4th_treatment/week4_concentration_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Week4BeforeSudScreen extends StatefulWidget {
  final int loopCount;

  const Week4BeforeSudScreen({super.key, this.loopCount = 1});

  @override
  State<Week4BeforeSudScreen> createState() => _Week4BeforeSudScreenState();
}

class _Week4BeforeSudScreenState extends State<Week4BeforeSudScreen> {
  int _sud = 5;
  bool _isLoading = false;

  Future<List<String>> _fetchBListFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('로그인 정보 없음');
    final snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('abc_models')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();
    if (snapshot.docs.isEmpty) return [];
    final abcModel = snapshot.docs.first.data();
    final bRaw = (abcModel['belief'] ?? '') as String;
    return bRaw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final Color trackColor =
        _sud <= 2
            ? Colors.green
            : _sud >= 8
            ? Colors.red
            : Colors.amber;
    return Scaffold(
      appBar: const CustomAppBar(title: '4주차 - SUD 평가 (before)'),
      backgroundColor: const Color(0xFFFBF8FF),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: NavigationButtons(
          leftLabel: '이전',
          rightLabel: '다음',
          onBack: () => Navigator.pop(context),
          onNext: () async {
            setState(() => _isLoading = true);
            final beforeSudValue = _sud;
            try {
              final actualBList = await _fetchBListFromFirestore();
              if (actualBList.isEmpty) {
                setState(() => _isLoading = false);
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('B(생각) 데이터가 없습니다.')),
                );
                return;
              }
              setState(() => _isLoading = false);
              Navigator.push(
                // ignore: use_build_context_synchronously
                context,
                PageRouteBuilder(
                  pageBuilder:
                      (_, __, ___) => Week4ConcentrationScreen(
                        bListInput: actualBList,
                        beforeSud: beforeSudValue,
                        allBList: actualBList,
                      ),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              );
            } catch (e) {
              setState(() => _isLoading = false);
              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('B(생각) 불러오기 실패: \\${e.toString()}')),
              );
            }
          },
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(AppSizes.padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      '지금 느끼는 불안 정도를 슬라이드로 선택해 주세요.',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: Text(
                        '$_sud',
                        style: TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.bold,
                          color: trackColor,
                        ),
                      ),
                    ),
                    Center(
                      child: Icon(
                        _sud <= 2
                            ? Icons.sentiment_very_satisfied
                            : _sud >= 8
                            ? Icons.sentiment_very_dissatisfied_sharp
                            : Icons.sentiment_neutral,
                        size: 160,
                        color: trackColor,
                      ),
                    ),
                    const SizedBox(height: 32),
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
                          child: Text(
                            '0',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        const Positioned(
                          right: 0,
                          child: Text(
                            '10',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: const [
                        SizedBox(width: 12),
                        Text('평온', textAlign: TextAlign.center),
                        Spacer(),
                        Text('보통', textAlign: TextAlign.center),
                        Spacer(),
                        Text('불안', textAlign: TextAlign.center),
                        SizedBox(width: 12),
                      ],
                    ),
                  ],
                ),
              ),
    );
  }
}
