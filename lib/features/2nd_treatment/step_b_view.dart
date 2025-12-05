import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/abc_chips_design.dart';
import 'package:gad_app_team/widgets/abc_step_card.dart';
import 'package:gad_app_team/widgets/blue_banner.dart';

class StepBView extends StatefulWidget {
  /// B칩들: label + chipId + type 포함
  final List<AbcChip> chips;

  /// 현재 선택된 chipId 집합
  final Set<String> selectedChipIds;

  /// 칩 선택/해제 콜백 (chipId, selected)
  final void Function(String chipId, bool selected)? onChipTap;

  /// "+추가" 눌렀을 때 (실제 팝업은 상위에서)
  final VoidCallback? onAddBelief;

  /// X 삭제 눌렀을 때 (chipId)
  final void Function(String chipId)? onDeleteBelief;

  /// 예시 모드 여부
  final bool isExampleMode;

  const StepBView({
    super.key,
    required this.chips,
    required this.selectedChipIds,
    this.onChipTap,
    this.onAddBelief,
    this.onDeleteBelief,
    this.isExampleMode = false,
  });

  @override
  State<StepBView> createState() => _StepBViewState();
}

class _StepBViewState extends State<StepBView> {
  String _bannerMessage = "아래에 '넘어질까봐 두려움' 칩을 눌러 \n선택해보세요!";

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AbcStepCard(
            activeIndex: 1,
            smallText: '그 상황에서 어떤 생각을\n했는지 적어봐요',
            bigText: '그때 어떤 생각이\n들었나요?',
          ),
          const SizedBox(height: 40),

          // ✅ 예시 모드 전용 배너
          if (widget.isExampleMode) ...[
            JellyfishBanner(message: _bannerMessage),
            const SizedBox(height: 30),
          ],

          // ✅ 칩 그리드 (chipId 기반, 다중 선택 가능)
          AbcChipsDesign(
            chips: widget.chips,
            selectedChipIds: widget.selectedChipIds,
            singleSelect: false, // B는 여러 개 선택 가능
            isExampleMode: widget.isExampleMode,
            onChipToggle: (chipId, selected) {
              widget.onChipTap?.call(chipId, selected);

              if (widget.isExampleMode) {
                // chipId로 해당 칩 찾아서 label 확인
                AbcChip? found;
                for (final c in widget.chips) {
                  if (c.chipId == chipId) {
                    found = c;
                    break;
                  }
                }
                final label = found?.label ?? '';

                setState(() {
                  _bannerMessage =
                  (selected && label == '넘어질까봐 두려움')
                      ? "선택한 뒤 아래의 '다음' 버튼을 눌러주세요!"
                      : "아래에 '넘어질까봐 두려움' 칩을 눌러 \n선택해보세요!";
                });
              }
            },
            // 삭제: chipId 그대로 위로 올려보냄
            onChipDelete:
            widget.isExampleMode ? null : widget.onDeleteBelief,
            // "+추가": 텍스트 입력 팝업은 상위(AbcInputScreen)에서
            onChipAdd: widget.isExampleMode ? null : widget.onAddBelief,
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}
