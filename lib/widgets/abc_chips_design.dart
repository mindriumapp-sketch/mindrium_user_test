import 'package:gad_app_team/utils/text_line_material.dart';

/// 🌊 ABC 칩 디자인 공용 위젯 (Mindrium 공통 스타일)
///
/// - [chips] : 화면에 보여줄 칩들 (AbcChip 리스트)
/// - [selectedChipIds] : 현재 선택된 chipId 집합
/// - [onChipToggle] : 칩 탭해서 선택/해제될 때 호출 (chipId, selected)
/// - [onChipDelete] : X 버튼 눌러 칩 삭제할 때 호출 (chipId)
/// - [onChipAdd] : "+추가" 칩 눌렀을 때 호출 (실제 입력 팝업은 상위에서 처리)
/// - [isExampleMode] : 예시 모드일 때 +추가/삭제 버튼 숨길 때 사용
/// - [singleSelect] : true면 하나만 선택되도록 동작

class AbcChip {
  final String chipId;   // presets도 포함해서 전부 ID 부여
  final String label;    // 그리드에 찍힐 텍스트
  final String type;     // "A" | "B" | "CP" | "CE" | "CA"
  final bool isPreset;   // 기본 제공 칩인지 여부

  const AbcChip({
    required this.chipId,
    required this.label,
    required this.type,
    this.isPreset = false,
  });
}


class AbcChipsDesign extends StatefulWidget {
  final List<AbcChip> chips;
  final Set<String> selectedChipIds;
  final void Function(String chipId, bool selected)? onChipToggle;
  final void Function(String chipId)? onChipDelete;
  final VoidCallback? onChipAdd;
  final bool isExampleMode;
  final bool singleSelect;

  const AbcChipsDesign({
    super.key,
    required this.chips,
    required this.selectedChipIds,
    this.onChipToggle,
    this.onChipDelete,
    this.onChipAdd,
    this.isExampleMode = false,
    this.singleSelect = false,
  });

  @override
  State<AbcChipsDesign> createState() => _AbcChipsDesignState();
}

class _AbcChipsDesignState extends State<AbcChipsDesign> {
  late Set<String> _selectedChipIds;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _selectedChipIds = Set<String>.from(widget.selectedChipIds);
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(covariant AbcChipsDesign oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 상위에서 selectedChipIds가 바뀌면 내부 상태 동기화
    _selectedChipIds = Set<String>.from(widget.selectedChipIds);
  }

  void _toggleChip(AbcChip chip, bool selected) {
    if (widget.singleSelect) {
      if (selected) {
        final prev = List<String>.from(_selectedChipIds);
        setState(() {
          _selectedChipIds
            ..clear()
            ..add(chip.chipId);
        });
        for (final p in prev) {
          if (p != chip.chipId) {
            widget.onChipToggle?.call(p, false);
          }
        }
        widget.onChipToggle?.call(chip.chipId, true);
      } else {
        setState(() => _selectedChipIds.remove(chip.chipId));
        widget.onChipToggle?.call(chip.chipId, false);
      }
    } else {
      setState(() {
        if (selected) {
          _selectedChipIds.add(chip.chipId);
        } else {
          _selectedChipIds.remove(chip.chipId);
        }
      });
      widget.onChipToggle?.call(chip.chipId, selected);
    }
  }

  void _deleteChip(AbcChip chip) {
    widget.onChipDelete?.call(chip.chipId);
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      radius: const Radius.circular(12),
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 10,
            runSpacing: 12,
            children: [
              ...widget.chips.map((chip) {
                final bool isSelected =
                _selectedChipIds.contains(chip.chipId);

                // ✅ 프리셋도 삭제 가능하게: isPreset 안 막음
                final bool canDelete = !widget.isExampleMode;

                if (isSelected) {
                  return _SelectedChip(
                    label: chip.label,
                    showClose: canDelete,
                    onTap: () => _toggleChip(chip, false),
                    onRemove: canDelete ? () => _deleteChip(chip) : null,
                  );
                } else {
                  return _UnselectedChip(
                    label: chip.label,
                    showClose: canDelete,
                    onTap: () => _toggleChip(chip, true),
                    onRemove: canDelete ? () => _deleteChip(chip) : null,
                  );
                }
              }),

              // ✅ 예시모드가 아닐 때만 "+추가" 칩 보여주기
              if (!widget.isExampleMode)
                _AddChipButton(onTap: widget.onChipAdd),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

/// ✅ 선택된 칩
class _SelectedChip extends StatelessWidget {
  final String label;
  final bool showClose;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _SelectedChip({
    required this.label,
    required this.onTap,
    this.showClose = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        height: 38,
        padding: EdgeInsets.only(left: 16, right: showClose ? 6 : 16),
        decoration: BoxDecoration(
          color: const Color(0xFF47A6FF),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF47A6FF).withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Noto Sans KR',
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showClose && onRemove != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ✅ 선택되지 않은 칩
class _UnselectedChip extends StatelessWidget {
  final String label;
  final bool showClose;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _UnselectedChip({
    required this.label,
    required this.onTap,
    this.showClose = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: EdgeInsets.only(left: 16, right: showClose ? 6 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF344B60),
                fontSize: 16,
                fontFamily: 'Noto Sans KR',
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showClose && onRemove != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFF47A6FF).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xFF47A6FF),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ✅ “+추가” 칩
class _AddChipButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _AddChipButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF47A6FF), width: 1.2),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 18, color: Color(0xFF47A6FF)),
            SizedBox(width: 4),
            Text(
              '추가',
              style: TextStyle(
                color: Color(0xFF47A6FF),
                fontSize: 14.5,
                fontFamily: 'Noto Sans KR',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
