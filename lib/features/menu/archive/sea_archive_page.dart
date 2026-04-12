// File: sea_archive_page.dart
// 🌊 Mindrium SeaArchivePage — Immersive Aquarium with following speech bubble
import 'dart:math';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/worry_groups_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/features/menu/archive/archived_diary_screen.dart';
import 'package:gad_app_team/utils/server_datetime.dart';
import 'package:gad_app_team/features/menu/archive/character_battle.dart';

class SeaArchivePage extends StatefulWidget {
  const SeaArchivePage({super.key});

  @override
  State<SeaArchivePage> createState() => _SeaArchivePageState();
}

class _SeaArchivePageState extends State<SeaArchivePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  FishFieldController? _fieldController;
  int _lastCount = 0;
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final WorryGroupsApi _worryGroupsApi = WorryGroupsApi(_apiClient);
  Future<List<Map<String, dynamic>>>? _groupsFuture;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _groupsFuture = _loadGroups();
    _startComfortMessageLoop();
  }

  Future<List<Map<String, dynamic>>> _loadGroups() async {
    final access = await _tokens.access;
    if (access == null) return [];
    try {
      // 기본 조회는 archived != true 그룹만 내려옴
      final groups = await _worryGroupsApi.listWorryGroups();

      final enriched = await Future.wait(
        groups.map((group) async {
          final rawGroupId = group['group_id'];
          final groupId = rawGroupId?.toString() ?? '';
          if (groupId.isEmpty) return group;

          try {
            final response = await _apiClient.dio.get(
              '/diaries',
              queryParameters: {
                'group_id': groupId,
                'include_drafts': true,
                // 목록 화면과 동일한 기준으로 집계해야 점수/개수가 일치한다.
                'include_auto': false,
              },
            );

            final rawList = response.data as List? ?? const [];
            final diaries =
                rawList
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();

            double sudSum = 0.0;
            for (final diary in diaries) {
              final raw = diary['latest_sud'];
              if (raw is num) {
                sudSum += raw.toDouble().clamp(0.0, 10.0);
              } else if (raw is String) {
                final parsed = double.tryParse(raw);
                if (parsed != null) {
                  sudSum += parsed.clamp(0.0, 10.0);
                }
              }
            }

            final avgSud =
                diaries.isEmpty
                    ? null
                    : sudSum / diaries.length;

            return {
              ...group,
              'avg_sud': avgSud,
              'diary_count': diaries.length,
            };
          } catch (_) {
            return group;
          }
        }),
      );

      return enriched;
    } catch (e) {
      debugPrint('worry_groups(archived=false) 로드 실패: $e');
      return [];
    }
  }

  void _startComfortMessageLoop() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 5));

      if (_fieldController == null) continue;

      final fishCount = _fieldController!.count;

      if (fishCount == 0) continue;

      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final bottomSafe = padding.bottom;
    final topSafe = padding.top;

    //하단 네비 게이 높이를 직접 지정 (고정값)
    const double navBarHeight = 64.0; // 아이콘 + padding 고려

    const double guideTextTop = 60.0;
    const double guideTextHeight = 80.0;
    final double guideTopWithSafe = guideTextTop + topSafe;
    final double avoidTop = guideTopWithSafe + guideTextHeight;
    final double avoidBottom = navBarHeight + bottomSafe;
    final fishArea = Size(size.width, size.height - avoidBottom);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          //배경
          Positioned.fill(
            child: Image.asset(
              'assets/image/sea_archive_bg.png',
              fit: BoxFit.cover,
            ),
          ),

          //물고기 필드
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _groupsFuture,
            builder: (context, snap) {
              final groups = snap.data ?? [];
              _fieldController ??= FishFieldController(count: groups.length);
              if (_lastCount != groups.length) {
                _fieldController = FishFieldController(count: groups.length);
                _lastCount = groups.length;
              }

              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (groups.isEmpty) {
                return const Center(
                  child: Text(
                    '아직 아카이브된 캐릭터가 없어요.',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              return Padding(
                padding: EdgeInsets.only(bottom: avoidBottom),
                child: Stack(
                  children: [
                    for (int i = 0; i < groups.length; i++)
                      _SmoothFish(
                        index: i,
                        data: groups[i],
                        area: fishArea,
                        avoidBottom: 64,
                        // 오버레이(그룹명/SUD바)가 캐릭터 위에 뜨므로 상단 여유를 추가
                        avoidTop: avoidTop + 34,
                        field: _fieldController!,
                        onTap: (img, data) {
                          showDialog(
                            context: context,
                            builder:
                                (_) => _FishInfoPopup(
                                  image: img,
                                  data: data,
                                  onResolveCompleted:
                                      () => setState(
                                        () => _groupsFuture = _loadGroups(),
                                      ),
                                ),
                          );
                        },
                      ),

                    //안내 문구 (status bar 아래에 배치)
                    Positioned(
                      top: guideTopWithSafe,
                      left: 20,
                      right: 20,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            '물고기를 클릭하면 내 불안을 확인할 수 있어요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF004A6E),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          //하단 네비게이션 바
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _GlassNavigationBar(),
          ),
        ],
      ),
    );
  }
}

//controller
class FishFieldController {
  final int count;
  final Map<int, Offset> _positions = {};
  final Map<int, Rect> _bounds = {};

  FishFieldController({required this.count});

  void updatePosition(int index, Offset pos) {
    _positions[index] = pos;
  }

  Offset? getPosition(int index) => _positions[index];

  void setBounds(int index, Rect rect) {
    _bounds[index] = rect;
  }

  Rect? getBounds(int index) => _bounds[index];
}

//fish animation
class _SmoothFish extends StatefulWidget {
  final int index;
  final Map<String, dynamic> data;
  final Size area;
  final double avoidBottom;
  final double avoidTop;
  final FishFieldController field;
  final void Function(ImageProvider, Map<String, dynamic>) onTap;

  const _SmoothFish({
    required this.index,
    required this.data,
    required this.area,
    required this.field,
    required this.onTap,
    this.avoidBottom = 0,
    this.avoidTop = 0,
  });

  @override
  State<_SmoothFish> createState() => _SmoothFishState();
}

class _SmoothFishState extends State<_SmoothFish>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  late final Random _r;
  late Offset _pos;
  late Offset _vel;
  bool _facingRight = true;
  Duration? _lastTick;
  static const double speed = 35.0;
  static const double fishSize = 85.0;

  double get _maxX => (widget.area.width - fishSize).clamp(0, double.infinity);

  // 상단 금지구역(안내문구) 아래부터만 유영
  double get _minY {
    final upper = max(0.0, widget.area.height - fishSize); // y의 이론상 최댓값
    return widget.avoidTop.clamp(0.0, upper).toDouble();
  }

  double get _maxY {
    final limit = widget.area.height - fishSize - widget.avoidBottom;
    return max(_minY, limit).clamp(0, double.infinity); // 항상 _minY ≤ _maxY 보장
  }

  @override
  void initState() {
    super.initState();
    _r = Random(widget.index * 131);
    _initPositionAndVelocity();
    _ticker =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(_onTick)
          ..repeat();
  }

  void _initPositionAndVelocity() {
    // 스폰도 _minY ~ _maxY*0.7 구간에서만
    final usable = max(0.0, _maxY - _minY);
    final spawnRange = usable * 0.7;
    final spawnY =
        _minY + (_r.nextDouble() * (spawnRange <= 0 ? 0.0 : spawnRange));

    _pos = Offset(_r.nextDouble() * (_maxX <= 0 ? 0.0 : _maxX), spawnY);
    _vel = Offset.fromDirection(_r.nextDouble() * 2 * pi, speed);
  }

  @override
  void didUpdateWidget(covariant _SmoothFish oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 경계 변화 시 현재 위치를 안전 구간으로 클램프
    if (oldWidget.avoidBottom != widget.avoidBottom ||
        oldWidget.area != widget.area ||
        // avoidTop 변화도 감지
        (oldWidget.avoidTop != widget.avoidTop)) {
      _pos = Offset(_pos.dx.clamp(0, _maxX), _pos.dy.clamp(_minY, _maxY));
    }
  }

  void _onTick() {
    final now = _ticker.lastElapsedDuration ?? Duration.zero;
    final dt =
        (_lastTick == null)
            ? 1 / 60
            : ((now - _lastTick!).inMicroseconds / 1e6).clamp(0.0, 1 / 30.0);
    _lastTick = now;

    var next = _pos + _vel * dt;

    // 좌우 벽
    if (next.dx < 0 || next.dx > _maxX) {
      _vel = Offset(-_vel.dx, _vel.dy);
      next = Offset(next.dx.clamp(0, _maxX), next.dy);
    }
    // 상단/하단 경계: _minY ~ _maxY
    if (next.dy < _minY || next.dy > _maxY) {
      _vel = Offset(_vel.dx, -_vel.dy);
      next = Offset(next.dx, next.dy.clamp(_minY, _maxY));
    }

    _facingRight = _vel.dx >= 0;

    _pos = next;
    widget.field
      ..updatePosition(widget.index, _pos)
      ..setBounds(
        widget.index,
        Rect.fromLTWH(_pos.dx, _pos.dy, fishSize, fishSize),
      );

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final title = (data['group_title'] ?? '그룹').toString();
    final sudAverage = _resolveSudAverage(data);
    final sudRatio = sudAverage == null ? 0.0 : (sudAverage / 10).clamp(0.0, 1.0);
    final barColor = _sudColor(sudAverage);
    final sudTextColor = _sudTextColor(sudAverage);
    final img = AssetImage(
      'assets/image/character${data['character_id'] ?? data['group_id'] ?? 1}.png',
    );

    return Positioned(
      left: _pos.dx,
      top: _pos.dy,
      child: RepaintBoundary(
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => widget.onTap(img, data),
          child: SizedBox(
            width: fishSize,
            height: fishSize,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(
                    _facingRight ? 1.0 : -1.0,
                    1.0,
                    1.0,
                  ),
                  child: Image(image: img, width: fishSize, height: fishSize),
                ),
                Positioned(
                  top: -34,
                  left: -8,
                  right: -8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF4FAFF),
                          shadows: [
                            Shadow(
                              color: Color(0x7A16384C),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 0.1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCCFFFFFF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x99DCEAF5)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 3.5,
                                  value: sudRatio,
                                  backgroundColor: const Color(0xFFD7E2EB),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    barColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              sudAverage == null
                                  ? '-/10.0'
                                  : '${sudAverage.toStringAsFixed(1)}/10.0',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: sudTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  double? _resolveSudAverage(Map<String, dynamic> data) {
    final candidates = [
      data['avg_sud'],
      data['sud_avg'],
      data['average_sud'],
      data['mean_sud'],
      data['sud_mean'],
      data['latest_sud'],
    ];

    for (final value in candidates) {
      final parsed = _asDouble(value);
      if (parsed != null) {
        return parsed.clamp(0.0, 10.0);
      }
    }
    return null;
  }

  Color _sudColor(double? sudAverage) {
    if (sudAverage == null) return const Color(0xFF9CB1C5);
    if (sudAverage >= 8.0) return const Color(0xFFE4686C);
    if (sudAverage >= 3.0) return const Color(0xFFF4C159);
    return const Color(0xFF5B9FD3);
  }

  Color _sudTextColor(double? sudAverage) {
    if (sudAverage == null) return const Color(0xFF5D7184);
    if (sudAverage >= 8.0) return const Color(0xFFC34D58);
    if (sudAverage >= 3.0) return const Color(0xFFAD7F1E);
    return const Color(0xFF2F6FA1);
  }
}

class _FishInfoPopup extends StatelessWidget {
  final ImageProvider image;
  final Map<String, dynamic> data;
  final VoidCallback? onResolveCompleted;

  const _FishInfoPopup({
    required this.image,
    required this.data,
    this.onResolveCompleted,
  });

  DateTime? _asDateTime(dynamic value) {
    return parseServerDateTime(value);
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '정보 없음';

    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year.$month.$day';
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  double? _resolveSudAverage(Map<String, dynamic> raw) {
    final candidates = [
      raw['avg_sud'],
      raw['sud_avg'],
      raw['average_sud'],
      raw['mean_sud'],
      raw['sud_mean'],
      raw['latest_sud'],
    ];
    for (final value in candidates) {
      final parsed = _asDouble(value);
      if (parsed != null) return parsed.clamp(0.0, 10.0);
    }
    return null;
  }

  Color _sudColor(double? sudAverage) {
    if (sudAverage == null) return const Color(0xFF9CB1C5);
    if (sudAverage >= 7.0) return const Color(0xFFE4686C);
    if (sudAverage >= 4.0) return const Color(0xFFF4C159);
    return const Color(0xFF5B9FD3);
  }

  Color _sudTextColor(double? sudAverage) {
    if (sudAverage == null) return const Color(0xFF5D7184);
    if (sudAverage >= 7.0) return const Color(0xFFC34D58);
    if (sudAverage >= 4.0) return const Color(0xFFAD7F1E);
    return const Color(0xFF2F6FA1);
  }

  Widget _buildDescriptionText(String desc) {
    final description = desc.isEmpty ? '저장된 설명이 없습니다.' : desc;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF5B9FD3).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF1B405C),
                height: 1.58,
                fontWeight: desc.isEmpty ? FontWeight.w500 : FontWeight.w600,
                fontFamily: 'Noto Sans KR',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openArchivedDiaries(
    BuildContext context, {
    required String groupId,
    required String title,
    required String desc,
    required int characterId,
    required DateTime createdAt,
    required DateTime archivedAt,
  }) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ArchivedDiaryScreen(
              groupId: groupId,
              groupTitle: title,
              groupContents: desc,
              characterId: characterId,
              createdAt: createdAt,
              archivedAt: archivedAt,
            ),
      ),
    );
  }

  Future<void> _startResolveFlow(
    BuildContext context, {
    required String groupId,
    required String characterName,
    required String characterDescription,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop(); // 팝업 닫기

    final status = await _resolveAlternativeThoughtStatus(groupId);
    if (!status.hasAlternativeThoughts) {
      final targetDiaryId = status.targetDiaryId;
      if (targetDiaryId == null || targetDiaryId.isEmpty) {
        ScaffoldMessenger.of(
          navigator.context,
        ).showSnackBar(const SnackBar(content: Text('대체 생각을 작성할 일기가 없어요.')));
        return;
      }
      final result = await navigator.pushNamed(
        '/apply_alt_thought',
        arguments: {
          'abcId': targetDiaryId,
          'origin': 'apply',
          'returnAfterSave': true,
        },
      );
      if (result != true) return;
    }

    await navigator.push(
      MaterialPageRoute(
        builder:
            (_) => PokemonBattleDeletePage(
              groupId: groupId,
              characterName: characterName,
              characterDescription: characterDescription,
            ),
      ),
    );
    onResolveCompleted?.call();
  }

  Future<({bool hasAlternativeThoughts, String? targetDiaryId})>
  _resolveAlternativeThoughtStatus(String groupId) async {
    final tokens = TokenStorage();
    final client = ApiClient(tokens: tokens);
    try {
      final response = await client.dio.get(
        '/diaries',
        queryParameters: {'group_id': groupId},
      );
      final diaries = (response.data as List?)?.cast<Map<String, dynamic>>() ?? const [];
      if (diaries.isEmpty) {
        return (hasAlternativeThoughts: false, targetDiaryId: null);
      }
      String? latestDiaryId;
      for (final diary in diaries) {
        latestDiaryId ??= diary['diary_id']?.toString();
        if (_hasAlternativeThought(diary['alternative_thoughts'])) {
          return (hasAlternativeThoughts: true, targetDiaryId: latestDiaryId);
        }
      }
      return (hasAlternativeThoughts: false, targetDiaryId: latestDiaryId);
    } on DioException {
      return (hasAlternativeThoughts: false, targetDiaryId: null);
    } catch (_) {
      return (hasAlternativeThoughts: false, targetDiaryId: null);
    }
  }

  Future<int> _fetchDiaryCount(String groupId) async {
    if (groupId.isEmpty) return 0;
    final tokens = TokenStorage();
    final client = ApiClient(tokens: tokens);
    try {
      final response = await client.dio.get(
        '/diaries',
        queryParameters: {
          'group_id': groupId,
          'include_drafts': true,
        },
      );
      final diaries =
          (response.data as List?)?.cast<Map<String, dynamic>>() ?? const [];
      return diaries.length;
    } catch (_) {
      return _asInt(data['diary_count']) ?? 0;
    }
  }

  bool _hasAlternativeThought(dynamic value) {
    if (value is List) {
      return value.any((e) => e.toString().trim().isNotEmpty);
    }
    if (value is String) {
      return value.trim().isNotEmpty;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final dialogMaxHeight = min(620.0, MediaQuery.of(context).size.height - 56);
    final title = (data['group_title'] ?? '이름 없는 캐릭터').toString();
    final desc = (data['group_contents'] ?? '').toString();
    final sudAverage = _resolveSudAverage(data);
    final sudRatio = sudAverage == null ? 0.0 : (sudAverage / 10).clamp(0.0, 1.0);
    final sudBarColor = _sudColor(sudAverage);
    final sudTextColor = _sudTextColor(sudAverage);
    final archivedAt =
        _asDateTime(data['archived_at']) ?? _asDateTime(data['updated_at']);
    final createdAt = _asDateTime(data['created_at']);
    final diaryCount = _asInt(data['diary_count']) ?? 0;
    final groupId = (data['group_id'] ?? '').toString();
    final characterId = _asInt(data['character_id']) ?? 1;
    final resolvedCreatedAt = createdAt ?? DateTime.now();
    final resolvedArchivedAt = archivedAt ?? resolvedCreatedAt;
    final canResolve =
        groupId.isNotEmpty &&
        groupId != 'group_example' &&
        sudAverage != null &&
        sudAverage <= 3.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: BoxConstraints(maxWidth: 360, maxHeight: dialogMaxHeight),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24, width: 1.2),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 62,
                      height: 62,
                      child: Image(
                        image: image,
                        fit: BoxFit.contain,
                        errorBuilder:
                            (_, __, ___) => const Icon(
                              Icons.catching_pokemon,
                              size: 30,
                              color: Color(0xFF0E2C48),
                            ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 19,
                              color: Color(0xFF0E2C48),
                              height: 1.3,
                              letterSpacing: -0.3,
                              fontFamily: 'Noto Sans KR',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF1FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFD6E2FF)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: Color(0xFF496AC6),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '생성일: ${_formatDate(createdAt)}',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF496AC6),
                                    fontFamily: 'Noto Sans KR',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDescriptionText(desc),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    '불안 점수 평균',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF456178),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xCCFFFFFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x99DCEAF5)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 5,
                            value: sudRatio,
                            backgroundColor: const Color(0xFFD7E2EB),
                            valueColor: AlwaysStoppedAnimation<Color>(sudBarColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        sudAverage == null
                            ? '-/10.0'
                            : '${sudAverage.toStringAsFixed(1)}/10.0',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: sudTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF5FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDCE8FF)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '그룹의 일기 보러가기',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4659C2),
                          ),
                        ),
                      ),
                      FutureBuilder<int>(
                        future: _fetchDiaryCount(groupId),
                        initialData: diaryCount,
                        builder: (context, snapshot) {
                          final resolvedCount = snapshot.data ?? diaryCount;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCE8FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$resolvedCount개',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4659C2),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap:
                            groupId.isEmpty
                                ? null
                                : () => _openArchivedDiaries(
                                  context,
                                  groupId: groupId,
                                  title: title,
                                  desc: desc,
                                  characterId: characterId,
                                  createdAt: resolvedCreatedAt,
                                  archivedAt: resolvedArchivedAt,
                                ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color:  Color(0xFF5B9FD3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (canResolve) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          () => _startResolveFlow(
                            context,
                            groupId: groupId,
                            characterName: title,
                            characterDescription: desc,
                          ),
                      icon: const Icon(Icons.auto_fix_high_rounded),
                      label: const Text('해결하기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2F8FD8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6FD3D4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//하단 네비게이션
class _GlassNavigationBar extends StatelessWidget {
  const _GlassNavigationBar(); // ✅ onHeight 제거됨

  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.home_rounded,
      Icons.school_rounded,
      Icons.water_rounded,
      Icons.settings_rounded,
    ];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          color: Colors.white.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(icons.length, (i) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: i == 2 ? 1.25 : 1.0),
                duration: const Duration(milliseconds: 300),
                builder:
                    (_, scale, child) => Transform.scale(
                      scale: scale,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient:
                              i == 2
                                  ? const LinearGradient(
                                    colors: [
                                      Color(0xFF89D4F5),
                                      Color(0xFFB2F2E8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                  : null,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          icons[i],
                          size: 28,
                          color: i == 2 ? Colors.white : Colors.white70,
                        ),
                      ),
                    ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
