import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:dio/dio.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/custom_popup_design.dart';
import 'package:gad_app_team/widgets/abc_chips_design.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/custom_tags_api.dart';

import 'abc_visualization_screen.dart';
import 'step_a_view.dart';
import 'step_b_view.dart';
import 'step_c_view.dart';
import 'abc_guide_screen.dart';
import 'abc_real_start_screen.dart';

class AbcInputScreen extends StatefulWidget {
  final bool isExampleMode;
  final Map<String, String>? exampleData;
  final bool showGuide;
  final String? abcId;
  final String? origin;
  final String? diaryRoute;
  final int? beforeSud;
  final String? sessionId;

  const AbcInputScreen({
    super.key,
    this.isExampleMode = false,
    this.exampleData,
    this.showGuide = true,
    this.abcId,
    this.origin,
    this.diaryRoute,
    this.beforeSud,
    this.sessionId,
  });

  @override
  State<AbcInputScreen> createState() => _AbcInputScreenState();
}

class _AbcInputScreenState extends State<AbcInputScreen> {
  // ====== 🔹 메모리 캐시 (앱 켜져 있는 동안 재사용) ======
  static List<AbcChip>? _cachedAChips;
  static List<AbcChip>? _cachedBChips;
  static List<AbcChip>? _cachedPhysicalChips;
  static List<AbcChip>? _cachedEmotionChips;
  static List<AbcChip>? _cachedBehaviorChips;

  int _currentStep = 0; // 0: A, 1: B, 2: C
  int _currentCSubStep = 0; // 0: 신체, 1: 감정, 2: 행동

  // ---------------------- 칩 목록 (AbcChip) ----------------------
  final List<AbcChip> _aChips = [];
  final List<AbcChip> _bChips = [];
  final List<AbcChip> _physicalChips = [];
  final List<AbcChip> _emotionChips = [];
  final List<AbcChip> _behaviorChips = [];

  // ---------------------- 선택 상태 (chipId 기반) ----------------
  final Set<String> _selectedAChipIds = {};
  final Set<String> _selectedBChipIds = {};
  final Set<String> _selectedPhysicalChipIds = {};
  final Set<String> _selectedEmotionChipIds = {};
  final Set<String> _selectedBehaviorChipIds = {};

  late bool _showGuide;
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final CustomTagsApi _customTagsApi = CustomTagsApi(_apiClient);
  bool _loadingCustomTags = false;

  @override
  void initState() {
    super.initState();
    _showGuide = widget.showGuide;

    if (widget.isExampleMode) {
      // 예시 모드는 API / 캐시 안 씀
      _ensureExamplePresetChips();
    } else {
      // 1) 캐시가 있으면 먼저 하이드레이션 → 바로 UI에 보여줌
      _hydrateFromCache();
      // 2) 백그라운드에서 최신 custom_tags 로딩
      Future.microtask(_loadCustomTags);
    }
  }

  // ---------------------- 캐시 → 로컬 리스트로 복사 ----------------------
  void _hydrateFromCache() {
    if (_cachedAChips != null && _cachedAChips!.isNotEmpty) {
      _aChips.addAll(_cachedAChips!);
    }
    if (_cachedBChips != null && _cachedBChips!.isNotEmpty) {
      _bChips.addAll(_cachedBChips!);
    }
    if (_cachedPhysicalChips != null && _cachedPhysicalChips!.isNotEmpty) {
      _physicalChips.addAll(_cachedPhysicalChips!);
    }
    if (_cachedEmotionChips != null && _cachedEmotionChips!.isNotEmpty) {
      _emotionChips.addAll(_cachedEmotionChips!);
    }
    if (_cachedBehaviorChips != null && _cachedBehaviorChips!.isNotEmpty) {
      _behaviorChips.addAll(_cachedBehaviorChips!);
    }
  }

