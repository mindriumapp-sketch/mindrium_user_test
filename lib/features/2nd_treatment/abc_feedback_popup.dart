import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gad_app_team/widgets/custom_popup_design.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_group_add_screen.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/models/grid_item.dart';
import 'package:gad_app_team/widgets/abc_visualization_design.dart'; // ✅ 추가
import 'package:gad_app_team/widgets/blue_banner.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/api/sud_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

/// 🌊 Mindrium ABC Feedback Popup (MemoFullDesign + Visualization)
class AbcFeedbackPopup extends StatefulWidget {
  final List<GridItem> activatingEventChips;
  final List<GridItem> beliefChips;
  final List<GridItem> feedbackEmotionChips;
  final List<String> selectedPhysicalChips;
  final List<String> selectedEmotionChips;
  final List<String> selectedBehaviorChips;
  final bool isExampleMode;
  final String? origin;
  final String? abcId;
  final int? beforeSud;

  const AbcFeedbackPopup({
    super.key,
    required this.activatingEventChips,
    required this.beliefChips,
    required this.feedbackEmotionChips,
    required this.selectedPhysicalChips,
    required this.selectedEmotionChips,
    required this.selectedBehaviorChips,
    this.isExampleMode = false,
    this.origin,
    this.abcId,
    this.beforeSud,
  });

  @override
  State<AbcFeedbackPopup> createState() => _AbcFeedbackPopupState();
}

class _AbcFeedbackPopupState extends State<AbcFeedbackPopup> {
  bool _showFeedback = true;
  bool _isSaving = false;
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final DiariesApi _diariesApi = DiariesApi(_apiClient);
  late final SudApi _sudApi = SudApi(_apiClient);

