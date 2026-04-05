import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/tutorial_design.dart';

import 'week6_visual_screen.dart';
import 'week6_route_utils.dart';

/// 🌊 Mindrium 스타일 6주차 - 행동 구분 연습 (다르게 생각해보기)
class Week6ConfrontAnxietyScreen extends StatefulWidget {
  final List<String> previousChips;
  const Week6ConfrontAnxietyScreen({super.key, required this.previousChips});

  @override
  State<Week6ConfrontAnxietyScreen> createState() =>
      _Week6ConfrontAnxietyScreenState();
}

class _Week6ConfrontAnxietyScreenState
    extends State<Week6ConfrontAnxietyScreen> {
  final List<String> _chips = [];

  /// 🪸 입력 다이얼로그 (ApplyDesign 스타일 유지)
  void _showInputDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      useSafeArea: false,
      barrierDismissible: true,
      builder:
          (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 28,
                bottom: MediaQuery.of(context).viewInsets.bottom + 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '지금까지 했던 행동과 반대로 생각해볼까요?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF263C69),
                      fontFamily: 'Noto Sans KR',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Color(0xFFE0E3EB)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              hintText: '예: 피하지 않고 대화하기',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            autofocus: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '(이)라는',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF263C69),
                          fontFamily: 'Noto Sans KR',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '행동을 할 것 같다고 상상했습니다.',
                    style: TextStyle(
                      color: Color(0xFF263C69),
                      fontSize: 16,
                      fontFamily: 'Noto Sans KR',
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      final value = controller.text.trim();
                      if (value.isNotEmpty) {
                        setState(() {
                          _chips.add(value);
                        });
                        Navigator.pop(context);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF5B3EFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      '추가',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Noto Sans KR',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ApplyDesign(
      appBarTitle: '행동 구분 연습',
      cardTitle: '다르게 생각해보기',
      onBack: () => Navigator.pop(context),
      onNext: () {
        Navigator.push(
          context,
          buildWeek6NoAnimationRoute(
            Week6VisualScreen(
              previousChips: widget.previousChips,
              alternativeChips: _chips,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /// 🪸 상단 시각 카드 (ApplyDesign 내부 카드 느낌으로)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Text(
                    '불안 직면',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF263C69),
                      fontFamily: 'Noto Sans KR',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(22),
                    bottomRight: Radius.circular(22),
                  ),
                  child: Image.asset(
                    'assets/image/alternative thoughts.png',
                    fit: BoxFit.cover,
                    height: 180,
                    width: double.infinity,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          /// 💭 하단 행동 상상 카드
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
            child: Column(
              children: [
                const Text(
                  '불안을 직면하는 행동으로 생각해볼까요?',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: Color(0xFF5B3EFF),
                    fontFamily: 'Noto Sans KR',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: 120,
                    maxHeight: 220,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F8FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Color(0xFFE0E3EB)),
                  ),
                  child:
                      _chips.isEmpty
                          ? const Center(
                            child: Text(
                              '여기에 입력한 내용이 표시됩니다',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 15,
                                fontFamily: 'Noto Sans KR',
                              ),
                            ),
                          )
                          : SingleChildScrollView(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  _chips
                                      .map(
                                        (text) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(
                                              color: const Color(0xFFCAD3F2),
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            text,
                                            style: const TextStyle(
                                              color: Color(0xFF5B3EFF),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                              fontFamily: 'Noto Sans KR',
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _showInputDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B3EFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      '입력하기',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Noto Sans KR',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
