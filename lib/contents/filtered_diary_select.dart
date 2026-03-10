import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:dio/dio.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/primary_action_button.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/api/sud_api.dart';
import 'package:gad_app_team/data/apply_solve_provider.dart';
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
  bool _submitting = false;

  int? _asInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    if (raw is String) return int.tryParse(raw);
    return null;
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
      final mapped = raw
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

  double? _resolveDistanceMeters(Map<String, dynamic> diary, Position? current) {
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
    final raw = diary['created_at'];
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

  /// 그룹이 전달되면 해당 그룹만, 아니면 전체 일기 중
  /// latest_sud 가 null 이거나 > 2 인 일기를 대상으로
  /// 1) 현재 위치와의 거리 2) 현재 시간과의 차이 순서로 정렬
  Future<List<Map<String, dynamic>>> _loadFilteredDiaries(String? groupId) async {
    final normalizedGroupId = groupId?.trim();
    final diaries = await _diariesApi.listDiaries(
      groupId: (normalizedGroupId == null || normalizedGroupId.isEmpty)
          ? null
          : normalizedGroupId,
    );
    final currentPosition = await _tryGetCurrentPosition();
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final filtered = <Map<String, dynamic>>[];

    for (final diary in diaries) {
      final latestSud = diary['latest_sud'];
      if (latestSud == null) {
        filtered.add({
          ...diary,
          '_sort_distance_m': _resolveDistanceMeters(diary, currentPosition),
          '_sort_time_gap_m': _resolveTimeGapMinutes(diary, nowMinutes),
        });
        continue;
      }
      if (latestSud is num && latestSud > 2) {
        filtered.add({
          ...diary,
          '_sort_distance_m': _resolveDistanceMeters(diary, currentPosition),
          '_sort_time_gap_m': _resolveTimeGapMinutes(diary, nowMinutes),
        });
      } else if (latestSud is String) {
        final v = num.tryParse(latestSud);
        if (v != null && v > 2) {
          filtered.add({
            ...diary,
            '_sort_distance_m': _resolveDistanceMeters(diary, currentPosition),
            '_sort_time_gap_m': _resolveTimeGapMinutes(diary, nowMinutes),
          });
        }
      }
    }

    filtered.sort((a, b) {
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

      final createdA = _resolveCreatedAt(a);
      final createdB = _resolveCreatedAt(b);
      if (createdA == null && createdB != null) return 1;
      if (createdA != null && createdB == null) return -1;
      if (createdA != null && createdB != null) {
        return createdB.compareTo(createdA); // 최신순 fallback
      }

      return 0;
    });

    for (final diary in filtered) {
      diary.remove('_sort_distance_m');
      diary.remove('_sort_time_gap_m');
    }

    return filtered;
  }

  Future<void> _handleSelectedDiary(Map<dynamic, dynamic> args) async {
    if (_submitting || _selectedIds.isEmpty) return;
    final selectedId = _selectedIds.first;

    final flow = context.read<ApplyOrSolveFlow>()..syncFromArgs(args, notify: false);
    final beforeSud = _asInt(args['beforeSud']) ?? flow.beforeSud;
    final origin = flow.origin;
    if (beforeSud == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 불안 점수를 입력해주세요.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final sudRes = await _sudApi.createSudScore(
        diaryId: selectedId,
        beforeScore: beforeSud,
      );
      final sudId = sudRes['sud_id']?.toString();

      String groupId = '';
      try {
        final diary = await _diariesApi.getDiary(selectedId);
        groupId = diary['group_id']?.toString() ?? '';
      } catch (_) {
        groupId = '';
      }

      if (!mounted) return;
      flow.setOrigin(origin);
      flow.setBeforeSud(beforeSud);
      flow.setDiaryId(selectedId);
      flow.setGroupId(groupId);
      if (sudId != null && sudId.isNotEmpty) {
        flow.setSudId(sudId);
      }

      final nextArgs = <String, dynamic>{
        ...flow.toArgs(),
        'origin': origin,
        'abcId': selectedId,
        'groupId': groupId,
        'beforeSud': beforeSud,
        if (sudId != null && sudId.isNotEmpty) 'sudId': sudId,
      };

      final completedWeeks = context.read<UserProvider>().lastCompletedWeek;
      final highSudRoute =
          completedWeeks >= 4 ? '/relax_or_alternative' : '/relax_yes_or_no';
      final nextRoute = beforeSud > 2 ? highSudRoute : '/diary_relax_home';
      Navigator.pushReplacementNamed(context, nextRoute, arguments: nextArgs);
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? e.response?.data['detail']?.toString()
          : e.message;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SUD 저장 실패: ${message ?? '오류'}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SUD 저장 실패: $e')),
      );
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
    final args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
    final String? groupId = args['groupId'] as String?;

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

          // 🌿 콘텐츠 본문
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadFilteredDiaries(groupId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '일기를 불러오지 못했습니다.\n${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                );
              }
              final docs = snap.data ?? const [];
              if (docs.isEmpty) {
                final emptyText = (groupId != null && groupId.trim().isNotEmpty)
                    ? '해당 그룹에 SUD 점수가 3점 이상인 일기가 없습니다.'
                    : '선택 가능한 일기가 없습니다.';
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      emptyText,
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

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 100, 20, 120),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final diary = docs[index];

                  // ✅ 백엔드 스키마: "diary_id"
                  final diaryId = diary['diary_id']?.toString() ?? '';

                  // ✅ activation 은 DiaryChip(Map). label 사용
                  final activationRaw = diary['activation'];
                  String title;
                  if (activationRaw is Map &&
                      (activationRaw['label']?.toString().trim().isNotEmpty ??
                          false)) {
                    title = activationRaw['label'].toString().trim();
                  } else if (activationRaw is String &&
                      activationRaw.trim().isNotEmpty) {
                    title = activationRaw.trim();
                  } else {
                    title = '(제목 없음)';
                  }

                  final belief = _buildBelief(diary['belief']);
                  final consequence = _buildConsequence(diary);
                  final isSelected = _selectedIds.contains(diaryId);

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
                        color: isSelected
                            ? const Color(0xFF47A6FF)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        setState(() {
                          _selectedIds.clear();
                          if (diaryId.isNotEmpty) {
                            _selectedIds.add(diaryId);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              margin: const EdgeInsets.only(
                                top: 4,
                                right: 12,
                              ),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF47A6FF)
                                      : Colors.grey.shade400,
                                  width: 2,
                                ),
                                color: isSelected
                                    ? const Color(0xFF47A6FF)
                                    : Colors.white,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    )
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
                },
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: PrimaryActionButton(
            text: _submitting ? '저장 중...' : '선택하기',
            onPressed: (_submitting || _selectedIds.isEmpty)
                ? null
                : () => _handleSelectedDiary(args),
          ),
        ),
      ),
    );
  }
}
