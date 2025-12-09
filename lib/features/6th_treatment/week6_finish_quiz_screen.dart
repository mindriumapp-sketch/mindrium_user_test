import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

// 💙 공용 UI 위젯
import 'package:gad_app_team/widgets/quiz_card.dart';
import 'package:gad_app_team/widgets/jellyfish_notice.dart';
import 'package:gad_app_team/widgets/choice_card_button.dart';

// ✅ 시각화 화면
import 'week6_visual_screen.dart';

class Week6FinishQuizScreen extends StatefulWidget {
  /// [{behavior: ..., userChoice: ..., actualResult: ...}]
  final List<Map<String, dynamic>> mismatchedBehaviors;

  const Week6FinishQuizScreen({super.key, required this.mismatchedBehaviors});

  @override
  State<Week6FinishQuizScreen> createState() => _Week6FinishQuizScreenState();
}

class _Week6FinishQuizScreenState extends State<Week6FinishQuizScreen> {
  int _currentIdx = 0;
  // 인덱스별 사용자가 고른 답: 'face' | 'avoid'
  final Map<int, String> _answers = {};

  String? _diaryId; // 최신 일기 ID
  bool _isLoading = true;
  String? _error;

  List<String> _behaviorList = [];
  String _currentBehavior = '';
  late final ApiClient _client;
  late final DiariesApi _diariesApi;

