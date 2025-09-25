import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/data/education_model.dart';
import 'package:gad_app_team/utils/bold_text_parser.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';

class EducationPage extends StatefulWidget {
  final List<String> jsonPrefixes;
  final Widget Function()? nextPageBuilder;
  final String? title;

  const EducationPage({
    super.key,
    required this.jsonPrefixes,
    this.nextPageBuilder,
    this.title,
  });

  @override
  State<EducationPage> createState() => _EducationPageState();
}

class _EducationPageState extends State<EducationPage> {
  final PageController _pageController = PageController();
  List<EducationContent> contents = [];
  bool isLoading = true;
  int currentIndex = 0;

  int prefixIndex = 0;
  int partIndex = 1;
  bool hasNextPart = true;

  @override
  void initState() {
    super.initState();
    _loadEducationContent();
  }

  Future<void> _loadEducationContent() async {
    setState(() => isLoading = true);

    final prefix = widget.jsonPrefixes[prefixIndex];
    final path = "assets/education_data/$prefix$partIndex.json";
    final data = await EducationDataLoader.loadContents(path);

    final nextPath = "assets/education_data/$prefix${partIndex + 1}.json";
    final hasMoreInCurrentPrefix =
        await EducationDataLoader.fileExists(nextPath);

    setState(() {
      contents = data;
      isLoading = false;
      currentIndex = 0;
      hasNextPart = hasMoreInCurrentPrefix ||
          (prefixIndex < widget.jsonPrefixes.length - 1);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  Future<void> _loadNextPartOrPrefix() async {
    final prefix = widget.jsonPrefixes[prefixIndex];
    final nextPath = "assets/education_data/$prefix${partIndex + 1}.json";
    final hasMore = await EducationDataLoader.fileExists(nextPath);

    if (hasMore) {
      partIndex++;
    } else if (prefixIndex < widget.jsonPrefixes.length - 1) {
      prefixIndex++;
      partIndex = 1;
    } else {
      _showNextDialog();
      return;
    }

    await _loadEducationContent();
  }

  void _goToPreviousPart() {
    if (partIndex > 1) {
      partIndex--;
    } else if (prefixIndex > 0) {
      prefixIndex--;
      partIndex = 1;
    } else {
      return;
    }

    _loadEducationContent();
  }

  void _showNextDialog() {
    if (widget.nextPageBuilder == null) {
      _showCompleteDialog();
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('완료'),
          content: const Text('교육이 완료되었습니다. 다음 단계로 넘어가시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => widget.nextPageBuilder!()),
                );
              },
              child: const Text('다음'),
            ),
          ],
        ),
      );
    }
  }

  void _showCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('교육 완료'),
        content: const Text('교육이 완료되었습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = widget.title ?? '교육';

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: CustomAppBar(title: titleText),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => currentIndex = index),
                    itemCount: contents.length,
                    itemBuilder: (context, index) {
                      final content = contents[index];
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSizes.padding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              content.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSizes.space),
                            const SizedBox(height: AppSizes.space),
                            ...content.paragraphs.map(
                              (text) => Padding(
                                padding:
                                    const EdgeInsets.all(AppSizes.padding),
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: AppSizes.fontSize,
                                    ),
                                    children: parseBoldText(text),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: NavigationButtons(
          onBack: currentIndex == 0 &&
                  partIndex == 1 &&
                  prefixIndex == 0
              ? null
              : currentIndex == 0
                  ? _goToPreviousPart
                  : () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      ),
          onNext: currentIndex == contents.length - 1
              ? _loadNextPartOrPrefix
              : () => _pageController.nextPage(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  ),
        ),
      ),
    );
  }
}