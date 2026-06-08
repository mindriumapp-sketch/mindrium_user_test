import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/contents/apply_flow/apply_flow_route_data.dart';
import 'package:gad_app_team/contents/apply_flow/sud_rating_content.dart';
import 'package:gad_app_team/widgets/tutorial_design.dart'; // ✅ ApplyDesign
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/sud_api.dart';
import 'package:dio/dio.dart';

class AfterSudRatingScreen extends StatefulWidget {
  const AfterSudRatingScreen({super.key});

  @override
  State<AfterSudRatingScreen> createState() => _AfterSudRatingScreenState();
}

class _AfterSudRatingScreenState extends State<AfterSudRatingScreen> {
  int _sud = 5;
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final SudApi _sudApi = SudApi(_apiClient);

  Map<String, dynamic> _args() {
    return castApplyFlowArgs(ModalRoute.of(context)?.settings.arguments);
  }

  ApplyFlowRouteData _routeData({bool override = false, bool notify = false}) {
    return ApplyFlowRouteData.read(
      context,
      rawArgs: _args(),
      override: override,
      notify: notify,
    );
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

  // ───────────────────── FastAPI 저장 ─────────────────────
  Future<Map<String, dynamic>?> _createFallbackSud({
    required String abcId,
    required int beforeSud,
  }) async {
    try {
      return await _sudApi.createSudScore(
        diaryId: abcId,
        beforeScore: beforeSud,
        afterScore: _sud,
      );
    } on DioException catch (e) {
      debugPrint(
        '[after_sud] fallback createSudScore DioException: ${e.message}',
      );
    } catch (e) {
      debugPrint('[after_sud] fallback createSudScore error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _saveSud() async {
    final route = _routeData();
    final flow = route.flow;
    final abcId = route.abcId;
    final sudId = route.sudId;
    final beforeSud = route.beforeSud ?? _sud;

    if (abcId != null) flow.setDiaryId(abcId);
    if (sudId != null) flow.setSudId(sudId);

    if (abcId == null || abcId.isEmpty) {
      debugPrint('[after_sud] missing abcId: abcId=$abcId, sudId=$sudId');
      _showSnack('SUD를 저장하지 못했습니다. 다시 시도해주세요.');
      return null;
    }

    if (sudId == null || sudId.isEmpty) {
      debugPrint('[after_sud] missing ids: abcId=$abcId, sudId=$sudId');
      final fallback = await _createFallbackSud(
        abcId: abcId,
        beforeSud: beforeSud,
      );
      final fallbackSudId = fallback?['sud_id']?.toString();
      if (fallbackSudId != null && fallbackSudId.isNotEmpty) {
        flow.setSudId(fallbackSudId);
      }
      if (fallback == null) {
        _showSnack('SUD를 저장하지 못했습니다. 다시 시도해주세요.');
      }
      return fallback;
    }

    final access = await _tokens.access;
    if (access == null) {
      _showSnack('로그인이 필요합니다.');
      return null;
    }

    try {
      final res = await _sudApi.updateSudScore(
        diaryId: abcId,
        sudId: sudId,
        afterScore: _sud,
      );
      return res;
    } on DioException catch (e) {
      debugPrint('[after_sud] updateSudScore DioException: ${e.message}');
    } catch (e) {
      debugPrint('[after_sud] updateSudScore error: $e');
    }

    final fallback = await _createFallbackSud(
      abcId: abcId,
      beforeSud: beforeSud,
    );
    final fallbackSudId = fallback?['sud_id']?.toString();
    if (fallbackSudId != null && fallbackSudId.isNotEmpty) {
      flow.setSudId(fallbackSudId);
    }
    if (fallback == null) {
      _showSnack('SUD를 저장하지 못했습니다. 다시 시도해주세요.');
    }
    return fallback;
  }

  // ───────────────────── 저장 후 이동 ─────────────────────
  void _navigateHome() {
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
  }

  // ───────────────────── UI ─────────────────────
  @override
  Widget build(BuildContext context) {
    _routeData(notify: false);

    return ApplyDesign(
      appBarTitle: '불안 평가',
      cardTitle: '활동을 진행한 후,\n느끼는 불안 정도를 선택해 주세요',
      onBack: () => Navigator.pop(context),
      onNext: () async {
        await _saveSud();
        if (!context.mounted) return;
        _navigateHome();
      },
      child: SudRatingContent(
        value: _sud,
        onChanged: (value) => setState(() => _sud = value),
      ),
    );
  }
}
