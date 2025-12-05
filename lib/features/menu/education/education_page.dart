// 🌊 Mindrium EducationPage — MemoSheet + CustomPopup + 하이라이트 + 슬라이드 평탄화
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/data/education_model.dart';
import 'package:gad_app_team/widgets/memo_sheet_design.dart';
import 'package:gad_app_team/widgets/custom_popup_design.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';

class EducationPage extends StatefulWidget {
  /// ex. ['week1_', 'week1b_']
  final List<String> jsonPrefixes;
  final Widget Function()? nextPageBuilder;
  final String? title;
  final bool isRelax;
  final String? imagePath;
  final String? sessionId;

  const EducationPage({
    super.key,
    required this.jsonPrefixes,
    this.nextPageBuilder,
    this.title,
    this.isRelax = false,
    this.imagePath,
    this.sessionId,
  });

  @override
  State<EducationPage> createState() => _EducationPageState();
}

/// 하나의 "슬라이드(페이지)" 단위 모델
class _Slide {
  final EducationContent content;
  final int prefixIndex; // jsonPrefixes 상 몇 번째 prefix인지
  final int partIndex;   // 해당 prefix 내 part 번호 (1,2,3...)
  final int pageInPart;  // 해당 part 내 페이지 번호 (1,2,3...)

  const _Slide({
    required this.content,
    required this.prefixIndex,
    required this.partIndex,
    required this.pageInPart,
  });
}

class _EducationPageState extends State<EducationPage> {
  final PageController _pageController = PageController();

  /// 모든 prefix/part/json을 평탄화한 슬라이드 리스트
  List<_Slide> _slides = [];

  bool isLoading = true;
  int currentIndex = 0;



  @override
  void initState() {
    super.initState();
    _preloadAllSlides();
  }

