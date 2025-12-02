import 'package:gad_app_team/utils/text_line_material.dart';
import '../../widgets/custom_appbar.dart';
import '../../widgets/navigation_button.dart';

class StepADesign extends StatefulWidget {
  final String tabLabel;
  final String subtitle;
  final String title;
  final List<String> chips;

  final String? selectedChip;
  final List<String>? selectedChips;
  final void Function(String)? onAddLabel;
  final void Function(String)? onChipTap;

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  final Widget? tutorialWidget;
  final bool showTutorial;

  const StepADesign({
    super.key,
    required this.tabLabel,
    required this.subtitle,
    required this.title,
    required this.chips,
    this.selectedChip,
    this.selectedChips,
    this.onAddLabel,
    this.onChipTap,
    this.onPrevious,
    this.onNext,
    this.tutorialWidget,
    this.showTutorial = false,
  });

  @override
  State<StepADesign> createState() => _StepADesignState();
}

class _StepADesignState extends State<StepADesign> {
  bool _isAdding = false;
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(title: widget.tabLabel),
      body: Stack(
        fit: StackFit.expand,
        children: [
          /// 🌊 배경 (그라데이션 + eduhome)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6FD3FF), Color(0xFFBDEFFF)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Image.asset(
              'assets/image/eduhome.png',
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.45),
            ),
          ),

          /// 📜 본문
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height * 0.8,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center, // ✅ 세로 중앙
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildMainCard(),
                            const SizedBox(height: 36),
                            if (widget.chips.isNotEmpty)
                              _buildChipGrid()
                            else
                              const Text(
                                '아래의 "추가" 버튼을 눌러 상황을 입력해보세요.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontFamily: 'Noto Sans KR',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            if (widget.showTutorial &&
                                widget.tutorialWidget != null) ...[
                              const SizedBox(height: 40),
                              widget.tutorialWidget!,
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              /// ✅ 네비게이션 버튼
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: NavigationButtons(
                  leftLabel: '이전',
                  rightLabel: '다음',
                  onBack: () {
                    if (widget.onPrevious != null) {
                      widget.onPrevious!();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  onNext: () {
                    if (widget.onNext != null) {
                      widget.onNext!();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ===== 메인 카드 =====
  Widget _buildMainCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        /// 북마크 탭
        Container(
          height: 42,
          margin: const EdgeInsets.only(bottom: 0),
          child: Row(
            children: const [
              Expanded(child: _BookMarkLabel(label: 'A 상황', isActive: true)),
              Expanded(child: _BookMarkLabel(label: 'B 생각')),
              Expanded(child: _BookMarkLabel(label: 'C 결과')),
            ],
          ),
        ),

        /// 본문 카드
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(22),
              bottomRight: Radius.circular(22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF263C69),
                  fontSize: 14,
                  fontFamily: 'Noto Sans KR',
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF141F35),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Noto Sans KR',
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ===== 칩 그리드 =====
  Widget _buildChipGrid() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 14,
      children: [
        for (final label in widget.chips)
          if (label != '추가')
            _BlueChip(
              label: label,
              selected:
                  (widget.selectedChips?.contains(label) ?? false) ||
                  label == widget.selectedChip,
              onTap:
                  widget.onChipTap == null
                      ? null
                      : () => widget.onChipTap!(label),
            )
          else
            _AddChipInline(
              isAdding: _isAdding,
              controller: _controller,
              onStartAdd: () => setState(() => _isAdding = true),
              onSubmit: (value) {
                if (value.trim().isEmpty) {
                  setState(() => _isAdding = false);
                  return;
                }
                widget.onAddLabel?.call(value.trim());
                _controller.clear();
                setState(() => _isAdding = false);
              },
            ),
      ],
    );
  }
}

/// ===== 북마크 탭 =====
class _BookMarkLabel extends StatelessWidget {
  final String label;
  final bool isActive;
  const _BookMarkLabel({required this.label, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isActive
                  ? [const Color(0xFF47A6FF), const Color(0xFF6FC7FF)]
                  : [const Color(0xFFAADCFD), const Color(0xFFC8EDFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'Noto Sans KR',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// ===== 칩 =====
class _BlueChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _BlueChip({required this.label, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final gradientColors =
        selected
            ? [const Color(0xFF47A6FF), const Color(0xFF6FC7FF)]
            : [const Color(0xFF7FCFFF), const Color(0xFFA7E4FF)];

    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontFamily: 'Noto Sans KR',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// ===== 추가 칩 입력 =====
class _AddChipInline extends StatelessWidget {
  final bool isAdding;
  final TextEditingController controller;
  final VoidCallback onStartAdd;
  final void Function(String) onSubmit;

  const _AddChipInline({
    required this.isAdding,
    required this.controller,
    required this.onStartAdd,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    if (isAdding) {
      return SizedBox(
        width: 130,
        child: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: onSubmit,
          decoration: InputDecoration(
            hintText: '입력 후 Enter',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(50),
              borderSide: const BorderSide(color: Color(0xFF47A6FF)),
            ),
          ),
          style: const TextStyle(fontFamily: 'Noto Sans KR', fontSize: 14),
        ),
      );
    }

    return GestureDetector(
      onTap: onStartAdd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF47A6FF), width: 1.4),
          borderRadius: BorderRadius.circular(50),
          color: Colors.white.withOpacity(0.85),
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
                fontSize: 15,
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
