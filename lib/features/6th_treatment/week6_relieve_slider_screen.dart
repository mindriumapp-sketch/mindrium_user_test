import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/widgets/tutorial_design.dart'; // ✅ ApplyDesign 정의 파일
import 'package:gad_app_team/widgets/top_btm_card.dart';
import 'week6_relieve_result_screen.dart';

/// 🌊 6주차 - 불안 직면 VS 회피 (3주차와 동일 디자인 적용)
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

  const Week6RelieveSliderScreen({
    super.key,
    required this.selectedBehavior,
    required this.behaviorType,
    this.isLongTerm = false,
    this.shortTermValue,
    this.remainingBehaviors,
    required this.allBehaviorList,
    this.mismatchedBehaviors,
  });

  @override
  State<Week6RelieveSliderScreen> createState() =>
      _Week6RelieveSliderScreenState();
}

class _Week6RelieveSliderScreenState extends State<Week6RelieveSliderScreen> {
  int? _selectedValue;

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<UserProvider>(context, listen: false).userName;

    return ApplyDoubleCard(
      appBarTitle: '불안 직면 VS 회피',
      onBack: () => Navigator.pop(context),
      onNext: _selectedValue != null
          ? () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => Week6RelieveResultScreen(
              selectedBehavior: widget.selectedBehavior,
              behaviorType: widget.behaviorType,
              sliderValue: _selectedValue!.toDouble(),
              isLongTerm: widget.isLongTerm,
              shortTermValue: widget.shortTermValue,
              remainingBehaviors: widget.remainingBehaviors,
              allBehaviorList: widget.allBehaviorList,
              mismatchedBehaviors: widget.mismatchedBehaviors,
            ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      }
          : null,

      // 👇 위에서 쓰던 값들이랑 맞춘 레이아웃 옵션
      pagePadding: const EdgeInsets.symmetric(horizontal: 34, vertical: 24),
      panelsGap: 16,
      panelRadius: 20,
      panelPadding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      topPadding: 20,
      height: 130,

      // 두 패널 사이에 들어갈 말풍선
      middleNoticeText: _selectedValue == null ? widget.isLongTerm
          ? '이번엔 “장기적으로” 불안이 얼마나 줄어들지 생각해볼게요.\n아래에서 선택해 주세요.'
          : '방금 보신 행동이 “당장” 불안을 덜어줄지 생각해볼게요.\n아래에서 선택해 주세요.'
          : _selectedValue == 0 ? '불안이 완화되지 않음으로 \n선택하셨군요'
          : '불안이 완화됨으로 선택하셨군요',
      middleNoticeColor: _selectedValue == null
          ? Colors.black45
          :_selectedValue == 0 ? const Color(0xFFFF5252) : const Color(0xFF4CAF50),

      // 🔼 상단 패널
      topChild: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          Text(
            '$userName님께서 걱정일기에 작성해주신 행동을 보며 진행해주세요.',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF224C78),
              fontFamily: 'Noto Sans KR',
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              widget.selectedBehavior,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF263C69),
                fontFamily: 'Noto Sans KR',
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),

      // 🔽 하단 패널
      bottomChild: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.isLongTerm
                ? '이 행동을 하신다면 장기적으로 불안이 완화될 것 같으신가요?'
                : '이 행동을 하신다면 단기적으로 불안이 완화될 것 같으신가요?',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF224C78),
              fontWeight: FontWeight.w500,
              fontFamily: 'Noto Sans KR',
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          MindriumChoiceButtons(
            label1: '불안 완화되지 않음',
            label2: '불안 완화됨',
            selectedValue: _selectedValue,
            onSelect: (val) => setState(() => _selectedValue = val),
          ),
        ],
      ),
    );
  }
}
