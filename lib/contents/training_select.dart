import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';

class TrainingSelect extends StatelessWidget {
  const TrainingSelect({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: '훈련 선택'),
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '어떤 활동을 진행하시겠어요?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            // ABC로 이동
            SizedBox(
              width: 200,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/abc',
                    arguments: {
                      'origin': 'training',
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
                  '일기 작성',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 이완으로 이동 (training 플로우 표시)
            SizedBox(
              width: 200,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/relax',
                    arguments: {'origin': 'training'},
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
                  '이완 활동',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
