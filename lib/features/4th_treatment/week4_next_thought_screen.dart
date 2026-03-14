// lib/features/4th_treatment/week4_next_thought_screen.dart
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:provider/provider.dart';

import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/features/4th_treatment/week4_classfication_screen.dart';
import 'package:gad_app_team/features/4th_treatment/week4_flow_prompt_widgets.dart';

// ✅ ApplyDesign (배경 + AppBar + BlueWhiteCard + 하단 네비 버튼)
import 'package:gad_app_team/widgets/tutorial_design.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/api/custom_tags_api.dart';

class Week4NextThoughtScreen extends StatefulWidget {
  final List<String> remainingBList;
  final List<String> allBList;
  final List<String>? alternativeThoughts;
  final bool isFromAnxietyScreen;
  final List<String> addedAnxietyThoughts;
  final List<String>? existingAlternativeThoughts;
  final String? abcId;
  final int loopCount;

  const Week4NextThoughtScreen({
    super.key,
    required this.remainingBList,
    required this.allBList,
    this.alternativeThoughts,
    this.isFromAnxietyScreen = false,
    this.addedAnxietyThoughts = const [],
    this.existingAlternativeThoughts,
    this.abcId,
    this.loopCount = 1,
  });

  @override
  State<Week4NextThoughtScreen> createState() => _Week4NextThoughtScreenState();
}

class _Week4NextThoughtScreenState extends State<Week4NextThoughtScreen> {
  bool _isNextEnabled = false;
  int _secondsLeft = 5;
  bool _showSituation = true; // 상황 안내 먼저, 이후 보라 안내
  String? _activatingEvent;
  bool _isLoading = true;
  late final ApiClient _client;
  late final DiariesApi _diariesApi;
  late final CustomTagsApi _customTagsApi;

  @override
  void initState() {
    super.initState();
    _client = ApiClient(tokens: TokenStorage());
    _diariesApi = DiariesApi(_client);
    _customTagsApi = CustomTagsApi(_client);
    _startCountdown();
    _fetchActivatingEvent();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      if (_secondsLeft > 0) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return false;
        setState(() {
          _secondsLeft--;
        });
        return true;
      } else {
        setState(() {
          _isNextEnabled = true;
        });
        return false;
      }
    });
  }

  Future<void> _fetchActivatingEvent() async {
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic>? diary;
      if (widget.abcId != null && widget.abcId!.isNotEmpty) {
        diary = await _diariesApi.getDiary(widget.abcId!);
      } else {
        final list = await _diariesApi.listDiaries();
        if (list.isNotEmpty) diary = list.first;
      }
      if (!mounted) return;
      setState(() {
        _activatingEvent =
            (diary?['activating_events'] ?? diary?['activatingEvent'])
                ?.toString();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<UserProvider>(context, listen: false).userName;
    final nextThought =
        widget.remainingBList.isNotEmpty ? widget.remainingBList.first : '';
    final situationText =
        (_activatingEvent != null && _activatingEvent!.isNotEmpty)
            ? '$_activatingEvent 상황'
            : '이때의 상황을 떠올려보세요.';
    final remainingCount = widget.remainingBList.length;

    // === 카드 안에 들어갈 본문 위젯 ===
    final Widget body = Week4FlowPromptBody(
      title: _showSituation ? '같은 상황을 한 번 더 떠올려볼게요' : '다음 생각으로 이어가볼게요',
      subtitle:
          _showSituation
              ? '$userName님이 적어주신 같은 상황 안에서, 이어지는 다른 생각도 차례대로 살펴볼 거예요.'
              : '같은 상황에서 떠오른 또 다른 생각을 살펴보고 도움이 되는 생각을 계속 찾아볼게요.',
      situationText: situationText,
      thoughtText: _showSituation ? null : nextThought,
      footerText:
          _showSituation
              ? '상황이 선명하지 않아도 괜찮아요. 떠오르는 만큼만 천천히 머물러보세요.'
              : '준비가 되면 다음 버튼을 눌러 이 생각도 차근차근 살펴보세요.',
      badgeText: remainingCount > 0 ? '남은 생각 $remainingCount개' : null,
      isLoading: _isLoading,
      secondsLeft: _isNextEnabled ? null : _secondsLeft,
      waitingText: '$_secondsLeft초 후에 다음으로 넘어갈 수 있어요',
    );

    // === ApplyDesign 사용: 배경/앱바/중앙 BlueWhiteCard/하단 네비 버튼 ===
    return ApplyDesign(
      appBarTitle: '인지 왜곡 찾기',
      cardTitle: '그때 상황 다시 떠올리기',
      onBack: () => Navigator.pop(context),
      onNext:
          _isNextEnabled
              ? () async {
                if (_showSituation) {
                  setState(() => _showSituation = false);
                  return;
                }
                final navigator = Navigator.of(context);
                // 1) 새로 입력한 불안 생각을 일기 belief에 누적 + 커스텀 태그 저장
                try {
                  final newThoughts =
                      widget.isFromAnxietyScreen
                          ? widget.addedAnxietyThoughts
                          : <String>[];
                  if (newThoughts.isNotEmpty) {
                    final id = widget.abcId;
                    // diaryId가 없으면 최신으로 보정
                    final diary =
                        (id != null && id.isNotEmpty)
                            ? await _diariesApi.getDiary(id)
                            : await _diariesApi.getLatestDiary();
                    final diaryId = diary['diaryId']?.toString();
                    if (diaryId != null && diaryId.isNotEmpty) {
                      final List<String> existingBelief =
                          [
                                ...((diary['belief'] is List)
                                    ? (diary['belief'] as List).map(
                                      (e) => e.toString(),
                                    )
                                    : diary['belief']?.toString().split(',') ??
                                        <String>[]),
                              ]
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList();
                      final toAdd =
                          newThoughts
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList();
                      final merged =
                          <String>{...existingBelief, ...toAdd}.toList();
                      await _diariesApi.updateDiary(diaryId, {
                        'belief': merged,
                      });
                      // 커스텀 태그(B)로도 저장
                      for (final t in toAdd) {
                        await _customTagsApi.createCustomTag(
                          label: t,
                          type: 'B',
                        );
                      }
                    }
                  }
                } catch (_) {}

                // 2) 다음 화면 이동
                if (!mounted) return;
                navigator.push(
                  PageRouteBuilder(
                    pageBuilder:
                        (_, __, ___) => Week4ClassificationScreen(
                          bListInput:
                              widget.isFromAnxietyScreen
                                  ? widget.addedAnxietyThoughts
                                  : widget.remainingBList,
                          allBList: widget.allBList,
                          alternativeThoughts: widget.alternativeThoughts,
                          isFromAnxietyScreen: widget.isFromAnxietyScreen,
                          existingAlternativeThoughts:
                              widget.existingAlternativeThoughts,
                          abcId: widget.abcId,
                          loopCount: widget.loopCount,
                        ),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              }
              : null,
      child: body, // 비활성화 상태면 null 전달 → NavigationButtons에서 비활성 처리
    );
  }
}