  /// ✅ 모든 prefix/part를 한 번에 로드해서 _slides에 평탄화
  Future<void> _preloadAllSlides() async {
    try {
      setState(() => isLoading = true);

      final List<_Slide> slides = [];

      for (int pIdx = 0; pIdx < widget.jsonPrefixes.length; pIdx++) {
        final prefix = widget.jsonPrefixes[pIdx]; // 예: 'week1_part1_'

        // 🔹 prefix에서 part 번호 추출 (없으면 pIdx+1로 fallback)
        final partMatch = RegExp(r'part(\d+)').firstMatch(prefix);
        final int partIndexFromName =
        partMatch != null ? int.parse(partMatch.group(1)!) : (pIdx + 1);

        int page = 1;
        while (true) {
          // 🔹 실제 파일명: assets/education_data/week1_part1_1.json
          final path = "assets/education_data/$prefix$page.json";

          final exists = await EducationDataLoader.fileExists(path);
          if (!exists) break;

          final data = await EducationDataLoader.loadContents(path);

          // 파일 하나에 페이지 여러 개 들어있어도 상관없게 loop
          for (final content in data) {
            slides.add(
              _Slide(
                content: content,
                prefixIndex: pIdx,
                partIndex: partIndexFromName, // 파일명 기준 part 번호
                pageInPart: page,
              ),
            );
          }

          page++;
        }
      }

      setState(() {
        _slides = slides;
        isLoading = false;
        currentIndex = 0;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients && _slides.isNotEmpty) {
          _pageController.jumpToPage(currentIndex);
        }
      });
    } catch (e) {
      debugPrint("❌ Error preloading education contents: $e");
      setState(() => isLoading = false);
    }
  }

  /// ✅ 현재 슬라이드 기준, 다음 행동 결정
  void _handleNext() {
    if (_slides.isEmpty) return;

    if (currentIndex >= _slides.length - 1) {
      _showNextDialog();
    } else {
      final nextIndex = currentIndex + 1;
      _pageController.jumpToPage(nextIndex);
      setState(() {
        currentIndex = nextIndex;
      });
    }
  }

  /// ✅ 현재 슬라이드 기준, 이전 행동 결정
  void _handleBack() {
    if (_slides.isEmpty) return;

    if (currentIndex == 0) {
      // 맨 처음 페이지면 아무것도 하지 않음 (필요시 Navigator.pop으로 교체 가능)
      return;
    } else {
      final prevIndex = currentIndex - 1;
      _pageController.jumpToPage(prevIndex);
      setState(() {
        currentIndex = prevIndex;
      });
    }
  }

  /// ✅ 다음 단계 다이얼로그 (완료 or Relax 시작 or 다음 위젯)
  void _showNextDialog() {
    if (widget.nextPageBuilder == null) {
      if (!widget.isRelax) {
        _showCompleteDialog();
      } else {
        _showStartDialog();
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => widget.nextPageBuilder!()),
      );
    }
  }

  /// 🪸 교육 완료 다이얼로그 — CustomPopupDesign
  void _showCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CustomPopupDesign(
        title: '교육 완료',
        message: '교육이 완료되었습니다.',
        positiveText: '닫기',
        negativeText: '취소',
        backgroundAsset: null,
        iconAsset: null,
        onNegativePressed: () => Navigator.pop(context),
        onPositivePressed: () {
          Navigator.popUntil(context, ModalRoute.withName('/education'));
        },
      ),
    );
  }

  /// 🧘 이완 교육 다이얼로그 — CustomPopupDesign(확인 단일 버튼)
  void _showStartDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CustomPopupDesign(
        title: '이완 음성 안내 시작',
        message:
        '잠시 후, 이완을 위한 음성 안내가 시작됩니다.\n주변 소리와 음량을 조절해보세요.',
        positiveText: '확인',
        negativeText: null,
        backgroundAsset: null,
        iconAsset: null,
        onPositivePressed: () async {
          // await EduProgress.markWeekDone(1);
          Navigator.pop(context);
          Navigator.pushReplacementNamed(
            context,
            '/relaxation_education',
            arguments: {
              'sessionId': widget.sessionId,
              'taskId': 'week1_education',
              'weekNumber': 1,
              'mp3Asset': 'week1.mp3',
              'riveAsset': 'week1.riv',
            },
          );
        },
      ),
    );
  }

  // ====== ⬇⬇⬇ 하이라이트 처리 유틸 ======
  /// 한 문단(문자열)에 줄바꿈이 포함돼 있으면 줄 단위로 RichText를 여러 개 렌더
  Widget _richParagraph(String text, TextStyle baseStyle) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          HighlightText(
            text: protectKoreanWords(line),
            style: baseStyle,
          ),
      ],
    );
  }

  /// 제목에도 동일한 하이라이트 규칙 적용
  Widget _richTitle(String text) {
    const titleStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: Color(0xFF232323),
      fontFamily: 'Noto Sans KR',
      height: 1.4,
    );
    return HighlightText(
      text: protectKoreanWords(text),
      style: titleStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    String titleText = widget.title ?? '불안에 대한 교육';
    if (_slides.isNotEmpty) {
      final slide = _slides[currentIndex];
      if (!widget.isRelax) {
        // ✅ 일반 교육 파트들
        final baseTitle = titleText;
        titleText = '$baseTitle (${slide.partIndex}/6)';
      } else {
        final prefix = _slides[currentIndex].content.title;
        if (prefix.contains('이완')) {
          titleText = '점진적 이완';
        }
      }
    }

    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_slides.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(
          child: Text(
            '교육 데이터를 찾을 수 없습니다.',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Noto Sans KR',
            ),
          ),
        ),
      );
    }

    return MemoFullDesign(
      appBarTitle: titleText,
      onBack: currentIndex == 0 ? () {} : _handleBack,
      onNext: _handleNext,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: PageView.builder(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) {
            setState(() => currentIndex = index);
          },
          itemCount: _slides.length,
          itemBuilder: (context, index) {
            final content = _slides[index].content;
            const bodyStyle = TextStyle(
              color: Color(0xFF232323),
              fontSize: 14,
              fontFamily: 'Noto Sans KR',
              height: 1.4,
              letterSpacing: 0.2,
            );

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _richTitle(content.title),
                  const SizedBox(height: 16),

                  // 문단들
                  for (final paragraph in content.paragraphs)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _richParagraph(paragraph, bodyStyle),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
