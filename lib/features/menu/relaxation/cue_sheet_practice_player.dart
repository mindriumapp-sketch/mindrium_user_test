import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/data/today_task_provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/features/1st_treatment/week1_screen.dart';
import 'package:gad_app_team/features/2nd_treatment/week2_screen.dart';
import 'package:gad_app_team/features/3rd_treatment/week3_screen.dart';
import 'package:gad_app_team/features/4th_treatment/week4_screen.dart';
import 'package:gad_app_team/features/5th_treatment/week5_screen.dart';
import 'package:gad_app_team/features/6th_treatment/week6_screen.dart';
import 'package:gad_app_team/features/7th_treatment/week7_screen.dart';
import 'package:gad_app_team/features/8th_treatment/week8_screen.dart';
import 'package:gad_app_team/features/menu/relaxation/relaxation_education.dart'
    show relaxationTitleForWeek;
import 'package:gad_app_team/features/menu/relaxation/relaxation_logger.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/custom_popup_design.dart';
import 'package:gad_app_team/widgets/session_transition_dialog.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const double _kDefaultMaxImageScale = 1.5;

class RelaxationCue {
  final double startSec;
  final double endSec;
  final String screenType;
  final String imageAsset;
  final String caption;
  final String phase;
  final bool overlayPlanned;
  final double? maxImageScale;
  final String? overlayTarget;
  final String? overlayPhase;
  final String? overlayFadeIn;
  final String? overlayPeakOrHold;
  final String? overlayFadeOut;
  final String? overlayEnd;
  final String? note;
  final String? spokenFocusOrOldCaption;

  const RelaxationCue({
    required this.startSec,
    required this.endSec,
    required this.screenType,
    required this.imageAsset,
    required this.caption,
    required this.phase,
    required this.overlayPlanned,
    this.maxImageScale,
    this.overlayTarget,
    this.overlayPhase,
    this.overlayFadeIn,
    this.overlayPeakOrHold,
    this.overlayFadeOut,
    this.overlayEnd,
    this.note,
    this.spokenFocusOrOldCaption,
  });

  factory RelaxationCue.fromJson(Map<String, dynamic> json) {
    return RelaxationCue(
      startSec: _readSeconds(json, 'start_sec', legacyKey: 'start'),
      endSec: _readSeconds(json, 'end_sec', legacyKey: 'end'),
      screenType: json['screen_type'] as String? ?? '',
      imageAsset: _readImageAsset(json),
      caption: (json['caption'] as String?) ?? '',
      phase: json['phase'] as String? ?? '',
      overlayPlanned: json['overlay_planned'] == true,
      maxImageScale: (json['max_image_scale'] as num?)?.toDouble(),
      overlayTarget: json['overlay_target'] as String?,
      overlayPhase: json['overlay_phase'] as String?,
      overlayFadeIn: json['overlay_fade_in'] as String?,
      overlayPeakOrHold: json['overlay_peak_or_hold'] as String?,
      overlayFadeOut: json['overlay_fade_out'] as String?,
      overlayEnd: json['overlay_end'] as String?,
      note: json['note'] as String?,
      spokenFocusOrOldCaption: json['spoken_focus_or_old_caption'] as String?,
    );
  }
}

String _readImageAsset(Map<String, dynamic> json) {
  final raw = json['image_asset'] as String? ?? json['image'] as String? ?? '';
  return raw == 'caption_only' ? '' : raw;
}

Future<void> _completeEducationFlow({
  required BuildContext context,
  required String taskId,
  required int weekNumber,
}) async {
  final userProvider = context.read<UserProvider>();
  final todayTaskProvider = context.read<TodayTaskProvider>();
  final nav = Navigator.of(context);

  if (taskId.endsWith('_education')) {
    await userProvider.refreshProgress();
    if (!context.mounted) return;
    userProvider.markMainRelaxCompletedLocally(weekNumber: weekNumber);
    todayTaskProvider.setTodayTaskLocally(relaxationDone: true);
  }

  if (!context.mounted) return;
  _handleAfterEducationRelaxationComplete(
    context: context,
    nav: nav,
    userProvider: userProvider,
    weekNumber: weekNumber,
  );
}