  // ---------------------- 예시 모드 프리셋 ----------------------
  void _ensureExamplePresetChips() {
    if (!_aChips.any((c) => c.label == '자전거를 타려고 함')) {
      _aChips.insert(
        0,
        const AbcChip(
          chipId: 'example_A_bike',
          label: '자전거를 타려고 함',
          type: 'A',
          isPreset: true,
        ),
      );
    }
    if (!_bChips.any((c) => c.label == '넘어질까봐 두려움')) {
      _bChips.insert(
        0,
        const AbcChip(
          chipId: 'example_B_fear',
          label: '넘어질까봐 두려움',
          type: 'B',
          isPreset: true,
        ),
      );
    }
    if (!_physicalChips.any((c) => c.label == '두근거림')) {
      _physicalChips.insert(
        0,
        const AbcChip(
          chipId: 'example_CP_no_bike',
          label: '두근거림',
          type: 'CP',
          isPreset: true,
        ),
      );
    }
    if (!_emotionChips.any((c) => c.label == '불안')) {
      _emotionChips.insert(
        0,
        const AbcChip(
          chipId: 'example_CE_no_bike',
          label: '불안',
          type: 'CE',
          isPreset: true,
        ),
      );
    }
    if (!_behaviorChips.any((c) => c.label == '자전거를 타지 않았어요')) {
      _behaviorChips.insert(
        0,
        const AbcChip(
          chipId: 'example_CA_no_bike',
          label: '자전거를 타지 않았어요',
          type: 'CA',
          isPreset: true,
        ),
      );
    }
  }

  // ---------------------- custom_tags 로드 ----------------------
  Future<void> _loadCustomTags() async {
    if (_loadingCustomTags) return;
    setState(() => _loadingCustomTags = true);

    try {
      final tags = await _customTagsApi.listCustomTags();
      if (!mounted) return;

      setState(() {
        for (final tag in tags) {
          final type = (tag['type'] ?? '').toString();
          final label = (tag['label'] ?? '').toString();
          if (label.isEmpty) continue;

          final chipId =
          (tag['chip_id'] ?? tag['_id'] ?? '').toString().trim();
          if (chipId.isEmpty) continue;

          final isPreset = tag['is_preset'] == true;

          final chip = AbcChip(
            chipId: chipId,
            label: label,
            type: type,
            isPreset: isPreset,
          );

          switch (type) {
            case 'A':
              if (!_aChips.any((c) => c.chipId == chip.chipId)) {
                _aChips.add(chip);
              }
              break;
            case 'B':
              if (!_bChips.any((c) => c.chipId == chip.chipId)) {
                _bChips.add(chip);
              }
              break;
            case 'CP':
              if (!_physicalChips.any((c) => c.chipId == chip.chipId)) {
                _physicalChips.add(chip);
              }
              break;
            case 'CE':
              if (!_emotionChips.any((c) => c.chipId == chip.chipId)) {
                _emotionChips.add(chip);
              }
              break;
            case 'CA':
              if (!_behaviorChips.any((c) => c.chipId == chip.chipId)) {
                _behaviorChips.add(chip);
              }
              break;
          }
        }

        // 🔹 최신 상태를 static 캐시에 반영
        _cachedAChips = List<AbcChip>.from(_aChips);
        _cachedBChips = List<AbcChip>.from(_bChips);
        _cachedPhysicalChips = List<AbcChip>.from(_physicalChips);
        _cachedEmotionChips = List<AbcChip>.from(_emotionChips);
        _cachedBehaviorChips = List<AbcChip>.from(_behaviorChips);
      });
    } catch (e) {
      debugPrint('커스텀 태그 로드 실패: $e');
    } finally {
      if (mounted) setState(() => _loadingCustomTags = false);
    }
  }

  // ---------------------- 캐시 업데이트 헬퍼 ----------------------
  void _updateCacheForChip(AbcChip chip) {
    List<AbcChip>? target;
    switch (chip.type) {
      case 'A':
        _cachedAChips ??= [];
        target = _cachedAChips;
        break;
      case 'B':
        _cachedBChips ??= [];
        target = _cachedBChips;
        break;
      case 'CP':
        _cachedPhysicalChips ??= [];
        target = _cachedPhysicalChips;
        break;
      case 'CE':
        _cachedEmotionChips ??= [];
        target = _cachedEmotionChips;
        break;
      case 'CA':
        _cachedBehaviorChips ??= [];
        target = _cachedBehaviorChips;
        break;
    }
    if (target != null &&
        !target.any((c) => c.chipId == chip.chipId)) {
      target.add(chip);
    }
  }

