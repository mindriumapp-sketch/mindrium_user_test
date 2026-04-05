import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/top_btm_card.dart';
import 'week6_behavior_classification_screen.dart';
import 'week6_flow_widgets.dart';
import 'week6_route_utils.dart';

/// 🌊 6주차 - 행동 구분 연습 (3주차와 동일 디자인 적용)
/// - 기능은 그대로 유지
/// - UI는 ApplyDesign 구조로 변경
class Week6RelieveSliderScreen extends StatefulWidget {
  final String selectedBehavior;
  final String behaviorType; // 'face' 또는 'avoid'
  final bool isLongTerm; // 단기/장기 구분
  final double? shortTermValue; // 단기 슬라이더 값
  final List<String>? remainingBehaviors; // 남은 행동 목록
  final List<String> allBehaviorList; // 전체 행동 목록
  final List<Map<String, dynamic>>? mismatchedBehaviors; // 일치하지 않은 행동들
  final String diaryId;
  final Map<String, dynamic> diary;

  const Week6RelieveSliderScreen({
    super.key,
    required this.selectedBehavior,
    required this.behaviorType,
    this.isLongTerm = false,
    this.shortTermValue,
    this.remainingBehaviors,
    required this.allBehaviorList,
    this.mismatchedBehaviors,
    required this.diaryId,
    required this.diary,
  });

  @override
  State<Week6RelieveSliderScreen> createState() =>
      _Week6RelieveSliderScreenState();
}

class _Week6RelieveSliderScreenState extends State<Week6RelieveSliderScreen> {
  int? _selectedValue;

  @override
  Widget build(BuildContext context) {
    final currentBehaviorIndex =
        widget.allBehaviorList.length -
        (widget.remainingBehaviors?.length ?? 0);
    final stageLabel = widget.isLongTerm ? '장기 평가' : '단기 평가';
    final questionTitle =
        widget.isLongTerm
            ? '이 행동이 시간이 지나도 도움이 될까요?'
            : '이 행동을 하면 당장은 마음이 좀 편해질까요?';
    final negativeTitle =
        widget.isLongTerm ? '도움이 오래가진 않을 것 같아요' : '당장은 별로 편해지지 않을 것 같아요';
    final positiveTitle =
        widget.isLongTerm ? '나중에도 도움이 될 것 같아요' : '당장은 좀 편해질 것 같아요';
    final topTitle =
        widget.isLongTerm ? '이 행동이 나중에도 도움이 될지 볼게요' : '이 행동이 당장 어떤 느낌을 줄지 볼게요';
    final topSubtitle =
        widget.isLongTerm
            ? '아래에서 가장 가까운 쪽 하나를 골라주세요.'
            : '이 행동 직후의 느낌을 떠올리며 하나를 골라주세요.';
    final helperText =
        _selectedValue == null ? '가까운 쪽 하나를 골라주세요.' : '선택이 완료되었어요.';

    return ApplyDoubleCard(
      appBarTitle: '행동 구분 연습',
      rightLabel: '다음',
      onBack: () => Navigator.pop(context),
      onNext:
          _selectedValue != null
              ? () {
                final selectedValue = _selectedValue!.toDouble();

                Navigator.push(
                  context,
                  buildWeek6NoAnimationRoute(
                    widget.isLongTerm
                        ? Week6BehaviorClassificationScreen(
                          selectedBehavior: widget.selectedBehavior,
                          behaviorType: widget.behaviorType,
                          shortTermValue: widget.shortTermValue ?? 0.0,
                          longTermValue: selectedValue,
                          remainingBehaviors: widget.remainingBehaviors,
                          allBehaviorList: widget.allBehaviorList,
                          mismatchedBehaviors: widget.mismatchedBehaviors,
                          diaryId: widget.diaryId,
                          diary: widget.diary,
                        )
                        : Week6RelieveSliderScreen(
                          selectedBehavior: widget.selectedBehavior,
                          behaviorType: widget.behaviorType,
                          isLongTerm: true,
                          shortTermValue: selectedValue,
                          remainingBehaviors: widget.remainingBehaviors,
                          allBehaviorList: widget.allBehaviorList,
                          mismatchedBehaviors: widget.mismatchedBehaviors,
                          diaryId: widget.diaryId,
                          diary: widget.diary,
                        ),
                  ),
                );
              }
              : null,

      pagePadding: const EdgeInsets.symmetric(horizontal: 34, vertical: 24),
      panelsGap: 16,
      panelRadius: 20,
      panelPadding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      topChild: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Week6ProgressHeader(
            stageLabel: stageLabel,
            currentIndex: currentBehaviorIndex,
            totalCount: widget.allBehaviorList.length,
            title: topTitle,
            subtitle: topSubtitle,
          ),
          const SizedBox(height: 18),
          Week6InfoCard(
            title: '지금 평가하는 행동',
            subtitle: null,
            icon: Icons.visibility_outlined,
            child: Text(
              widget.selectedBehavior,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF263C69),
                fontFamily: 'Noto Sans KR',
                height: 1.5,
              ),
            ),
          ),
        ],
      ),

      bottomChild: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            questionTitle,
            style: const TextStyle(
              fontSize: 20,
              color: Color(0xFF263C69),
              fontWeight: FontWeight.w800,
              fontFamily: 'Noto Sans KR',
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            helperText,
            style: TextStyle(
              fontSize: 13,
              color:
                  _selectedValue == null
                      ? const Color(0xFF6B7D90)
                      : const Color(0xFF2E7D5B),
              fontWeight: FontWeight.w600,
              fontFamily: 'Noto Sans KR',
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Week6ChoiceOptionCard(
            title: negativeTitle,
            palette: Week6ChoicePalette.coral,
            isSelected: _selectedValue == 0,
            onTap: () => setState(() => _selectedValue = 0),
            showSelectionIndicator: false,
          ),
          const SizedBox(height: 12),
          Week6ChoiceOptionCard(
            title: positiveTitle,
            palette: Week6ChoicePalette.blue,
            isSelected: _selectedValue == 10,
            onTap: () => setState(() => _selectedValue = 10),
            showSelectionIndicator: false,
          ),
        ],
      ),
    );
  }
}
