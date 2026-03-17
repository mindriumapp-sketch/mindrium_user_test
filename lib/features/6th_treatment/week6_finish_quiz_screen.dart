import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/custom_tags_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:dio/dio.dart';

// 💙 공용 UI 위젯
import 'package:gad_app_team/widgets/quiz_card.dart';
import 'package:gad_app_team/widgets/jellyfish_notice.dart';

// ✅ 시각화 화면
import 'week6_diary_utils.dart';
import 'week6_flow_widgets.dart';
import 'week6_route_utils.dart';
import 'week6_visual_screen.dart';

class Week6FinishQuizScreen extends StatefulWidget {
  /// [{behavior: ..., userChoice: ..., actualResult: ...}]
  final List<Map<String, dynamic>> mismatchedBehaviors;
  final String diaryId;
  final Map<String, dynamic> diary;

  const Week6FinishQuizScreen({
    super.key,
    required this.mismatchedBehaviors,
    required this.diaryId,
    required this.diary,
  });

  @override
  State<Week6FinishQuizScreen> createState() => _Week6FinishQuizScreenState();
}

class _Week6FinishQuizScreenState extends State<Week6FinishQuizScreen> {
  int _currentIdx = 0;
  // 인덱스별 사용자가 고른 답: 'face' | 'avoid'
  final Map<int, String> _answers = {};

  String? _diaryId;
  bool _isLoading = true;
  String? _error;

  List<String> _behaviorList = [];
  List<String?> _behaviorChipIds = [];
  String _currentBehavior = '';
  late final ApiClient _client;
  late final CustomTagsApi _customTagsApi;

  @override
  void initState() {
    super.initState();
    _client = ApiClient(tokens: TokenStorage());
    _customTagsApi = CustomTagsApi(_client);
    _initializeDiary();
  }

  void _initializeDiary() {
    final behaviorEntries = Week6DiaryUtils.extractBehaviorEntries(
      widget.diary,
    );
    final behaviorList = behaviorEntries.map((entry) => entry.label).toList();
    final chipIds = behaviorEntries.map((entry) => entry.chipId).toList();

    _diaryId = widget.diaryId.trim().isEmpty ? null : widget.diaryId.trim();
    _behaviorList = behaviorList;
    _behaviorChipIds = chipIds;
    _currentBehavior = _behaviorList.isNotEmpty ? _behaviorList.first : '';
    _error = _diaryId == null ? '선택한 일기 정보를 불러오지 못했습니다.' : null;
    _isLoading = false;
  }

