import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/abc_chips_design.dart';
import 'package:gad_app_team/widgets/abc_step_card.dart';
import 'package:gad_app_team/widgets/blue_banner.dart';

/// 🧩 C단계: 결과(신체·감정·행동) 3단계 뷰 (chipId 기반)
class StepCView extends StatefulWidget {
  final int subStep; // 0=신체, 1=감정, 2=행동

  /// C1: 신체 칩들
  final List<AbcChip> physicalChips;

  /// C2: 감정 칩들
  final List<AbcChip> emotionChips;

  /// C3: 행동 칩들
  final List<AbcChip> behaviorChips;

  /// 현재 선택된 chipId 집합
  final Set<String> selectedPhysicalChipIds;
  final Set<String> selectedEmotionChipIds;
  final Set<String> selectedBehaviorChipIds;

  final bool isExampleMode;

  /// "+추가" 눌렀을 때 (팝업은 상위 AbcInputScreen에서 처리)
  final VoidCallback? onAddPhysical;
  final VoidCallback? onAddEmotion;
  final VoidCallback? onAddBehavior;

  /// X 삭제 눌렀을 때 (chipId)
  final void Function(String chipId)? onDeletePhysical;
  final void Function(String chipId)? onDeleteEmotion;
  final void Function(String chipId)? onDeleteBehavior;

  /// ✅ 부모(AbcInputScreen)에 "선택 상태 바뀜"만 알려주는 콜백
  final VoidCallback? onSelectionChanged;

  const StepCView({
    super.key,
    required this.subStep,
    required this.physicalChips,
    required this.emotionChips,
    required this.behaviorChips,
    required this.selectedPhysicalChipIds,
    required this.selectedEmotionChipIds,
    required this.selectedBehaviorChipIds,
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
      chips: widget.physicalChips,
      selectedChipIds: widget.selectedPhysicalChipIds,
      guideMessage:
          widget.isExampleMode
              ? "아래에서 '두근거림'을 선택해보세요!"
              : "질문에 따라 그때의 결과를 하나씩 살펴봐요.",
      onAdd: widget.isExampleMode ? null : widget.onAddPhysical,
      onDelete: widget.isExampleMode ? null : widget.onDeletePhysical,
    );
  }

  /// 💬 1단계: 감정 반응 선택 화면
  Widget _buildEmotionStep() {
    return _buildCommonSection(
      title: '불안한 그 순간, \n어떤 감정을 느꼈나요?',
      chips: widget.emotionChips,
      selectedChipIds: widget.selectedEmotionChipIds,
      guideMessage:
          widget.isExampleMode
              ? "아래에서 '불안'을 선택해보세요!"
              : "질문에 따라 그때의 결과를 하나씩 살펴봐요.",
      onAdd: widget.isExampleMode ? null : widget.onAddEmotion,
      onDelete: widget.isExampleMode ? null : widget.onDeleteEmotion,
    );
  }

  /// 🏃‍♀️ 2단계: 행동 반응 선택 화면
  Widget _buildBehaviorStep() {
    return _buildCommonSection(
      title: '불안할 때 실제로 어떤 행동을 했나요?',
      chips: widget.behaviorChips,
      selectedChipIds: widget.selectedBehaviorChipIds,
      guideMessage:
          widget.isExampleMode
              ? "아래에서 '자전거를 타지 않았어요'를 선택해보세요!"
              : "질문에 따라 그때의 결과를 하나씩 살펴봐요.",
      onAdd: widget.isExampleMode ? null : widget.onAddBehavior,
      onDelete: widget.isExampleMode ? null : widget.onDeleteBehavior,
    );
  }

  /// 🎯 공통 구성 (신체/감정/행동 공용 뷰) — chipId 기반
  Widget _buildCommonSection({
    required String title,
    required List<AbcChip> chips,
    required Set<String> selectedChipIds,
    required String guideMessage,
    required VoidCallback? onAdd,
    required void Function(String chipId)? onDelete,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: AbcStepCard(activeIndex: 2, bigText: title),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: JellyfishBanner(message: guideMessage),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: AbcChipsDesign(
              chips: chips,
              selectedChipIds: selectedChipIds,
              singleSelect: false,
              isExampleMode: widget.isExampleMode,
              onChipToggle: (chipId, selected) {
                setState(() {
                  if (selected) {
                    selectedChipIds.add(chipId);
                  } else {
                    selectedChipIds.remove(chipId);
                  }
                });
                widget.onSelectionChanged?.call();
              },
              onChipAdd: onAdd,
              onChipDelete: onDelete,
            ),
          ),
        ),
      ],
    );
  }
}