  // ---------------------- 커스텀 태그 추가 ----------------------
  Future<void> _saveCustomTag({
    required String type,
    required String text,
    required void Function(AbcChip chip) onSuccess,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    try {
      final created = await _customTagsApi.createCustomTag(
        label: trimmed,
        type: type,
      );

      final chipId =
      (created['chip_id'] ?? created['_id'] ?? '').toString().trim();
      final label = (created['label'] ?? trimmed).toString();
      final createdType = (created['type'] ?? type).toString();
      final isPreset = created['is_preset'] == true;

      if (chipId.isEmpty || label.isEmpty) {
        throw Exception('잘못된 커스텀 태그 응답');
      }

      final chip = AbcChip(
        chipId: chipId,
        label: label,
        type: createdType,
        isPreset: isPreset,
      );

      if (!mounted) return;
      setState(() {
        // 화면 상태 업데이트
        onSuccess(chip);
        // 캐시도 함께 업데이트 → 다음 진입 시에도 바로 반영
        _updateCacheForChip(chip);
      });
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? e.response?.data['detail']?.toString()
          : e.message;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('추가에 실패했습니다: ${message ?? '오류'}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('추가에 실패했습니다: $e')),
      );
    }
  }

  Future<void> _showAddPopup({
    required String title,
    required String highlightText,
    required Iterable<String> existingLabels,
    required void Function(String text) onConfirm,
  }) async {
    final TextEditingController controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return CustomPopupDesign(
          title: title,
          highlightText: highlightText,
          message: '',
          positiveText: '추가',
          negativeText: '취소',
          onPositivePressed: () {
            final text = controller.text.trim();
            if (text.isNotEmpty) {
              onConfirm(text);
            }
            Navigator.pop(ctx);
          },
          onNegativePressed: () => Navigator.pop(ctx),
          enableInput: true,
          controller: controller,
          inputHint: '새로운 항목을 입력해주세요',
          inputMaxLength: 15,
          inputMaxLengthErrorText: '15자 이내로 작성해주세요.',
          inputValidator: (text) {
            if (text.isEmpty) return null;
            String normalize(String value) =>
                value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
            final normalizedText = normalize(text);
            final isDuplicated = existingLabels.any(
              (label) => normalize(label) == normalizedText,
            );
            if (isDuplicated) return '중복된 항목입니다.';
            return null;
          },
        );
      },
    );
  }

  // ---------------------- 캐시 업데이트 헬퍼(삭제) ----------------------
  void _removeFromCache(String chipId) {
    _cachedAChips?.removeWhere((c) => c.chipId == chipId);
    _cachedBChips?.removeWhere((c) => c.chipId == chipId);
    _cachedPhysicalChips?.removeWhere((c) => c.chipId == chipId);
    _cachedEmotionChips?.removeWhere((c) => c.chipId == chipId);
    _cachedBehaviorChips?.removeWhere((c) => c.chipId == chipId);
  }

  void _deleteTagLocallyAndRemote(String chipId) {
    // 1) 로컬 + 캐시에서 먼저 제거
    setState(() {
      _aChips.removeWhere((c) => c.chipId == chipId);
      _bChips.removeWhere((c) => c.chipId == chipId);
      _physicalChips.removeWhere((c) => c.chipId == chipId);
      _emotionChips.removeWhere((c) => c.chipId == chipId);
      _behaviorChips.removeWhere((c) => c.chipId == chipId);

      _selectedAChipIds.remove(chipId);
      _selectedBChipIds.remove(chipId);
      _selectedPhysicalChipIds.remove(chipId);
      _selectedEmotionChipIds.remove(chipId);
      _selectedBehaviorChipIds.remove(chipId);

      _removeFromCache(chipId);
    });

    // 2) 서버 삭제는 fire-and-forget 비동기로
    () async {
      try {
        await _customTagsApi.deleteCustomTag(chipId: chipId);
      } on DioException catch (e) {
        final message = e.response?.data is Map
            ? e.response?.data['detail']?.toString()
            : e.message;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제에 실패했습니다: ${message ?? '오류'}')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제에 실패했습니다: $e')),
        );
      }
    }();
  }

  // ---------------------- 다음 버튼 활성화 ----------------------
  bool get _isNextEnabled {
    switch (_currentStep) {
      case 0:
        return _selectedAChipIds.isNotEmpty;
      case 1:
        return _selectedBChipIds.isNotEmpty;
      case 2:
        if (_currentCSubStep == 0) {
          return _selectedPhysicalChipIds.isNotEmpty;
        }
        if (_currentCSubStep == 1) {
          return _selectedEmotionChipIds.isNotEmpty;
        }
        if (_currentCSubStep == 2) {
          return _selectedBehaviorChipIds.isNotEmpty;
        }
        return false;
      default:
        return false;
    }
  }

  // ---------------------- step 이동 / 완료 ----------------------
  void _nextStep() {
    setState(() {
      if (_currentStep < 2) {
        _currentStep++;
        if (_currentStep == 2) _currentCSubStep = 0;
        return;
      }

      if (_currentCSubStep < 2) {
        _currentCSubStep++;
        return;
      }

      // A/B/C 모두 끝난 경우
      if (widget.isExampleMode) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AbcRealStartScreen(sessionId: widget.sessionId),
          ),
        );
      } else {
        final activatingChips = _aChips
            .where((c) => _selectedAChipIds.contains(c.chipId))
            .toList();
        final beliefChips = _bChips
            .where((c) => _selectedBChipIds.contains(c.chipId))
            .toList();
        final physicalSelected = _physicalChips
            .where((c) => _selectedPhysicalChipIds.contains(c.chipId))
            .toList();
        final emotionSelected = _emotionChips
            .where((c) => _selectedEmotionChipIds.contains(c.chipId))
            .toList();
        final behaviorSelected = _behaviorChips
            .where((c) => _selectedBehaviorChipIds.contains(c.chipId))
            .toList();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AbcVisualizationScreen(
              sessionId: widget.sessionId,
              activatingChips: activatingChips,
              beliefChips: beliefChips,
              physicalChips: physicalSelected,
              emotionChips: emotionSelected,
              behaviorChips: behaviorSelected,
              isExampleMode: widget.isExampleMode,
              origin: widget.origin,
              diaryRoute: widget.diaryRoute,
              beforeSud: widget.beforeSud,
              abcId: widget.abcId,
              sudId: null,
            ),
          ),
        );
      }
    });
  }

  void _previousStep() {
    setState(() {
      if (_currentStep == 2 && _currentCSubStep > 0) {
        _currentCSubStep--;
      } else if (_currentStep > 0) {
        _currentStep--;
      } else {
        Navigator.pop(context);
      }
    });
  }

  // ---------------------- build ----------------------
  @override
  Widget build(BuildContext context) {
    if (_showGuide) return const AbcGuideScreen();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: (widget.isExampleMode
            ? '예시 연습하기'
            : '일기 작성'),
        onBack: () {
          if (_currentStep == 0 && _currentCSubStep == 0) {
            Navigator.pop(context);
          } else {
            _previousStep();
          }
        },
        onHomePressed: () {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
                (route) => false,
          );
        },
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.35,
            child: Image.asset(
              'assets/image/eduhome.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 34,
                      vertical: 24,
                    ),
                    child: _buildStepContent(),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
