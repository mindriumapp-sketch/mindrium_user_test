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
  final int openAllItemsSignal;
  final String? chipSectionLabel;

  const AbcChipsDesign({
    super.key,
    required this.chips,
    required this.selectedChipIds,
    this.onChipToggle,
    this.onChipDelete,
    this.onChipAdd,
    this.isExampleMode = false,
    this.singleSelect = false,
    this.openAllItemsSignal = 0,
    this.chipSectionLabel,
  });

  @override
  State<AbcChipsDesign> createState() => _AbcChipsDesignState();
}

class _AbcChipsDesignState extends State<AbcChipsDesign> {
  static const int _collapsedChipLimit = 6;
  static const double _allItemsModalInitialHeight = 560;
  static const double _allItemsModalExpandedHeight = 700;
  static const double _allItemsModalFixedWidth = 430;
  late Set<String> _selectedChipIds;
  late final ScrollController _scrollController;
  bool _isAllItemsModalOpen = false;

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

    if (widget.openAllItemsSignal != oldWidget.openAllItemsSignal &&
        !widget.isExampleMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isAllItemsModalOpen) return;
        _showAllChipsModal();
      });
    }
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

  Widget _buildChipWidget(AbcChip chip) {
    final bool isSelected = _selectedChipIds.contains(chip.chipId);
    final bool canDelete = !widget.isExampleMode;

    if (isSelected) {
      return _SelectedChip(
        label: chip.label,
        showClose: canDelete,
        onTap: () => _toggleChip(chip, false),
        onRemove: canDelete ? () => _deleteChip(chip) : null,
      );
    }
    return _UnselectedChip(
      label: chip.label,
      showClose: canDelete,
      onTap: () => _toggleChip(chip, true),
      onRemove: canDelete ? () => _deleteChip(chip) : null,
    );
  }

  Widget _buildChipWidgetForModal(
    AbcChip chip,
    void Function(void Function()) setModalState,
  ) {
    final bool isSelected = _selectedChipIds.contains(chip.chipId);
    final bool canDelete = !widget.isExampleMode;

    if (isSelected) {
      return _SelectedChip(
        label: chip.label,
        showClose: canDelete,
        onTap: () {
          _toggleChip(chip, false);
          setModalState(() {});
        },
        onRemove:
            canDelete
                ? () {
                  _deleteChip(chip);
                  setModalState(() {});
                }
                : null,
      );
    }
    return _UnselectedChip(
      label: chip.label,
      showClose: canDelete,
      onTap: () {
        _toggleChip(chip, true);
        setModalState(() {});
      },
      onRemove:
          canDelete
              ? () {
                _deleteChip(chip);
                setModalState(() {});
              }
              : null,
    );
  }

  Future<void> _showAllChipsModal() async {
    if (_isAllItemsModalOpen) return;
    _isAllItemsModalOpen = true;
    try {
      final sheetController = DraggableScrollableController();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          final media = MediaQuery.of(context);
          final maxAllowedHeight =
              media.size.height - media.padding.top - 8;
          final systemBottomInset = media.viewPadding.bottom > 0
              ? media.viewPadding.bottom
              : media.padding.bottom;
          final modalBottomInset = systemBottomInset + 8;
          final initialHeight = _allItemsModalInitialHeight.clamp(
            380.0,
            maxAllowedHeight,
          );
          final expandedHeight = _allItemsModalExpandedHeight.clamp(
            initialHeight,
            maxAllowedHeight,
          );
          final minHeight = 380.0.clamp(320.0, initialHeight).toDouble();
          final minChildSize = (minHeight / maxAllowedHeight).clamp(0.3, 1.0);
          final initialChildSize = (initialHeight / maxAllowedHeight).clamp(
            minChildSize,
            1.0,
          );
          final maxChildSize = (expandedHeight / maxAllowedHeight).clamp(
            initialChildSize,
            1.0,
          );
          final maxAllowedWidth = media.size.width - 16;
          final modalWidth =
              _allItemsModalFixedWidth > maxAllowedWidth
                  ? maxAllowedWidth
                  : _allItemsModalFixedWidth;
          return StatefulBuilder(
            builder: (context, setModalState) {
              return SafeArea(
                top: false,
                bottom: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: modalWidth,
                    child: DraggableScrollableSheet(
                      controller: sheetController,
                      expand: false,
                      minChildSize: minChildSize,
                      initialChildSize: initialChildSize,
                      maxChildSize: maxChildSize,
                      builder: (context, sheetScrollController) {
                        return Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FCFF),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          child: Column(
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragUpdate: (details) {
                                  if (!sheetController.isAttached) return;
                                  final dy = details.primaryDelta ?? 0;
                                  final deltaSize = -dy / maxAllowedHeight;
                                  final nextSize = (sheetController.size +
                                          deltaSize)
                                      .clamp(minChildSize, maxChildSize);
                                  sheetController.jumpTo(nextSize);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFBFD2E6),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        '전체 항목',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1F3A4D),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.chipSectionLabel == null ||
                                                widget.chipSectionLabel!.trim().isEmpty
                                            ? '현재 칩 ${widget.chips.length}개'
                                            : '현재 ${widget.chipSectionLabel!.trim()} 칩 ${widget.chips.length}개',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF6C8194),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Stack(
                                  children: [
                                    SingleChildScrollView(
                                      controller: sheetScrollController,
                                      padding: EdgeInsets.fromLTRB(
                                        18,
                                        0,
                                        18,
                                        84 + modalBottomInset,
                                      ),
                                      physics: const BouncingScrollPhysics(),
                                      child: Wrap(
                                        spacing: 10,
                                        runSpacing: 12,
                                        children: [
                                          ...widget.chips.map(
                                            (chip) => _buildChipWidgetForModal(
                                              chip,
                                              setModalState,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!widget.isExampleMode)
                                      Positioned(
                                        right: 18,
                                        bottom: 14 + modalBottomInset,
                                        child: _FloatingAddButton(
                                          onTap: () {
                                            Navigator.pop(context);
                                            widget.onChipAdd?.call();
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      _isAllItemsModalOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final systemBottomInset = media.viewPadding.bottom > 0
        ? media.viewPadding.bottom
        : media.padding.bottom;
    final int visibleCount =
        widget.chips.length > _collapsedChipLimit
            ? _collapsedChipLimit
            : widget.chips.length;
    final visibleChips = widget.chips.take(visibleCount).toList();
    final int hiddenCount = widget.chips.length - visibleCount;

    final chipsArea = SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      child: Padding(
        // 우측 하단 고정 + 버튼/행이 겹치지 않도록 여유를 넉넉히 확보
        padding: EdgeInsets.only(bottom: 104 + systemBottomInset),
        child: Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [
            ...visibleChips.map(_buildChipWidget),
            if (hiddenCount > 0)
              _MoreChipButton(
                hiddenCount: hiddenCount,
                onTap: _showAllChipsModal,
              ),
          ],
        ),
      ),
    );
    if (widget.isExampleMode) return chipsArea;

    return Stack(
      children: [
        Positioned.fill(child: chipsArea),
        Positioned(
          right: 0,
          bottom: 8 + systemBottomInset,
          child: _FloatingAddButton(onTap: widget.onChipAdd),
        ),
      ],
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
    final maxChipWidth = MediaQuery.sizeOf(context).width * 0.72;
    const radius = 14.0;
    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
          minHeight: 38,
          maxWidth: maxChipWidth,
        ),
        padding: EdgeInsets.only(left: 16, right: showClose ? 6 : 16),
        decoration: BoxDecoration(
          color: const Color(0xFF47A6FF),
          borderRadius: BorderRadius.circular(radius),
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
            Flexible(
              child: Text(
                label,
                maxLines: null,
                softWrap: true,
                overflow: TextOverflow.visible,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Noto Sans KR',
                  fontWeight: FontWeight.w500,
                ),
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
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF344B60),
                  fontSize: 16,
                  fontFamily: 'Noto Sans KR',
                  fontWeight: FontWeight.w500,
                ),
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

class _MoreChipButton extends StatelessWidget {
  final int hiddenCount;
  final VoidCallback? onTap;

  const _MoreChipButton({required this.hiddenCount, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF4FF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF9FCBF0), width: 1.1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.expand_more_rounded, size: 18, color: Color(0xFF3B82C4)),
            const SizedBox(width: 3),
            Text(
              '더보기 +$hiddenCount',
              style: const TextStyle(
                color: Color(0xFF2E6EA3),
                fontSize: 14,
                fontFamily: 'Noto Sans KR',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingAddButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _FloatingAddButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF47A6FF),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF47A6FF).withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}
