// File: character_battle.dart
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PokemonBattleDeletePage extends StatefulWidget {
  final String groupId; // ✅ 전달받은 그룹 ID

  const PokemonBattleDeletePage({Key? key, required this.groupId})
      : super(key: key);

  @override
  _PokemonBattleDeletePageState createState() =>
      _PokemonBattleDeletePageState();
}

class _PokemonBattleDeletePageState extends State<PokemonBattleDeletePage>
    with TickerProviderStateMixin {
  // Firestore에서 불러온 스킬 리스트
  List<String> _skillsList = [];
  bool _isLoading = true;

  // HP 관련
  int _maxHp = 0;
  int _targetHp = 0;

  // 상태
  bool _isAttacking = false;
  String? _selectedSkill;

  // 애니메이션 컨트롤러
  late final AnimationController _shakeController;

  // 대시보드 높이
  static const double _dashboardHeight = 260;

  // 공격 애니메이션 통일 파라미터
  static const Duration _kAttackDuration = Duration(milliseconds: 1400);
  static const Duration _kExitDuration = Duration(milliseconds: 3000);
  static const Offset _kAttackOffset = Offset(0.2, -0.4);
  static const double _kAttackScale = 1.3;

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

    _loadSkillsFromFirestore(); // ✅ Firestore 데이터 불러오기
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Offset get _attackOffset => _isAttacking ? _kAttackOffset : Offset.zero;
  double get _attackScale => _isAttacking ? _kAttackScale : 1.0;
  Duration get _attackDuration => _kAttackDuration;
  Duration get _exitDuration => _kExitDuration;

  // ✅ Firestore에서 alternative_thoughts 불러오기
  Future<void> _loadSkillsFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('abc_models')
          .where('group_id', isEqualTo: widget.groupId)
          .get();

      final Set<String> skills = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final List<dynamic>? alternatives = data['alternative_thoughts'];
        if (alternatives != null) {
          for (final item in alternatives) {
            if (item is String && item.trim().isNotEmpty) {
              skills.add(item.trim());
            }
          }
        }
      }

      setState(() {
        _skillsList = skills.isNotEmpty
            ? skills.toList()
            : ['대체 생각이 없습니다.'];
        _maxHp = _skillsList.length;
        _targetHp = _maxHp;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Firestore에서 스킬 불러오기 실패: $e');
      setState(() {
        _skillsList = ['데이터를 불러오지 못했습니다.'];
        _maxHp = 1;
        _targetHp = 1;
        _isLoading = false;
      });
    }
  }

  // ✅ 그룹 archived 처리 함수
  Future<void> _archiveGroup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('abc_group');
      final qs = await col.where('group_id', isEqualTo: widget.groupId).get();

      for (final doc in qs.docs) {
        await doc.reference.update({
          'archived': true,
          'archived_at': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('✅ 그룹 ${widget.groupId} archived 처리 완료');
    } catch (e) {
      debugPrint('❌ 그룹 archived 처리 실패: $e');
    }
  }

  // 공격 함수
  void _onAttack() {
    if (_selectedSkill == null || _isAttacking || _targetHp == 0) return;

    setState(() => _isAttacking = true);
    _shakeController.forward();

    Future.delayed(_attackDuration, () {
      setState(() {
        _targetHp = max(0, _targetHp - 1);
        _isAttacking = false;
        _skillsList.remove(_selectedSkill);
        _selectedSkill = null;
      });
      _shakeController.stop();
      _shakeController.value = 0;

      // ✅ 모든 스킬 사용 완료 시 Firestore 업데이트
      if (_targetHp == 0) {
        _archiveGroup();
      }
    });
  }

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

    final myChar = 'assets/image/men.png';
    final targetChar = 'assets/image/character${widget.groupId}.png';
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
          child: isDefeated
              ? _buildVictoryScreen(context)
              : _buildBattleScreen(
                  context,
                  bgImage,
                  myChar,
                  targetChar,
                  accent,
                  dashboardColor,
                  chipBg,
                  isDefeated,
                ),
        ),
      ),
    );
  }

  // ✅ 승리 화면 (모든 스킬 사용 후)
Widget _buildVictoryScreen(BuildContext context) {
  return Container(
    width: double.infinity,
    color: Colors.black.withOpacity(0.9),
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.emoji_events, color: Colors.amber, size: 100),
        const SizedBox(height: 24),
        const Text(
          '축하합니다!',
          style: TextStyle(
            color: Colors.tealAccent,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '당신의 불안이 보관함으로 이동되었습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: () {
            // ✅ Navigator.pushReplacementNamed으로 /archive_sea 이동
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/archive_sea',
              (route) => false, // 이전 스택 제거 후 완전히 교체
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.tealAccent.shade200,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.check, color: Colors.black),
          label: const Text(
            '보관함으로 이동',
            style: TextStyle(color: Colors.black, fontSize: 18),
          ),
        ),
      ],
    ),
  );
}
  // ✅ 전투 중 화면
  Widget _buildBattleScreen(
    BuildContext context,
    String bgImage,
    String myChar,
    String targetChar,
    Color accent,
    Color dashboardColor,
    Color chipBg,
    bool isDefeated,
  ) {
    return Column(
      children: [
        const SizedBox(height: 16),
        if (!isDefeated)
          const Text(
            '대체 생각으로 불안을 물리치세요!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
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
                        final dx =
                            _isAttacking ? _shakeController.value * 4 : 0.0;
                        return Transform.translate(
                          offset: Offset(dx, 0),
                          child: AnimatedScale(
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
              // 내 캐릭터
              Positioned(
                bottom: 0,
                left: 5,
                child: AnimatedSlide(
                  offset: _attackOffset,
                  duration: _attackDuration,
                  curve: Curves.easeOut,
                  child: AnimatedScale(
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
              // 공격 중 스킬명 표시
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
    );
  }

  // 대시보드 (기존 동일)
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
          const Text(
            '스킬(대체 생각)을 골라 공격하세요!',
            style: TextStyle(color: Colors.white, fontSize: 14),
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
