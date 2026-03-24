// File: lib/features/7th_treatment/week7_add_display_screen.dart
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/7th_treatment/week7_planning_screen.dart';
import 'package:gad_app_team/widgets/tutorial_design.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/custom_tags_api.dart';
import 'package:gad_app_team/data/api/week7_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

// Week7 화면 복귀 감지를 위한 RouteObserver
final RouteObserver<PageRoute<dynamic>> week7RouteObserver =
    RouteObserver<PageRoute<dynamic>>();

class Week7AddDisplayScreen extends StatefulWidget {
  final String? initialBehavior;

  /// 6→7주차 진입 시 초기 자동 추가를 지연할지 여부 (기본: true)
  final bool deferInitialMarkAsAdded;

  const Week7AddDisplayScreen({
    super.key,
    this.initialBehavior,
    this.deferInitialMarkAsAdded = true,
  });

  @override
  State<Week7AddDisplayScreen> createState() => _Week7AddDisplayScreenState();

  // 전역 상태 getter/setter
  static Set<String> get globalAddedBehaviors =>
      Set<String>.from(_Week7AddDisplayScreenState._globalAddedBehaviors);

  static void updateGlobalAddedBehaviors(Set<String> behaviors) {
    _Week7AddDisplayScreenState._globalAddedBehaviors
      ..clear()
      ..addAll(behaviors);
  }

  static List<String> get globalNewBehaviors =>
      List<String>.from(_Week7AddDisplayScreenState._globalNewBehaviors);

  static void updateGlobalNewBehaviors(List<String> behaviors) {
    _Week7AddDisplayScreenState._globalNewBehaviors
      ..clear()
      ..addAll(behaviors);
  }

  // 행동 이름 → chip_id 맵 전역 getter
  static Map<String, String> get globalBehaviorToChip =>
      Map<String, String>.from(
        _Week7AddDisplayScreenState._globalBehaviorToChip,
      );

  static void registerGlobalBehaviorToChip(String behavior, String chipId) {
    if (behavior.trim().isEmpty || chipId.trim().isEmpty) return;
    _Week7AddDisplayScreenState._globalBehaviorToChip[behavior] = chipId;
  }
}