  // 💬 피드백 텍스트 카드
  Widget _buildFeedbackContent() {
    final userName = Provider.of<UserProvider>(context, listen: false).userName;
    final situation = widget.activatingEventChips
        .map((e) => e.label)
        .join(', ');
    final thought = widget.beliefChips.map((e) => e.label).join(', ');
    final emotions = widget.feedbackEmotionChips.map((e) => e.label).join(', ');
    final physical = widget.selectedPhysicalChips.join(', ');
    final behavior = widget.selectedBehaviorChips.join(', ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          Text(
            protectKoreanWords("👏 \n $userName님,\n말씀해주셔서 감사합니다."),
            style: const TextStyle(
              fontSize: 18,
              height: 1.6
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4,),
          Container(
            width: 800,
            height: 1,
            decoration: BoxDecoration(
              color: Colors.black26.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            protectKoreanWords("$userName님께서는 ‘$situation’ 상황에서 ‘$thought’ 생각을 하셨고,\n"
            "'$emotions’ 감정을 느끼셨습니다.\n\n"
            "그 결과 신체적으로 ‘$physical’ 증상이 나타났으며,\n"
            "‘$behavior’ 행동을 하셨습니다.\n\n"),
            style: const TextStyle(
              fontSize: 16.5,
              color: Colors.black,
              height: 1.6,
            ),
          ),
        ],
      )
    );
  }

  // 🎨 새 디자인 적용된 시각화 화면
  Widget _buildVisualizationContent() {
    final situation = widget.activatingEventChips
        .map((e) => e.label)
        .join(', ');
    final belief = widget.beliefChips.map((e) => e.label).join(', ');
    final result = widget.feedbackEmotionChips.map((e) => e.label).join(', ');

    return AbcVisualizationDesign.buildVisualizationLayout(
      situationLabel: '상황',
      beliefLabel: '생각',
      resultLabel: '결과',
      situationText: situation,
      beliefText: belief,
      resultText: result,
    );
  }

  List<Map<String, dynamic>> _mapGridItems(List<GridItem> items) {
    return items
        .map((e) => e.label.trim())
        .where((label) => label.isNotEmpty)
        .map((label) => _diariesApi.makeDiaryChip(label: label))
        .toList();
  }

  List<Map<String, dynamic>> _mapStringChips(List<String> items) {
    return items
        .map((e) => e.trim())
        .where((label) => label.isNotEmpty)
        .map((label) => _diariesApi.makeDiaryChip(label: label))
        .toList();
  }

  // ✅ FastAPI 저장 + 화면 이동
  Future<void> _saveAndGoToAdd() async {
    setState(() => _isSaving = true);

    try {
      final access = await _tokens.access;
      if (access == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
        }
        return;
      }

      final activationLabel =
          widget.activatingEventChips.isNotEmpty
              ? widget.activatingEventChips.first.label.trim()
              : '';
      if (activationLabel.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('상황을 선택해 주세요.')));
        }
        return;
      }

      final activation = _diariesApi.makeDiaryChip(label: activationLabel);
      final beliefChips = _mapGridItems(widget.beliefChips);
      final emotionChips = _mapStringChips(widget.selectedEmotionChips);
      final physicalChips = _mapStringChips(widget.selectedPhysicalChips);
      final behaviorChips = _mapStringChips(widget.selectedBehaviorChips);

      Position? pos;
      try {
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.always ||
            perm == LocationPermission.whileInUse) {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
            ),
          );
        }
      } catch (e) {
        debugPrint("위치 획득 실패: $e");
      }

      Map<String, dynamic> diary;
      String diaryId;

      if (widget.abcId == null || widget.abcId!.isEmpty) {
        diary = await _diariesApi.createDiary(
          activation: activation,
          belief: beliefChips,
          consequenceP: physicalChips,
          consequenceE: emotionChips,
          consequenceB: behaviorChips,
          alternativeThoughts: const [],
          alarms: const [],
          latitude: pos?.latitude,
          longitude: pos?.longitude,
        );
        diaryId = diary['diary_id']?.toString() ?? '';
        debugPrint("✅ FastAPI ABC 모델 생성 완료: $diaryId");
      } else {
        final body = {
          'activation': activation,
          'belief': beliefChips,
          'consequence_physical': physicalChips,
          'consequence_emotion': emotionChips,
          'consequence_action': behaviorChips,
          'alternative_thoughts': const [],
          'alarms': const [],
          if (pos != null) 'latitude': pos.latitude,
          if (pos != null) 'longitude': pos.longitude,
        };
        diary = await _diariesApi.updateDiary(widget.abcId!, body);
        diaryId = widget.abcId!;
        debugPrint("✅ FastAPI ABC 모델 수정 완료: $diaryId");
      }

      if (diaryId.isEmpty) {
        throw Exception('일기 ID를 확인할 수 없습니다.');
      }

      if (widget.beforeSud != null) {
        try {
          await _sudApi.createSudScore(
            diaryId: diaryId,
            beforeScore: widget.beforeSud!,
          );
        } catch (e) {
          debugPrint('SUD 저장 실패: $e');
        }
      }

      if (mounted) {
        BlueBanner.show(context, '저장이 완료되었습니다.');
      }

      Future.microtask(() {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => AbcGroupAddScreen(
                  origin: widget.origin ?? 'etc',
                  diaryId: diaryId,
                  label:
                      widget.activatingEventChips.isNotEmpty
                          ? widget.activatingEventChips[0].label
                          : '',
                  beforeSud: widget.beforeSud,
                  diary: 'new',
            ),
          ),
        );
      });
    } on DioException catch (e, st) {
      debugPrint('❌ ABC 저장 실패: $e\n$st');
      final detail =
          e.response?.data is Map
              ? e.response?.data['detail']?.toString()
              : e.message;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: ${detail ?? e}')),
        );
      }
    } catch (e, st) {
      debugPrint('❌ ABC 저장 실패: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ✅ 저장 의사 팝업
  void _showSavePopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogCtx) => CustomPopupDesign(
            title: "걱정그룹에 추가하시겠습니까?",
            message: "작성한 걱정일기를 저장하고 그룹에 추가하시겠습니까?",
            positiveText: "예",
            negativeText: "아니요",
            iconAsset: "assets/image/popup1.png",
            backgroundAsset: "assets/image/sea_bg_3d.png",
            onPositivePressed: () async {
              Navigator.pop(dialogCtx);
              await Future.delayed(const Duration(milliseconds: 150));
              _saveAndGoToAdd();
            },
            onNegativePressed: () {
              Navigator.pop(dialogCtx);
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AbcVisualizationDesign(
      showFeedback: _showFeedback,
      isSaving: _isSaving,
      onBack: () {
        if (!_showFeedback) {
          setState(() => _showFeedback = true);
        } else {
          Navigator.pop(context);
        }
      },
      onNext:
          _isSaving
              ? () {}
              : () {
                if (_showFeedback) {
                  setState(() => _showFeedback = false);
                } else {
                  _showSavePopup();
                }
              },
      feedbackWidget: _buildFeedbackContent(),
      visualizationWidget: _buildVisualizationContent(),
    );
  }
}
