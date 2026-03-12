import 'package:flutter/material.dart';

class HomeWidgetTutorialStep {
  const HomeWidgetTutorialStep({
    required this.imageAsset,
    required this.title,
    required this.description,
  });

  final String imageAsset;
  final String title;
  final String description;
}

class HomeWidgetTutorialDialog extends StatefulWidget {
  const HomeWidgetTutorialDialog({super.key, required this.steps})
    : assert(steps.length > 0, 'steps must not be empty');

  final List<HomeWidgetTutorialStep> steps;

  static const String _title = '홈 위젯 사용 가이드';
  static const Color _primaryColor = Color(0xFF2F8FD8);
  static const Color _titleColor = Color(0xFF1B3A57);
  static const Color _inactiveDotColor = Color(0xFFC9D8E6);

  static Future<void> show(
    BuildContext context, {
    required List<HomeWidgetTutorialStep> steps,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HomeWidgetTutorialDialog(steps: steps),
    );
  }

  @override
  State<HomeWidgetTutorialDialog> createState() =>
      _HomeWidgetTutorialDialogState();
}

class _HomeWidgetTutorialDialogState extends State<HomeWidgetTutorialDialog> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == widget.steps.length - 1;
    final currentStep = widget.steps[_currentPage];
    final maxImageHeight = MediaQuery.sizeOf(context).height * 0.5;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              HomeWidgetTutorialDialog._title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: HomeWidgetTutorialDialog._titleColor,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxImageHeight),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.steps.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    final step = widget.steps[index];
                    return Container(
                      color: const Color(0xFFF7FAFF),
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        step.imageAsset,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              currentStep.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: HomeWidgetTutorialDialog._titleColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              currentStep.description,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.steps.length, (index) {
                final selected = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: selected ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color:
                        selected
                            ? HomeWidgetTutorialDialog._primaryColor
                            : HomeWidgetTutorialDialog._inactiveDotColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    if (isLastPage) {
                      Navigator.pop(context);
                      return;
                    }
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeInOut,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HomeWidgetTutorialDialog._primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isLastPage ? '완료' : '다음'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
