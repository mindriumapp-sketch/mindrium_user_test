import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:dio/dio.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/survey_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/widgets/tutorial_design.dart';
import 'package:gad_app_team/widgets/blue_banner.dart';

class _SText {
  static const intro = TextStyle(
    fontSize: AppSizes.fontSize,
    fontWeight: FontWeight.w400,
    color: Color.fromARGB(255, 72, 71, 71),
    height: 1.45,
  );
}

/// --------- 데이터 ---------
const List<String> kFrequencyOptions = ["없음", "2, 3일 이상", "7일 이상", "거의 매일"];

/// --------- PHQ-9 ---------
class BeforeSurveyScreen extends StatefulWidget {
  const BeforeSurveyScreen({super.key});
  @override
  State<BeforeSurveyScreen> createState() => _BeforeSurveyScreenState();
}

class _BeforeSurveyScreenState extends State<BeforeSurveyScreen> {
  final List<int?> _answers = List<int?>.filled(9, null);

  final List<String> _questions = [
    "1. 최근 2주간, 일 또는 활동을 하는 데 흥미나 즐거움을 느끼지 못한다.",
    "2. 최근 2주간, 기분이 가라앉거나, 우울하거나, 희망이 없다고 느낀다.",
    "3. 최근 2주간, 잠이 들거나 계속 잠을 자는 것이 어렵다. 또는 잠을 너무 많이 잔다.",
    "4. 최근 2주간, 피곤하다고 느끼거나, 기운이 거의 없다.",
    "5. 최근 2주간, 입맛이 없거나, 과식을 한다.",
    "6. 최근 2주간, 자신을 부정적으로 본다. 혹은 자신이 실패자라고 느끼거나, 자신 또는 가족을 실망시킨다.",
    "7. 최근 2주간, 신문을 읽거나 텔레비전을 보는 것과 같은 일상적인 일에 집중하는 것이 어렵다.",
    "8. 최근 2주간, 다른 사람들이 주목할 정도로 너무 느리게 움직이거나 말한다. 또는 반대로 평소보다 많이 움직여서 너무 안절부절못하거나 들떠 있다.",
    "9. 최근 2주간, 자신이 죽는 것이 더 낫다고 생각하거나, 어떤 식으로든 자신을 해칠 것이라고 생각한다.",
  ];

  void _next() {
    if (_answers.contains(null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("모든 문항에 답해주세요.")));
      return;
    }

    final phq9 = _answers.map((e) => e!).toList();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Gad7SurveyScreen(phq9: phq9)),
    );
  }

  /// 🌊 질문 카드 (8주차 스타일)
  Widget _buildQuestionCard(int qIndex) {
    final question = _questions[qIndex];
    // 질문 텍스트에서 번호 제거 (이미 번호가 포함되어 있음)
    final questionText = question;
    return Container(
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
                    '${qIndex + 1}',
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
                  questionText,
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
          ...List.generate(
            kFrequencyOptions.length,
            (opt) => _buildOption(qIndex, opt),
          ),
        ],
      ),
    );
  }

  /// 🔘 선택지 버튼 (8주차 스타일)
  Widget _buildOption(int q, int opt) {
    final selected = _answers[q] == opt;
    return GestureDetector(
      onTap: () => setState(() => _answers[q] = opt),
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
          boxShadow: selected
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
                  color: selected
                      ? const Color(0xFF74D2FF)
                      : const Color(0xFFCBD5E0),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : null,
            ),
            const SizedBox(width: 14),
            Text(
              kFrequencyOptions[opt],
              style: TextStyle(
                fontFamily: 'NotoSansKR',
                fontSize: 15,
                color: selected
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

  @override
  Widget build(BuildContext context) {
    return ApplyDesign(
      appBarTitle: '사전설문',
      cardTitle: 'Mindrium 시작 전\n현재 상태를 확인해요',
      onBack: () => Navigator.pop(context),
      onNext: _next,
      rightLabel: '다음',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const JellyfishBanner(message: '지난 2주 동안의 우울 증상을\n아래 항목에 따라 평가해주세요.'),
          const SizedBox(height: 18),
          const Text(
            "PHQ-9 (우울 관련 질문)\n"
            "최근 2주간, 얼마나 자주 다음과 같은 문제들로 곤란을 겪으셨습니까?",
            style: _SText.intro,
          ),
          const SizedBox(height: 16),
          ...List.generate(_questions.length, _buildQuestionCard),
        ],
      ),
    );
  }
}

/// --------- GAD-7 ---------
class Gad7SurveyScreen extends StatefulWidget {
  final List<int> phq9;
  const Gad7SurveyScreen({super.key, required this.phq9});

