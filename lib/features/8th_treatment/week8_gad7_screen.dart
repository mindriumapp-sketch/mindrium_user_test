// File: features/8th_treatment/week8_gad7_screen.dart
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/tutorial_design.dart';
import 'package:gad_app_team/features/8th_treatment/week8_survey_screen.dart';
import 'package:gad_app_team/widgets/blue_banner.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/survey_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

class Week8Gad7Screen extends StatefulWidget {
  const Week8Gad7Screen({super.key});

  @override
  State<Week8Gad7Screen> createState() => _Week8Gad7ScreenState();
}

class _Week8Gad7ScreenState extends State<Week8Gad7Screen> {
  final List<int> _answers = List.filled(7, -1);
  bool _isCompleted = false;
  bool _isSubmitting = false;
  late final List<GlobalKey> _questionKeys;

  // API 클라이언트
  late final ApiClient _apiClient;
  late final SurveyApi _surveyApi;

  final List<String> _questions = [
    '최근 2주간, 초조하거나 불안하거나 조마조마하게 느낀다.',
    '최근 2주간, 걱정하는 것을 멈추거나 조절할 수가 없다.',
    '최근 2주간, 여러 가지 것들에 대해 걱정을 너무 많이 한다.',
    '최근 2주간, 편하게 있기가 어렵다.',
    '최근 2주간, 쉽게 짜증이 나거나 쉽게 성을 내게 된다.',
    '최근 2주간, 너무 안절부절못해서 가만히 있기가 힘들다.',
    '최근 2주간, 마치 끔찍한 일이 생길 것처럼 두렵게 느껴진다.',
  ];

  final List<String> _options = ['없음', '2~3일 이상', '7일 이상', '거의 매일'];

  void _selectAnswer(int q, int a) {
    setState(() {
      _answers[q] = a;
      _isCompleted = _answers.every((v) => v >= 0);
    });

    if (q < _questions.length - 1) {
      final nextContext = _questionKeys[q + 1].currentContext;
      if (nextContext != null) {
        Scrollable.ensureVisible(
          nextContext,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: 0.08,
        );
      }
    }
  }

  int _score() => _answers.reduce((a, b) => a + b);

  @override
  void initState() {
    super.initState();
    _questionKeys = List.generate(_questions.length, (_) => GlobalKey());
    _apiClient = ApiClient(tokens: TokenStorage());
    _surveyApi = SurveyApi(_apiClient);
  }

  Future<void> _submitAndNavigate() async {
    if (_isSubmitting || !_isCompleted) return;
    setState(() => _isSubmitting = true);

    try {
      final score = _score();
      await _surveyApi.submitSurvey(
        type: 'after_survey',
        answers: {'gad7_answers': _answers, 'gad7_score': score},
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Week8SurveyScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      BlueBanner.show(context, '설문 제출에 실패했습니다: $e');
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ApplyDesign(
      appBarTitle: '불안 평가',
      cardTitle: '마인드리움 사용 후\n불안이 얼마나 줄었나요?',
      onBack: () => Navigator.pop(context),
      onNext:
          _isCompleted
              ? _submitAndNavigate
              : () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('모든 문항에 답해주세요.'))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JellyfishBanner(message: '지난 2주 동안의 불안 증상을 \n아래 항목에 따라 평가해주세요.'),
          const SizedBox(height: 30),
          ...List.generate(_questions.length, _buildQuestionCard),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  /// 🌊 질문 카드
  Widget _buildQuestionCard(int i) {
    final question = _questions[i];
    return Container(
      key: _questionKeys[i],
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB9EAFD)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF74D2FF).withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 질문 헤더
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF74D2FF), Color(0xFF99E0FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontFamily: 'NotoSansKR',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(
                    fontFamily: 'NotoSansKR',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B3A57),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 선택지
          ...List.generate(_options.length, (j) => _buildOption(i, j)),
        ],
      ),
    );
  }

  /// 🔘 선택지 버튼
  Widget _buildOption(int q, int opt) {
    final selected = _answers[q] == opt;
    return GestureDetector(
      onTap: () => _selectAnswer(q, opt),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE6F3FA) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF74D2FF) : const Color(0xFFE2E8F0),
            width: selected ? 1.8 : 1,
          ),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: const Color(0xFF74D2FF).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                  : [],
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? const Color(0xFF74D2FF) : Colors.transparent,
                border: Border.all(
                  color:
                      selected
                          ? const Color(0xFF74D2FF)
                          : const Color(0xFFCBD5E0),
                  width: 2,
                ),
              ),
              child:
                  selected
                      ? const Icon(Icons.check, color: Colors.white, size: 12)
                      : null,
            ),
            const SizedBox(width: 14),
            Text(
              _options[opt],
              style: TextStyle(
                fontFamily: 'NotoSansKR',
                fontSize: 15,
                color:
                    selected
                        ? const Color(0xFF1B3A57)
                        : const Color(0xFF4A5568),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
