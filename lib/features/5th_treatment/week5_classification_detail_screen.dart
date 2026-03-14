import 'package:gad_app_team/utils/text_line_material.dart';

class Week5ClassificationDetailScreen extends StatelessWidget {
  final List<Map<String, dynamic>> quizResults;
  const Week5ClassificationDetailScreen({super.key, required this.quizResults});

  /// 내부 키('healthy'/'anxious')를 한국어 라벨로 변환
  String _labelKR(String t) => t == 'healthy' ? '불안을 직면하는 행동' : '불안을 회피하는 행동';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        title: const Text('정답 상세 보기'),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF224C78),
        elevation: 0,
      ),

      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEAF7FF), Color(0xFFF8FCFF)],
              ),
            ),
          ),

          Opacity(
            opacity: 0.20,
            child: Image.asset('assets/image/eduhome.png', fit: BoxFit.cover),
          ),

          Container(color: Colors.white.withValues(alpha: 0.12)),

          SafeArea(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              itemCount: quizResults.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final correctCount =
                      quizResults.where((e) => e['isCorrect'] == true).length;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.74),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.70),
                        width: 1.2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF19C37D,
                                ).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: Color(0xFF19C37D),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                '이번 연습 돌아보기',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF243B53),
                                  fontFamily: 'Noto Sans KR',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '맞은 문항과 틀린 문항을 다시 보며 내 행동의 패턴을 천천히 점검해보세요.',
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.5,
                            color: Color(0xFF5B7083),
                            fontFamily: 'Noto Sans KR',
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F7FB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '총 ${quizResults.length}문항 중 ${correctCount}개 정답',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4F6475),
                              fontFamily: 'Noto Sans KR',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final item = quizResults[index - 1];
                final isCorrect = item['isCorrect'] as bool;
                final text = item['text'] as String;
                final userChoice = _labelKR(item['userChoice'] as String);
                final correctType = _labelKR(item['correctType'] as String);
                final wrongReasonRaw =
                    item['wrongReason'] ?? item['wrong_reason'];
                final wrongReason =
                    wrongReasonRaw is String
                        ? wrongReasonRaw.trim()
                        : (wrongReasonRaw?.toString() ?? '').trim();

                final barColor =
                    isCorrect
                        ? const Color(0xFF19C37D)
                        : const Color(0xFFFF6B6B);
                final barIcon =
                    isCorrect ? Icons.check_rounded : Icons.close_rounded;
                final barLabel = isCorrect ? '정답' : '오답';

                return Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.78),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(color: barColor),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  barIcon,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                barLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Noto Sans KR',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F7FB),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${index}번 문항',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4B6584),
                                    fontFamily: 'Noto Sans KR',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                text,
                                style: const TextStyle(
                                  color: Color(0xFF232F3E),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  height: 1.5,
                                  fontFamily: 'Noto Sans KR',
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (!isCorrect) ...[
                                _AnswerRow(
                                  label: '내 답',
                                  value: userChoice,
                                  color: const Color(0xFFFF6B6B),
                                  icon: Icons.close_rounded,
                                ),
                                const SizedBox(height: 10),
                              ],
                              _AnswerRow(
                                label: '정답',
                                value: correctType,
                                color: const Color(0xFF19C37D),
                                icon: Icons.check_rounded,
                              ),
                              if (!isCorrect) ...[
                                const SizedBox(height: 12),
                                _ReasonCard(
                                  reason:
                                      wrongReason.isNotEmpty
                                          ? wrongReason
                                          : '이 문장이 왜 이 유형에 해당하는지 생각해보세요.',
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// '내 답: …' / '정답: …' 한 줄 표시 위젯
class _AnswerRow extends StatelessWidget {
  const _AnswerRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  height: 1.45,
                  fontFamily: 'Noto Sans KR',
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonCard extends StatelessWidget {
  const _ReasonCard({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3D89A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE9B8),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              size: 15,
              color: Color(0xFFB7791F),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Color(0xFF7A5A1D),
                  fontSize: 14.5,
                  height: 1.5,
                  fontFamily: 'Noto Sans KR',
                ),
                children: [
                  const TextSpan(
                    text: '왜 오답일까요? ',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text: reason,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}