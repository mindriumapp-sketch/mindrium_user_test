import 'package:dio/dio.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/primary_action_button.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';

class DiaryShowScreen extends StatefulWidget {
  final String? groupId;

  const DiaryShowScreen({super.key, this.groupId});

  @override
  State<DiaryShowScreen> createState() => _DiaryShowScreenState();
}

class _DiaryShowScreenState extends State<DiaryShowScreen> {
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final DiariesApi _diariesApi = DiariesApi(_apiClient);

  bool _initialized = false;
  String? _groupId;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
    _groupId = widget.groupId ?? args['groupId']?.toString();
    _future = _loadFilteredDiaries(_groupId);
    _initialized = true;
  }

  String _formatLocTime(Map<String, dynamic> d) {
    try {
      final location = (d['location'] ?? d['location_desc'] ?? '')
          .toString()
          .trim();
      final timeVal = (d['time'] ?? '').toString().trim();

      final parts = <String>[
        if (location.isNotEmpty) '위치: $location',
        if (timeVal.isNotEmpty) '시간: $timeVal',
      ];
      return parts.isNotEmpty ? parts.join(', ') : '위치/시간 없음';
    } catch (_) {
      return '위치/시간 없음';
    }
  }

  num? _parseSud(dynamic raw) {
    if (raw is num) return raw;
    if (raw is String && raw.isNotEmpty) return num.tryParse(raw);
    return null;
  }

  Map<String, dynamic>? _normalizeLocTime(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(
        raw.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    if (raw is List) {
      final items = raw
          .whereType<Map>()
          .map(
            (e) => Map<String, dynamic>.from(
              e.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .toList();
      if (items.isNotEmpty) return items.last;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _loadFilteredDiaries(
    String? groupId,
  ) async {
    if (groupId == null || groupId.isEmpty) {
      throw Exception('그룹 정보를 찾을 수 없습니다.');
    }

    final access = await _tokens.access;
    if (access == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final diaries = await _diariesApi.listDiaries(groupId: groupId);
    final filtered = <Map<String, dynamic>>[];

    for (final diary in diaries) {
      final locTime = _normalizeLocTime(diary['loc_time'] ?? diary['alarms']);
      if (locTime == null) continue;

      final latestSud = _parseSud(diary['latest_sud']);
      if (latestSud == null || latestSud > 2) {
        filtered.add({...diary, 'loc_time': locTime});
      }
    }

    return filtered;
  }

  String _resolveTitle(Map<String, dynamic> diary) {
    final activationRaw = diary['activation'];
    if (activationRaw is Map &&
        (activationRaw['label']?.toString().trim().isNotEmpty ?? false)) {
      return activationRaw['label'].toString().trim();
    }
    if (activationRaw is String && activationRaw.trim().isNotEmpty) {
      return activationRaw.trim();
    }
    final fallback = diary['activatingEvent'] ?? diary['activation_label'];
    if (fallback != null) {
      final s = fallback.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '(제목 없음)';
  }

  Widget _buildDiaryCard(
    BuildContext context,
    String title,
    Map<String, dynamic> locTime,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Noto Sans KR',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F3D63),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Noto Sans KR',
                  fontSize: 14.5,
                  height: 1.5,
                  color: Color(0xFF232323),
                ),
                children: [
                  TextSpan(
                    text: '${_formatLocTime(locTime)}에 ',
                    style: const TextStyle(
                      color: Color(0xFF47A6FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: '설정한 위치/시간이 되면 '),
                  TextSpan(
                    text: '"$title"',
                    style: const TextStyle(
                      color: Color(0xFF007BCE),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: '에 대한 감정을 차분히 들여다보세요.\n'),
                  const TextSpan(
                    text: '잘 해낼 수 있을 거예요 💙',
                    style: TextStyle(
                      color: Color(0xFF007BCE),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiaryList(
    BuildContext context,
    List<Map<String, dynamic>> docs,
  ) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFB4E0FF), Color(0xFFE3F6FF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Opacity(
          opacity: 0.25,
          child: Image.asset(
            'assets/image/eduhome.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 80),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 10,
                ),
                child: Text(
                  protectKoreanWords('아직 해결되지 않은 불안이 남아있어요 🐚\n아래 일기들을 다시 살펴보세요.'),
                  style: const TextStyle(
                    fontFamily: 'Noto Sans KR',
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F3D63),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final diary = docs[index];
                    final title = _resolveTitle(diary);
                    final locTime = _normalizeLocTime(diary['loc_time']);
                    if (locTime == null) {
                      return const SizedBox.shrink();
                    }

                    return _buildDiaryCard(context, title, locTime);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: const CustomAppBar(title: '걱정 일기 위치/시간 목록'),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final message = snap.error is DioException
                ? (snap.error as DioException).message
                : snap.error.toString();
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '일기 로드 중 오류가 발생했습니다.\n$message',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snap.data ?? const [];
          if (docs.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.pushReplacementNamed(
                  context,
                  '/battle',
                  arguments: {'groupId': _groupId ?? ''},
                );
              }
            });
            return const SizedBox.shrink();
          }
          return _buildDiaryList(context, docs);
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20),
        child: PrimaryActionButton(
          text: '확인',
          onPressed:
              () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (_) => false,
              ),
        ),
      ),
    );
  }
}