  // 🔹 저장만 하는 함수로 변경 (네비게이션 X)
  Future<void> _saveBehaviorClassifications() async {
    if (_diaryId == null) {
      throw Exception('일기 ID가 없습니다.');
    }

    final answeredIndexes = _answers.keys.toList()..sort();
    if (answeredIndexes.isEmpty) return;

    final now = DateTime.now().toUtc();

    // chip_id 캐시 (일기 → 커스텀 태그)
    final Map<String, String> labelToChipId = {};
    for (int i = 0; i < _behaviorList.length; i++) {
      final chipId = i < _behaviorChipIds.length ? _behaviorChipIds[i] : null;
      final label = _behaviorList[i];
      if (chipId != null && chipId.isNotEmpty && label.isNotEmpty) {
        labelToChipId[label] = chipId;
      }
    }

    // 기존 CA 태그 조회 (중복 생성 방지)
    try {
      final tags = await _customTagsApi.listCustomTags(chipType: 'CA');
      for (final tag in tags) {
        final label = (tag['text'] ?? tag['label'])?.toString().trim();
        final chipId = tag['chip_id']?.toString();
        if (label != null &&
            label.isNotEmpty &&
            chipId != null &&
            chipId.isNotEmpty) {
          labelToChipId.putIfAbsent(label, () => chipId);
        }
      }
    } catch (e) {
      debugPrint('⚠️ 커스텀 태그 조회 실패: $e');
    }

    for (final idx in answeredIndexes) {
      if (idx < 0 || idx >= _behaviorList.length) continue;
      final answer = _answers[idx];
      final behavior = _behaviorList[idx];
      if (answer == null || behavior.isEmpty) continue;

      final shortTerm = answer == 'face' ? 'confront' : 'avoid';
      final category = answer == 'face' ? 'healthy' : 'anxious';

      String? chipId = labelToChipId[behavior];

      if (chipId == null || chipId.isEmpty) {
        try {
          final created = await _customTagsApi.createCustomTag(
            label: behavior,
            type: 'CA',
          );
          chipId = (created['chip_id'] ?? created['_id'])?.toString();
          if (chipId != null && chipId.isNotEmpty) {
            labelToChipId[behavior] = chipId;
          }
        } catch (e) {
          debugPrint('⚠️ 칩 생성 실패 ($behavior): $e');
          continue;
        }
      }

      if (chipId == null || chipId.isEmpty) continue;

      try {
        await _customTagsApi.createCategoryLog(
          chipId: chipId,
          diaryId: _diaryId!.toString(),
          category: category,
          shortTerm: shortTerm,
          longTerm: shortTerm,
          completedAt: now,
        );
      } on DioException catch (e) {
        debugPrint(
          '⚠️ 분류 로그 저장 실패 ($behavior): '
          '${e.response?.data ?? e.message}',
        );
      } catch (e) {
        debugPrint('⚠️ 분류 로그 저장 실패 ($behavior): $e');
      }
    }
  }

  bool get _hasBehavior => _currentBehavior.isNotEmpty;

  String? get _selectedType => _answers[_currentIdx];

  void _selectAnswer(String answer) {
    setState(() {
      _answers[_currentIdx] = answer;
    });
  }

  void _moveToPreviousBehavior() {
    setState(() {
      _currentIdx--;
      _currentBehavior = _behaviorList[_currentIdx];
    });
  }

  void _moveToNextBehavior() {
    setState(() {
      _currentIdx++;
      _currentBehavior = _behaviorList[_currentIdx];
    });
  }

  ({List<String> avoidList, List<String> faceList}) _buildVisualLists() {
    final avoidList = <String>[];
    final faceList = <String>[];

    for (int i = 0; i < _behaviorList.length; i++) {
      final answer = _answers[i];
      if (answer == 'avoid') {
        avoidList.add(_behaviorList[i]);
      } else if (answer == 'face') {
        faceList.add(_behaviorList[i]);
      }
    }

    return (avoidList: avoidList, faceList: faceList);
  }

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
                    child:
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : (_error != null)
                            ? Center(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.redAccent),
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
                              crossAxisAlignment: CrossAxisAlignment.center,
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
                                  feedback: '이 행동은 불안을 직면하는 쪽일까요, \n회피하는 쪽일까요?',
                                  feedbackColor: Colors.indigo,
                                ),
                                const SizedBox(height: 20),

                                // 🔹 선택 버튼
                                Week6BehaviorTypeSelector(
                                  selectedType: _selectedType,
                                  onSelected: _selectAnswer,
                                ),

                                const Spacer(),
                              ],
                            ),
                  ),
                ),

                // 아래 네비게이션 (항상 바닥)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
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
                        _moveToPreviousBehavior();
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    onNext:
                        (!_isLoading &&
                                _error == null &&
                                hasBehavior &&
                                _answers[_currentIdx] != null)
                            ? () async {
                              if (!isLast) {
                                _moveToNextBehavior();
                              } else {
                                final navigator = Navigator.of(context);
                                // 🔥 마지막일 때만 저장하고 → 시각화 화면으로 이동
                                await _saveBehaviorClassifications();
                                if (!mounted) return;

                                final lists = _buildVisualLists();

                                if (!mounted) return;

                                navigator.push(
                                  buildWeek6NoAnimationRoute(
                                    Week6VisualScreen(
                                      previousChips: lists.avoidList,
                                      alternativeChips: lists.faceList,
                                    ),
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
