import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gad_app_team/widgets/custom_popup_design.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_group_add.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/models/grid_item.dart';
import 'package:gad_app_team/widgets/abc_visualization_design.dart'; // ✅ 추가
import 'package:gad_app_team/widgets/blue_banner.dart';

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

  // ✅ 위치 수집 동의 팝업
  Future<void> _askLocationConsent() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => CustomPopupDesign(
            title: "위치 정보 수집 동의",
            message: "현재 위치 정보를 함께 저장하시겠습니까?",
            positiveText: "동의",
            negativeText: "거부",
            iconAsset: "assets/image/dialog_fish.png",
            backgroundAsset: "assets/image/sea_bg_3d.png",
            onPositivePressed: () async {
              Navigator.pop(ctx);
              await Future.delayed(const Duration(milliseconds: 150));
              await _saveAndGoToAdd(withLocation: true);
            },
            onNegativePressed: () async {
              Navigator.pop(ctx);
              await Future.delayed(const Duration(milliseconds: 150));
              await _saveAndGoToAdd(withLocation: false);
            },
          ),
    );
  }

  // ✅ Firestore 저장 + 화면 이동
  Future<void> _saveAndGoToAdd({required bool withLocation}) async {
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final userCollection = firestore
          .collection('users')
          .doc(user.uid)
          .collection('abc_models');

      Position? pos;
      if (withLocation) {
        try {
          LocationPermission perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.denied) {
            perm = await Geolocator.requestPermission();
          }
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
      }

      final data = {
        'activatingEvent': widget.activatingEventChips
            .map((e) => e.label)
            .join(', '),
        'belief': widget.beliefChips.map((e) => e.label).join(', '),
        'consequence_emotion': widget.selectedEmotionChips.join(', '),
        'consequence_physical': widget.selectedPhysicalChips.join(', '),
        'consequence_behavior': widget.selectedBehaviorChips.join(', '),
        if (pos != null) 'latitude': pos.latitude,
        if (pos != null) 'longitude': pos.longitude,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await userCollection.add(data);
      debugPrint("✅ ABC 모델 저장 완료: ${docRef.id}");

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
                  abcId: docRef.id,
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
              _askLocationConsent();
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