  String _chipLabel(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map) {
      return (raw['label'] ??
              raw['chip_label'] ??
              raw['chipId'] ??
              raw['chip_id'] ??
              '')
          .toString()
          .trim();
    }
    return raw.toString().trim();
  }

  List<String> _chipList(dynamic raw) {
    if (raw is List) {
      return raw
          .map(_chipLabel)
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final s = _chipLabel(raw);
    return s
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _client = ApiClient(tokens: TokenStorage());
    _diariesApi = DiariesApi(_client);
    _fetchLatestDiary();
  }

  // 🔹 최신 일기에서 행동 리스트 만들기
  Future<void> _fetchLatestDiary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // 최신 일기 불러오기
      final latest = await _diariesApi.getLatestDiary();
      if (!mounted) return;

      final consequenceB =
          latest['consequence_action'] ??
              latest['consequence_behavior'] ??
              latest['consequence_b'];
      final behaviorList = _chipList(consequenceB);

      setState(() {
        _diaryId =
            (latest['diary_id'] ?? latest['diaryId'] ?? latest['id'])
                ?.toString();
        _behaviorList = behaviorList;
        _currentBehavior = _behaviorList.isNotEmpty ? _behaviorList.first : '';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '데이터를 불러오지 못했습니다.';
        _isLoading = false;
      });
    }
  }

  // 🔹 저장만 하는 함수로 변경 (네비게이션 X)
  Future<void> _saveBehaviorClassifications() async {
    if (_diaryId == null) {
      throw Exception('일기 ID가 없습니다.');
    }

    // confront_avoid_logs 형태로 변환
    final now = DateTime.now().toUtc().toIso8601String();
    final List<Map<String, dynamic>> logs = [];

    for (int i = 0; i < _behaviorList.length; i++) {
      if (_answers.containsKey(i)) {
        final behavior = _behaviorList[i];
        final type = _answers[i] == 'face' ? 'confronted' : 'avoided';
        logs.add({
          'type': type,
          'comment': behavior,
          'created_at': now,
        });
      }
    }

    // 일기 업데이트
    await _diariesApi.updateDiary(_diaryId!, {
      'confrontAvoidLogs': logs,
    });
  }

  bool get _hasBehavior => _currentBehavior.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    const double sidePadding = 20.0;
    final userName = Provider.of<UserProvider>(context, listen: false).userName;
    final bool hasBehavior = _hasBehavior;
    final bool isLast =
    hasBehavior ? _currentIdx == _behaviorList.length - 1 : true;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 🌊 배경 이미지 (Week3랑 동일 구조)
          Opacity(
            opacity: 0.35,
            child: Image.asset(
              'assets/image/eduhome.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              filterQuality: FilterQuality.high,
            ),
          ),

          // 실제 콘텐츠
          SafeArea(
            child: Column(
              children: [
                const CustomAppBar(title: '마무리 퀴즈'),

                // 위쪽 콘텐츠 영역
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: sidePadding,
                      vertical: 12,
                    ),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : (_error != null)
                        ? Center(
                      child: Text(
                        _error!,
                        style:
                        const TextStyle(color: Colors.redAccent),
                      ),
                    )
                        : (!hasBehavior)
                        ? const Center(
                      child: Text(
                        '최근에 작성한 일기가 없습니다.',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                        : Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),

                        // 🔹 문제 카드 (사용자 행동)
                        QuizCard(
                          noticeText: '$userName님이 작성한 행동',
                          quizText: _currentBehavior,
                          currentIndex: _currentIdx + 1,
                          totalCount: _behaviorList.length,
                        ),
                        const SizedBox(height: 15),

                        // 🔹 해파리 말풍선
                        JellyfishNotice(
                          feedback: _answers[_currentIdx] == null
                              ? '이 행동은 불안을 직면하는 쪽일까요, \n회피하는 쪽일까요?'
                              : _answers[_currentIdx] == 'face'
                              ? '불안을 직면하는 행동이라고 \n선택하셨습니다.'
                              : '불안을 회피하는 행동이라고 \n선택하셨습니다.',
                          feedbackColor:
                          _answers[_currentIdx] == null
                              ? Colors.indigo
                              : _answers[_currentIdx] ==
                              'face'
                              ? const Color(0xFF40C79A)
                              : const Color(0xFFEB6A67),
                        ),
                        const SizedBox(height: 20),

                        // 🔹 선택 버튼
                        Column(
                          children: [
                            ChoiceCardButton(
                              height: 54,
                              type: ChoiceType.healthy,
                              onPressed: () {
                                setState(() {
                                  _answers[_currentIdx] = 'face';
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            ChoiceCardButton(
                              height: 54,
                              type: ChoiceType.anxious,
                              onPressed: () {
                                setState(() {
                                  _answers[_currentIdx] = 'avoid';
                                });
                              },
                            ),
                          ],
                        ),

                        const Spacer(),
                      ],
                    ),
                  ),
                ),

                // 아래 네비게이션 (항상 바닥)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: NavigationButtons(
                    leftLabel: '이전',
                    rightLabel: '다음',
                    onBack: () {
                      if (_isLoading) return;
                      if (_error != null) {
                        Navigator.pop(context);
                        return;
                      }
                      if (!hasBehavior) {
                        Navigator.pop(context);
                        return;
                      }

                      if (_currentIdx > 0) {
                        setState(() {
                          _currentIdx--;
                          _currentBehavior = _behaviorList[_currentIdx];
                        });
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    onNext: (!_isLoading &&
                        _error == null &&
                        hasBehavior &&
                        _answers[_currentIdx] != null)
                        ? () async {
                      if (!isLast) {
                        // 다음 행동으로
                        setState(() {
                          _currentIdx++;
                          _currentBehavior =
                          _behaviorList[_currentIdx];
                        });
                      } else {
                        final navigator = Navigator.of(context);
                        // 🔥 마지막일 때만 저장하고 → 시각화 화면으로 이동
                        await _saveBehaviorClassifications();
                        if (!mounted) return;

                        // 시각화용 리스트 만들기
                        final List<String> avoidList = [];
                        final List<String> faceList = [];
                        for (int i = 0; i < _behaviorList.length; i++) {
                          final ans = _answers[i];
                          if (ans == 'avoid') {
                            avoidList.add(_behaviorList[i]);
                          } else if (ans == 'face') {
                            faceList.add(_behaviorList[i]);
                          }
                        }

                        if (!mounted) return;

                        navigator.push(
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) =>
                                Week6VisualScreen(
                                  previousChips: avoidList,
                                  alternativeChips: faceList,
                                ),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                          ),
                        );
                      }
                    }
                        : null,
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
