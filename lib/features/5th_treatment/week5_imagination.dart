import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'week5_confront_anxiety.dart';

class Week5ImaginationScreen extends StatefulWidget {
  const Week5ImaginationScreen({super.key});

  @override
  State<Week5ImaginationScreen> createState() => _Week5ImaginationScreenState();
}

class _Week5ImaginationScreenState extends State<Week5ImaginationScreen> {
  final List<String> _chips = [];

  void _showInputDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      useSafeArea: false,
      barrierDismissible: true,
      builder:
          (_) => Dialog(
            backgroundColor: const Color(0xFFE8EAF6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
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
                    '불안하면 어떤 행동을 할까요?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.indigo,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.indigo.shade100),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 80,
                              maxWidth: 200,
                            ),
                            child: TextField(
                              controller: controller,
                              decoration: const InputDecoration(
                                hintText: '예: 자리를 피해버리기',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              autofocus: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '(이)라는',
                            style: TextStyle(color: Colors.black, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '행동을 할 것 같다고 상상했습니다.',
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                    ],
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
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('추가'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '5주차 - 불안 직면 VS 회피'),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 상단 카드
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Card(
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 8.0),
                        child: Text(
                          '불안 회피',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                          child: Image.asset(
                            'assets/image/imagination.png',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // 하단 카드 (새 구조)
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Card(
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          '불안하면 어떤 행동을 할까요?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFFF2F3F7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child:
                                _chips.isEmpty
                                    ? Center(
                                      child: Text(
                                        '여기에 입력한 내용이 표시됩니다',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 15,
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
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 10,
                                                        ),
                                                    margin:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFF6F8FF,
                                                      ),
                                                      border: Border.all(
                                                        color: const Color(
                                                          0xFFCED4DA,
                                                        ),
                                                        width: 1.2,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      text,
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF2962F6,
                                                        ),
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                      ),
                                    ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _showInputDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2962F6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '입력하기',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            NavigationButtons(
              onBack: () => Navigator.pop(context),
              onNext: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder:
                        (context, animation, secondaryAnimation) =>
                            Week5ConfrontAnxietyScreen(
                              previousChips: _chips,
                            ),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
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
