import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/surface_variation.dart';

CounselingMessage _assistant(String text) => CounselingMessage(
  id: text,
  role: 'assistant',
  text: text,
  createdAt: DateTime(2026, 9, 5),
);

void main() {
  test('최근에 쓴 문형을 건너뛴다', () {
    const selector = DeterministicSurfaceVariation();
    final selected = selector.select(
      candidates: const ['첫 문형', '둘째 문형', '셋째 문형'],
      recentMessages: [_assistant('직전에 첫 문형을 사용했다')],
    );

    expect(selected, '둘째 문형');
  });

  test('모든 문형 소진 뒤에도 같은 이력과 seed에는 결정적이다', () {
    const selector = DeterministicSurfaceVariation();
    final history = [_assistant('첫 문형 둘째 문형 셋째 문형')];

    final first = selector.select(
      candidates: const ['첫 문형', '둘째 문형', '셋째 문형'],
      recentMessages: history,
      seed: '발표가 걱정돼요',
    );
    final second = selector.select(
      candidates: const ['첫 문형', '둘째 문형', '셋째 문형'],
      recentMessages: history,
      seed: '발표가 걱정돼요',
    );

    expect(first, second);
  });

}