class _Week7AddDisplayScreenState extends State<Week7AddDisplayScreen>
    with TickerProviderStateMixin, RouteAware {
  bool _isLoading = true;
  String? _error;

  List<Map<String, String>> _behaviorCards = [];

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late final ApiClient _client;
  late final CustomTagsApi _customTagsApi;
  // late final UserDataApi _userDataApi;
  late final Week7Api _week7Api;

  // 공유 전역 상태
  static final Set<String> _globalAddedBehaviors = {};
  static final List<String> _globalNewBehaviors = [];
  static final Map<String, String> _globalBehaviorToChip = {};

  List<Map<String, dynamic>> _customTags = [];
  final Map<String, String> _chipToBehavior = {};

  static const EdgeInsets _listInnerPad = EdgeInsets.symmetric(horizontal: 12);

  @override
  void initState() {
    super.initState();
    _client = ApiClient(tokens: TokenStorage());
    _customTagsApi = CustomTagsApi(_client);
    // _userDataApi = UserDataApi(_client);
    _week7Api = Week7Api(_client);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _initializeWeek7Data();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // RouteObserver에 등록
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      week7RouteObserver.subscribe(this, route);
    }
  }

  // 다른 화면에서 돌아왔을 때 호출됨
  @override
  void didPopNext() {
    // 이 화면은 6주차 분류 결과(로그)만 보여준다.
    if (!_isLoading) {
      _loadBehaviorCardsFromLogs();
      _refreshWeek7Session();
    }
  }

  Future<void> _refreshWeek7Session() async {
    try {
      final session = await _week7Api.fetchWeek7Session();
      final newBehaviors = <String>{};

      if (session != null) {
        final items = _extractWeek7Items(session);
        for (final raw in items) {
          final chipId = raw['chip_id']?.toString();
          final classification = _extractClassification(raw);
          if (chipId == null || classification == null) continue;

          final behavior =
              _chipToBehavior[chipId] ??
              _customTags
                  .where((tag) => tag['chip_id'] == chipId)
                  .map((tag) => tag['text']?.toString())
                  .firstWhere(
                    (value) => value != null && value.isNotEmpty,
                    orElse: () => null,
                  );

          if (behavior != null) {
            _registerChipBehavior(chipId, behavior);
            newBehaviors.add(behavior);
          }
        }
      }

      Week7AddDisplayScreen.updateGlobalAddedBehaviors(newBehaviors);
    } catch (e) {
      debugPrint('Week7 세션 새로고침 오류: $e');
    }
  }

  @override
  void dispose() {
    week7RouteObserver.unsubscribe(this);
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _initializeWeek7Data() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _loadCustomTags();
      await _loadBehaviorCardsFromLogs();
      await _refreshWeek7Session();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (_behaviorCards.isNotEmpty) {
          _fadeController.forward();
          _slideController.forward();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '데이터를 불러오지 못했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCustomTags() async {
    final tags = await _customTagsApi.listCustomTags(chipType: 'CA');
    for (final tag in tags) {
      final chipId = tag['chip_id']?.toString();
      final label = (tag['text'] ?? tag['label'])?.toString().trim();
      if (chipId != null && label != null && label.isNotEmpty) {
        _registerChipBehavior(chipId, label);
      }
    }
    if (!mounted) return;
    setState(() {
      _customTags = tags;
    });
  }

  void _registerChipBehavior(String chipId, String behavior) {
    _chipToBehavior[chipId] = behavior;
    _globalBehaviorToChip[behavior] = chipId; // 전역 맵도 업데이트
  }

  Future<void> _loadBehaviorCardsFromLogs() async {
    final allLogs = await _customTagsApi.listCategoryLogs();
    if (!mounted) return;
    setState(() {
      _initBehaviorCardsFromLogs(allLogs);
    });
  }

  List<Map<String, dynamic>> _extractWeek7Items(Map<String, dynamic> session) {
    final dynamic rawItems =
        session['classification_items'] ?? session['behavior_items'];
    if (rawItems is! List) return const [];
    return rawItems.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  String? _extractClassification(Map<String, dynamic> raw) {
    return raw['classification']?.toString() ?? raw['category']?.toString();
  }

  void _initBehaviorCardsFromLogs(List<Map<String, dynamic>> logs) {
    // category logs 기반: chip_id → behavior 매핑 후 분류 적용
    final Map<String, String> behaviorMap = {}; // behavior -> classification

    for (var log in logs) {
      final chipId = log['chip_id']?.toString();
      if (chipId == null) continue;

      final tag = _customTags.firstWhere(
        (t) => t['chip_id']?.toString() == chipId,
        orElse: () => const {},
      );

      final behavior =
          _chipToBehavior[chipId] ??
          (tag['text'] ?? tag['label'])?.toString() ??
          chipId;

      final shortTerm = log['short_term']?.toString();
      final type = log['type']?.toString();
      final classification =
          shortTerm == 'confront' || type == 'confronted' ? '직면' : '회피';

      behaviorMap[behavior] = classification;
    }

    _behaviorCards =
        behaviorMap.entries
            .map((e) => {'behavior': e.key, 'classification': e.value})
            .toList()
          ..sort((a, b) {
            // 정렬 순서: 직면 -> 회피 -> 기타
            final aOrder = _getClassificationOrder(a['classification'] ?? '');
            final bOrder = _getClassificationOrder(b['classification'] ?? '');
            if (aOrder != bOrder) {
              return aOrder.compareTo(bOrder);
            }
            // 같은 분류 내에서는 행동 이름으로 정렬
            return (a['behavior'] ?? '').compareTo(b['behavior'] ?? '');
          });
  }

  int _getClassificationOrder(String classification) {
    switch (classification) {
      case '직면':
        return 1; // 첫 번째
      case '회피':
        return 2; // 두 번째
      default:
        return 3; // 마지막
    }
  }

  String _getClassificationText(String classification) {
    switch (classification) {
      case '직면':
        return '불안 직면';
      case '회피':
        return '불안 회피';
      default:
        return '미분류';
    }
  }

  // ── 리스트 카드 (조회 전용: 분류 결과만 표시)
  Widget _buildBehaviorCard(Map<String, String> card, int index) {
    final classification = card['classification'] ?? '';
    final behavior = card['behavior'] ?? '';

    final bool isFacing = classification == '직면';

    // 🎨 상태 기반 컬러 시스템
    final Color pillBg =
        isFacing ? const Color(0xFFE8F5E1) : const Color(0xFFFEE5E8);

    final Color pillText =
        isFacing ? const Color(0xFF2E6B45) : const Color(0xFFD6455F);

    final Color borderColor =
        isFacing ? const Color(0xFFD2E8D2) : const Color(0xFFF5D0D6);

    final Color shadowColor =
        isFacing ? const Color(0x332E6B45) : const Color(0x33D6455F);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getClassificationText(classification),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: pillText,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            behavior,
            style: const TextStyle(
              color: Color(0xFF263C69),
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── 화면
  @override
  Widget build(BuildContext context) {
    return ApplyDesign(
      appBarTitle: '생활 습관 개선',
      cardTitle: '6주차 분석 결과',
      onBack: () => Navigator.pop(context),
      onNext: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const Week7PlanningScreen(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      },

      // 👉 카드 내부 (디자인만 수정)
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          // 중앙 정렬 안내 문구 (텍스트만)
          const Text(
            '6주차에서 분류한 행동들을 확인해보세요!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              wordSpacing: 1.6,
              fontWeight: FontWeight.w500,
              color: Color(0xFF626262),
            ),
          ),
          const SizedBox(height: 40),

          // 리스트 (Expanded → shrinkWrap ListView로 수정)
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            )
          else if (_behaviorCards.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  '분류된 행동이 없습니다',
                  style: TextStyle(color: Color(0xFF718096)),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: _listInnerPad,
              itemCount: _behaviorCards.length,
              itemBuilder: (context, index) {
                final card = _behaviorCards[index];
                return _buildBehaviorCard(card, index);
              },
            ),
        ],
      ),
    );
  }
}