child: NavigationButtons(
                    onBack: _previousStep,
                    onNext: _isNextEnabled ? _nextStep : null,
                    rightLabel: widget.isExampleMode && _currentCSubStep == 2
                        ? '확인'
                        : '다음',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------- 각 step 내용 ----------------------
  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return StepAView(
          chips: _aChips,
          selectedChipIds: _selectedAChipIds,
          isExampleMode: widget.isExampleMode,
          onChipTap: (chipId, selected) {
            setState(() {
              _selectedAChipIds
                ..clear()
                ..add(chipId);
            });
          },
          onAddSituation: widget.isExampleMode
              ? null
              : () => _showAddPopup(
            title: '상황 추가',
            highlightText: 'A - 사건 (Activating Event)',
            existingLabels: _aChips.map((c) => c.label),
            onConfirm: (t) {
              _saveCustomTag(
                type: 'A',
                text: t,
                onSuccess: (chip) {
                  if (!_aChips
                      .any((c) => c.chipId == chip.chipId)) {
                    _aChips.add(chip);
                  }
                },
              );
            },
          ),
          onDeleteSituation: widget.isExampleMode
              ? null
              : (chipId) {
            setState(() {
              _aChips.removeWhere((c) => c.chipId == chipId);
              _selectedAChipIds.remove(chipId);
              _deleteTagLocallyAndRemote(chipId);
            });
          },
        );

      case 1:
        return StepBView(
          chips: _bChips,
          selectedChipIds: _selectedBChipIds,
          isExampleMode: widget.isExampleMode,
          onChipTap: (chipId, selected) {
            setState(() {
              if (selected) {
                _selectedBChipIds.add(chipId);
              } else {
                _selectedBChipIds.remove(chipId);
              }
            });
          },
          onAddBelief: widget.isExampleMode
              ? null
              : () => _showAddPopup(
            title: '생각 추가',
            highlightText: 'B - 생각 (Belief)',
            existingLabels: _bChips.map((c) => c.label),
            onConfirm: (t) {
              _saveCustomTag(
                type: 'B',
                text: t,
                onSuccess: (chip) {
                  if (!_bChips
                      .any((c) => c.chipId == chip.chipId)) {
                    _bChips.add(chip);
                  }
                },
              );
            },
          ),
          onDeleteBelief: widget.isExampleMode
              ? null
              : (chipId) {
            setState(() {
              _bChips.removeWhere((c) => c.chipId == chipId);
              _selectedBChipIds.remove(chipId);
              _deleteTagLocallyAndRemote(chipId);
            });
          },
        );

      case 2:
      default:
        return StepCView(
          subStep: _currentCSubStep,
          physicalChips: _physicalChips,
          emotionChips: _emotionChips,
          behaviorChips: _behaviorChips,
          selectedPhysicalChipIds: _selectedPhysicalChipIds,
          selectedEmotionChipIds: _selectedEmotionChipIds,
          selectedBehaviorChipIds: _selectedBehaviorChipIds,
          isExampleMode: widget.isExampleMode,
          onAddPhysical: widget.isExampleMode
              ? null
              : () => _showAddPopup(
            title: '신체 반응 추가',
            highlightText: 'C1 - 신체 (Physical)',
            existingLabels: _physicalChips.map((c) => c.label),
            onConfirm: (t) {
              _saveCustomTag(
                type: 'CP',
                text: t,
                onSuccess: (chip) {
                  if (!_physicalChips
                      .any((c) => c.chipId == chip.chipId)) {
                    _physicalChips.add(chip);
                  }
                },
              );
            },
          ),
          onAddEmotion: widget.isExampleMode
              ? null
              : () => _showAddPopup(
            title: '감정 반응 추가',
            highlightText: 'C2 - 감정 (Emotion)',
            existingLabels: _emotionChips.map((c) => c.label),
            onConfirm: (t) {
              _saveCustomTag(
                type: 'CE',
                text: t,
                onSuccess: (chip) {
                  if (!_emotionChips
                      .any((c) => c.chipId == chip.chipId)) {
                    _emotionChips.add(chip);
                  }
                },
              );
            },
          ),
          onAddBehavior: widget.isExampleMode
              ? null
              : () => _showAddPopup(
            title: '행동 반응 추가',
            highlightText: 'C3 - 행동 (Behavior)',
            existingLabels: _behaviorChips.map((c) => c.label),
            onConfirm: (t) {
              _saveCustomTag(
                type: 'CA',
                text: t,
                onSuccess: (chip) {
                  if (!_behaviorChips
                      .any((c) => c.chipId == chip.chipId)) {
                    _behaviorChips.add(chip);
                  }
                },
              );
            },
          ),
          onDeletePhysical: widget.isExampleMode
              ? null
              : (chipId) {
            setState(() {
              _physicalChips
                  .removeWhere((c) => c.chipId == chipId);
              _selectedPhysicalChipIds.remove(chipId);
              _deleteTagLocallyAndRemote(chipId);
            });
          },
          onDeleteEmotion: widget.isExampleMode
              ? null
              : (chipId) {
            setState(() {
              _emotionChips.removeWhere((c) => c.chipId == chipId);
              _selectedEmotionChipIds.remove(chipId);
              _deleteTagLocallyAndRemote(chipId);
            });
          },
          onDeleteBehavior: widget.isExampleMode
              ? null
              : (chipId) {
            setState(() {
              _behaviorChips.removeWhere((c) => c.chipId == chipId);
              _selectedBehaviorChipIds.remove(chipId);
              _deleteTagLocallyAndRemote(chipId);
            });
          },
          onSelectionChanged: () => setState(() {}),
        );
    }
  }
}
