import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'week4_alternative_thoughts.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'week4_skip_choice_screen.dart';
import 'week4_after_sud_screen.dart';
import 'week4_classfication_screen.dart' as week4;

// 소개를 하는 페이지
class Week4ClassificationResultScreen extends StatelessWidget {
  List<String> _removeDuplicates(List<String> list) {
    final uniqueList = <String>[];
    for (final item in list) {
      if (!uniqueList.contains(item)) {
        uniqueList.add(item);
      }
    }
    return uniqueList;
  }

  final List<double>? bScores;
  final List<String>? bList;
  final int? beforeSud;
  final List<String>? remainingBList;
  final List<String>? allBList;
  final List<String>? alternativeThoughts;
  final bool isFromAnxietyScreen;
  final List<String>? existingAlternativeThoughts;
  final String? abcId;
  final int loopCount;

  const Week4ClassificationResultScreen({
    super.key,
    this.bScores,
    this.bList,
    this.beforeSud,
    this.remainingBList,
    this.allBList,
    this.alternativeThoughts,
    this.isFromAnxietyScreen = false,
    this.existingAlternativeThoughts,
    this.abcId,
    this.loopCount = 1,
  });

  @override
  Widget build(BuildContext context) {
    final String mainThought =
        (bList != null && bList!.isNotEmpty) ? bList!.last : '';

    // 경로 기반 카피 조정 (적용하기 플로우인지 확인)
    // origin == 'apply'로 전달되면 전용 문구를 사용
    final args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
    final String? abcId_   = args['abcId'] as String?;
    final String? origin   = args['origin'] as String?;
    final dynamic diary = args['diary'];
    final bool isFromApply = origin == 'apply';

    // 불안한 생각을 추가한 경우의 텍스트 구성
    String mainQuestionText;
    if (isFromApply) {
      mainQuestionText = '다른 생각에 대해서도 도움이 되는 생각을 찾아볼까요?';
    } else if (isFromAnxietyScreen) {
      mainQuestionText = '방금 보셨던 "$mainThought"(라)는 생각에 대해 도움이 되는 생각을 찾아보는 시간을 가져보겠습니다!';
    } else {
      mainQuestionText = '방금 보셨던 "$mainThought"(라)는 생각에 대해 도움이 되는 생각을 찾아보는 시간을 가져볼까요?';
    }

    // Safe defaults when nullable params are not provided
    final int safeBeforeSud = beforeSud ?? 0;
    final List<String> safeRemainingBList = remainingBList ?? const <String>[];
    final List<String> safeAllBList = allBList ?? const <String>[];
    // 보조 문구와 버튼 라벨 (적용하기 전용 카피)
    final supportText = isFromApply
        ? '만약 지금은 좀 부담스러우시다면 \n다음번에 해도 괜찮아요.'
        : '만약 지금은 좀 부담스러우시다면 다른 생각들 먼저 보고 다시 돌아와도 괜찮아요.';
    final secondaryButtonLabel = isFromApply
        ? '다음번에 찾아볼게요.'
        : '다른 생각으로 진행할게요.';

    debugPrint('abcId: $abcId_');

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '4주차 - 인지 왜곡 찾기'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28.0,
                  vertical: 48.0,
                ),
                child: Builder(
                  builder: (context) {
                    final userName =
                        Provider.of<UserProvider>(
                          context,
                          listen: false,
                        ).userName;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '$userName님',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5B3EFF),
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: 48,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Color(0xFF5B3EFF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          mainQuestionText,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                            height: 1.5,
                            letterSpacing: 0.1,
                          ),
                          textAlign: TextAlign.left,
                        ),
                        if (!isFromAnxietyScreen) ...[
                          const SizedBox(height: 16),
                          Text(
                            '아래 두 가지 방법 중 하나를 선택해주세요.',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF5B3EFF),
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          supportText,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        // 상하로 배치된 버튼들
                        SizedBox(
                          width: double.infinity,
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (isFromApply) {
                                      // 적용하기 플로우: 선택 화면으로 돌아가 다른 생각을 다시 선택
                                      Navigator.pushReplacementNamed(
                                        context,
                                        '/apply_alt_thought',
                                        arguments: {
                                          'abcId': abcId_,
                                          'beforeSud': safeBeforeSud,
                                          if(diary != null) 'diary': diary
                                        },
                                      );
                                      return;
                                    }
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder:
                                            (
                                              _,
                                              __,
                                              ___,
                                            ) => Week4AlternativeThoughtsScreen(
                                              allBList: safeAllBList,
                                              previousChips:
                                                  mainThought.isNotEmpty
                                                      ? [mainThought]
                                                      : [],
                                              beforeSud: safeBeforeSud,
                                              remainingBList:
                                                  safeRemainingBList,
                                              existingAlternativeThoughts:
                                                  _removeDuplicates([
                                                    ...?existingAlternativeThoughts,
                                                    ...?alternativeThoughts,
                                                  ]),
                                              isFromAnxietyScreen:
                                                  isFromAnxietyScreen,
                                              originalBList:
                                                  safeAllBList, // 모든 B 생각들 (원래 + 추가한 불안한 생각들)
                                              abcId: abcId_,
                                              loopCount: loopCount,
                                            ),
                                        transitionDuration: Duration.zero,
                                        reverseTransitionDuration:
                                            Duration.zero,
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2962F6),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    '도움이 되는 생각을 찾아볼게요!',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              if (!isFromAnxietyScreen) ...[
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (isFromApply) {
                                        // 적용하기 플로우: 바로 after_sud로 이동 (abcId 전달)
                                        Navigator.pushReplacementNamed(
                                          context,
                                          '/after_sud',
                                          arguments: {
                                            'abcId': abcId_,
                                            'origin': origin,
                                            // 적용하기 플로우에서는 명시적으로 'new'로 표기해 After SUD에서 알림 설정 분기로 사용
                                            'diary': 'new',
                                          },
                                        );
                                        return;
                                      }
                                      // 대체생각을 하나라도 작성했으면 바로 after sud로 이동
                                      if (alternativeThoughts != null &&
                                          alternativeThoughts!.isNotEmpty) {
                                        if (abcId_ != null && abcId_.isNotEmpty) {
                                          // abcId가 있으면 named route로 이동
                                          Navigator.pushReplacementNamed(
                                            context,
                                            '/after_sud',
                                            arguments: {'abcId': abcId_},
                                          );
                                        } else {
                                          // abcId가 없으면 기존 화면으로 직접 이동
                                          Navigator.pushReplacement(
                                            context,
                                            PageRouteBuilder(
                                              pageBuilder: (_, __, ___) => Week4AfterSudScreen(
                                                beforeSud: safeBeforeSud,
                                                currentB: (bList != null && bList!.isNotEmpty)
                                                    ? bList!.last
                                                    : '',
                                                remainingBList: safeRemainingBList,
                                                allBList: safeAllBList,
                                                alternativeThoughts: alternativeThoughts ?? [],
                                              ),
                                              transitionDuration: Duration.zero,
                                              reverseTransitionDuration: Duration.zero,
                                            ),
                                          );
                                        }
                                      } else if (safeRemainingBList.isEmpty) {
                                        // 대체생각도 없고 남은 생각도 없으면 skip choice 화면으로 이동
                                        Navigator.pushReplacement(
                                          context,
                                          PageRouteBuilder(
                                            pageBuilder:
                                                (_, __, ___) =>
                                                    Week4SkipChoiceScreen(
                                                      allBList: safeAllBList,
                                                      beforeSud: safeBeforeSud,
                                                      remainingBList:
                                                          safeRemainingBList,
                                                      abcId: abcId,
                                                    ), 
                                            transitionDuration: Duration.zero,
                                            reverseTransitionDuration:
                                                Duration.zero,
                                          ),
                                        );
                                      } else {
                                        // 남은 B가 있으면 다음 B로 진행
                                        if (abcId_ != null && abcId_.isNotEmpty) {
                                          Navigator.pushNamed(
                                            context,
                                            '/alt_thought',
                                            arguments: {
                                              'abcId': abcId_,
                                            },
                                          ); 
                                        } else {
                                          // 모든 생각을 건너뛰었다면 skip_choice_screen으로 이동
                                          Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                              pageBuilder: (_, __, ___) => week4.Week4ClassificationScreen(
                                                bListInput: safeRemainingBList,
                                                beforeSud: safeBeforeSud,
                                                allBList: safeAllBList,
                                                alternativeThoughts: alternativeThoughts,
                                                abcId: abcId,
                                              ),
                                              transitionDuration: Duration.zero,
                                              reverseTransitionDuration: Duration.zero,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF2962F6),
                                      side: const BorderSide(
                                        color: Color(0xFF2962F6),
                                        width: 2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      secondaryButtonLabel,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