Future<void> _completeNotiFlow({
  required BuildContext context,
  required String taskId,
  required int? weekNumber,
  required String nextPage,
  required String? relaxId,
}) async {
  final userProvider = context.read<UserProvider>();
  final todayTaskProvider = context.read<TodayTaskProvider>();
  final nav = Navigator.of(context);
  final currentArgs = ModalRoute.of(context)?.settings.arguments;

  if (taskId == 'daily_review') {
    await userProvider.refreshProgress();
    if (!context.mounted) return;
    todayTaskProvider.setTodayTaskLocally(relaxationDone: true);
  } else if (taskId.endsWith('_education')) {
    await userProvider.refreshProgress();
    if (!context.mounted) return;
    if (weekNumber != null) {
      userProvider.markMainRelaxCompletedLocally(weekNumber: weekNumber);
    }
    todayTaskProvider.setTodayTaskLocally(relaxationDone: true);
  }

  if (!context.mounted) return;
  final nextArgs = <String, dynamic>{
    'taskId': taskId,
    'weekNumber': weekNumber,
    'relaxId': relaxId,
  };

  if (currentArgs is Map) {
    final beforeSud = currentArgs['beforeSud'];
    final sudId = currentArgs['sudId'];
    if (beforeSud != null) nextArgs['beforeSud'] = beforeSud;
    if (sudId != null) nextArgs['sudId'] = sudId;
  }

  nav.pushNamedAndRemoveUntil(nextPage, (_) => false, arguments: nextArgs);
}

void _handleAfterEducationRelaxationComplete({
  required BuildContext context,
  required NavigatorState nav,
  required UserProvider userProvider,
  required int weekNumber,
}) {
  final shouldShowTransition =
      weekNumber == userProvider.currentWeek && !userProvider.mainCbtCompleted;

  if (!shouldShowTransition) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => CustomPopupDesign(
            title: '이완이 완료되었습니다',
            message: '잘하셨어요. 10초 후 교육 홈으로 이동합니다.',
            positiveText: '지금 이동',
            autoPositiveAfter: const Duration(seconds: 10),
            negativeText: null,
            onPositivePressed: () {
              nav.pop();
              nav.pushNamedAndRemoveUntil('/home_edu', (_) => false);
            },
          ),
    );
    return;
  }

  showRelaxationToCbtDialog(
    context: context,
    weekNumber: weekNumber,
    onMoveNow: () {
      nav.pop();
      nav.pushReplacement(
        MaterialPageRoute(builder: (_) => _buildCbtFirstScreen(weekNumber)),
      );
    },
  );
}

Widget _buildCbtFirstScreen(int weekNumber) {
  switch (weekNumber) {
    case 1:
      return const Week1Screen();
    case 2:
      return const Week2Screen();
    case 3:
      return const Week3Screen();
    case 4:
      return const Week4Screen();
    case 5:
      return const Week5Screen();
    case 6:
      return const Week6Screen();
    case 7:
      return const Week7Screen();
    case 8:
      return const Week8Screen();
    default:
      return const Week1Screen();
  }
}

double _readSeconds(
  Map<String, dynamic> json,
  String key, {
  required String legacyKey,
}) {
  final value = json[key] ?? json[legacyKey];
  if (value is num) return value.toDouble();
  if (value is String) return _parseTimestampSeconds(value);
  throw FormatException('Cue field "$key" must be seconds or timestamp.');
}

double _parseTimestampSeconds(String raw) {
  final parts = raw.split(':');
  if (parts.length != 3) {
    return double.tryParse(raw) ??
        (throw FormatException('Invalid cue timestamp: $raw'));
  }

  final hours = int.parse(parts[0]);
  final minutes = int.parse(parts[1]);
  final seconds = double.parse(parts[2]);
  return hours * 3600 + minutes * 60 + seconds;
}

const Duration _kInitialAudioDelay = Duration(milliseconds: 0);
const Duration _kAutosaveInterval = Duration(seconds: 30);

typedef CueSheetCompletionHandler =
    Future<void> Function(BuildContext context, String? relaxId);

class CueSheetEducationPlayer extends StatelessWidget {
  final String? sessionId;
  final String taskId;
  final int? weekNumber;
  final String mp3Asset;
  final String cueSheetAsset;

