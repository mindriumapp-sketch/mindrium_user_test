// 🔹 SUD(불안 정도) 입력 및 저장 화면
// 사용자가 0~10 점수 선택 → Firestore 저장 → 점수에 따라 다음 화면 이동
// Mindrium 공통 ApplyDesign 사용 (튜토리얼 카드형 레이아웃)

// ─────────────────────────  FLUTTER  ─────────────────────────
import 'package:gad_app_team/utils/text_line_material.dart';

// ────────────────────────  PACKAGES  ────────────────────────
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';

// ───────────────────────────  LOCAL  ────────────────────────
import 'package:gad_app_team/contents/apply_flow/apply_flow_route_data.dart';
import 'package:gad_app_team/contents/apply_flow/sud_rating_content.dart';
import 'package:gad_app_team/widgets/tutorial_design.dart'; // ★ ApplyDesign 가져오기
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/api/sud_api.dart';
import 'package:gad_app_team/data/user_provider.dart';

/// SUD(0‒10)을 입력받아 저장하고, 점수에 따라 후속 행동을 안내하는 화면
class BeforeSudRatingScreen extends StatefulWidget {
  final String? abcId;
  const BeforeSudRatingScreen({super.key, this.abcId});

  @override
  State<BeforeSudRatingScreen> createState() => _BeforeSudRatingScreenState();
}

class _BeforeSudRatingScreenState extends State<BeforeSudRatingScreen> {
  int _sud = 5; // 슬라이더 값 (0‒10)
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final DiariesApi _diariesApi = DiariesApi(_apiClient);
  late final SudApi _sudApi = SudApi(_apiClient);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[SUD] arguments = ${widget.abcId}');
  }

  // ────────────────────── FastAPI 저장 ──────────────────────
  Future<Map<String, dynamic>?> _saveSudAndGet(String? abcId) async {
    if (abcId == null || abcId.isEmpty) {
      return null;
    }

    final access = await _tokens.access;
    if (access == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final res = await _sudApi.createSudScore(diaryId: abcId, beforeScore: _sud);
    return res;
  }

  Future<String> _loadGroupId(String abcId) async {
    try {
      final diary = await _diariesApi.getDiary(abcId);
      final dynamic raw = diary['group_id'];
      return raw == null ? '' : raw.toString();
    } on DioException catch (_) {
      return '';
    } catch (_) {
      return '';
    }
  }

  Future<bool> _hasAccessToken() async {
    final access = await _tokens.access;
    return access != null;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  // ────────────────────────── UI ──────────────────────────
  @override
  Widget build(BuildContext context) {
    final route = ApplyFlowRouteData.read(
      context,
      rawArgs: ModalRoute.of(context)?.settings.arguments,
    );
    final bool isHomeTodayDiary = route.args['isHomeTodayDiary'] == true;
    final flow = route.flow;
    final String origin = route.origin;
    final String? abcId = widget.abcId ?? route.abcId;
    final bool hasAbcId = abcId?.isNotEmpty ?? false;
    final String cardTitle =
        isHomeTodayDiary ? '오늘 느낀 불안 정도를\n선택해 주세요' : '지금 느끼는 불안 정도를\n선택해 주세요';

    // ApplyDesign로 상단/본문/하단을 모두 구성 (eduhome.png 배경 포함)
    return ApplyDesign(
      appBarTitle: '불안 평가',
      cardTitle: cardTitle,
      onBack: () => Navigator.pop(context),
      onNext: () async {
        if (_saving) return;
        setState(() => _saving = true);

        try {
          Map<String, dynamic>? res;
          if (hasAbcId) {
            res = await _saveSudAndGet(abcId);
          }

          if (!context.mounted) return;
          flow.setBeforeSud(_sud);

          if (!hasAbcId) {
            final nextRoute =
                origin == 'daily' ? '/abc' : '/solve_entry_choice';
            Navigator.pushReplacementNamed(
              context,
              nextRoute,
              arguments: route.mergedArgs(
                extra: {
                  'origin': origin,
                  'beforeSud': _sud,
                  'isHomeTodayDiary': isHomeTodayDiary,
                },
              ),
            );
            return;
          }

          final isLoggedIn = await _hasAccessToken();
          if (!isLoggedIn) {
            _showSnack('로그인 정보가 없습니다.');
            return;
          }

          if (!hasAbcId) {
            _showSnack('기록 정보를 찾을 수 없습니다. 다시 시도해 주세요.');
            return;
          }

          final ensuredAbcId = abcId!;
          final groupId = await _loadGroupId(ensuredAbcId);
          if (!context.mounted) return;
          flow
            ..setDiaryId(ensuredAbcId)
            ..setGroupId(groupId);

          final sudId = res?['sud_id']?.toString() ?? '';
          if (sudId.isNotEmpty) flow.setSudId(sudId);

          if (_sud > 2) {
            final completedWeeks =
                context.read<UserProvider>().lastCompletedWeek;
            final nextRoute =
                completedWeeks >= 4
                    ? '/relax_or_alternative'
                    : '/relax_yes_or_no';
            Navigator.pushReplacementNamed(
              context,
              nextRoute,
              arguments: route.mergedArgs(
                extra: {
                  'abcId': ensuredAbcId,
                  'groupId': groupId,
                  'beforeSud': _sud,
                  'sudId': sudId,
                  'isHomeTodayDiary': isHomeTodayDiary,
                },
              ),
            );
          } else {
            Navigator.pushReplacementNamed(
              context,
              '/diary_relax_home',
              arguments: route.mergedArgs(
                extra: {
                  'abcId': ensuredAbcId,
                  'groupId': groupId,
                  'origin': origin,
                  'beforeSud': _sud,
                  'sudId': sudId,
                  'isHomeTodayDiary': isHomeTodayDiary,
                },
              ),
            );
          }
        } on DioException catch (e) {
          final message =
              e.response?.data is Map
                  ? e.response?.data['detail']?.toString()
                  : e.message;
          _showSnack('SUD를 저장하지 못했습니다: ${message ?? '알 수 없는 오류'}');
        } catch (e) {
          _showSnack('SUD를 저장하지 못했습니다: $e');
        } finally {
          if (mounted) setState(() => _saving = false);
        }
      },

      // ─── 카드 내부 콘텐츠 ───
      child: SudRatingContent(
        value: _sud,
        isPastTense: isHomeTodayDiary,
        onChanged: (value) => setState(() => _sud = value),
      ),
    );
  }
}
