import 'package:gad_app_team/data/api/sud_api.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_group_add_screen.dart';
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';
import 'package:provider/provider.dart';

import '../../data/user_provider.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

// 💡 Mindrium 위젯 디자인들
import 'package:gad_app_team/widgets/abc_chips_design.dart';
import 'package:gad_app_team/widgets/memo_sheet_design.dart';
import 'package:gad_app_team/widgets/abc_visualization_design.dart';
import 'package:gad_app_team/widgets/custom_popup_design.dart';

/// 📊 시각화 + 피드백 화면 (AbcChip 기반)
class AbcVisualizationScreen extends StatefulWidget {
  final String? sessionId;

  /// A: 상황 (선택된 칩들 — 실제로는 1개이지만 리스트로 유지)
  final List<AbcChip> activatingChips;

  /// B: 생각 (선택된 칩들)
  final List<AbcChip> beliefChips;

  /// C1: 신체
  final List<AbcChip> physicalChips;

  /// C2: 감정
  final List<AbcChip> emotionChips;

  /// C3: 행동
  final List<AbcChip> behaviorChips;

  /// 예시 모드 여부 (실제론 AbcInput에서 예시는 바로 RealStart로 가서 여기 안 올 듯)
  final bool isExampleMode;
  final String? origin;
  final String? abcId;
  final int? beforeSud;

  const AbcVisualizationScreen({
    super.key,
    required this.activatingChips,
    required this.beliefChips,
    required this.physicalChips,
    required this.emotionChips,
    required this.behaviorChips,
    required this.isExampleMode,
    this.origin,
    this.abcId,
    this.beforeSud,
    this.sessionId,
  });

  @override
  State<AbcVisualizationScreen> createState() => _AbcVisualizationScreenState();
}

class _AbcVisualizationScreenState extends State<AbcVisualizationScreen> {
  bool _showFeedback = true;
  bool _isSaving = false;
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final DiariesApi _diariesApi = DiariesApi(_apiClient);
  late final SudApi _sudApi = SudApi(_apiClient);
  String? _diaryId;
  String? sudId;

  @override
  void initState() {
    super.initState();
    _diaryId = widget.abcId;  // 기존 일기에서 들어온 경우 이미 값 있음
  }