  const CueSheetEducationPlayer({
    super.key,
    this.sessionId,
    required this.taskId,
    required this.weekNumber,
    required this.mp3Asset,
    required this.cueSheetAsset,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedWeekNumber =
        weekNumber ?? context.read<UserProvider>().currentWeek;
    return CueSheetPlayerCore(
      taskId: taskId,
      weekNumber: weekNumber,
      mp3Asset: mp3Asset,
      cueSheetAsset: cueSheetAsset,
      title: relaxationTitleForWeek(resolvedWeekNumber),
      onCompleted: (context, relaxId) async {
        await _completeEducationFlow(
          context: context,
          taskId: taskId,
          weekNumber: resolvedWeekNumber,
        );
      },
    );
  }
}

class CueSheetNotiPlayer extends StatelessWidget {
  final String taskId;
  final int? weekNumber;
  final String mp3Asset;
  final String cueSheetAsset;
  final String nextPage;

  const CueSheetNotiPlayer({
    super.key,
    required this.taskId,
    required this.weekNumber,
    required this.mp3Asset,
    required this.cueSheetAsset,
    required this.nextPage,
  });

  @override
  Widget build(BuildContext context) {
    return CueSheetPlayerCore(
      taskId: taskId,
      weekNumber: weekNumber,
      mp3Asset: mp3Asset,
      cueSheetAsset: cueSheetAsset,
      title: weekNumber == null ? '이완 활동' : relaxationTitleForWeek(weekNumber),
      onCompleted: (context, relaxId) async {
        await _completeNotiFlow(
          context: context,
          taskId: taskId,
          weekNumber: weekNumber,
          nextPage: nextPage,
          relaxId: relaxId,
        );
      },
    );
  }
}

class CueSheetPlayerCore extends StatefulWidget {
  final String taskId;
  final int? weekNumber;
  final String mp3Asset;
  final String cueSheetAsset;
  final String title;
  final CueSheetCompletionHandler onCompleted;

  const CueSheetPlayerCore({
    super.key,
    required this.taskId,
    required this.weekNumber,
    required this.mp3Asset,
    required this.cueSheetAsset,
    required this.title,
    required this.onCompleted,
  });