  @override
  State<Gad7SurveyScreen> createState() => _Gad7SurveyScreenState();
}

class _Gad7SurveyScreenState extends State<Gad7SurveyScreen> {
  final List<int?> _gadAnswers = List<int?>.filled(7, null);
  bool _saving = false;
  late final SurveyApi _surveyApi;

  final List<String> _gadQuestions = const [
    "1. 지난 2주 동안, 너무 긴장하거나 불안하거나 초조한 느낌이 들었습니까?",
    "2. 지난 2주 동안, 통제할 수 없을 정도로 걱정이 많았습니까?",
    "3. 지난 2주 동안, 여러 가지 일에 대해 걱정하는 것을 멈추기 어려웠습니까?",
    "4. 지난 2주 동안, 불안하거나 초조해서 가만히 있지 못하고 안절부절 못했습니까?",
    "5. 지난 2주 동안, 쉽게 피곤하거나 지쳤습니까?",
    "6. 지난 2주 동안, 집중하기 어렵거나 마음이 멍해진 느낌이 들었습니까?",
    "7. 지난 2주 동안, 신체적으로 긴장하거나 근육이 뻣뻣하거나 떨렸습니까?",
  ];

  @override
  void initState() {
    super.initState();
    final tokens = TokenStorage();
    final client = ApiClient(tokens: tokens);
    _surveyApi = SurveyApi(client);
  }

  Future<void> _submit() async {
    if (_gadAnswers.contains(null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("모든 문항에 답해주세요.")));
      return;
    }
    if (_saving) return;

    final gad7 = _gadAnswers.map((e) => e!).toList();
    final phq9Score = widget.phq9.fold<int>(0, (sum, value) => sum + value);
    final gad7Score = gad7.fold<int>(0, (sum, value) => sum + value);
    setState(() => _saving = true);

    try {
      // TODO: description에 뭐 넣을거 없쥬? 예전에 있어서 넣엇던 필드인디
      await _surveyApi.submitSurvey(
        type: 'before_survey',
        answers: {
          'phq9_answers': widget.phq9,
          'gad7_answers': gad7,
          'phq9_score': phq9Score,
          'gad7_score': gad7Score,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('설문이 제출되었습니다. 감사합니다.')));
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } on DioException catch (e) {
      final data = e.response?.data;
      var message = '제출할 수 없습니다.';
      if (data is Map && data['detail'] != null) {
        message = data['detail'].toString();
      } else if (e.message != null) {
        message = e.message!;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('제출 중 오류가 발생했습니다: $message')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('제출 중 오류가 발생했습니다: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 🌊 질문 카드 (8주차 스타일)
  Widget _buildGadQuestionCard(int qIndex) {
    final question = _gadQuestions[qIndex];
    // 질문 텍스트에서 번호 제거 (이미 번호가 포함되어 있음)
    final questionText = question;
    return Container(
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
                    '${qIndex + 1}',
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
                  questionText,
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
          ...List.generate(
            kFrequencyOptions.length,
            (opt) => _buildGadOption(qIndex, opt),
          ),
        ],
      ),
    );
  }

  /// 🔘 선택지 버튼 (8주차 스타일)
  Widget _buildGadOption(int q, int opt) {
    final selected = _gadAnswers[q] == opt;
    return GestureDetector(
      onTap: () => setState(() => _gadAnswers[q] = opt),
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
          boxShadow: selected
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
                  color: selected
                      ? const Color(0xFF74D2FF)
                      : const Color(0xFFCBD5E0),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : null,
            ),
            const SizedBox(width: 14),
            Text(
              kFrequencyOptions[opt],
              style: TextStyle(
                fontFamily: 'NotoSansKR',
                fontSize: 15,
                color: selected
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

  @override
  Widget build(BuildContext context) {
    return ApplyDesign(
      appBarTitle: '사전설문',
      cardTitle: 'Mindrium 시작 전\n현재 상태를 확인해요',
      onBack: () => Navigator.pop(context),
      onNext: _submit,
      rightLabel: '완료',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const JellyfishBanner(message: '지난 2주 동안의 불안 증상을\n아래 항목에 따라 평가해주세요.'),
          const SizedBox(height: 18),
          const Text(
            "GAD-7 (불안 관련 질문)\n"
            "최근 2주간, 얼마나 자주 다음과 같은 문제들로 곤란을 겪으셨습니까?",
            style: _SText.intro,
          ),
          const SizedBox(height: 16),
          ...List.generate(_gadQuestions.length, _buildGadQuestionCard),
        ],
      ),
    );
  }
}
