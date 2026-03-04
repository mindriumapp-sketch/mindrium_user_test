import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/abc_chips_design.dart';
import 'package:gad_app_team/widgets/abc_step_card.dart';
import 'package:gad_app_team/widgets/blue_banner.dart';

class StepAView extends StatefulWidget {
  /// A칩들: label + chipId + type 포함
  final List<AbcChip> chips;

  /// 현재 선택된 chipId 집합
  final Set<String> selectedChipIds;

  /// 칩 선택/해제 콜백 (chipId, selected)
  final void Function(String chipId, bool selected)? onChipTap;

  /// "+추가" 눌렀을 때 (실제 팝업은 상위에서)
  final VoidCallback? onAddSituation;

  /// X 삭제 눌렀을 때 (chipId)
  final void Function(String chipId)? onDeleteSituation;

  /// 예시 모드 여부
  final bool isExampleMode;

  const StepAView({
    super.key,
    required this.chips,
    required this.selectedChipIds,
    this.onChipTap,
    this.onAddSituation,
    this.onDeleteSituation,
    this.isExampleMode = false,
  });

  @override
  State<StepAView> createState() => _StepAViewState();
}

class _StepAViewState extends State<StepAView> {
  String _bannerMessage = "아래에서 '자전거를 타려고 함'을 선택해보세요!";

  String get _guideMessage {
    if (widget.isExampleMode) return _bannerMessage;
    return "먼저 불안을 느낀 상황(A)을 선택해보세요.\n원하는 항목이 없다면 + 추가로 입력할 수 있어요.";
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AbcStepCard(
            activeIndex: 0,
            smallText: '불안을 유발한 상황을 떠올려요',
            bigText: '불안을 느낀 순간,\n어떤 상황이었나요?',
          ),
          const SizedBox(height: 40),

          // ✅ 칩 영역 (chipId 기반)
          AbcChipsDesign(
            chips: widget.chips,
            selectedChipIds: widget.selectedChipIds,
            singleSelect: true,
            isExampleMode: widget.isExampleMode,
            onChipToggle: (chipId, selected) {
              // 상위에 chipId + 선택 여부 전달
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
                  (selected && label == '자전거를 타려고 함')
                      ? "좋아요! 이제 아래의 '다음' 버튼을 눌러주세요."
                      : "아래에서 '자전거를 타려고 함'을 선택해보세요!";
                });
              }
            },
            // 삭제: chipId 그대로 위로 올려보냄
            onChipDelete:
            widget.isExampleMode ? null : widget.onDeleteSituation,
            // "+추가": 텍스트 입력 팝업은 상위(AbcInputScreen)에서
            onChipAdd: widget.isExampleMode ? null : widget.onAddSituation,
          ),
          const SizedBox(height: 20),
          // ✅ 단계 고정 해파리 가이드 (칩 하단 고정)
          JellyfishBanner(message: _guideMessage),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}
