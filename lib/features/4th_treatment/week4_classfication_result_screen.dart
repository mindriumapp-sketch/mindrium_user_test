// lib/features/4th_treatment/week4_classfication_result_screen.dart
import 'package:gad_app_team/utils/text_line_material.dart';
// import 'package:provider/provider.dart';

// import 'package:gad_app_team/data/user_provider.dart';
import 'week4_alternative_thoughts.dart';
import 'package:gad_app_team/data/apply_solve_provider.dart';

// ✅ 동일 UI 컴포넌트 (SkipChoice와 통일)
import 'package:gad_app_team/widgets/quiz_card.dart';
import 'package:gad_app_team/widgets/choice_card_button.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:provider/provider.dart';

class Week4ClassificationResultScreen extends StatelessWidget {
  const Week4ClassificationResultScreen({
    super.key,
    this.bScores,
    this.bList,
    this.remainingBList,
    this.allBList,
    this.alternativeThoughts,
    this.isFromAnxietyScreen = false,
    this.existingAlternativeThoughts,
    this.abcId,
    this.loopCount = 1,
  });

  List<String> _removeDuplicates(List<String> list) {
    final uniqueList = <String>[];
    for (final item in list) {
      if (!uniqueList.contains(item)) uniqueList.add(item);
    }
    return uniqueList;
  }

  final List<double>? bScores;
  final List<String>? bList;
  final List<String>? remainingBList;
  final List<String>? allBList;
  final List<String>? alternativeThoughts;
  final bool isFromAnxietyScreen;
  final List<String>? existingAlternativeThoughts;
  final String? abcId;
  final int loopCount;

  String _chipLabel(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map) {
      return (raw['label'] ?? '').toString();
    }
    if (raw is String) {
      final match = RegExp(r'label\s*[:=]\s*([^,}]+)').firstMatch(raw);
      if (match != null) return match.group(1)?.trim() ?? '';
    }
    return raw.toString();
  }

  @override
  Widget build(BuildContext context) {
    final String mainThought = _chipLabel(
      (bList != null && bList!.isNotEmpty) ? bList!.last : '',
    );

    // 경로 기반 카피/플로우
    final args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
    final flow =
        context.read<ApplyOrSolveFlow>()..syncFromArgs(args, notify: false);
    final sanitizedFlowArgs =
        Map<String, dynamic>.from(flow.toArgs())
          ..remove('beforeSud')
          ..remove('sudId');
    final String? abcId_ = args['abcId'] as String? ?? flow.diaryId;
    final String rawOrigin = args['origin'] as String? ?? flow.origin;
    final String origin = rawOrigin == 'solve' ? 'apply' : rawOrigin;
    final dynamic diary = args['diary'] ?? flow.diary;
    final bool isFromApply = origin == 'apply';

    // final userName = Provider.of<UserProvider>(context, listen: false).userName;

    // 메인 문구
    String mainQuestionText;
    if (isFromApply) {
      mainQuestionText = '다른 생각에 대해서도 도움이 되는 생각을 찾아볼까요?';
    } else if (isFromAnxietyScreen) {
      mainQuestionText =
          '방금 보셨던 "$mainThought"라는 생각에 대해 도움이 되는 생각을 찾아보는 시간을 가져보겠습니다!';
    } else {
      mainQuestionText = '방금 보셨던 "$mainThought"라는 생각에 대해 도움이 되는 생각을 찾아볼까요?';
    }

    // 디폴트 값들
    final List<String> safeRemainingBList = remainingBList ?? const <String>[];
    final List<String> safeAllBList = allBList ?? const <String>[];
    final List<String> mergedAlternativeThoughts = _removeDuplicates([
      ...?existingAlternativeThoughts,
      ...?alternativeThoughts,
    ]);
    final bool hasMoreThoughts = safeRemainingBList.isNotEmpty;

    final primaryButtonLabel =
        isFromApply ? '다른 생각도 이어서 볼게요!' : '도움이 되는 생각을 적어볼게요!';

    final String quizText =
        isFromApply
            ? [
              mainQuestionText,
              if (!isFromAnxietyScreen) '\n\n아래 두 가지 방법 중 하나를 선택해주세요.',
            ].join(' ')
            : hasMoreThoughts
            ? '방금 보셨던 "$mainThought"라는 생각에 대해 도움이 되는 생각을 적어보고,\n이어지는 다른 생각들도 하나씩 살펴볼게요.'
            : '방금 보셨던 "$mainThought"라는 생각에 대해 도움이 되는 생각을 적어보겠습니다.';

    // ===== 네비게이션 핸들러 (원본 로직 유지) =====
    void onPrimary() {
      if (isFromApply) {
        // 적용하기 플로우: 선택 화면으로 돌아가 다른 생각 선택
        Navigator.pushReplacementNamed(
          context,
          '/apply_alt_thought',
          arguments: {
            ...sanitizedFlowArgs,
            'abcId': abcId_,
            'origin': 'apply',
            if (diary != null) 'diary': diary,
          },
        );
        return;
      }
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder:
              (_, __, ___) => Week4AlternativeThoughtsScreen(
                allBList: safeAllBList,
                previousChips: mainThought.isNotEmpty ? [mainThought] : [],
                remainingBList: safeRemainingBList,
                existingAlternativeThoughts: mergedAlternativeThoughts,
                isFromAnxietyScreen: isFromAnxietyScreen,
                originalBList: safeAllBList,
                abcId: abcId ?? abcId_, // 명시적으로 전달
                loopCount: loopCount,
                origin: isFromApply ? 'apply' : null,
                diary: diary,
                flowMode:
                    isFromApply
                        ? Week4AlternativeThoughtsFlowMode.applyAfterSud
                        : Week4AlternativeThoughtsFlowMode.week4BeliefLoop,
              ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }

    void onSecondaryApply() {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    }

    // ===== 레이아웃 =====
    final horizontal = 34.0;
    final screenW = MediaQuery.of(context).size.width;
    final maxCardWidth = screenW - horizontal * 2;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(title: '인지 왜곡 찾기'),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🌊 배경
          Container(
            color: Colors.white, // 흰 배경 유지
            child: Opacity(
              opacity: 0.35, // ApplyDesign과 동일한 투명도
              child: Image.asset(
                'assets/image/eduhome.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          // 본문
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxCardWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1) 본문 카드 (진행표시 생략)
                      QuizCard(
                        quizText: quizText,
                        quizSize: 18,
                        currentIndex: 1,
                        // totalCount: null → 진행상태 숨김 (위젯에서 null 허용 구현되어 있어야 함)
                      ),

                      const SizedBox(height: 16),

                      // 2) 선택 버튼들 (ChoiceCardButton 사용)
                      ChoiceCardButton(
                        // 메인 액션(파란)
                        type: ChoiceType.other,
                        onPressed: onPrimary,
                        // 라벨을 외부에서 덮어쓰기 위해 text 사용(네가 수정한 ChoiceCardButton에 대응)
                        othText: primaryButtonLabel,
                        height: 54,
                      ),

                      if (isFromApply && !isFromAnxietyScreen) ...[
                        const SizedBox(height: 10),
                        ChoiceCardButton(
                          // 보조 액션(분홍)
                          type: ChoiceType.another,
                          onPressed: onSecondaryApply,
                          anoText: '다음번에 찾아볼게요.',
                          height: 54,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
