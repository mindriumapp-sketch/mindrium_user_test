import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';

class Week3VisualScreen extends StatefulWidget {
  final List<String> previousChips;
  final List<String> alternativeChips;
  const Week3VisualScreen({
    super.key,
    required this.previousChips,
    required this.alternativeChips,
  });

  @override
  State<Week3VisualScreen> createState() => _Week3VisualScreenState();
}

class _Week3VisualScreenState extends State<Week3VisualScreen> {
  final List<String> chips = [];

  @override
  Widget build(BuildContext context) {
    final int maxLen =
        widget.previousChips.length > widget.alternativeChips.length
            ? widget.previousChips.length
            : widget.alternativeChips.length;

    List<TableRow> rows = List.generate(maxLen, (i) {
      final left =
          i < widget.previousChips.length ? widget.previousChips[i] : '';
      final right =
          i < widget.alternativeChips.length ? widget.alternativeChips[i] : '';
      return TableRow(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child:
                left.isNotEmpty
                    ? Card(
                      color: const Color(0xFFFFF1F1),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Text(
                          left,
                          style: const TextStyle(
                            color: Color(0xFFD32F2F),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child:
                right.isNotEmpty
                    ? Card(
                      color: const Color(0xFFE6F9ED),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Text(
                          right,
                          style: const TextStyle(
                            color: Color(0xFF388E3C),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      );
    });

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '3주차 - Self Talk'),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 상단 카드
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                    maxWidth: 500,
                  ),
                  child: Card(
                    color: const Color(0xFFF8FAFF),
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          // 상단 타이틀+아이콘
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                color: Colors.indigo,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Self Talk',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          // 헤더(고정)
                          Table(
                            columnWidths: const {
                              0: FlexColumnWidth(1),
                              1: FlexColumnWidth(1),
                            },
                            defaultVerticalAlignment:
                                TableCellVerticalAlignment.middle,
                            children: [
                              TableRow(
                                children: [
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: Text(
                                        '도움이 되지 않는 생각',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.redAccent[200],
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: Text(
                                        '도움이 되는 생각',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[400],
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Divider(height: 1, color: Colors.grey[300]),
                          // 내용(스크롤)
                          Expanded(
                            child: SingleChildScrollView(
                              child: Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(1),
                                  1: FlexColumnWidth(1),
                                },
                                defaultVerticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                children: rows, // rows는 List<TableRow>
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            NavigationButtons(
              onBack: () => Navigator.pop(context),
              onNext: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder:
                      (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text('수고하셨습니다!'),
                        content: const Text('오늘도 자기이해와 긍정적 자기대화를 실천했어요.'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(); // 다이얼로그 닫기
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                '/',
                                (route) => false,
                              ); // 홈으로 이동
                            },
                            child: const Text('확인'),
                          ),
                        ],
                      ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
