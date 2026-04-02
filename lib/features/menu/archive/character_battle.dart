import 'package:gad_app_team/utils/text_line_material.dart';
import 'dart:math';
import 'package:gad_app_team/features/menu/archive/character_battle_asr.dart';
import 'dart:async';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/worry_groups_api.dart';
import 'package:gad_app_team/widgets/jellyfish_notice.dart';

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
  late final AnimationController _scoreController;

  // ========== 음성인식 ==========
  late final CharacterBattleAsr _voice;
  bool _listening = false;
  DateTime? _listenStartedAt;

  // ========== 말풍선 ==========
  int _currentEmotionIndex = 0;
  bool _isBubbleVisible = true;
  String? _bubbleText;
  Timer? _bubbleTimer;

  // 사용자 말풍선 추가
  String? _userBubbleText;
  bool _isUserBubbleVisible = false;
  Timer? _userBubbleTimer;

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

    _scoreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _voice = CharacterBattleAsr();
    // iOS에서 화면 진입 시 즉시 STT 초기화가 앱 종료로 이어지는 경우가 있어
    // 마이크 버튼을 눌렀을 때만 초기화하도록 지연한다.
    _loadData();
    _startEmotionCycle();
  }

  @override
  void dispose() {
    _voice.dispose();
    _bubbleTimer?.cancel();
    _userBubbleTimer?.cancel();
    _shakeController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  // ========== 초기화 ==========

  Future<void> _initializeVoice() async {
    debugPrint('🎤 [음성인식] 초기화 시작');

    final success = await _voice.initialize(
      onStatus: (s) {
        // 패키지에서 오는 상태 문자열에 따라 listening 플래그 업데이트
        if (s == 'listening') {
          if (mounted) {
            setState(() => _listening = true);
          }
        } else if (s == 'notListening') {
          if (mounted) {
            setState(() => _listening = false);
          }
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _listening = false);
        }
        debugPrint('❌ [음성인식 에러] $e');
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
      debugPrint('🔍 [데이터 로드 시작] group_id: ${widget.groupId}');

      // 1. 그룹 정보 조회
      final groupData = await _worryGroupsApi.getWorryGroup(widget.groupId);
      final characterName = groupData['group_title']?.toString() ?? '이름 없음';
      final characterId = groupData['character_id'] as int?;

      debugPrint('🎨 [캐릭터 정보] name: $characterName, id: $characterId');

      // 2. 그룹의 모든 일기 조회 (한 번만)
      final response = await _apiClient.dio.get(
        '/diaries',
        queryParameters: {
          'group_id': widget.groupId,
          'include_drafts': true,
          'include_auto': true,
        },
      );

      debugPrint('📦 [일기 응답]: ${response.data}');

      final List<String> emotions = [];
      final List<String> skills = [];

      // 3. 일기 데이터에서 belief와 alternative_thoughts 추출
      if (response.data is List) {
        for (final item in response.data) {
          if (item is! Map) continue;

          // belief 추출
          final List<dynamic>? beliefData = item['belief'];
          if (beliefData != null) {
            for (final b in beliefData) {
              // belief 배열 안의 각 항목에서 label 값 추출
              if (b is Map && b['label'] != null) {
                final labelText = b['label'].toString().trim();
                if (labelText.isNotEmpty) {
                  emotions.add(labelText);
                }
              }
            }
          }

          // alternative_thoughts 추출
          final List<dynamic>? altThoughts = item['alternative_thoughts'];
          if (altThoughts != null) {
            for (final alt in altThoughts) {
              if (alt is String) {
                final text = alt.trim();
                if (text.isNotEmpty) skills.add(text);
                continue;
              }
              if (alt is Map) {
                final raw =
                    alt['label'] ??
                    alt['text'] ??
                    alt['value'] ??
                    alt['content'] ??
                    alt['thought'];
                final text = raw?.toString().trim() ?? '';
                if (text.isNotEmpty) skills.add(text);
              }
            }
          }
        }
      }

      final battleSkills = List<String>.from(skills);
      // 모든 대체 생각을 보여주되, 전투 완료는 최대 3개 발화 성공으로 제한
      final requiredHits = battleSkills.isEmpty ? 1 : min(3, battleSkills.length);

      debugPrint('🎯 [최종 감정 목록]: $emotions');
      debugPrint('🎯 [최종 스킬 목록(전투용)]: $battleSkills');
      debugPrint(
        '📊 [전투 데이터] diaries=${(response.data as List?)?.length ?? 0}, thoughts=${battleSkills.length}',
      );

      // belief를 랜덤으로 섞어서 다양하게 보여주기
      if (emotions.isNotEmpty) {
        emotions.shuffle();
      }

      setState(() {
        _characterName = characterName;
        _characterId = characterId;
        _characterEmotions = emotions.isNotEmpty ? emotions : ['감정 데이터가 없습니다'];
        _currentEmotionIndex = 0;
        _skillsList = battleSkills.isNotEmpty ? battleSkills : ['대체 생각이 없습니다'];
        _maxHp = requiredHits;
        _targetHp = _maxHp;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ 데이터 로드 실패: $e');
      setState(() {
        _characterEmotions = ['데이터를 불러오지 못했습니다'];
        _skillsList = ['데이터를 불러오지 못했습니다'];
        _maxHp = 1;
        _targetHp = 1;
        _isLoading = false;
      });
    }
  }

  // ========== 공격 로직 ==========

  Future<void> _handleAttack() async {
    if (_selectedSkill == null || _isAttacking || _isDefeated) return;

    debugPrint('⚔️ [공격 버튼] 선택된 스킬: $_selectedSkill');

    final skillIndex = _skillsList.indexOf(_selectedSkill!);
    if (skillIndex == -1 || _shrunkChips.contains(skillIndex)) {
      debugPrint('❌ 이미 사용된 스킬');
      return;
    }

    setState(() {
      _isAttacking = true;
      _userBubbleText = _selectedSkill;
      _isUserBubbleVisible = true;
    });

    // 타격 준비 시간
    await Future.delayed(const Duration(milliseconds: 1200));

    setState(() {
      _shrunkChips.add(skillIndex);
      _targetHp = max(0, _targetHp - 1);
      _selectedSkill = null;
    });

    _shakeController.forward(from: 0);

    if (_targetHp <= 0) {
      // 마무리 연출 후 패배 처리
      await Future.delayed(const Duration(milliseconds: 800));
      setState(() {
        _isDefeated = true;
        _bubbleText = '으악..!';
      });

      await Future.delayed(const Duration(seconds: 2));
      await _archiveGroup();

      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      // 아직 HP 남아있으면 말풍선 닫고 감정 변경
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _isUserBubbleVisible = false);

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() {
        _currentEmotionIndex =
            (_currentEmotionIndex + 1) % _characterEmotions.length;
        _isAttacking = false;
      });
    }
  }

  // ========== 음성인식 ==========

  Future<void> _onMicPressed() async {
    debugPrint('🎤 [마이크 클릭]');

    if (_isAttacking || _isDefeated) {
      debugPrint('⚠️ [공격 중 또는 패배] 마이크 입력 무시');
      return;
    }
    if (_selectedSkill == null) {
      _showToast('먼저 아래 대체 생각을 선택해주세요');
      return;
    }

    if (!_voice.isReady) {
      debugPrint('❌ [준비 안됨] 재초기화 시도');
      await _initializeVoice();
      if (!_voice.isReady) {
        _showErrorDialog();
        return;
      }
    }

    // 바로 listening 시작
    setState(() {
      _listening = true;
    });

    _listenStartedAt = DateTime.now();
    debugPrint('🎤 [음성인식 시작] ${_listenStartedAt!.toIso8601String()}');

    try {
      final success = await _voice.startListening(
        localeId: 'ko_KR',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        onPartial: (_) {
          if (!mounted) return;
        },
        onFinal: (t) async {
          if (!mounted) return;
          setState(() => _listening = false);

          final trimmed = t.trim();
          if (trimmed.isNotEmpty) {
            _showToast('인식 완료: $trimmed');
            await _handleVoiceChoice(trimmed);
          } else {
            _showToast('음성이 인식되지 않았습니다');
          }
        },
      );

      if (!success) {
        if (mounted) setState(() => _listening = false);
        _showErrorDialog();
      }
    } catch (e) {
      debugPrint('❌ [예외] $e');
      if (mounted) setState(() => _listening = false);
      _showErrorDialog();
    }
  }

  Future<void> _handleVoiceChoice(String utter) async {
    final text = utter.trim();
    if (text.isEmpty || _skillsList.isEmpty) return;
    if (_isAttacking || _isDefeated) return;
    if (_selectedSkill == null) {
      _showToast('먼저 대체 생각을 선택해주세요');
      return;
    }

    final selectedIndex = _skillsList.indexOf(_selectedSkill!);
    if (selectedIndex < 0 || _shrunkChips.contains(selectedIndex)) {
      _showToast('다른 대체 생각을 선택해주세요');
      return;
    }

    final chosen = _skillsList[selectedIndex];
    final score = CharacterBattleAsr.similarity(
      text.toLowerCase(),
      chosen.toLowerCase(),
    );

    if (score < 0.3) {
      debugPrint('❌ [낮은 유사도] $score');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 선택한 생각 "$chosen"과(와) 다르게 인식됐어요'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
        ),
      );
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
        if (_characterEmotions.isNotEmpty) {
          _currentEmotionIndex =
              (_currentEmotionIndex + 1) % _characterEmotions.length;
        }
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

    const bgImage = 'assets/image/battle_scene_bg.png';
    final myChar = 'assets/image/men.png';
    final mediaQuery = MediaQuery.of(context);
    final topInset = mediaQuery.padding.top;
    final safeBottom = mediaQuery.padding.bottom;
    const contentTopOffset = 52.0;
    const bottomBarBottomSpacing = 20.0;
    const bottomBarEstimatedHeight = 220.0;
    const micSpacingAboveBottomBar = 28.0;

    final bottomBarBottom = safeBottom + bottomBarBottomSpacing;
    final micBottom =
        bottomBarBottom + bottomBarEstimatedHeight + micSpacingAboveBottomBar;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset(bgImage, fit: BoxFit.cover)),
          _buildBackButton(topInset),
          _buildHpPanel(contentTopOffset),
          _buildCharacters(myChar, contentTopOffset),
          _buildMicButton(micBottom),
          _buildBottomBar(bottomBarBottom),
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
        color: Colors.black.withValues(alpha: 0.28),
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: Colors.white,
          iconSize: 20,
          tooltip: '뒤로가기',
        ),
      ),
    );
  }

  Widget _buildHpPanel(double contentTopOffset) {
    return Positioned(
      top: 190 + contentTopOffset,
      right: 200,
      child: Container(
        width: 150,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _characterName ?? '불안한 캐릭터',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              '불안 캐릭터',
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
            const SizedBox(height: 6),
            _buildHpBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHpBar() {
    final segments = max(1, _maxHp);
    final hpRatio = (_targetHp / segments).clamp(0.0, 1.0);

    Color hpColor;
    if (hpRatio > 0.5) {
      // 초록 -> 노랑
      final t = (1.0 - hpRatio) / 0.5;
      hpColor = Color.lerp(const Color(0xFF2CE0B7), const Color(0xFFFFD54F), t)!;
    } else {
      // 노랑 -> 빨강
      final t = (0.5 - hpRatio) / 0.5;
      hpColor = Color.lerp(const Color(0xFFFFD54F), const Color(0xFFFF5D5D), t)!;
    }

    return Container(
      height: 12,
      decoration: BoxDecoration(
        // 불안 점수 바와 유사한 밝은 트랙 톤
        color: const Color(0xFFD7E2EB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0x99DCEAF5),
          width: 0.9,
        ),
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
                      colors: [
                        hpColor.withValues(alpha: 0.95),
                        hpColor,
                      ],
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

  Widget _buildCharacters(String myChar, double contentTopOffset) {
    final dx = _shakeController.value;

    return Stack(
      children: [
        // 내 캐릭터 + 사용자 말풍선
        Positioned(
          left: 8,
          bottom: 160,
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
              Image.asset(myChar, height: 220, fit: BoxFit.contain),
            ],
          ),
        ),

        // 타겟 캐릭터 + 감정 말풍선
        Positioned(
          top: 210 + contentTopOffset,
          right: 24 + dx,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (_characterEmotions.isNotEmpty)
                Positioned(
                  top: -60,
                  right: 0,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child:
                        _isBubbleVisible
                            ? _buildEmotionBubble(
                              _bubbleText ??
                                  _characterEmotions[_currentEmotionIndex],
                              key: ValueKey("visible_$_currentEmotionIndex"),
                            )
                            : const SizedBox.shrink(key: ValueKey("hidden")),
                  ),
                ),

              // ★ 자동 HP 상태에 맞는 표정 이미지
              Image.asset(
                _getCharacterImage(),
                height: 160,
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
    final id = _characterId ?? 1; // character_id 사용, 없으면 기본값 1

    if (_maxHp == 0) {
      return 'assets/image/character$id.png';
    }

    double ratio = _targetHp / _maxHp;

    if (ratio > 2 / 3) {
      return 'assets/image/character$id.png'; // 기본 표정
    } else if (ratio > 1 / 3) {
      return 'assets/image/character${id}_mid.png'; // 중간 데미지
    } else {
      return 'assets/image/character${id}_last.png'; // 마지막 데미지
    }
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

  Widget _buildMicButton(double bottom) {
    return Positioned(
      bottom: bottom,
      right: 24,
      child: GestureDetector(
        onTap: () async {
          if (_isAttacking || _isDefeated) return;

          if (_listening) {
            await _voice.stop();
            if (mounted) setState(() => _listening = false);
            return;
          }

          await _onMicPressed();
        },
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

  Widget _buildBottomBar(double bottom) {
    return Positioned(
      left: 10,
      right: 10,
      bottom: bottom,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 65, 79, 79).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 18),
                child: Transform.scale(
                  scale: 0.74,
                  alignment: Alignment.centerLeft,
                  child: const JellyfishNotice(
                    feedback: '도움이 되는 생각을 하나씩 선택 후 말해보세요!',
                    feedbackColor: Color(0xFF35546C),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 8.0;
                final chipWidth = (constraints.maxWidth - spacing) / 2;

                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 148),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: spacing,
                      runSpacing: 8,
                      children: List.generate(_skillsList.length, (idx) {
                        final skill = _skillsList[idx];
                        final used = _shrunkChips.contains(idx);
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
                              onSelected: (v) {
                                if (used || _isAttacking || _isDefeated) return;
                                setState(() {
                                  _selectedSkill = v ? skill : null;
                                });
                              },
                              labelStyle: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                              ),
                              selectedColor: const Color(0xFF56E0C6),
                              backgroundColor: Colors.white,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              '전체 생각 ${_skillsList.length}개 · 진행 ${_shrunkChips.length}/${_maxHp} · 남은 생각 ${_targetHp}개',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/home_mindrium', (_) => false,
                );
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
