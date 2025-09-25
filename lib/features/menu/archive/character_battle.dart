// File: character_battle.dart
import 'package:flutter/material.dart';
import 'dart:math';

class PokemonBattleDeletePage extends StatefulWidget {
  const PokemonBattleDeletePage({Key? key}) : super(key: key);

  @override
  _PokemonBattleDeletePageState createState() =>
      _PokemonBattleDeletePageState();
}

class _PokemonBattleDeletePageState extends State<PokemonBattleDeletePage>
    with TickerProviderStateMixin {
  // 스킬(대체 생각) 목록
  static const List<String> _initialSkills = [
    '연습대로만 해!',
    '지금 시선처리 매우 좋아!',
    '발음 아주 잘하고 있어!',
  ];
  final List<String> _skillsList = List.from(_initialSkills);

  // HP
  final int _maxHp = _initialSkills.length;
  int _targetHp = _initialSkills.length;

  // 상태
  bool _isAttacking = false;
  String? _selectedSkill;

  // 흔들림 컨트롤러
  late final AnimationController _shakeController;

  // 대시보드 높이
  static const double _dashboardHeight = 260;

  // ───────────────────────────────────────────────────────────
  // ✅ 공격 애니메이션 통일 파라미터 (스킬 관계없이 고정)
  static const Duration _kAttackDuration = Duration(milliseconds: 1400);
  static const Duration _kExitDuration = Duration(milliseconds: 3000);
  static const Offset _kAttackOffset = Offset(0.2, -0.4);
  static const double _kAttackScale = 1.3;
  // ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
      lowerBound: -1,
      upperBound: 1,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reverse();
      } else if (status == AnimationStatus.dismissed && _isAttacking) {
        _shakeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────
  // ✅ (통일) 공격 애니메이션 파생 값
  Offset get _attackOffset => _isAttacking ? _kAttackOffset : Offset.zero;
  double get _attackScale => _isAttacking ? _kAttackScale : 1.0;
  Duration get _attackDuration => _kAttackDuration;
  Duration get _exitDuration => _kExitDuration;
  // ───────────────────────────────────────────────────────────

  void _onAttack() {
    if (_selectedSkill == null || _isAttacking || _targetHp == 0) return;

    setState(() => _isAttacking = true);
    _shakeController.forward();

    // 통일된 공격 시간 후 데미지 처리
    Future.delayed(_attackDuration, () {
      setState(() {
        _targetHp = max(0, _targetHp - 1);
        _isAttacking = false;
        _skillsList.remove(_selectedSkill);
        _selectedSkill = null;
      });
      _shakeController.stop();
      _shakeController.value = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    const myChar = 'assets/image/men.png';
    const targetChar = 'assets/image/character4.png';
    const bgImage = 'assets/image/delete.png';
    final isDefeated = _targetHp == 0;

    final bgColor = Colors.blueGrey.shade900;
    final dashboardColor = Colors.blueGrey.shade800;
    final accent = Colors.tealAccent.shade200;
    final chipBg = Colors.blueGrey.shade700;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          '불안 격파 챌린지',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _shakeController,
          builder: (ctx, child) {
            final dx = _isAttacking ? _shakeController.value * 4 : 0.0;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: Column(
            children: [
              const SizedBox(height: 16),
              // NOTE: Positioned는 Stack 자식에서만 허용됨. (원래 코드 유지)
              if (!isDefeated)
                const Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Text(
                    '대체 생각으로 발표 불안을 물리치세요!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        bgImage,
                        fit: BoxFit.cover,
                        color: Colors.black.withValues(alpha: 0.4),
                        colorBlendMode: BlendMode.darken,
                      ),
                    ),
                    // 상대 캐릭터
                    Positioned(
                      top: 16,
                      right: 16,
                      child: AnimatedOpacity(
                        opacity: isDefeated ? 0 : 1,
                        duration: _exitDuration,
                        child: AnimatedSlide(
                          offset: isDefeated ? const Offset(1, 1) : Offset.zero,
                          duration: _exitDuration,
                          curve: Curves.easeIn,
                          child: AnimatedBuilder(
                            animation: _shakeController,
                            builder: (ctx, child) {
                              final dx = _isAttacking
                                  ? _shakeController.value * 4
                                  : 0.0;
                              return Transform.translate(
                                offset: Offset(dx, 0),
                                child: AnimatedScale(
                                  // ✅ 통일된 스케일 지속시간 사용
                                  scale: _attackScale,
                                  duration: _attackDuration,
                                  curve: Curves.elasticOut,
                                  child: child,
                                ),
                              );
                            },
                            child: Image.asset(
                              targetChar,
                              height: 160,
                              errorBuilder: (_, __, ___) =>
                              const Icon(Icons.error, size: 160),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 내 캐릭터 (승리하면 숨김)
                    if (!isDefeated)
                      Positioned(
                        bottom: 0,
                        left: 5,
                        child: AnimatedSlide(
                          // ✅ 통일된 이동량/지속시간 사용
                          offset: _attackOffset,
                          duration: _attackDuration,
                          curve: Curves.easeOut,
                          child: AnimatedScale(
                            // ✅ 통일된 스케일/지속시간 사용
                            scale: _attackScale,
                            duration: _attackDuration,
                            curve: Curves.elasticOut,
                            child: Image.asset(
                              myChar,
                              height: 230,
                              errorBuilder: (_, __, ___) =>
                              const Icon(Icons.error, size: 80),
                            ),
                          ),
                        ),
                      ),
                    // 스킬명 오버레이
                    if (_isAttacking && _selectedSkill != null)
                      Positioned.fill(
                        child: Center(
                          child: Text(
                            _selectedSkill!,
                            style: TextStyle(
                              color: accent,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(blurRadius: 6, color: Colors.black45)
                              ],
                            ),
                          ),
                        ),
                      ),
                    // 승리 메시지
                    if (isDefeated)
                      Positioned.fill(
                        child: Center(
                          child: Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 24.0),
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: const TextSpan(
                                style: TextStyle(
                                  color: Colors.lightGreenAccent,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 6,
                                      color: Colors.black45,
                                    )
                                  ],
                                ),
                                children: [
                                  TextSpan(text: '축하합니다!'),
                                  WidgetSpan(child: SizedBox(width: 10)),
                                  TextSpan(text: '발표 불안을 완전히 물리쳤습니다!'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!isDefeated)
                _buildDashboard(
                  dashboardColor: dashboardColor,
                  accent: accent,
                  chipBg: chipBg,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard({
    required Color dashboardColor,
    required Color accent,
    required Color chipBg,
  }) {
    return Container(
      height: _dashboardHeight,
      decoration: BoxDecoration(
        color: dashboardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HP: $_targetHp/$_maxHp',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 12,
              value: _maxHp > 0 ? _targetHp / _maxHp : 0,
              backgroundColor: Colors.grey.shade800,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 1),
            child: Text(
              '스킬(대체 생각)을 골라 "발표 불안"을 물리치세요',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _skillsList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, idx) {
                final skill = _skillsList[idx];
                final selected = skill == _selectedSkill;
                return ChoiceChip(
                  label: Text(skill),
                  labelStyle: const TextStyle(color: Colors.white),
                  selected: selected,
                  onSelected: (v) {
                    if (!_isAttacking && _targetHp > 0 && v) {
                      setState(() => _selectedSkill = skill);
                    }
                  },
                  selectedColor: accent,
                  backgroundColor: chipBg,
                );
              },
            ),
          ),
          const Spacer(),
          Center(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_selectedSkill != null &&
                    !_isAttacking &&
                    _targetHp > 0)
                    ? _onAttack
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  '공격',
                  style: TextStyle(color: Colors.black, fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
