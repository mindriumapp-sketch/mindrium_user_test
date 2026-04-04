import 'dart:async';
import 'dart:math';

import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/worry_groups_api.dart';
import 'package:gad_app_team/features/menu/archive/character_battle_asr.dart';
import 'package:gad_app_team/utils/text_line_material.dart';

const _defaultCharacterId = 1;
const _maxBattleHits = 3;
const _voiceMatchThreshold = 0.3;

const _battleSceneBackgroundAsset = 'assets/image/battle_scene_bg.png';
const _playerCharacterAsset = 'assets/image/men.png';

const _contentTopOffset = 52.0;
const _bottomBarBottomSpacing = 20.0;
const _micSpacingAboveBottomBar = 28.0;
const _contentLift = 50.0;
const _playerCharacterHeight = 220.0;
const _targetCharacterHeight = 160.0;
const _skillChipSpacing = 8.0;

const _attackWindUpDuration = Duration(milliseconds: 1200);
const _enemyDefeatRevealDelay = Duration(milliseconds: 800);
const _userBubbleHideDelay = Duration(milliseconds: 600);
const _emotionChangeDelay = Duration(milliseconds: 400);
const _voiceListenFor = Duration(seconds: 30);
const _voicePauseFor = Duration(seconds: 5);

class _BattleData {
  const _BattleData({
    required this.characterName,
    required this.characterId,
    required this.emotions,
    required this.skills,
  });

  final String characterName;
  final int? characterId;
  final List<String> emotions;
  final List<String> skills;

  int get requiredHits =>
      skills.isEmpty ? 1 : min(_maxBattleHits, skills.length);
}

class PokemonBattleDeletePage extends StatefulWidget {
  final String groupId;
  final String? characterName;
  final String? characterDescription;

  const PokemonBattleDeletePage({
    super.key,
    required this.groupId,
    this.characterName,
    this.characterDescription,
  });

  @override
  State<PokemonBattleDeletePage> createState() =>
      _PokemonBattleDeletePageState();
}