  @override
  Widget build(BuildContext context) {
    return MemoFullDesign(
      appBarTitle: (widget.origin != null) ? '2주차 - ABC 모델' : '일기 작성',
      onBack: () {
        if (!_showFeedback) {
          setState(() => _showFeedback = true);
        } else {
          Navigator.pop(context);
        }
      },
      onNext: _isSaving
          ? null
          : () {
        if (_showFeedback) {
          setState(() => _showFeedback = false);
        } else {
          _handleSave(context);
        }
      },
      rightLabel: _showFeedback
          ? '다음'
          : _isSaving
          ? '저장 중...'
          : '저장',
      memoHeight: MediaQuery.of(context).size.height * 0.67,
      child: Column(
        children: [
          if (_showFeedback) _buildFeedbackCard(context),
          if (!_showFeedback) _buildAbcFlowDiagram(),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 💬 피드백 카드
  // ──────────────────────────────────────────────
  Widget _buildFeedbackCard(BuildContext context) {
    final userName =
        Provider.of<UserProvider>(context, listen: false).userName;

    final situation =
    widget.activatingChips.map((c) => c.label).join(', ');
    final thought = widget.beliefChips.map((c) => c.label).join(', ');
    final emotion = widget.emotionChips.map((c) => c.label).join(', ');
    final physical = widget.physicalChips.map((c) => c.label).join(', ');
    final behavior = widget.behaviorChips.map((c) => c.label).join(', ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          const Text(
            '글로 정리해보기',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: DesignPalette.textBlack,
              fontFamily: 'Noto Sans KR',
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 200,
            height: 2,
            decoration: BoxDecoration(
              color: Colors.black26.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            protectKoreanWords(
              '$userName님, \n말씀해주셔서 감사합니다 👏\n\n'
                  '‘$situation’ 상황에서 \n‘$thought’ 생각을 하셨고,\n‘$emotion’ 감정을 느끼셨습니다.\n\n'
                  '그 결과 신체적으로 ‘$physical’ 증상이 나타났고,\n‘$behavior’ 행동을 하셨습니다.',
            ),
            style: const TextStyle(
              height: 1.6,
              fontSize: 16,
              color: Colors.black87,
              fontFamily: 'Noto Sans KR',
            ),
            textAlign: TextAlign.start,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 🔵 A→B→C 시각화 다이어그램
  // ──────────────────────────────────────────────
  Widget _buildAbcFlowDiagram() {
    final situationText =
    widget.activatingChips.map((c) => c.label).join(', ');
    final beliefText =
    widget.beliefChips.map((c) => c.label).join(', ');
    final resultText = <String>[
      ...widget.emotionChips.map((c) => c.label),
      ...widget.physicalChips.map((c) => c.label),
      ...widget.behaviorChips.map((c) => c.label),
    ].join(', ');

    return AbcVisualizationDesign.buildVisualizationLayout(
      situationLabel: '상황 (A)',
      beliefLabel: '생각 (B)',
      resultLabel: '결과 (C)',
      situationText: situationText,
      beliefText: beliefText,
      resultText: resultText,
    );
  }

  // ──────────────────────────────────────────────
  // 🔹 FastAPI 기반 저장 로직 (chipId + label 저장)
  // ──────────────────────────────────────────────
  Future<void> _handleSave(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      // 1) A 칩 검증
      final AbcChip? activationChipObj =
      widget.activatingChips.isNotEmpty ? widget.activatingChips.first : null;

      if (activationChipObj == null) {
        throw Exception('A 상황이 선택되지 않았습니다.');
      }

      // 2) 공통 변환 함수
      Map<String, dynamic> chipToDiaryChip(AbcChip chip) {
        return _diariesApi.makeDiaryChip(
          label: chip.label.trim(),
          chipId: chip.chipId.isEmpty ? null : chip.chipId,
        );
      }

      final activationChip = chipToDiaryChip(activationChipObj);
      final beliefChips = widget.beliefChips.map(chipToDiaryChip).toList();
      final emotionChips = widget.emotionChips.map(chipToDiaryChip).toList();
      final physicalChips = widget.physicalChips.map(chipToDiaryChip).toList();
      final behaviorChips = widget.behaviorChips.map(chipToDiaryChip).toList();

      // 3) 토큰 체크
      final access = await _tokens.access;
      if (access == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final bool locationConsent = await _requestLocationConsent();

      // 4) 새 일기 vs 기존 일기 분기
      Map<String, dynamic> diary;

      if (_diaryId == null) {
        // 새 일기 생성
        diary = await _diariesApi.createDiary(
          activation: activationChip,
          belief: beliefChips,
          consequenceP: physicalChips,
          consequenceE: emotionChips,
          consequenceB: behaviorChips,
          alternativeThoughts: const [],
          alarms: const [],
        );

        _diaryId = diary['diary_id'].toString();
        debugPrint('FastAPI diary 생성 완료: $_diaryId');
      } else {
        // ✏️ 기존 일기 수정
        final body = {
          'activation': activationChip,
          'belief': beliefChips,
          'consequence_physical': physicalChips,
          'consequence_emotion': emotionChips,
          'consequence_action': behaviorChips,
          'alternative_thoughts': const [],
          'alarms': const [],
        };

        diary = await _diariesApi.updateDiary(_diaryId!, body);
        debugPrint('FastAPI diary 수정 완료: $_diaryId');
      }

      final resolvedDiaryId = _diaryId!;

      // 5) SUD 저장 – 한 번만 만들고, 그 이후 수정에서는 안 만들기
      if (widget.beforeSud != null && sudId == null) {
        _sudApi
            .createSudScore(
          diaryId: resolvedDiaryId,
          beforeScore: widget.beforeSud!,
        )
            .then((res) {
          sudId = res['sud_id']?.toString();
        }).catchError((e) {
          debugPrint('SUD 저장 실패: $e');
          return;
        });
      }

      // 6) 저장 성공 후 다음 화면
      if (!mounted) return;
      _showSavedPopup(
        diaryId: resolvedDiaryId,
        label: activationChipObj.label,
        locationConsent: locationConsent,
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ──────────────────────────────────────────────
  // 📍 위치 정보 동의 팝업
  // ──────────────────────────────────────────────
  Future<bool> _requestLocationConsent() async {
    if (!mounted) return false;
    bool consent = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return CustomPopupDesign(
          title: '위치 정보 수집 동의',
          message:
          '현재 위치 정보를 함께 저장하여 개인 맞춤형 피드백을 제공하려고 합니다.\n'
              '위치 정보 제공에 동의하시겠습니까?',
          positiveText: '동의함',
          negativeText: '동의 안 함',
          onPositivePressed: () {
            consent = true;
            Navigator.pop(ctx);
          },
          onNegativePressed: () {
            consent = false;
            Navigator.pop(ctx);
          },
          // backgroundAsset: 'assets/image/popup_bg.png',
          iconAsset: 'assets/image/jellyfish.png',
        );
      },
    );

    return consent;
  }

  // ──────────────────────────────────────────────
  // ✅ 저장 완료 후 알림 설정 화면으로 이동
  // ──────────────────────────────────────────────
  void _showSavedPopup({String? diaryId, String? label, bool? locationConsent}) {
    final resolvedDiaryId = diaryId ?? widget.abcId;
    final resolvedLabel =
        label ?? widget.activatingChips.map((c) => c.label).join(', ');

    final args = <String, dynamic>{};
    if (resolvedDiaryId != null && resolvedDiaryId.isNotEmpty) {
      args['abcId'] = resolvedDiaryId;
    }
    if (resolvedLabel.isNotEmpty) {
      args['label'] = resolvedLabel;
    }
    if (widget.origin != null) {
      args['origin'] = widget.origin;
    }
    if (widget.sessionId != null && widget.sessionId!.isNotEmpty) {
      args['sessionId'] = widget.sessionId;
    }
    if (locationConsent != null) {
      args['locationConsent'] = locationConsent;
    }
    if (widget.beforeSud != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => AbcGroupAddScreen(
                origin: widget.origin,
                abcId: resolvedDiaryId,
                beforeSud: widget.beforeSud,
                sudId: sudId,
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pushNamed(
      context,
      '/noti_select',
      arguments: args.isEmpty ? null : args,
    );
  }
}
