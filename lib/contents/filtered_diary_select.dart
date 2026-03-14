import 'dart:async';

import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/contents/apply_flow/apply_flow_route_data.dart';
import 'package:dio/dio.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/primary_action_button.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/api/sud_api.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

class DiarySelectScreen extends StatefulWidget {
  const DiarySelectScreen({super.key});

  @override
  State<DiarySelectScreen> createState() => _DiarySelectScreenState();
}

class _DiarySelectScreenState extends State<DiarySelectScreen> {
  final Set<String> _selectedIds = {};
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final DiariesApi _diariesApi = DiariesApi(_apiClient);
  late final SudApi _sudApi = SudApi(_apiClient);
  bool _didLoad = false;
  String? _groupId;
  List<Map<String, dynamic>> _docs = const [];
  bool _isLoading = true;
  bool _isRefiningOrder = false;
  String? _error;
  bool _submitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;

    final route = ApplyFlowRouteData.read(
      context,
      rawArgs: ModalRoute.of(context)?.settings.arguments,
      notify: false,
    );
    _groupId = route.groupId;

    _loadFilteredDiaries();
  }

  /// DiaryChip 리스트에서 label만 뽑는 헬퍼
  List<String> _chipLabels(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>() // DiaryChip JSON: {label, chip_id, category}
          .map((m) => m['label']?.toString().trim())
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toList();
    }
    if (raw is Map) {
      final label = raw['label']?.toString().trim();
      return label == null || label.isEmpty ? const [] : [label];
    }
    return const [];
  }

  String _buildBelief(dynamic raw) {
    final labels = _chipLabels(raw);
    return labels.join(', ');
  }

  String _buildConsequence(Map<String, dynamic> diary) {
    final pieces = <String>[];

    for (final key in [
      'consequence_physical',
      'consequence_emotion',
      'consequence_action',
    ]) {
      final labels = _chipLabels(diary[key]);
      pieces.addAll(labels);
    }

    return pieces.join(', ');
  }

  String _buildActivationTitle(dynamic activationRaw) {
    if (activationRaw is Map &&
        (activationRaw['label']?.toString().trim().isNotEmpty ?? false)) {
      return activationRaw['label'].toString().trim();
    }
    if (activationRaw is String && activationRaw.trim().isNotEmpty) {
      return activationRaw.trim();
    }
    return '(제목 없음)';
  }

  double? _asDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.trim());
    return null;
  }

  Map<String, dynamic>? _normalizeLocTime(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    if (raw is List) {
      final mapped =
          raw
              .whereType<Map>()
              .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
              .toList();
      return mapped.isEmpty ? null : mapped.last.cast<String, dynamic>();
    }
    return null;
  }

  int? _parseTimeMinutes(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(value);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  int _circularMinutesDiff(int baseMinutes, int targetMinutes) {
    final diff = (baseMinutes - targetMinutes).abs();
    return diff <= 720 ? diff : 1440 - diff;
  }

  double? _resolveDistanceMeters(
    Map<String, dynamic> diary,
    Position? current,
  ) {
    if (current == null) return null;
    final locTime = _normalizeLocTime(diary['loc_time'] ?? diary['alarms']);
    final lat = _asDouble(locTime?['latitude']);
    final lng = _asDouble(locTime?['longitude']);
    if (lat == null || lng == null) return null;
    return Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      lat,
      lng,
    );
  }

  int? _resolveTimeGapMinutes(Map<String, dynamic> diary, int nowMinutes) {
    final locTime = _normalizeLocTime(diary['loc_time'] ?? diary['alarms']);
    final diaryMinutes = _parseTimeMinutes(locTime?['time']);
    if (diaryMinutes == null) return null;
    return _circularMinutesDiff(nowMinutes, diaryMinutes);
  }

  DateTime? _resolveCreatedAt(Map<String, dynamic> diary) {
    final raw = diary['created_at'] ?? diary['createdAt'];
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  Future<Position?> _tryGetCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }

  bool _isSelectableDiary(Map<String, dynamic> diary) {
    final latestSud = diary['latest_sud'];
    if (latestSud == null) return true;
    if (latestSud is num) return latestSud > 2;
    if (latestSud is String) {
      final parsed = num.tryParse(latestSud);
      return parsed != null && parsed > 2;
    }
    return false;
  }

  List<Map<String, dynamic>> _buildFilteredDocs(
    List<Map<String, dynamic>> diaries,
  ) {
    final filtered = <Map<String, dynamic>>[];
    for (final diary in diaries) {
      if (_isSelectableDiary(diary)) {
        filtered.add(Map<String, dynamic>.from(diary));
      }
    }
    return filtered;
  }

  int _compareByRecentFirst(Map<String, dynamic> a, Map<String, dynamic> b) {
    final createdA = _resolveCreatedAt(a);
    final createdB = _resolveCreatedAt(b);
    if (createdA == null && createdB != null) return 1;
    if (createdA != null && createdB == null) return -1;
    if (createdA != null && createdB != null) {
      final createdCompare = createdB.compareTo(createdA);
      if (createdCompare != 0) return createdCompare;
    }
    return 0;
  }

  List<Map<String, dynamic>> _withSortHints(
    List<Map<String, dynamic>> diaries, {
    required Position? currentPosition,
    required int nowMinutes,
  }) {
    return diaries
        .map(
          (diary) => {
            ...diary,
            '_sort_distance_m': _resolveDistanceMeters(diary, currentPosition),
            '_sort_time_gap_m': _resolveTimeGapMinutes(diary, nowMinutes),
          },
        )
        .toList();
  }

  int _compareByDistanceTimeThenRecent(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final distanceA = a['_sort_distance_m'] as double?;
    final distanceB = b['_sort_distance_m'] as double?;

    if (distanceA == null && distanceB != null) return 1;
    if (distanceA != null && distanceB == null) return -1;
    if (distanceA != null && distanceB != null) {
      final cmpDistance = distanceA.compareTo(distanceB);
      if (cmpDistance != 0) return cmpDistance;
    }

    final timeGapA = a['_sort_time_gap_m'] as int?;
    final timeGapB = b['_sort_time_gap_m'] as int?;

    if (timeGapA == null && timeGapB != null) return 1;
    if (timeGapA != null && timeGapB == null) return -1;
    if (timeGapA != null && timeGapB != null) {
      final cmpTimeGap = timeGapA.compareTo(timeGapB);
      if (cmpTimeGap != 0) return cmpTimeGap;
    }

    return _compareByRecentFirst(a, b);
  }

  List<Map<String, dynamic>> _withoutSortHints(
    List<Map<String, dynamic>> docs,
  ) {
    return docs.map((diary) {
      final copy = Map<String, dynamic>.from(diary);
      copy.remove('_sort_distance_m');
      copy.remove('_sort_time_gap_m');
      return copy;
    }).toList();
  }

  bool _hasSameOrder(
    List<Map<String, dynamic>> previous,
    List<Map<String, dynamic>> next,
  ) {
    if (previous.length != next.length) return false;
    for (var i = 0; i < previous.length; i++) {
      final prevId = previous[i]['diary_id']?.toString();
      final nextId = next[i]['diary_id']?.toString();
      if (prevId != nextId) return false;
    }
    return true;
  }

  /// 그룹이 전달되면 해당 그룹만, 아니면 전체 일기 중
  /// latest_sud 가 null 이거나 > 2 인 일기를 대상으로 먼저 최신순으로 빠르게 보여주고,
  /// 이후 위치/시간 기준 정렬을 비동기로 덧씌운다.
  Future<void> _loadFilteredDiaries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final diaries = await _diariesApi.listDiaries(groupId: _groupId);
      final filtered = _buildFilteredDocs(diaries)..sort(_compareByRecentFirst);

      if (!mounted) return;
      setState(() {
        _docs = filtered;
        _isLoading = false;
      });

      unawaited(_refineDiaryOrdering());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refineDiaryOrdering() async {
    if (_docs.isEmpty || _isRefiningOrder) return;

    setState(() => _isRefiningOrder = true);
    try {
      final currentPosition = await _tryGetCurrentPosition();
      if (!mounted) return;
      if (currentPosition == null) {
        setState(() => _isRefiningOrder = false);
        return;
      }

      final now = DateTime.now();
      final nowMinutes = now.hour * 60 + now.minute;
      final enriched = _withSortHints(
        _docs,
        currentPosition: currentPosition,
        nowMinutes: nowMinutes,
      )..sort(_compareByDistanceTimeThenRecent);
      final refined = _withoutSortHints(enriched);

      if (!mounted) return;
      setState(() {
        _isRefiningOrder = false;
        if (!_hasSameOrder(_docs, refined)) {
          _docs = refined;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRefiningOrder = false);
    }
  }

  Future<void> _handleSelectedDiary(Map<String, dynamic> args) async {
    if (_submitting || _selectedIds.isEmpty) return;
    final selectedId = _selectedIds.first;

    final route = ApplyFlowRouteData.read(
      context,
      rawArgs: args,
      notify: false,
    );
    final flow = route.flow;
    final beforeSud = route.beforeSud;
    final origin = route.origin;
    if (beforeSud == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('먼저 불안 점수를 입력해주세요.')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final sudRes = await _sudApi.createSudScore(
        diaryId: selectedId,
        beforeScore: beforeSud,
      );
      final sudId = sudRes['sud_id']?.toString();

      final selectedDiary = _docs.cast<Map<String, dynamic>?>().firstWhere(
        (doc) => doc?['diary_id']?.toString() == selectedId,
        orElse: () => null,
      );
      String groupId = selectedDiary?['group_id']?.toString() ?? '';
      try {
        if (groupId.isEmpty) {
          final diary = await _diariesApi.getDiary(selectedId);
          groupId = diary['group_id']?.toString() ?? '';
        }
      } catch (_) {
        if (groupId.isEmpty) {
          groupId = '';
        }
      }

      if (!mounted) return;
      flow.setOrigin(origin);
      flow.setBeforeSud(beforeSud);
      flow.setDiaryId(selectedId);
      flow.setGroupId(groupId);
      if (sudId != null && sudId.isNotEmpty) {
        flow.setSudId(sudId);
      }

      final nextArgs = route.mergedArgs(
        extra: {
          'origin': origin,
          'abcId': selectedId,
          'groupId': groupId,
          'beforeSud': beforeSud,
          if (sudId != null && sudId.isNotEmpty) 'sudId': sudId,
        },
      );

      final completedWeeks = context.read<UserProvider>().lastCompletedWeek;
      final highSudRoute =
          completedWeeks >= 4 ? '/relax_or_alternative' : '/relax_yes_or_no';
      final nextRoute = beforeSud > 2 ? highSudRoute : '/diary_relax_home';
      Navigator.pushReplacementNamed(context, nextRoute, arguments: nextArgs);
    } on DioException catch (e) {
      final message =
          e.response?.data is Map
              ? e.response?.data['detail']?.toString()
              : e.message;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('SUD 저장 실패: ${message ?? '오류'}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('SUD 저장 실패: $e')));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      } else {
        _submitting = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = castApplyFlowArgs(ModalRoute.of(context)?.settings.arguments);
    final selectedId = _selectedIds.isEmpty ? null : _selectedIds.first;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const CustomAppBar(title: '일기 선택하기'),
      body: Stack(
        children: [
          // 🌊 배경 이미지 + 오션 그라데이션 오버레이
          Positioned.fill(
            child: Image.asset(
              'assets/image/eduhome.png',
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.35),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xCCB3E5FC),
                  Color(0x99E1F5FE),
                  Color(0x66FFFFFF),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          _DiarySelectBody(
            docs: _docs,
            isLoading: _isLoading,
            isRefiningOrder: _isRefiningOrder,
            error: _error,
            groupId: _groupId,
            selectedId: selectedId,
            buildTitle: _buildActivationTitle,
            buildBelief: _buildBelief,
            buildConsequence: _buildConsequence,
            onSelectDiary: (diaryId) {
              setState(() {
                _selectedIds.clear();
                if (diaryId.isNotEmpty) {
                  _selectedIds.add(diaryId);
                }
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: PrimaryActionButton(
            text: _submitting ? '저장 중...' : '선택하기',
            onPressed:
                (_submitting || _selectedIds.isEmpty)
                    ? null
                    : () => _handleSelectedDiary(args),
          ),
        ),
      ),
    );
  }
}

class _DiarySelectBody extends StatelessWidget {
  const _DiarySelectBody({
    required this.docs,
    required this.isLoading,
    required this.isRefiningOrder,
    required this.error,
    required this.groupId,
    required this.selectedId,
    required this.buildTitle,
    required this.buildBelief,
    required this.buildConsequence,
    required this.onSelectDiary,
  });

  final List<Map<String, dynamic>> docs;
  final bool isLoading;
  final bool isRefiningOrder;
  final String? error;
  final String? groupId;
  final String? selectedId;
  final String Function(dynamic activationRaw) buildTitle;
  final String Function(dynamic raw) buildBelief;
  final String Function(Map<String, dynamic> diary) buildConsequence;
  final ValueChanged<String> onSelectDiary;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '일기를 불러오지 못했습니다.\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      );
    }
    if (docs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            (groupId != null && groupId!.isNotEmpty)
                ? '해당 그룹에 SUD 점수가 3점 이상인 일기가 없습니다.'
                : '선택 가능한 일기가 없습니다.',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black54,
              fontFamily: 'Noto Sans KR',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 120),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final diary = docs[index];
            final diaryId = diary['diary_id']?.toString() ?? '';
            return _DiaryOptionCard(
              title: buildTitle(diary['activation']),
              belief: buildBelief(diary['belief']),
              consequence: buildConsequence(diary),
              selected: selectedId == diaryId,
              onTap: () => onSelectDiary(diaryId),
            );
          },
        ),
        if (isRefiningOrder) const _DiaryOrderRefiningBanner(),
      ],
    );
  }
}

class _DiaryOptionCard extends StatelessWidget {
  const _DiaryOptionCard({
    required this.title,
    required this.belief,
    required this.consequence,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String belief;
  final String consequence;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: selected ? const Color(0xFF47A6FF) : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 4, right: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        selected
                            ? const Color(0xFF47A6FF)
                            : Colors.grey.shade400,
                    width: 2,
                  ),
                  color: selected ? const Color(0xFF47A6FF) : Colors.white,
                ),
                child:
                    selected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '상황: $title',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Noto Sans KR',
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (belief.isNotEmpty)
                      Text(
                        '생각: $belief',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          fontFamily: 'Noto Sans KR',
                        ),
                      ),
                    if (consequence.isNotEmpty)
                      Text(
                        '결과: $consequence',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          fontFamily: 'Noto Sans KR',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiaryOrderRefiningBanner extends StatelessWidget {
  const _DiaryOrderRefiningBanner();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      right: 20,
      top: 56,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFD5E6F4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Text(
              '가까운 일기 순으로 정리하고 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5D748C),
                fontFamily: 'Noto Sans KR',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
