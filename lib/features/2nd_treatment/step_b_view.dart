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
  final int openAllItemsSignal;

  const StepBView({
    super.key,
    required this.chips,
    required this.selectedChipIds,
    this.onChipTap,
    this.onAddBelief,
    this.onDeleteBelief,
    this.isExampleMode = false,
    this.openAllItemsSignal = 0,
  });

  @override
  State<StepBView> createState() => _StepBViewState();
}

class _StepBViewState extends State<StepBView> {
  String _bannerMessage = "아래에서 '넘어질까봐 두려움'을 선택해보세요!";

  String get _guideMessage {
    if (widget.isExampleMode) return _bannerMessage;
    return "원하는 항목이 없다면 아래 + 버튼\n으로 추가할 수 있어요.";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: AbcStepCard(
            activeIndex: 1,
            bigText: '불안한 그 순간,\n어떤 생각이 들었나요?',
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: JellyfishBanner(message: _guideMessage),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: AbcChipsDesign(
              chips: widget.chips,
              selectedChipIds: widget.selectedChipIds,
              singleSelect: false,
              isExampleMode: widget.isExampleMode,
              openAllItemsSignal: widget.openAllItemsSignal,
              onChipToggle: (chipId, selected) {
                widget.onChipTap?.call(chipId, selected);

                if (widget.isExampleMode) {
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
                            ? "좋아요! 이제 아래의 '다음' 버튼을 눌러주세요."
                            : "아래에서 '넘어질까봐 두려움'을 선택해보세요!";
                  });
                }
              },
              onChipDelete: widget.isExampleMode ? null : widget.onDeleteBelief,
              onChipAdd: widget.isExampleMode ? null : widget.onAddBelief,
            ),
          ),
        ),
      ],
    );
  }
}