  @override
  State<CueSheetPlayerCore> createState() => _CueSheetPlayerCoreState();
}

class _CueSheetPlayerCoreState extends State<CueSheetPlayerCore>
    with WidgetsBindingObserver {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final RelaxationLogger _logger;

  List<RelaxationCue> _cues = const [];
  RelaxationCue? _currentCue;
  RelaxationCue? _pendingCue;
  bool _isLoading = true;
  bool _isPlaying = false;
  bool _finalSaved = false;
  bool _audioStartedOnce = false;
  bool _volumeGuideShown = false;
  bool _canStartPlayback = false;
  String? _loadError;

  final Map<String, Future<Size?>> _imageSizeFutures = {};
  Timer? _autosaveTimer;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<void>? _completeSubscription;
  Future<void>? _precacheFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(WakelockPlus.enable());

    _logger = RelaxationLogger(
      taskId: widget.taskId,
      weekNumber: widget.weekNumber,
    );
    _logger.logEvent('start');

    _captureStartLocation();
    _startAutosaveTimer();
    _loadCueSheet();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showVolumeGuideIfNeeded();
    });
  }

  Future<void> _loadCueSheet() async {
    try {
      final raw = await rootBundle.loadString(widget.cueSheetAsset);
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw const FormatException('Cue sheet root must be a list.');
      }

      final cues =
          decoded
              .whereType<Map>()
              .map(
                (item) => RelaxationCue.fromJson(item.cast<String, dynamic>()),
              )
              .toList()
            ..sort((a, b) => a.startSec.compareTo(b.startSec));

      _precacheFuture = _precacheCueImages(cues);
      await _precacheFuture;

      if (!mounted) return;
      setState(() {
        _cues = cues;
        _currentCue = cues.isNotEmpty ? cues.first : null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Cue sheet load failed: $e');
      if (!mounted) return;
      setState(() {
        _loadError = 'cue sheet를 불러오지 못했습니다.';
        _isLoading = false;
      });
    }
  }

  Future<void> _precacheCueImages(List<RelaxationCue> cues) async {
    final imageAssets =
        cues
            .map((cue) => cue.imageAsset)
            .where((asset) => asset.isNotEmpty)
            .toSet();

    for (final imageAsset in imageAssets) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(imageAsset), context);
      } catch (e) {
        debugPrint('Cue image precache failed ($imageAsset): $e');
      }
    }
  }

  Future<Size?> _loadAssetImageSize(String asset) {
    return _imageSizeFutures.putIfAbsent(asset, () async {
      try {
        final data = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
        );
        final frame = await codec.getNextFrame();
        final image = frame.image;
        final size = Size(image.width.toDouble(), image.height.toDouble());
        image.dispose();
        codec.dispose();
        return size;
      } catch (e) {
        debugPrint('Cue image size load failed ($asset): $e');
        return null;
      }
    });
  }

  void _showVolumeGuideIfNeeded() {
    if (!mounted || _volumeGuideShown) return;
    _volumeGuideShown = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => PopScope(
            canPop: false,
            child: CustomPopupDesign(
              title: '이완 음성 안내 시작',
              message: '잠시 후, 이완을 위한 음성 안내가 시작됩니다.\n주변 소리와 음량을 조절해보세요.',
              positiveText: '확인',
              negativeText: null,
              backgroundAsset: null,
              iconAsset: null,
              onPositivePressed: () {
                Navigator.of(context).pop();
                _canStartPlayback = true;
                unawaited(_startAudioOnce());
              },
            ),
          ),
    );
  }

  void _startAutosaveTimer() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer.periodic(_kAutosaveInterval, (_) async {
      _logger.logEvent('autosave_tick');
      try {
        await _logger.saveLogs();
      } catch (e) {
        debugPrint('autosave error: $e');
      }
    });
  }

  Future<void> _startAudioOnce() async {
    if (_audioStartedOnce || !_canStartPlayback) return;
    _audioStartedOnce = true;
    await _precacheFuture;
    await _audioPlayer.setSource(AssetSource('relaxation/${widget.mp3Asset}'));
    await _audioPlayer.setVolume(0.8);
    await Future.delayed(_kInitialAudioDelay);

    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      _syncCue(position);
    });
    _completeSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      _logger.logEvent('audio_complete');
      unawaited(_completeSession());
    });

    await _audioPlayer.resume();
    if (mounted) {
      setState(() => _isPlaying = true);
    } else {
      _isPlaying = true;
    }
  }

  void _syncCue(Duration position) {
    final seconds = position.inMilliseconds / 1000.0;
    RelaxationCue? nextCue;
    for (final cue in _cues) {
      if (seconds >= cue.startSec && seconds < cue.endSec) {
        nextCue = cue;
        break;
      }
      if (seconds >= cue.startSec) {
        nextCue = cue;
      }
    }
    nextCue ??= _cues.isNotEmpty ? _cues.first : null;

    if (identical(nextCue, _currentCue) || identical(nextCue, _pendingCue)) {
      return;
    }
    if (!mounted) {
      _currentCue = nextCue;
      return;
    }

    final currentImage = _currentCue?.imageAsset ?? '';
    final nextImage = nextCue?.imageAsset ?? '';
    if (nextCue == null || nextImage.isEmpty || nextImage == currentImage) {
      setState(() => _currentCue = nextCue);
      return;
    }

    _pendingCue = nextCue;
    unawaited(_applyCueAfterImageReady(nextCue));
  }

  Future<void> _applyCueAfterImageReady(RelaxationCue cue) async {
    try {
      await precacheImage(AssetImage(cue.imageAsset), context);
    } catch (e) {
      debugPrint('Cue image switch precache failed (${cue.imageAsset}): $e');
    }

    if (!mounted || !identical(_pendingCue, cue)) return;
    setState(() {
      _currentCue = cue;
      _pendingCue = null;
    });
  }

  void _togglePlay() {
    if (!_canStartPlayback || _loadError != null) return;
    if (_isPlaying) {
      _audioPlayer.pause();
      _logger.logEvent('pause');
    } else {
      _audioPlayer.resume();
      _logger.logEvent('resume');
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  Future<void> _saveOnce({required String reason}) async {
    final isCompletionSave = reason == 'complete';
    if (_finalSaved && !isCompletionSave) return;
    if (isCompletionSave) {
      _finalSaved = true;
    }

    try {
      _logger.logEvent('final_save_$reason');
      await _logger.saveLogs();
    } catch (e) {
      debugPrint('saveLogs error ($reason): $e');
    }
  }

  Future<void> _completeSession() async {
    if (_finalSaved) return;
    _logger.setFullyCompleted();
    _logger.logEvent('session_complete');

    await _saveOnce(reason: 'complete');
    if (!mounted) return;

    await widget.onCompleted(context, _logger.relaxId);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_isPlaying) {
        _audioPlayer.pause();
        if (mounted) {
          setState(() => _isPlaying = false);
        } else {
          _isPlaying = false;
        }
      }
      _saveOnce(reason: 'app_paused');
    } else if (state == AppLifecycleState.resumed) {
      unawaited(WakelockPlus.enable());
      _startAutosaveTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
    _positionSubscription?.cancel();
    _completeSubscription?.cancel();
    _audioPlayer.dispose();
    unawaited(WakelockPlus.disable());
    _saveOnce(reason: 'dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cue = _currentCue;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        _saveOnce(reason: 'back');
      },
      child: GestureDetector(
        onTap: _togglePlay,
        child: Scaffold(
          backgroundColor: AppColors.white,
          appBar: CustomAppBar(
            title: widget.title,
            showHome: true,
            confirmOnBack: true,
          ),
          body: Stack(
            children: [
              Positioned.fill(child: _buildCueBody(cue)),
              if (!_isPlaying && !_isLoading)
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCueBody(RelaxationCue? cue) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Text(
          _loadError!,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.black,
          ),
        ),
      );
    }
    if (cue == null) {
      return const Center(
        child: Text(
          '표시할 cue가 없습니다.',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(50),
        child: _buildCueVisual(cue),
      ),
    );
  }

  Widget _buildCueVisual(RelaxationCue cue) {
    if (cue.screenType == 'caption_only' || cue.imageAsset.isEmpty) {
      return Center(
        child: Text(
          cue.caption,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            height: 1.35,
            fontWeight: FontWeight.w500,
            color: AppColors.black,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final imageAreaHeight = constraints.maxHeight * 0.66;
        final imageMaxHeight = imageAreaHeight * 0.92;
        final imageMaxWidth = constraints.maxWidth * 0.70;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: imageAreaHeight,
              child: Align(
                alignment: const Alignment(0, 0.35),
                child: _buildCueImage(
                  cue: cue,
                  imageMaxWidth: imageMaxWidth,
                  imageMaxHeight: imageMaxHeight,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                cue.caption,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: AppColors.black,
                ),
              ),
            ),
            // TODO: if cue.overlayPlanned is true and overlay assets exist,
            // render overlay PNG above the base image and animate opacity by phase.
          ],
        );
      },
    );
  }

  Widget _buildCueImage({
    required RelaxationCue cue,
    required double imageMaxWidth,
    required double imageMaxHeight,
  }) {
    final maxImageScale = cue.maxImageScale ?? _kDefaultMaxImageScale;
    if (maxImageScale <= 0) {
      return _buildConstrainedCueImage(
        cue: cue,
        maxWidth: imageMaxWidth,
        maxHeight: imageMaxHeight,
      );
    }

    return FutureBuilder<Size?>(
      future: _loadAssetImageSize(cue.imageAsset),
      builder: (context, snapshot) {
        final originalSize = snapshot.data;
        final maxWidth =
            originalSize == null
                ? imageMaxWidth
                : math.min(imageMaxWidth, originalSize.width * maxImageScale);
        final maxHeight =
            originalSize == null
                ? imageMaxHeight
                : math.min(imageMaxHeight, originalSize.height * maxImageScale);

        return _buildConstrainedCueImage(
          cue: cue,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        );
      },
    );
  }

  Widget _buildConstrainedCueImage({
    required RelaxationCue cue,
    required double maxWidth,
    required double maxHeight,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      child: Image.asset(
        cue.imageAsset,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: maxWidth,
            height: maxHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '이미지를 불러오지 못했습니다.',
              style: TextStyle(fontSize: 16),
            ),
          );
        },
      ),
    );
  }

  Future<void> _captureStartLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever ||
          perm == LocationPermission.unableToDetermine) {
        debugPrint('위치 권한 없음, 위치 로깅 생략');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );

      String? addressName;
      try {
        await setLocaleIdentifier('ko_KR');
        final placemarks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );

        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final components = <String?>[
            p.administrativeArea,
            p.locality,
            p.subLocality,
            p.thoroughfare,
          ];

          addressName = components
              .whereType<String>()
              .where((e) => e.isNotEmpty)
              .join(' ');
        }
      } catch (e) {
        debugPrint('reverse geocoding 실패: $e');
      }

      _logger.updateLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        addressName: addressName,
      );
    } catch (e) {
      debugPrint('위치 캡처 실패: $e');
    }
  }
}
