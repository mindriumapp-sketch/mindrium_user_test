import 'dart:async';
import 'package:gad_app_team/utils/text_line_material.dart';
// import 'package:gad_app_team/features/2nd_treatment/abc_input_screen.dart';
import 'package:gad_app_team/features/2nd_treatment/week2_screen.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_activate_screen.dart';
import 'package:gad_app_team/widgets/tutorial_design.dart';
import 'package:gad_app_team/widgets/blue_banner.dart';

class AbcGuideScreen extends StatefulWidget {
  final String? sessionId;
  const AbcGuideScreen({super.key, this.sessionId});

  @override
  State<AbcGuideScreen> createState() => _AbcGuideScreenState();
}

class _AbcGuideScreenState extends State<AbcGuideScreen> {
  bool _showJellyfishIcon = false; // 우상단 해파리 아이콘 노출 여부
  Timer? _jellyTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ✅ 화면 진입 시, 하얀 배너 + 해파리 4초 보여줌
      CustomBanner.show(context);

      // ✅ 4초 뒤부터 화면 우상단 해파리 아이콘 등장
      _startJellyTimer();
    });
  }

  void _startJellyTimer() {
    _jellyTimer?.cancel();
    _jellyTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _showJellyfishIcon = true;
      });
    });
  }

  @override
  void dispose() {
    // ✅ 화면 떠날 때: 타이머/배너 둘 다 정리
    _jellyTimer?.cancel();
    BlueBanner.hide();
    super.dispose();
  }

  void _goBack(BuildContext context) {
    BlueBanner.hide(); // 🔻 뒤로갈 때 배너 강제 제거
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Week2Screen(sessionId: widget.sessionId),
      ),
    );
  }

  void _goNext(BuildContext context) {
    BlueBanner.hide(); // 🔻 다음 화면 갈 때도 배너 강제 제거
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => AbcActivateScreen(sessionId: widget.sessionId),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1) 카드 포함 전체 화면
        ApplyDesign(
          appBarTitle: 'ABC 모델',
          cardTitle: 'ABC 모델이란?',
          onBack: () => _goBack(context),
          onNext: () => _goNext(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.psychology, size: 68, color: Color(0xFF3F51B5)),
              SizedBox(height: 24),
              Text(
                'ABC 모델은 인지행동치료(Cognitive Behavioral Therapy, CBT)에서 사용되는 대표적인 기법 중 하나로, '
                    '사람의 정서적 반응과 행동이 특정 사건 자체보다는 그 사건에 대한 생각(믿음)에 의해 결정된다는 개념을 바탕으로 합니다.\n\n'
                    '이 모델은 심리학자 앨버트 엘리스가 1950년대에 개발한 '
                    '합리적 정서행동치료(REBT)의 핵심 구성 요소로 소개되었습니다.\n\n'
                    '앞으로 걱정 일기를 매일 작성하면서, 인지행동치료(CBT)의 핵심 기법인 ABC 모델을 기반으로 기록할 것입니다.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: Colors.black87,
                  fontFamily: 'Noto Sans KR',
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 36),
            ],
          ),
        ),

        // 2) 카드 바깥 우상단 해파리 아이콘 (배너 다시 띄우기)
        if (_showJellyfishIcon)
          Positioned(
            top: 85,
            right: 40,
            child: GestureDetector(
              onTap: () {
                // 눌렀을 때 4초짜리 배너 다시 띄우기
                CustomBanner.show(context);
                // 아이콘은 계속 남아 있어도 됨 (원하면 다시 타이머 돌려서 잠깐 숨겼다 나와도 됨)
              },
              child: Image.asset(
                'assets/image/jellyfish_smart.png',
                width: 90,
                height: 90,
                fit: BoxFit.contain,
              ),
            ),
          ),
      ],
    );
  }
}

