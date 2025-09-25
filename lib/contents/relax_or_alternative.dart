import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';

class RelaxOrAlternativePage extends StatelessWidget {
  const RelaxOrAlternativePage({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
    final String? abcId   = args['abcId'] as String?;
    final int? sud   = args['sud'] as int?;
    final dynamic diary = args['diary'];

    return Scaffold(
      appBar: const CustomAppBar(title: '다음 단계 선택'),
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '어떤 활동을 진행하시겠어요?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            // ─── 이완 활동 버튼 ───────────────────────────────────────
            SizedBox(
              width: 220,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: 이완 페이지
                  Navigator.pushNamed(
                    context,
                    '/breath_muscle_relaxation',
                    arguments: {
                      'abcId': abcId,
                      if (diary!=null) 'diary': diary
                    }
                  );
                },
                style: ElevatedButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 22),
                  backgroundColor: Colors.indigo,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('이완 활동', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 24),
            // ─── 대체 생각 작성 버튼 ─────────────────────────────────
            SizedBox(
              width: 220,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/apply_alt_thought',
                    arguments: {
                      'abcId': abcId,
                      'sud': sud,
                      if(diary != null) 'diary': diary
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 22),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('대체 생각 작성',
                    style: TextStyle(color: Colors.black)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
