import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/blue_white_card.dart';
import 'package:gad_app_team/widgets/primary_action_button.dart';

class BeforeSurveyResultScreen extends StatelessWidget {
  final int phq9Score;
  final int gad7Score;

  const BeforeSurveyResultScreen({
    super.key,
    required this.phq9Score,
    required this.gad7Score,
  });

  @override
  Widget build(BuildContext context) {
    final phq9Band = _phq9Band(phq9Score);
    final gad7Band = _gad7Band(gad7Score);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.3,
            child: Image.asset(
              'assets/image/eduhome.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: BlueWhiteCard(
                        maxWidth: 420,
                        title: '사전설문 결과',
                        titleStyle: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF224C78),
                        ),
                        outerColor: Colors.white,
                        innerColor: Colors.white,
                        outerExpand: const EdgeInsets.fromLTRB(8, 10, 8, 14),
                        innerPadding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                        dividerColor: const Color(0xFFE4EEF7),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SurveyScoreCard(
                              title: '불안 정도',
                              scaleLabel: 'GAD-7',
                              score: gad7Score,
                              maxScore: 21,
                              icon: Icons.bolt_rounded,
                              accentColor: const Color(0xFF5DADEC),
                              band: gad7Band,
                            ),
                            const SizedBox(height: 14),
                            _SurveyScoreCard(
                              title: '우울 정도',
                              scaleLabel: 'PHQ-9',
                              score: phq9Score,
                              maxScore: 27,
                              icon: Icons.cloud_outlined,
                              accentColor: const Color(0xFFF1A7A0),
                              band: phq9Band,
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAFBFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE6EBF1),
                                ),
                              ),
                              child: const Text(
                                '이 결과는 현재 상태를 이해하기 위한 참고 정보이며, 전문적인 진단을 대신하지 않습니다. 힘듦이 오래가거나 일상 유지가 어려울 만큼 부담이 크다면 전문가와 상의해 보세요.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF647384),
                                  height: 1.55,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: PrimaryActionButton(
                    onPressed:
                        () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/permission_onboarding',
                          (_) => false,
                        ),
                    text: '홈으로 가기',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static _SurveyBand _phq9Band(int score) {
    if (score >= 20) {
      return const _SurveyBand(
        rank: 4,
        label: '매우 높음',
        color: Color(0xFFE57C75),
        description: '우울감으로 인한 부담이 큰 편일 수 있어요.',
      );
    }
    if (score >= 15) {
      return const _SurveyBand(
        rank: 3,
        label: '높음',
        color: Color(0xFFF3A65B),
        description: '우울감이 일상에 꽤 영향을 줄 수 있어요.',
      );
    }
    if (score >= 10) {
      return const _SurveyBand(
        rank: 2,
        label: '중간',
        color: Color(0xFFF0BE4F),
        description: '조금 더 주의 깊게 살펴보면 좋아요.',
      );
    }
    if (score >= 5) {
      return const _SurveyBand(
        rank: 1,
        label: '낮은 편',
        color: Color(0xFF74B39A),
        description: '가벼운 우울감이 느껴질 수 있어요.',
      );
    }
    return const _SurveyBand(
      rank: 0,
      label: '매우 낮음',
      color: Color(0xFF6CB8D9),
      description: '현재는 비교적 안정적인 편으로 보여요.',
    );
  }

  static _SurveyBand _gad7Band(int score) {
    if (score >= 15) {
      return const _SurveyBand(
        rank: 3,
        label: '높음',
        color: Color(0xFFE57C75),
        description: '불안으로 인한 긴장과 부담이 큰 편일 수 있어요.',
      );
    }
    if (score >= 10) {
      return const _SurveyBand(
        rank: 2,
        label: '중간',
        color: Color(0xFFF3A65B),
        description: '불안이 일상에 영향을 주고 있을 수 있어요.',
      );
    }
    if (score >= 5) {
      return const _SurveyBand(
        rank: 1,
        label: '낮은 편',
        color: Color(0xFFF0BE4F),
        description: '걱정과 긴장이 조금 이어질 수 있어요.',
      );
    }
    return const _SurveyBand(
      rank: 0,
      label: '매우 낮음',
      color: Color(0xFF6CB8D9),
      description: '현재 불안 수준은 비교적 낮은 편이에요.',
    );
  }
}

class _SurveyScoreCard extends StatelessWidget {
  final String title;
  final String scaleLabel;
  final int score;
  final int maxScore;
  final IconData icon;
  final Color accentColor;
  final _SurveyBand band;

  const _SurveyScoreCard({
    required this.title,
    required this.scaleLabel,
    required this.score,
    required this.maxScore,
    required this.icon,
    required this.accentColor,
    required this.band,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (score / maxScore).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EDF5)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
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
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF203A5B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      scaleLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7A8897),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: band.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  band.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: band.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 5),
                child: Text(
                  '/ $maxScore',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7A8897),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: const Color(0xFFF0F4F8),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            band.description,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF5D6D7E),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurveyBand {
  final int rank;
  final String label;
  final Color color;
  final String description;

  const _SurveyBand({
    required this.rank,
    required this.label,
    required this.color,
    required this.description,
  });
}
