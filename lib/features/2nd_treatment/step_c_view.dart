import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/abc_chips_design.dart';
import 'package:gad_app_team/widgets/abc_step_card.dart';
import 'package:gad_app_team/widgets/blue_banner.dart';

/// 🧩 C단계: 결과(신체·감정·행동) 3단계 뷰
class StepCView extends StatefulWidget {
  final int subStep; // 0=신체, 1=감정, 2=행동
  final List<String> physicalList;
  final List<String> emotionList;
  final List<String> behaviorList;
  final Set<int> selectedPhysical;
  final Set<int> selectedEmotion;
  final Set<int> selectedBehavior;
  final bool isExampleMode;

  final void Function(String text)? onAddPhysical;
  final void Function(String text)? onAddEmotion;
  final void Function(String text)? onAddBehavior;

  final void Function(int index)? onDeletePhysical;
  final void Function(int index)? onDeleteEmotion;
  final void Function(int index)? onDeleteBehavior;

  /// ✅ 부모(AbcInputScreen)에 선택 변경 알림 콜백
  final VoidCallback? onSelectionChanged;

  const StepCView({
    super.key,
    required this.subStep,
    required this.physicalList,
    required this.emotionList,
    required this.behaviorList,
    required this.selectedPhysical,
    required this.selectedEmotion,
    required this.selectedBehavior,
    this.isExampleMode = false,
    this.onAddPhysical,
    this.onAddEmotion,
    this.onAddBehavior,
    this.onDeletePhysical,
    this.onDeleteEmotion,
    this.onDeleteBehavior,
    this.onSelectionChanged,
  });

  @override
  State<StepCView> createState() => _StepCViewState();
}

class _StepCViewState extends State<StepCView> {
  @override
  Widget build(BuildContext context) {
    switch (widget.subStep) {
      case 0:
        return _buildPhysicalStep();
      case 1:
        return _buildEmotionStep();
      case 2:
      default:
        return _buildBehaviorStep();
    }
  }

  /// 🧠 0단계: 신체 반응 선택 화면
  Widget _buildPhysicalStep() {
    return _buildCommonSection(
      title: '불안할 때 몸에\n어떤 증상이 있었나요?',
      smallText: '결과를 관찰해요',
      chips: widget.physicalList,
      selectedIndexes: widget.selectedPhysical,
      exampleMessage: "예시로 '두근거림' 칩을 눌러 선택해보세요!",
      onAdd: widget.isExampleMode ? null : widget.onAddPhysical,
      onDelete: widget.isExampleMode ? null : widget.onDeletePhysical,
    );
  }

  /// 💬 1단계: 감정 반응 선택 화면
  Widget _buildEmotionStep() {
    return _buildCommonSection(
      title: '불안할 때\n어떤 감정을 느꼈나요?',
      smallText: '결과를 관찰해요',
      chips: widget.emotionList,
      selectedIndexes: widget.selectedEmotion,
      exampleMessage: "예시로 '불안' 칩을 눌러 선택해보세요!",
      onAdd: widget.isExampleMode ? null : widget.onAddEmotion,
      onDelete: widget.isExampleMode ? null : widget.onDeleteEmotion,
    );
  }

  /// 🏃‍♀️ 2단계: 행동 반응 선택 화면
  Widget _buildBehaviorStep() {
    return _buildCommonSection(
      title: '그때 어떤 행동을 했나요?',
      smallText: '결과를 관찰해요',
      chips: widget.behaviorList,
      selectedIndexes: widget.selectedBehavior,
      exampleMessage: "예시로 '자전거를 타지 않았어요' 칩을 눌러보세요!",
      onAdd: widget.isExampleMode ? null : widget.onAddBehavior,
      onDelete: widget.isExampleMode ? null : widget.onDeleteBehavior,
    );
  }

  /// 🎯 공통 구성 (신체/감정/행동 공용 뷰)
  Widget _buildCommonSection({
    required String title,
    required String smallText,
    required List<String> chips,
    required Set<int> selectedIndexes,
    required String exampleMessage,
    required void Function(String text)? onAdd,
    required void Function(int index)? onDelete,
  }) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AbcStepCard(
            activeIndex: 2,
            smallText: smallText,
            bigText: title,
            selectedChips: selectedIndexes.map((i) => chips[i]).toList(),
          ),
          const SizedBox(height: 30),
          if (widget.isExampleMode) JellyfishBanner(message: exampleMessage),
          const SizedBox(height: 20),
          AbcChipsDesign(
            chips: chips,
            defaultCount: widget.isExampleMode ? 3 : 4,
            selectedIndexes: selectedIndexes,
            singleSelect: false,
            onChipToggle: (i, selected) {
              setState(() {
                if (selected) {
                  selectedIndexes.add(i);
                } else {
                  selectedIndexes.remove(i);
                }
              });
              widget.onSelectionChanged?.call(); // ✅ 부모에게 상태 변경 알림
            },
            onChipAdd: onAdd,
            onChipDelete: onDelete,
            isExampleMode: widget.isExampleMode,
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}
