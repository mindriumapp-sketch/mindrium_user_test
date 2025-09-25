// File: sea_archive_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 바다 속에 '보관(archive)'된 캐릭터들이 화면 안에서 자연스럽게 유영.
/// - 모든 캐릭터/텍스트 같은 크기
/// - 동그라미 배경 제거(투명 PNG 그대로)
/// - 텍스트 박스까지 화면 밖으로 절대 나가지 않음(경계 반사 + 강제 클램프)
/// - 겹치면 '겹치지 않도록' 즉시 분리(MTV 반복) + 당구식(법선) 반사
/// - 드래그로 직접 위치 이동 가능(드래그 중 자동 유영 정지)
class SeaArchivePage extends StatefulWidget {
  const SeaArchivePage({Key? key}) : super(key: key);

  @override
  State<SeaArchivePage> createState() => _SeaArchivePageState();
}

class _SeaArchivePageState extends State<SeaArchivePage>
    with SingleTickerProviderStateMixin {
  AnimationController? _bgController;
  void _ensureBgController() {
    _bgController ??= AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  FishFieldController? _fieldController;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _ensureBgController();
  }

  @override
  void reassemble() {
    super.reassemble();
    _bgController?.repeat();
  }

  @override
  void dispose() {
    _bgController?.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _archiveGroupsQuery(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('abc_group')
        .where('archived', isEqualTo: true);
  }

  @override
  Widget build(BuildContext context) {
    _ensureBgController();
    final controller = _bgController!;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요합니다')),
      );
    }

    const colorTop = Color(0xFF013A63);
    const colorMid = Color(0xFF01497C);
    const colorBot = Color(0xFF2A6F97);

    return Scaffold(
      backgroundColor: colorMid,
      // appBar: AppBar(
      //   title: const Text('바다 속 보관함'),
      //   backgroundColor: Colors.teal,
      // ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [colorTop, colorMid, colorBot],
                ),
              ),
            ),
          ),
          Positioned.fill(child: _LightRays(controller: controller)),
          Positioned.fill(child: _Waves(controller: controller)),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _archiveGroupsQuery(uid).snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    '보관함에 있는 캐릭터가 없어요.\n그룹 화면에서 보관 처리하면 이곳에 나타납니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                );
              }

              if (_fieldController == null || _lastCount != docs.length) {
                _fieldController = FishFieldController(count: docs.length);
                _lastCount = docs.length;
              }

              final size = MediaQuery.of(context).size;
              return Stack(
                children: [
                  for (int i = 0; i < docs.length; i++)
                    _PhysicsFish(
                      index: i,
                      doc: docs[i],
                      area: size,
                      field: _fieldController!,
                      onTap: (img, title, desc, createdAt) {
                        _showFishDetailSheet(
                          title: title,
                          description: desc,
                          createdAt: createdAt?.toDate(),
                          image: img,
                        );
                      },
                      onLongPress: () => _unarchive(docs[i]),
                    ),
                ],
              );
            },
          ),

          Positioned.fill(child: _Bubbles(controller: controller, density: 14)),
        ],
      ),
    );
  }

  Future<void> _unarchive(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    try {
      await doc.reference.update({'archived': false});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('보관 해제되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('보관 해제 중 오류: $e')),
      );
    }
  }

  void _showFishDetailSheet({
    required String title,
    required String description,
    required ImageProvider image,
    DateTime? createdAt,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.blueGrey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(backgroundImage: image, radius: 32),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (description.isNotEmpty)
                  Text(
                    description,
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                if (createdAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '생성일: ${createdAt.toLocal()}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.tealAccent.shade200,
                          side: BorderSide(color: Colors.tealAccent.shade200),
                        ),
                        icon: const Icon(Icons.close),
                        label: const Text('닫기'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/* ────────────────────────────────────────────────────────────────────────────
 * 캐릭터 Row(이미지+텍스트) Bounds 공유 컨트롤러
 * ────────────────────────────────────────────────────────────────────────────*/
class FishFieldController {
  FishFieldController({required int count})
      : _bounds = List<Rect?>.filled(count, null, growable: false);

  final List<Rect?> _bounds;

  void setBounds(int index, Rect r) {
    if (index < 0 || index >= _bounds.length) return;
    _bounds[index] = r;
  }

  Iterable<Rect> othersBounds(int index) sync* {
    for (int i = 0; i < _bounds.length; i++) {
      if (i == index) continue;
      final r = _bounds[i];
      if (r != null) yield r;
    }
  }
}

/* ────────────────────────────────────────────────────────────────────────────
 * 경계 처리 결과
 * ────────────────────────────────────────────────────────────────────────────*/
class _BoundaryResult {
  final Offset pos;
  final Offset vel;
  const _BoundaryResult(this.pos, this.vel);
}

/* ────────────────────────────────────────────────────────────────────────────
 * 물리 느낌 유영 위젯
 * ────────────────────────────────────────────────────────────────────────────*/
class _PhysicsFish extends StatefulWidget {
  final int index;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Size area;
  final FishFieldController field;
  final void Function(ImageProvider, String, String, Timestamp?) onTap;
  final VoidCallback onLongPress;

  const _PhysicsFish({
    required this.index,
    required this.doc,
    required this.area,
    required this.field,
    required this.onTap,
    required this.onLongPress,
    Key? key,
  }) : super(key: key);

  @override
  State<_PhysicsFish> createState() => _PhysicsFishState();
}

class _PhysicsFishState extends State<_PhysicsFish>
    with SingleTickerProviderStateMixin {
  // UI 고정값
  static const double kCharSize = 52.0;
  static const double kRowGap = 10.0;
  static const double kTextWidth = 180.0;
  static const double kTextTitleSize = 14.0;
  static const double kTextDescSize = 12.0;
  static const double kRowHeight = 64.0;
  static const double kRowWidth = kCharSize + kRowGap + kTextWidth;

  // 물리 파라미터 (당구 느낌)
  static const double kSpeed = 30.0;              // 기본 순항 속도 ↑ (22 -> 30)
  static const double kMaxTurnRadPerSec = 1.1;    // 급회전 방지
  static const double kWanderFreq = 0.7;          // 방황 빈도
  static const double kWanderAmp  = 0.10;         // 방황 각도
  static const double kEdgePadding = 24.0;        // 화면 가장자리 여백
  static const double kSepBias = 1.5;             // 분리 후 살짝 더 밀기 (강화)
  static const double kRestitution = 0.1;        // 탄성
  static const int    kSeparationIters = 100;       // 한 프레임 분리 반복 ↑

  // 서브스텝 설정: 한 서브스텝에서 최대 이동 허용 거리(px)
  static const double kMaxStepDist = kRowHeight * 0.1; // 약 25px 정도

  late final AnimationController _ticker;
  late final Random _rng;

  // 상태
  late Offset _pos;     // Row 좌상단
  late double _heading; // 진행 각도
  late Offset _vel;     // 속도 벡터
  Duration? _lastTick;
  bool _isDragging = false;

  bool get _flipImageHorizontally => cos(_heading) < 0;

  @override
  void initState() {
    super.initState();
    _rng = Random(widget.doc.id.hashCode);

    _pos = _randomPosInside();
    _heading = _rng.nextDouble() * 2 * pi - pi;
    _vel = Offset(cos(_heading), sin(_heading)) * kSpeed;

    _ticker = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..addListener(_onTick)
      ..repeat();
  }

  @override
  void dispose() {
    _ticker.removeListener(_onTick);
    _ticker.dispose();
    super.dispose();
  }

  // ── 헬퍼들 ───────────────────────────────────────────────────────────
  Rect _boundsBox() {
    final w = widget.area.width;
    final h = widget.area.height;
    final minX = kEdgePadding;
    final minY = kEdgePadding;
    double maxX = w - kEdgePadding - kRowWidth;
    double maxY = h - kEdgePadding - kRowHeight;
    if (maxX < minX) maxX = minX; // 화면이 매우 작아도 안전
    if (maxY < minY) maxY = minY;
    return Rect.fromLTWH(minX, minY, maxX - minX, maxY - minY);
  }

  Offset _clampInsideBounds(Offset p) {
    final b = _boundsBox();
    return Offset(
      p.dx.clamp(b.left, b.right),
      p.dy.clamp(b.top, b.bottom),
    );
  }

  Offset _randomPosInside() {
    final b = _boundsBox();
    final left = b.left, top = b.top;
    final w = max(1.0, b.width), h = max(1.0, b.height);
    return Offset(
      left + _rng.nextDouble() * w,
      top + _rng.nextDouble() * h,
    );
  }

  Rect _rectAt(Offset p) => Rect.fromLTWH(p.dx, p.dy, kRowWidth, kRowHeight);

  double _len(Offset v) => sqrt(v.dx * v.dx + v.dy * v.dy);
  Offset _norm(Offset v) {
    final l = _len(v);
    return (l <= 1e-9) ? const Offset(1, 0) : v / l;
  }

  /// v를 법선 n에 대해 당구처럼 거울반사. 탄성 e(0.9~0.95 권장)
  Offset _reflectBilliard(Offset v, Offset n, {double e = kRestitution}) {
    final nn = _norm(n);
    final speed = _len(v);
    final dot = v.dx * nn.dx + v.dy * nn.dy;
    var reflected = v - nn * (2 * dot);        // 기하학적 반사
    reflected = _norm(reflected) * (speed * e); // 속도 크기 보존 + 약간 감쇠
    return reflected;
  }

  _BoundaryResult _resolveBoundary(Offset nextPos, Offset vel) {
    final b = _boundsBox();
    var np = nextPos;
    var v  = vel;

    // 좌우
    if (np.dx < b.left) {
      np = Offset(b.left, np.dy);
      v  = _reflectBilliard(v, const Offset(1, 0));   // 왼벽 법선
    } else if (np.dx > b.right) {
      np = Offset(b.right, np.dy);
      v  = _reflectBilliard(v, const Offset(-1, 0));  // 오른벽 법선
    }

    // 상하
    if (np.dy < b.top) {
      np = Offset(np.dx, b.top);
      v  = _reflectBilliard(v, const Offset(0, 1));   // 윗벽 법선
    } else if (np.dy > b.bottom) {
      np = Offset(np.dx, b.bottom);
      v  = _reflectBilliard(v, const Offset(0, -1));  // 아랫벽 법선
    }

    // 최종 보강(오차 방지)
    np = _clampInsideBounds(np);
    return _BoundaryResult(np, v);
  }

  // AABB 최소 이동 벡터(MTV)
  Offset? _mtv(Rect a, Rect b) {
    if (!a.overlaps(b)) return null;
    final dx1 = b.right - a.left;
    final dx2 = a.right - b.left;
    final dy1 = b.bottom - a.top;
    final dy2 = a.bottom - b.top;

    final pushX = (dx1 < dx2) ? -dx1 : dx2;
    final pushY = (dy1 < dy2) ? -dy1 : dy2;

    if (pushX.abs() < pushY.abs()) {
      return Offset(pushX, 0);
    } else {
      return Offset(0, pushY);
    }
  }

  void _applyWander(double dtSec) {
    final t = (_ticker.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0 +
        widget.index * 0.37;
    final wander = sin(t * kWanderFreq * 2 * pi) * kWanderAmp;
    final maxTurn = kMaxTurnRadPerSec * dtSec;
    final delta = wander.clamp(-maxTurn, maxTurn);
    _heading = _wrapAngle(_heading + delta);
    // 속도 크기는 유지하면서 방향만 바꿔서 자연스럽게
    final speed = _len(_vel);
    _vel = Offset(cos(_heading), sin(_heading)) * (speed == 0 ? kSpeed : speed);
  }

  // 겹침 완전 제거용: 한 프레임에 여러 번 분리 시도 + 당구식 반사
  _BoundaryResult _separateFromOthers(Offset pos, Offset vel) {
    var curPos = pos;
    var curVel = vel;

    for (int iter = 0; iter < kSeparationIters; iter++) {
      bool moved = false;
      var myRect = _rectAt(curPos);

      for (final other in widget.field.othersBounds(widget.index)) {
        final mtv = _mtv(myRect, other);
        if (mtv != null) {
          final n = _norm(mtv); // 분리 방향 = 충돌 법선

          // 완전 분리 + 약간 더 밀기
          curPos += mtv + n * kSepBias;
          myRect = _rectAt(curPos);

          // 당구식 반사(속도 크기 보존 + 약간 감쇠)
          curVel = _reflectBilliard(curVel, n);

          moved = true;
        }
      }

      // 분리 후 경계 재확인
      final b = _resolveBoundary(curPos, curVel);
      if (b.pos != curPos || b.vel != curVel) {
        curPos = b.pos;
        curVel = b.vel;
        moved = true;
      }

      if (!moved) break;
    }

    return _BoundaryResult(curPos, curVel);
  }

  // 서브스텝 통합: 한 번에 많이 이동하면 여러 번 나눠서 이동(터널링 방지)
  void _integrateWithSubsteps(double dtSec) {
    // 이번 프레임에서 예상 이동 거리
    final moveDist = _len(_vel) * dtSec;
    // 서브스텝 수: 한 스텝 이동이 kMaxStepDist 이하가 되도록
    final steps = max(1, (moveDist / kMaxStepDist).ceil());
    final stepDt = dtSec / steps;

    for (int i = 0; i < steps; i++) {
      // 자연스러운 방황(서브스텝 단위로도 조금씩 반영)
      _applyWander(stepDt);

      // 예측 이동
      var nextPos = _pos + _vel * stepDt;

      // 1차 경계 처리
      final b1 = _resolveBoundary(nextPos, _vel);
      nextPos = b1.pos;
      _vel = b1.vel;

      // 다른 개체와의 겹침 완전 제거(여러 번) + 반사
      final sep = _separateFromOthers(nextPos, _vel);
      nextPos = sep.pos;
      _vel = sep.vel;

      // 헤딩 갱신
      if (_vel.distanceSquared > 0.0001) {
        _heading = atan2(_vel.dy, _vel.dx);
      }

      // 🔒 최종 안전 클램프
      nextPos = _clampInsideBounds(nextPos);

      // 상태 반영
      _pos = nextPos;
      widget.field.setBounds(widget.index, _rectAt(_pos));
    }
  }

  void _onTick() {
    final now = _ticker.lastElapsedDuration ?? Duration.zero;
    final dtSec = (() {
      if (_lastTick == null) return 1 / 60.0;
      final d = (now - _lastTick!).inMicroseconds / 1e6;
      // 너무 큰 프레임은 클램프
      return d.clamp(0.0, 1 / 30.0);
    })();
    _lastTick = now;

    if (_isDragging) {
      // 드래그 중에도 화면 밖으로 안 나가게 즉시 보정
      _pos = _clampInsideBounds(_pos);
      widget.field.setBounds(widget.index, _rectAt(_pos));
      if (mounted) setState(() {});
      return;
    }

    // ✅ 서브스텝 기반 이동/충돌 처리(터널링 방지 + 확실한 분리)
    _integrateWithSubsteps(dtSec);

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data();
    final groupId = (data['group_id'] as String?) ?? '';
    final title = (data['group_title'] as String?) ?? '이름 없는 캐릭터';
    final desc = (data['group_contents'] as String?) ?? '';
    final createdAt = data['created_at'] as Timestamp?;

    final img = (groupId.isNotEmpty)
        ? AssetImage('assets/image/character$groupId.png')
        : const AssetImage('assets/image/character4.png');

    return Positioned(
      left: _pos.dx,
      top: _pos.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => _isDragging = true,
        onPanUpdate: (d) {
          var next = _pos + d.delta;

          // 드래그 중에도 항상 경계 내에서만
          next = _clampInsideBounds(next);

          // 드래그 방향으로 속도/각도 업데이트(부드럽게)
          if (d.delta.distanceSquared > 0.1) {
            final dir = _norm(d.delta);
            final speed = max(12.0, kSpeed); // 너무 느려지지 않게 하한
            _vel = Offset.lerp(_vel, dir * speed, 0.5)!;
            _heading = atan2(_vel.dy, _vel.dx);
          }

          _pos = next;
          widget.field.setBounds(widget.index, _rectAt(_pos));
          setState(() {});
        },
        onPanEnd: (_) {
          _isDragging = false;
          // 드래그 놓는 순간에도 겹침 제거 + 경계 확정
          final sep = _separateFromOthers(_pos, _vel);
          _pos = _clampInsideBounds(sep.pos);
          _vel = sep.vel;
          widget.field.setBounds(widget.index, _rectAt(_pos));
          setState(() {});
        },
        onTap: () => widget.onTap(img, title, desc, createdAt),
        onLongPress: widget.onLongPress,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..scale(_flipImageHorizontally ? -1.0 : 1.0, 1.0, 1.0),
              child: Image(
                image: img,
                width: kCharSize,
                height: kCharSize,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                const Icon(Icons.error, size: kCharSize),
              ),
            ),
            const SizedBox(width: kRowGap),
            Container(
              width: kTextWidth,
              height: kRowHeight,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24, width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: kTextTitleSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (desc.isNotEmpty)
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: kTextDescSize,
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _wrapAngle(double a) {
    while (a <= -pi) a += 2 * pi;
    while (a > pi) a -= 2 * pi;
    return a;
  }
}

/* ────────────────────────────────────────────────────────────────────────────
 * 배경 이펙트
 * ────────────────────────────────────────────────────────────────────────────*/
class _LightRays extends StatelessWidget {
  final AnimationController controller;
  const _LightRays({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) =>
          CustomPaint(painter: _LightRaysPainter(controller.value)),
    );
  }
}

class _LightRaysPainter extends CustomPainter {
  final double t;
  _LightRaysPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final shader = LinearGradient(
      colors: [
        Colors.white.withValues(alpha: 0.18),
        Colors.white.withValues(alpha: 0.0),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final paint = Paint()..shader = shader;

    const count = 3;
    for (int i = 0; i < count; i++) {
      final x = size.width * (0.2 + 0.3 * i) + sin(t * 2 * pi + i) * 20;
      final path = Path()
        ..moveTo(x - 40, 0)
        ..lineTo(x + 40, 0)
        ..lineTo(x + 80, size.height)
        ..lineTo(x - 80, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LightRaysPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _Waves extends StatelessWidget {
  final AnimationController controller;
  const _Waves({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) =>
          CustomPaint(painter: _WavesPainter(controller.value)),
    );
  }
}

class _WavesPainter extends CustomPainter {
  final double t;
  _WavesPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (double y = size.height * 0.25; y < size.height; y += 80) {
      final path = Path();
      for (double x = 0; x <= size.width; x += 10) {
        final dy = sin((x / size.width * 2 * pi) + (t * 2 * pi)) * 6;
        final ny = y + dy;
        if (x == 0) {
          path.moveTo(x, ny);
        } else {
          path.lineTo(x, ny);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavesPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _Bubbles extends StatelessWidget {
  final AnimationController controller;
  final int density;

  const _Bubbles({required this.controller, this.density = 10});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final size = MediaQuery.of(context).size;
        final widgets = <Widget>[];
        for (int i = 0; i < density; i++) {
          widgets.add(_Bubble(
            controllerValue: controller.value,
            seed: i * 997,
            area: size,
          ));
        }
        return Stack(children: widgets);
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  final double controllerValue;
  final int seed;
  final Size area;

  const _Bubble({
    required this.controllerValue,
    required this.seed,
    required this.area,
  });

  @override
  Widget build(BuildContext context) {
    final r = Random(seed);
    final baseX = r.nextDouble() * area.width;
    final baseY = r.nextDouble() * area.height;
    final speed = 0.35 + (seed % 30) / 100.0;
    final radius = 2.0 + (seed % 6).toDouble(); // 2~7
    final ampX = 8 + (seed % 18);

    final y = (baseY - controllerValue * area.height * speed) % area.height;
    final x = baseX + sin(controllerValue * 2 * pi * speed + seed) * ampX;

    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.18),
          border: Border.all(color: Colors.white24, width: 0.8),
        ),
      ),
    );
  }
}
