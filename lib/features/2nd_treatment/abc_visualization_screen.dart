import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';
import 'package:provider/provider.dart';

import '../../data/user_provider.dart';

// 💡 Mindrium 위젯 디자인들
import 'package:gad_app_team/widgets/abc_chips_design.dart';
import 'package:gad_app_team/widgets/memo_sheet_design.dart';
import 'package:gad_app_team/widgets/abc_visualization_design.dart';
import 'package:gad_app_team/features/2nd_treatment/loctime_selection_screen.dart';

/// 📊 시각화 + 피드백 화면 (AbcChip 기반)
class AbcVisualizationScreen extends StatefulWidget {
  final String? sessionId;

  /// A: 상황 (선택된 칩들 — 실제로는 1개이지만 리스트로 유지)
  final List<AbcChip> activatingChips;

  /// B: 생각 (선택된 칩들)
  final List<AbcChip> beliefChips;

  /// C1: 신체
  final List<AbcChip> physicalChips;

  /// C2: 감정
  final List<AbcChip> emotionChips;

  /// C3: 행동
  final List<AbcChip> behaviorChips;

  /// 예시 모드 여부
  final bool isExampleMode;
  final String? origin;
  final String? diaryRoute;
  final String? abcId;
  final int? beforeSud;
  final String? sudId;

  const AbcVisualizationScreen({
    super.key,
    required this.activatingChips,
    required this.beliefChips,
    required this.physicalChips,
    required this.emotionChips,
    required this.behaviorChips,
    required this.isExampleMode,
    this.origin,
    this.diaryRoute,
    this.abcId,
    this.beforeSud,
    this.sessionId,
    this.sudId,
  });

  @override
  State<AbcVisualizationScreen> createState() => _AbcVisualizationScreenState();
}

class _AbcVisualizationScreenState extends State<AbcVisualizationScreen> {
  bool _isTextView = true;

  @override
  Widget build(BuildContext context) {
    return MemoFullDesign(
      appBarTitle: (widget.origin != null) ? 'ABC 모델' : '일기 작성',
      topWidget: _buildViewToggle(),
      onBack: () => Navigator.pop(context),
      onNext: _goNext,
      rightLabel: '다음',
      memoHeight: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          _buildCommonGreeting(context),
          const SizedBox(height: 12),
          if (_isTextView) _buildFeedbackCard(context),
          if (!_isTextView) _buildAbcFlowDiagram(),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              label: '글로 보기',
              selected: _isTextView,
              onTap: () => setState(() => _isTextView = true),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildToggleButton(
              label: '그림으로 보기',
              selected: !_isTextView,
              onTap: () => setState(() => _isTextView = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF33A4F0) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF4B6B80),
              fontFamily: 'Noto Sans KR',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommonGreeting(BuildContext context) {
    final userName = Provider.of<UserProvider>(context, listen: false).userName;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          protectKoreanWords('$userName님, \n말씀해주셔서 감사합니다. \n작성해 주신 내용을 정리해 보겠습니다.\n'),
          style: const TextStyle(
            fontSize: 20,
            color: Colors.black87,
            fontFamily: 'Noto Sans KR',
          ),
          textAlign: TextAlign.start,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 💬 피드백 카드
  // ──────────────────────────────────────────────
  Widget _buildFeedbackCard(BuildContext context) {
    final situation = widget.activatingChips.map((c) => c.label).join(', ');
    final thought = widget.beliefChips.map((c) => c.label).join(', ');
    final emotion = widget.emotionChips.map((c) => c.label).join(', ');
    final physical = widget.physicalChips.map((c) => c.label).join(', ');
    final behavior = widget.behaviorChips.map((c) => c.label).join(', ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            protectKoreanWords(
              '"$situation" 상황에서 \n"$thought" 생각을 하셨고,\n"$emotion" 감정을 느끼셨습니다.\n\n'
              '그 결과 신체적으로 "$physical" 증상이 나타났고,\n"$behavior" 행동을 하셨습니다.',
            ),
            style: const TextStyle(
              fontSize: 20,
              color: Colors.black87,
              fontFamily: 'Noto Sans KR',
            ),
            textAlign: TextAlign.start,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 🔵 A→B→C 시각화 다이어그램
  // ──────────────────────────────────────────────
  Widget _buildAbcFlowDiagram() {
    final situationText = widget.activatingChips.map((c) => c.label).join(', ');
    final beliefText = widget.beliefChips.map((c) => c.label).join(', ');
    final resultText = <String>[
      ...widget.emotionChips.map((c) => c.label),
      ...widget.physicalChips.map((c) => c.label),
      ...widget.behaviorChips.map((c) => c.label),
    ].join(', ');

    return AbcVisualizationDesign.buildVisualizationLayout(
      situationLabel: '상황 (A)',
      beliefLabel: '생각 (B)',
      resultLabel: '결과 (C)',
      situationText: situationText,
      beliefText: beliefText,
      resultText: resultText,
    );
  }

  // ──────────────────────────────────────────────
  // ✅ 위치/시간 설정 화면으로 이동 (아직 저장하지 않음)
  // ──────────────────────────────────────────────
  void _goNext() {
    final resolvedLabel = widget.activatingChips.isNotEmpty
        ? widget.activatingChips.first.label
        : widget.activatingChips.map((c) => c.label).join(', ');

    if (!mounted) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => LocTimeSelectionScreen(
          abcId: widget.abcId ?? '',
          label: resolvedLabel.isNotEmpty ? resolvedLabel : null,
          origin: widget.origin,
          diaryRoute: widget.diaryRoute,
          sessionId: widget.sessionId,
          sudId: widget.sudId,
          beforeSud: widget.beforeSud,
          activatingChips: widget.activatingChips,
          beliefChips: widget.beliefChips,
          physicalChips: widget.physicalChips,
          emotionChips: widget.emotionChips,
          behaviorChips: widget.behaviorChips,
          autoOpenMapOnEntry: true,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}
