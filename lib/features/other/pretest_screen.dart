import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';

/// 수면 건강 상태 사전 조사 화면
class PreTestScreen extends StatefulWidget {
  final int initialStep;
  const PreTestScreen({super.key, this.initialStep = 0});

  @override
  State<PreTestScreen> createState() => _PreTestScreenState();
}

class _PreTestScreenState extends State<PreTestScreen> {
  late int step;
  final TextEditingController otherController = TextEditingController();

  final List<String> worries = [
    '건강 (자신과 타인의)',
    '재정 문제',
    '노화 관련 문제',
    '가족/친구 관계',
    '일상적 사건들',
    '일/봉사활동',
  ];

  final sleepOptions = ['4시간 이하', '5~6시간', '7~8시간', '9시간 이상'];
  final qualityOptions = ['매우 나쁨', '나쁨', '보통', '좋음', '매우 좋음'];

  List<String> selectedWorries = [];
  bool otherSelected = false;
  String? selectedSleepHours;
  String? selectedSleepQuality;

  @override
  void initState() {
    super.initState();
    step = widget.initialStep;
  }

  void toggleWorryOption(String option) {
    setState(() {
      selectedWorries.contains(option)
          ? selectedWorries.remove(option)
          : selectedWorries.add(option);
    });
  }

  Widget _buildCheckboxList({
    required List<String> options,
    required String? selected,
    required void Function(String) onSelected,
  }) {
    return Column(
      children:
          options
          .map(
            (option) => CheckboxListTile(
              value: selected == option,
              onChanged: (_) => onSelected(option),
                  title: Text(
                    option,
                    style: const TextStyle(fontSize: AppSizes.fontSize),
                  ),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              visualDensity: const VisualDensity(vertical: -2),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.all(AppSizes.padding),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          borderSide: const BorderSide(color: AppColors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          borderSide: const BorderSide(color: AppColors.grey),
        ),
      ),
    );
  }

  Widget buildIntroPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
        const Icon(
          Icons.description_outlined,
          size: 100,
          color: AppColors.indigo,
        ),
        const SizedBox(height: AppSizes.space),
        const Text(
          '건강 상태 조사',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSizes.space),
        const Text(
          '건강 상태를 점검하기 위한 설문을 시작할게요.\n'
          '설문 내용을 분석해서 문제를 올바르게 이해하고\n'
          '맞춤 프로그램을 구성해드립니다.\n\n'
          '소요 시간: 약 10분',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: AppSizes.fontSize),
        ),
        const SizedBox(height: AppSizes.space),
        FilledButton(
          onPressed: () => setState(() => step = 1),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.indigo,
            minimumSize: const Size(140, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            ),
          ),
          child: const Text(
            '시작하기',
            style: TextStyle(fontSize: AppSizes.fontSize),
          ),
        ),
        ],
      ),
    );
  }

  Widget buildSurveyPage1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSizes.space),
        const Text(
          '생각',
          style: TextStyle(
            fontSize: AppSizes.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Text(
          '당신의 마음 속에 어떤 걱정이 있나요?',
          style: TextStyle(fontSize: AppSizes.fontSize),
        ),
        const SizedBox(height: AppSizes.space),
        ...worries.map(
          (option) => CheckboxListTile(
            value: selectedWorries.contains(option),
            onChanged: (_) => toggleWorryOption(option),
            title: Text(
              option,
              style: const TextStyle(fontSize: AppSizes.fontSize),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            visualDensity: const VisualDensity(vertical: -2),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
        CheckboxListTile(
          value: otherSelected,
          onChanged: (v) => setState(() => otherSelected = v ?? false),
          title: const Text(
            '기타',
            style: TextStyle(fontSize: AppSizes.fontSize),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          visualDensity: const VisualDensity(vertical: -2),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        if (otherSelected)
          Padding(
            padding: const EdgeInsets.all(AppSizes.padding),
            child: _buildTextField(controller: otherController, label: '기타 사항'),
          ),
        const Spacer(),
        NavigationButtons(
          onNext: () => setState(() => step = 2),
          onBack: () => setState(() => step = 0),
        ),
      ],
    );
  }

  Widget buildSurveyPage2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSizes.space),
        const Text(
          '수면 시간',
          style: TextStyle(
            fontSize: AppSizes.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Text(
          '하루 평균 수면 시간은 얼마나 되나요?',
          style: TextStyle(fontSize: AppSizes.fontSize),
        ),
        const SizedBox(height: AppSizes.space),
        _buildCheckboxList(
          options: sleepOptions,
          selected: selectedSleepHours,
          onSelected: (val) => setState(() => selectedSleepHours = val),
        ),
        const Spacer(),
        NavigationButtons(
          onNext: () => setState(() => step = 3),
          onBack: () => setState(() => step = 1),
        ),
      ],
    );
  }

  Widget buildSurveyPage3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSizes.space),
        const Text(
          '수면의 질',
          style: TextStyle(
            fontSize: AppSizes.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Text(
          '최근 일주일 간 수면의 질은 어떤가요?',
          style: TextStyle(fontSize: AppSizes.fontSize),
        ),
        const SizedBox(height: AppSizes.space),
        _buildCheckboxList(
          options: qualityOptions,
          selected: selectedSleepQuality,
          onSelected: (val) => setState(() => selectedSleepQuality = val),
        ),
        const Spacer(),
        NavigationButtons(
          onNext: () => setState(() => step = 4),
          onBack: () => setState(() => step = 2),
        ),
      ],
    );
  }

  Widget buildResultPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '불안증상 검사결과',
          style: TextStyle(
            fontSize: AppSizes.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSizes.space),
        Container(
          padding: const EdgeInsets.all(AppSizes.padding),
          decoration: BoxDecoration(
            color: AppColors.indigo50,
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            border: Border.all(color: Colors.indigo, width: 2),
          ),
          child: const Text(
            '중간수준 (점수 10~14점)\n\n'
            '불안이 일상과 수면에 영향을 줄 가능성을 보고하셨습니다.\n'
            '추가적인 평가가 필요하며 전문가의 도움을 받아보시길 권해 드립니다.',
            style: TextStyle(fontSize: AppSizes.fontSize),
          ),
        ),
        const Spacer(),
        NavigationButtons(
          onNext: () {
            Navigator.pushNamed(context, '/home');
          },
          onBack: () => setState(() => step = 3),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      buildIntroPage(),
      buildSurveyPage1(),
      buildSurveyPage2(),
      buildSurveyPage3(),
      buildResultPage(),
    ];

    return Scaffold(
      backgroundColor: AppColors.grey100,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.padding),
          child: pages[step],
        ),
      ),
    );
  }
}