class _PokemonBattleDeletePageState extends State<PokemonBattleDeletePage>
    with TickerProviderStateMixin {
  // ========== API 클라이언트 ==========
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final WorryGroupsApi _worryGroupsApi = WorryGroupsApi(_apiClient);

  // ========== 데이터 ==========
  List<String> _skillsList = [];
  List<String> _characterEmotions = [];
  bool _isLoading = true;
  bool _isDefeated = false;

  String? _characterName;
  int? _characterId;

  // ========== HP ==========
  int _maxHp = 0;
  int _targetHp = 0;

  // ========== 상태 ==========
  bool _isAttacking = false;
  String? _selectedSkill;
  final Set<int> _shrunkChips = {};

  // ========== 애니메이션 ==========
  late final AnimationController _shakeController;

  // ========== 음성인식 ==========
  late final CharacterBattleAsr _voice;
  bool _listening = false;

  // ========== 말풍선 ==========
  int _currentEmotionIndex = 0;
  bool _isBubbleVisible = true;
  String? _bubbleText;

  String? _userBubbleText;
  bool _isUserBubbleVisible = false;

  bool get _isBattleLocked => _isAttacking || _isDefeated;

  int? get _selectedSkillIndex {
    final selectedSkill = _selectedSkill;
    if (selectedSkill == null) return null;

    final index = _skillsList.indexOf(selectedSkill);
    if (index < 0 || _shrunkChips.contains(index)) {
      return null;
    }
    return index;
  }

  String get _battleInstructionText =>
      '도움이 되는 생각을 하나씩 선택 후 말해보세요!  (${_shrunkChips.length}/$_maxHp)';

  String get _currentEmotionText {
    if (_characterEmotions.isEmpty) return '';
    return _bubbleText ?? _characterEmotions[_currentEmotionIndex];
  }

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: -4,
      upperBound: 4,
    )..addStatusListener((s) {
      if (s == AnimationStatus.completed) _shakeController.reverse();
    });

    _voice = CharacterBattleAsr();
    // iOS에서 화면 진입 시 즉시 STT 초기화가 앱 종료로 이어지는 경우가 있어
    // 마이크 버튼을 눌렀을 때만 초기화하도록 지연한다.
    _loadData();
    _startEmotionCycle();
  }

  @override
  void dispose() {
    _voice.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // ========== 초기화 ==========

  Future<void> _initializeVoice() async {
    debugPrint('🎤 [음성인식] 초기화 시작');

    final success = await _voice.initialize(
      onStatus: (status) {
        if (status == 'listening') {
          _setListeningState(true);
        } else if (status == 'notListening') {
          _setListeningState(false);
        }
      },
      onError: (error) {
        _setListeningState(false);
        debugPrint('❌ [음성인식 에러] $error');
      },
    );

    if (success) {
      debugPrint('✅ [음성인식] 초기화 성공');
    } else {
      debugPrint('❌ [음성인식] 초기화 실패');
    }
  }

  // ========== 데이터 로드 (통합) ==========

  Future<void> _loadData() async {
    try {
      final battleData = await _fetchBattleData();
      if (!mounted) return;

      setState(() {
        _characterName = battleData.characterName;
        _characterId = battleData.characterId;
        _characterEmotions =
            battleData.emotions.isNotEmpty
                ? battleData.emotions
                : ['감정 데이터가 없습니다'];
        _currentEmotionIndex = 0;
        _skillsList =
            battleData.skills.isNotEmpty ? battleData.skills : ['대체 생각이 없습니다'];
        _maxHp = battleData.requiredHits;
        _targetHp = battleData.requiredHits;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ 데이터 로드 실패: $e');
      if (!mounted) return;
      setState(() {
        _characterEmotions = ['데이터를 불러오지 못했습니다'];
        _skillsList = ['데이터를 불러오지 못했습니다'];
        _maxHp = 1;
        _targetHp = 1;
        _isLoading = false;
      });
    }
  }

  Future<_BattleData> _fetchBattleData() async {
    debugPrint('🔍 [데이터 로드 시작] group_id: ${widget.groupId}');

    final groupData = await _worryGroupsApi.getWorryGroup(widget.groupId);
    final characterName = groupData['group_title']?.toString() ?? '이름 없음';
    final characterId = groupData['character_id'] as int?;

    debugPrint('🎨 [캐릭터 정보] name: $characterName, id: $characterId');

    final response = await _apiClient.dio.get(
      '/diaries',
      queryParameters: {
        'group_id': widget.groupId,
        'include_drafts': true,
        'include_auto': true,
      },
    );

    final diaryEntries = response.data;
    debugPrint('📦 [일기 응답]: $diaryEntries');

    final emotions = <String>[];
    final skills = <String>[];

    if (diaryEntries is List) {
      for (final entry in diaryEntries.whereType<Map>()) {
        emotions.addAll(_extractBeliefLabels(entry));
        skills.addAll(_extractAlternativeThoughts(entry));
      }
    }

    if (emotions.isNotEmpty) {
      emotions.shuffle();
    }

    debugPrint('🎯 [최종 감정 목록]: $emotions');
    debugPrint('🎯 [최종 스킬 목록(전투용)]: $skills');
    debugPrint(
      '📊 [전투 데이터] diaries=${diaryEntries is List ? diaryEntries.length : 0}, thoughts=${skills.length}',
    );

    return _BattleData(
      characterName: characterName,
      characterId: characterId,
      emotions: emotions,
      skills: List<String>.from(skills),
    );
  }

  List<String> _extractBeliefLabels(Map diaryEntry) {
    final beliefData = diaryEntry['belief'];
    if (beliefData is! List) return const [];

    final labels = <String>[];
    for (final belief in beliefData.whereType<Map>()) {
      final labelText = _readTrimmedText(belief['label']);
      if (labelText != null) {
        labels.add(labelText);
      }
    }
    return labels;
  }

  List<String> _extractAlternativeThoughts(Map diaryEntry) {
    final altThoughts = diaryEntry['alternative_thoughts'];
    if (altThoughts is! List) return const [];

    final skills = <String>[];
    for (final alt in altThoughts) {
      if (alt is String) {
        final text = _readTrimmedText(alt);
        if (text != null) {
          skills.add(text);
        }
        continue;
      }

      if (alt is Map) {
        final text = _readTrimmedText(
          alt['label'] ??
              alt['text'] ??
              alt['value'] ??
              alt['content'] ??
              alt['thought'],
        );
        if (text != null) {
          skills.add(text);
        }
      }
    }
    return skills;
  }

  String? _readTrimmedText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  // ========== 공격 로직 ==========

  Future<void> _handleAttack() async {
    final selectedSkill = _selectedSkill;
    if (selectedSkill == null || _isBattleLocked) return;

    final skillIndex = _selectedSkillIndex;
    if (skillIndex == null) {
      debugPrint('❌ 이미 사용된 스킬');
      return;
    }

    debugPrint('⚔️ [공격 버튼] 선택된 스킬: $selectedSkill');

    _startAttack(selectedSkill);

    await Future.delayed(_attackWindUpDuration);
    if (!mounted) return;

    final isDefeated = _applyAttackDamage(skillIndex);

    _shakeController.forward(from: 0);

    if (isDefeated) {
      await _finishBattle();
      return;
    }

    await _prepareNextTurn();
  }

  void _startAttack(String skill) {
    setState(() {
      _isAttacking = true;
      _userBubbleText = skill;
      _isUserBubbleVisible = true;
    });
  }

  bool _applyAttackDamage(int skillIndex) {
    final nextHp = max(0, _targetHp - 1);

    setState(() {
      _shrunkChips.add(skillIndex);
      _targetHp = nextHp;
      _selectedSkill = null;
    });

    return nextHp <= 0;
  }

  Future<void> _finishBattle() async {
    await Future.delayed(_enemyDefeatRevealDelay);
    if (!mounted) return;

    setState(() {
      _isDefeated = true;
      _isAttacking = false;
      _bubbleText = '으악..!';
    });

    await Future.delayed(const Duration(seconds: 2));
    await _archiveGroup();

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _prepareNextTurn() async {
    await Future.delayed(_userBubbleHideDelay);
    if (!mounted) return;
    setState(() => _isUserBubbleVisible = false);

    await Future.delayed(_emotionChangeDelay);
    if (!mounted) return;
    setState(() {
      _advanceEmotion();
      _isAttacking = false;
    });
  }

  void _advanceEmotion() {
    if (_characterEmotions.isEmpty) return;
    _currentEmotionIndex =
        (_currentEmotionIndex + 1) % _characterEmotions.length;
  }

  // ========== 음성인식 ==========

  Future<void> _onMicPressed() async {
    debugPrint('🎤 [마이크 클릭]');

    if (_isBattleLocked) {
      debugPrint('⚠️ [공격 중 또는 패배] 마이크 입력 무시');
      return;
    }
    if (_selectedSkill == null) {
      _showToast('먼저 아래 대체 생각을 선택해주세요');
      return;
    }

    final isReady = await _ensureVoiceReady();
    if (!isReady) {
      return;
    }

    _setListeningState(true);

    final listenStartedAt = DateTime.now();
    debugPrint('🎤 [음성인식 시작] ${listenStartedAt.toIso8601String()}');

    try {
      final success = await _voice.startListening(
        localeId: 'ko_KR',
        listenFor: _voiceListenFor,
        pauseFor: _voicePauseFor,
        onPartial: (_) {},
        onFinal: (recognizedText) async {
          if (!mounted) return;
          _setListeningState(false);

          final trimmed = recognizedText.trim();
          if (trimmed.isNotEmpty) {
            _showToast('인식 완료: $trimmed');
            await _handleVoiceChoice(trimmed);
          } else {
            _showToast('음성이 인식되지 않았습니다');
          }
        },
      );

      if (!success) {
        _setListeningState(false);
        _showErrorDialog();
      }
    } catch (e) {
      debugPrint('❌ [예외] $e');
      _setListeningState(false);
      _showErrorDialog();
    }
  }

  Future<bool> _ensureVoiceReady() async {
    if (_voice.isReady) return true;

    debugPrint('❌ [준비 안됨] 재초기화 시도');
    await _initializeVoice();

    if (_voice.isReady) return true;

    _showErrorDialog();
    return false;
  }

  Future<void> _handleVoiceChoice(String utter) async {
    final text = utter.trim();
    if (text.isEmpty || _skillsList.isEmpty) return;
    if (_isBattleLocked) return;
    if (_selectedSkill == null) {
      _showToast('먼저 대체 생각을 선택해주세요');
      return;
    }

    final selectedIndex = _selectedSkillIndex;
    if (selectedIndex == null) {
      _showToast('다른 대체 생각을 선택해주세요');
      return;
    }

    final chosen = _skillsList[selectedIndex];
    final score = CharacterBattleAsr.similarity(
      text.toLowerCase(),
      chosen.toLowerCase(),
    );

    if (score < _voiceMatchThreshold) {
      debugPrint('❌ [낮은 유사도] $score');
      _showVoiceMismatchSnackBar(chosen);
      return;
    }

    debugPrint('✅ [선택] "$text" → "$chosen" ($score)');

    // 스킬만 선택하고, 실제 공격은 공통 플로우 사용
    if (!mounted) return;
    setState(() {
      _selectedSkill = chosen;
    });

    // 음성으로 선택한 경우 자동 공격 실행
    await _handleAttack();
  }

  // ========== UI 헬퍼 ==========

  void _showToast(String msg) {
    if (!mounted || msg.trim().isEmpty) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, maxLines: 2),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
        backgroundColor: Colors.black.withValues(alpha: 0.85),
      ),
    );
  }

  void _showVoiceMismatchSnackBar(String selectedSkill) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ 선택한 생각 "$selectedSkill"과(와) 다르게 인식됐어요'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
      ),
    );
  }

  void _setListeningState(bool value) {
    if (!mounted) return;
    setState(() => _listening = value);
  }

  void _showErrorDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('음성인식 오류'),
            content: const Text(
              '음성인식을 사용할 수 없습니다.\n\n'
              '1. 마이크 권한 확인\n'
              '2. 네트워크 연결 확인\n'
              '3. 실기기에서 테스트\n\n'
              '⚠️ 에뮬레이터는 지원되지 않습니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
    );
  }

  void _startEmotionCycle() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) break;

      setState(() => _isBubbleVisible = false);

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) break;

      setState(() {
        _advanceEmotion();
        _isBubbleVisible = true;
      });
    }
  }

  // ========== UI 빌드 ==========

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.tealAccent),
        ),
      );
    }

    final mediaQuery = MediaQuery.of(context);
    final topInset = mediaQuery.padding.top;
    final safeBottom = mediaQuery.padding.bottom;
    final contentTop = _contentTopOffset - _contentLift;
    final bottomBarBottom = safeBottom + _bottomBarBottomSpacing + _contentLift;
    final micBottom =
        safeBottom +
        _bottomBarBottomSpacing +
        _playerCharacterHeight +
        _micSpacingAboveBottomBar;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(_battleSceneBackgroundAsset, fit: BoxFit.cover),
          ),
          _buildBackButton(topInset),
          _buildHpPanel(contentTop),
          _buildCharacters(contentTop),
          _buildPlayerAndBottomBar(bottomBarBottom),
          _buildMicButton(micBottom),
          if (_isDefeated)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.92),
                child: _buildVictoryScene(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBackButton(double topInset) {
    return Positioned(
      top: topInset + 6,
      left: 10,
      child: Material(
        color: Colors.white.withValues(alpha: 0.75),
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: Colors.black87,
          iconSize: 20,
          tooltip: '뒤로가기',
        ),
      ),
    );
  }

  Widget _buildHpPanel(double contentTopOffset) {
    return Positioned(
      top: 140 + contentTopOffset,
      right: 220,
      child: Container(
        width: 160,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _characterName ?? '불안한 캐릭터',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            _buildHpBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHpBar() {
    final segments = max(1, _maxHp);
    final hpRatio = (_targetHp / segments).clamp(0.0, 1.0);
    final hpColor = _resolveHpColor(hpRatio);

    return Container(
      height: 12,
      decoration: BoxDecoration(
        // 불안 점수 바와 유사한 밝은 트랙 톤
        color: const Color(0xFFD7E2EB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x99DCEAF5), width: 0.9),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fillWidth = constraints.maxWidth * hpRatio;

            return Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  width: fillWidth,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [hpColor.withValues(alpha: 0.95), hpColor],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
                if (segments > 1)
                  ...List.generate(segments - 1, (idx) {
                    final dividerIndex = idx + 1;
                    final x =
                        (constraints.maxWidth * dividerIndex / segments) - 0.5;
                    return Positioned(
                      left: x,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 1,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }

  Color _resolveHpColor(double hpRatio) {
    if (hpRatio > 0.5) {
      final t = (1.0 - hpRatio) / 0.5;
      return Color.lerp(const Color(0xFF2CE0B7), const Color(0xFFFFD54F), t)!;
    }

    final t = (0.5 - hpRatio) / 0.5;
    return Color.lerp(const Color(0xFFFFD54F), const Color(0xFFFF5D5D), t)!;
  }

  Widget _buildCharacters(double contentTopOffset) {
    final dx = _shakeController.value;

    return Stack(
      children: [
        // 타겟 캐릭터 + 감정 말풍선
        Positioned(
          top: 200 + contentTopOffset,
          right: 24 + dx,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (_characterEmotions.isNotEmpty)
                Positioned(
                  top: -50,
                  right: 0,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child:
                        _isBubbleVisible
                            ? _buildEmotionBubble(
                              _currentEmotionText,
                              key: ValueKey("visible_$_currentEmotionIndex"),
                            )
                            : const SizedBox.shrink(key: ValueKey("hidden")),
                  ),
                ),

              Image.asset(
                _getCharacterImage(),
                height: _targetCharacterHeight,
                fit: BoxFit.contain,
                errorBuilder:
                    (_, __, ___) =>
                        const Icon(Icons.error, size: 100, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getCharacterImage() {
    final id = _characterId ?? _defaultCharacterId;

    if (_maxHp == 0) {
      return 'assets/image/character$id.png';
    }

    final ratio = _targetHp / _maxHp;

    if (ratio > 2 / 3) {
      return 'assets/image/character$id.png';
    }
    if (ratio > 1 / 3) {
      return 'assets/image/character${id}_mid.png';
    }
    return 'assets/image/character${id}_last.png';
  }

  Widget _buildEmotionBubble(String text, {Key? key, Color? backgroundColor}) {
    return Container(
      key: key,
      constraints: const BoxConstraints(maxWidth: 180, minHeight: 40),
      child: ClipOval(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          color: (backgroundColor ?? Colors.white).withValues(alpha: 0.95),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: backgroundColor != null ? Colors.white : Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerAndBottomBar(double bottom) {
    return Positioned(
      left: 10,
      right: 10,
      bottom: bottom,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: _playerCharacterHeight),
            child: _buildBottomBarCard(),
          ),
          Positioned(
            left: -2,
            top: 0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (_isUserBubbleVisible && _userBubbleText != null)
                  Positioned(
                    top: -60,
                    left: 80,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildEmotionBubble(
                        _userBubbleText!,
                        key: ValueKey("user_bubble_$_userBubbleText"),
                      ),
                    ),
                  ),
                Image.asset(
                  _playerCharacterAsset,
                  height: _playerCharacterHeight,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton(double bottom) {
    return Positioned(
      bottom: bottom,
      right: 24,
      child: GestureDetector(
        onTap: _handleMicTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            color:
                _listening
                    ? const Color(0xFF56E0C6).withValues(alpha: 0.9)
                    : const Color.fromARGB(
                      255,
                      65,
                      79,
                      79,
                    ).withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white30),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _listening ? Icons.hearing : Icons.mic,
                color: Colors.white,
                size: 54,
              ),
              const SizedBox(height: 2),
              Text(
                _listening ? '듣는 중...' : '터치하여\n마이크 켜기',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBarCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
              child: Text(
                _battleInstructionText,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          LayoutBuilder(
            builder: (context, constraints) {
              final chipWidth = (constraints.maxWidth - _skillChipSpacing) / 2;

              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 148),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: _skillChipSpacing,
                    runSpacing: 8,
                    children: List.generate(
                      _skillsList.length,
                      (idx) =>
                          _buildSkillChip(_skillsList[idx], idx, chipWidth),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleMicTap() async {
    if (_isBattleLocked) return;

    if (_listening) {
      await _voice.stop();
      _setListeningState(false);
      return;
    }

    await _onMicPressed();
  }

  Widget _buildSkillChip(String skill, int index, double chipWidth) {
    final used = _shrunkChips.contains(index);
    final selected = skill == _selectedSkill && !used;

    return SizedBox(
      width: chipWidth,
      child: Opacity(
        opacity: used ? 0.45 : 1.0,
        child: ChoiceChip(
          label: SizedBox(
            width: double.infinity,
            child: Text(
              skill,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          selected: selected,
          showCheckmark: false,
          onSelected: (value) {
            if (used || _isBattleLocked) return;
            setState(() {
              _selectedSkill = value ? skill : null;
            });
          },
          labelStyle: const TextStyle(color: Colors.black, fontSize: 12),
          selectedColor: const Color(0xFF56E0C6),
          backgroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildVictoryScene() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, size: 72, color: Color(0xFFFFD54F)),
          const SizedBox(height: 16),
          const Text(
            '축하합니다!',
            style: TextStyle(
              color: Color(0xFF2CE0B7),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '당신의 불안이 보관함으로 이동되었습니다.',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 220,
            child: ElevatedButton.icon(
              onPressed: () async {
                await _archiveGroup();
                if (!mounted) return;
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/home_mindrium', (_) => false);
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('보관함으로 이동'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2CE0B7),
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _archiveGroup() async {
    try {
      await _worryGroupsApi.archiveWorryGroup(widget.groupId);
      debugPrint('✅ [보관함] 그룹 아카이빙 완료');
    } catch (e) {
      debugPrint('❌ [보관함] 아카이빙 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('아카이빙 실패: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
