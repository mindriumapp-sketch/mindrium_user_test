import 'dart:async';

import 'package:dio/dio.dart';
import 'package:gad_app_team/data/api/sud_api.dart';
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:latlong2/latlong.dart';

import 'package:gad_app_team/widgets/map_picker.dart';
import 'package:gad_app_team/widgets/abc_chips_design.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_group_add_screen.dart'
    show AbcGroupAddScreen;

import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/loctime_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocTimeSelectionScreen extends StatefulWidget {
  final String? label;
  final String abcId;
  final String? loctimeId;
  final String? origin;
  final String? sessionId;
  final String? sudId;
  final int? beforeSud;
  final List<AbcChip> activatingChips;
  final List<AbcChip> beliefChips;
  final List<AbcChip> physicalChips;
  final List<AbcChip> emotionChips;
  final List<AbcChip> behaviorChips;
  final bool locationConsent;
  final bool autoOpenMapOnEntry;

  const LocTimeSelectionScreen({
    super.key,
    required this.abcId,
    this.label,
    this.loctimeId,
    this.origin,
    this.sessionId,
    this.sudId,
    this.beforeSud,
    this.activatingChips = const [],
    this.beliefChips = const [],
    this.physicalChips = const [],
    this.emotionChips = const [],
    this.behaviorChips = const [],
    this.locationConsent = true,
    this.autoOpenMapOnEntry = false,
  });

  @override
  State<LocTimeSelectionScreen> createState() =>
      _LocTimeSelectionScreenState();
}

class _LocTimeSelectionScreenState
    extends State<LocTimeSelectionScreen> {
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final DiariesApi _diariesApi = DiariesApi(_apiClient);
  late final SudApi _sudApi = SudApi(_apiClient);
  LocTimeSetting? _draftTime;
  LocTimeSetting? _draftLocation;
  String? _abcId; // 연결된 ABC 문서 ID (= diary_id)
  String? _lastDiaryResolveMessage;
  String? _resolvedSudId;

  RepeatOption _repeatOption = RepeatOption.daily;
  final Set<int> _selectedWeekdays = {};
  Duration _reminderDuration = const Duration(hours: 0, minutes: 0);
  bool _noLocTime = false;
  bool _isSaving = false; // 저장 중 상태
  bool _openedLocationPickerOnEntry = false;

  // ====== Alarm <-> LocTimeSetting 변환 ======

  LocTimeSetting _settingFromAlarm(Map<String, dynamic> alarm) {
    // time: "HH:MM"
    TimeOfDay? tod;
    final timeRaw = alarm['time']?.toString();
    if (timeRaw != null && timeRaw.contains(':')) {
      final parts = timeRaw.split(':');
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      tod = TimeOfDay(hour: hour, minute: minute);
    }

    // repeat_option: "daily" / "weekly"
    RepeatOption repeat = RepeatOption.daily;
    final repeatRaw = alarm['repeat_option']?.toString();
    if (repeatRaw == RepeatOption.weekly.name) {
      repeat = RepeatOption.weekly;
    }

    // weekdays: [1..7]
    final weekDays =
        (alarm['weekdays'] as List?)
            ?.map((e) => e is num ? e.toInt() : int.tryParse('$e') ?? 0)
            .where((e) => e > 0)
            .toList() ??
            const [];

    // reminder_minutes
    final reminderRaw = alarm['reminder_minutes'];
    final reminder =
    reminderRaw is num
        ? reminderRaw.toInt()
        : int.tryParse(reminderRaw?.toString() ?? '');

    return LocTimeSetting(
      id: alarm['alarm_id']?.toString(),
      diaryId: _abcId, // 클라 내부용 필드
      time: tod,
      repeatOption: repeat,
      weekdays: weekDays,
      reminderMinutes: reminder,
      location: alarm['location_desc']?.toString(),
      description: alarm['location_desc']?.toString(),
      notifyEnter: alarm['enter'] == true,
      notifyExit: alarm['exit'] == true,
      cause: widget.label,
    );
  }

  Map<String, dynamic> _alarmPayload(LocTimeSetting setting) {
    final weekDays =
    setting.repeatOption == RepeatOption.weekly
        ? (List<int>.from(setting.weekdays)..sort())
        : <int>[];

    final hasLocationText =
        (setting.location?.trim().isNotEmpty ?? false) ||
            (setting.description?.trim().isNotEmpty ?? false);

    final map = <String, dynamic>{
      'time':
      setting.time == null
          ? null
          : '${setting.time!.hour.toString().padLeft(2, '0')}:${setting.time!.minute.toString().padLeft(2, '0')}',
      'location_desc': setting.location ?? setting.description,
      'repeat_option':
      setting.repeatOption == RepeatOption.weekly ? 'weekly' : 'daily',
      'weekdays': weekDays,
      'reminder_minutes': setting.reminderMinutes,
      // false를 명시적으로 보내면 백엔드 검증에서 거절되는 경우가 있어
      // 위치 정보가 있을 때만 true 값만 전송한다.
      if (hasLocationText && setting.notifyEnter) 'enter': true,
      if (hasLocationText && setting.notifyExit) 'exit': true,
    };

    map.removeWhere((key, value) => value == null);
    return map;
  }

  Map<String, dynamic> _chipToDiaryChip(AbcChip chip) {
    return _diariesApi.makeDiaryChip(
      label: chip.label.trim(),
      chipId: chip.chipId.isEmpty ? null : chip.chipId,
    );
  }

  Future<String> _ensureDiarySaved() async {
    final hasPendingDiary = widget.activatingChips.isNotEmpty;
    var diaryId = _abcId;

    if (hasPendingDiary) {
      final activationChip = _chipToDiaryChip(widget.activatingChips.first);
      final belief = widget.beliefChips.map(_chipToDiaryChip).toList();
      final emotion = widget.emotionChips.map(_chipToDiaryChip).toList();
      final physical = widget.physicalChips.map(_chipToDiaryChip).toList();
      final behavior = widget.behaviorChips.map(_chipToDiaryChip).toList();

      if (diaryId == null || diaryId.isEmpty) {
        final created = await _diariesApi.createDiary(
          activation: activationChip,
          belief: belief,
          consequenceP: physical,
          consequenceE: emotion,
          consequenceB: behavior,
          alternativeThoughts: const [],
          alarms: const [],
        );
        diaryId = created['diary_id']?.toString();
      } else {
        await _diariesApi.updateDiary(diaryId, {
          'activation': activationChip,
          'belief': belief,
          'consequence_physical': physical,
          'consequence_emotion': emotion,
          'consequence_action': behavior,
          'alternative_thoughts': const [],
          'alarms': const [],
        });
      }

      if (diaryId == null || diaryId.isEmpty) {
        throw Exception('일기를 저장하지 못했습니다.');
      }

      if (widget.beforeSud != null &&
          (_resolvedSudId == null || _resolvedSudId!.isEmpty)) {
        try {
          final res = await _sudApi.createSudScore(
            diaryId: diaryId,
            beforeScore: widget.beforeSud!,
          );
          _resolvedSudId = res['sud_id']?.toString();
        } catch (e) {
          debugPrint('SUD 저장 실패: $e');
        }
      }

      _abcId = diaryId;
      return diaryId;
    }

    if (diaryId == null || diaryId.isEmpty) {
      throw Exception('일기 정보를 찾을 수 없습니다. 일기를 먼저 저장한 뒤 다시 시도해주세요.');
    }

    return diaryId;
  }

  // // ====== diary_id resolve ======
  //
  // Future<String?> _resolveDiaryId() async {
  //   // 1) 이미 state에 있다면 그대로 사용
  //   if (_abcId != null && _abcId!.isNotEmpty) {
  //     _lastDiaryResolveMessage = null;
  //     return _abcId;
  //   }
  //
  //   // 2) 위젯 파라미터로 전달된 abcId (사실상 diary_id)
  //   if (widget.abcId != null && widget.abcId!.isNotEmpty) {
  //     _abcId = widget.abcId;
  //     _lastDiaryResolveMessage = null;
  //     return _abcId;
  //   }
  //
  //   // 3) label 기반으로 일기 찾기 (activation.label)
  //   final label = widget.label?.trim();
  //   if (label == null || label.isEmpty) {
  //     _lastDiaryResolveMessage = '화면으로 전달된 일기 제목이 없어 일기를 특정할 수 없습니다.';
  //     return null;
  //   }
  //
  //   try {
  //     final diaries = await _diariesApi.listDiarySummaries();
  //     if (diaries.isEmpty) {
  //       _lastDiaryResolveMessage = '저장된 일기가 없습니다. 일기 작성 후 다시 시도해주세요.';
  //       return null;
  //     }
  //
  //     for (final diary in diaries) {
  //       final activation = diary['activation'];
  //       final title =
  //       activation is Map ? activation['label']?.toString().trim() : null;
  //
  //       if (title != null && title == label) {
  //         final id = diary['diary_id']?.toString();
  //         if (id != null && id.isNotEmpty) {
  //           _abcId = id;
  //           _lastDiaryResolveMessage = null;
  //           return _abcId;
  //         }
  //       }
  //     }
  //
  //     _lastDiaryResolveMessage =
  //     '"$label" 제목으로 저장된 일기를 찾지 못했습니다. 일기 제목을 확인하거나 일기 저장 후 다시 시도해주세요.';
  //   } on DioException catch (e) {
  //     final message =
  //     e.response?.data is Map
  //         ? e.response?.data['detail']?.toString()
  //         : e.message;
  //     _lastDiaryResolveMessage = '일기 목록을 불러오지 못했습니다: ${message ?? '알 수 없는 오류'}';
  //     debugPrint(_lastDiaryResolveMessage);
  //   } catch (e) {
  //     _lastDiaryResolveMessage = '일기 목록을 조회하는 중 오류가 발생했습니다: $e';
  //     debugPrint(_lastDiaryResolveMessage);
  //   }
  //
  //   return null;
  // }

  @override
  void initState() {
    super.initState();
    _noLocTime = false;
    _abcId = widget.abcId;
    _resolvedSudId = widget.sudId;
    unawaited(_loadExisting());
    _openLocationPickerOnEntryIfNeeded();
  }

  /// 기존 위치/시간 설정을 불러와 초깃값으로 반영
  Future<void> _loadExisting() async {
    // final diaryId = await _resolveDiaryId();
    final diaryId = _abcId;
    if (diaryId == null || diaryId.isEmpty) {
      if (mounted) {
        setState(() {
          _noLocTime = false;
        });
        final reason = _lastDiaryResolveMessage;
        if (reason != null && reason.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(reason)));
        }
      }
      return;
    }


    try {
      var alarms = await _diariesApi.listAlarms(diaryId);

      // loctimeId가 지정된 경우 해당 알람만 필터링
      if (widget.loctimeId != null && widget.loctimeId!.isNotEmpty) {
        final filtered = alarms.where(
              (alarm) => alarm['alarm_id']?.toString() == widget.loctimeId,
        );
        if (filtered.isNotEmpty) {
          alarms = filtered.toList();
        }
      }

      LocTimeSetting? timeSetting;
      LocTimeSetting? locationSetting;
      final weekSet = <int>{};
      Duration? reminder;

      for (final alarm in alarms) {
        final setting = _settingFromAlarm(alarm);
        final hasLocation =
            setting.notifyEnter ||
                setting.notifyExit ||
                (setting.location?.isNotEmpty ?? false);
        final hasTime = setting.time != null;

        if (hasLocation) {
          locationSetting = setting;
          weekSet.addAll(setting.weekdays);
        } else if (hasTime && timeSetting == null) {
          timeSetting = setting;
          weekSet.addAll(setting.weekdays);
        }

        if (setting.reminderMinutes != null) {
          reminder = Duration(minutes: setting.reminderMinutes!);
        }
      }

      // 위치 설정만 있고 시간도 들어있으면, 시간용 세팅도 만들어서 분리
      if (timeSetting == null &&
          locationSetting != null &&
          locationSetting.time != null) {
        final loc = locationSetting;
        timeSetting = loc.copyWith(
          latitude: null,
          longitude: null,
          location: null,
          notifyEnter: false,
          notifyExit: false,
        );
      }

      if (!mounted) return;
      setState(() {
        _draftTime = timeSetting;
        _draftLocation = locationSetting;
        _selectedWeekdays
          ..clear()
          ..addAll(
            weekSet.isNotEmpty
                ? weekSet
                : (timeSetting?.weekdays ??
                locationSetting?.weekdays ??
                const []),
          );
        _repeatOption =
            (locationSetting ?? timeSetting)?.repeatOption ??
                RepeatOption.daily;
        _reminderDuration = reminder ?? _reminderDuration;
        _noLocTime = false;
      });
    } on DioException catch (e) {
      final message =
      e.response?.data is Map
          ? e.response?.data['detail']?.toString()
          : e.message;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('위치/시간 정보를 불러오지 못했습니다: ${message ?? '오류'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('위치/시간 정보를 불러오지 못했습니다: $e')));
      }
    }
  }

  // ====== BottomSheets ======




  LocTimeSetting _buildDefaultTimeSetting() {
    final now = TimeOfDay.now();
    return LocTimeSetting(
      id: _draftTime?.id,
      diaryId: _abcId,
      time: now,
      cause: widget.label,
      repeatOption: _repeatOption,
      weekdays: _selectedWeekdays.toList(),
      reminderMinutes:
          _draftTime?.reminderMinutes ??
          _draftLocation?.reminderMinutes ??
          _reminderDuration.inMinutes,
      notifyEnter: false,
      notifyExit: false,
    );
  }

  Future<LocTimeSetting?> _buildDefaultLocationSetting() async {
    final pos = await _getPositionWithConsent(context);
    if (pos == null) return null;

    final address = await _reverseGeocodeKo(pos) ?? '현재 위치';

    return LocTimeSetting(
      id: _draftLocation?.id,
      diaryId: _abcId,
      cause: widget.label,
      location: address,
      description: address,
      latitude: pos.latitude,
      longitude: pos.longitude,
      repeatOption: _repeatOption,
      weekdays: _selectedWeekdays.toList(),
      reminderMinutes:
          _draftLocation?.reminderMinutes ??
          _draftTime?.reminderMinutes ??
          _reminderDuration.inMinutes,
      notifyEnter: true,
      notifyExit: false,
    );
  }

  void _openLocationPickerOnEntryIfNeeded() {
    if (!widget.autoOpenMapOnEntry || !mounted || _openedLocationPickerOnEntry) {
      return;
    }
    _openedLocationPickerOnEntry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showLocationSheet(saveAfterPick: true);
    });
  }

  Future<void> _showLocationSheet({bool saveAfterPick = false}) async {
    LatLng? initialLatLng;
    if (_draftLocation?.latitude != null && _draftLocation?.longitude != null) {
      initialLatLng = LatLng(
        _draftLocation!.latitude!,
        _draftLocation!.longitude!,
      );
    }

    final setting = await Navigator.of(context).push<LocTimeSetting>(
      MaterialPageRoute(
        builder: (_) => MapPicker(
          initial: initialLatLng,
          initialTime: _draftTime?.time ?? _draftLocation?.time,
        ),
      ),
    );

    if (setting == null) {
      if (saveAfterPick && mounted) {
        Navigator.maybePop(context);
      }
      return;
    }

    if (!mounted) return;

    final withRepeat = setting.copyWith(
      repeatOption: _repeatOption,
      weekdays: _selectedWeekdays.toList(),
    );

    final withId = withRepeat.copyWith(
      id: _draftLocation?.id,
      diaryId: _abcId,
      cause: widget.label,
      reminderMinutes: _draftLocation?.reminderMinutes,
    );

    final bool isNewLocation = _draftLocation == null;
    final LocTimeSetting withDefault =
        isNewLocation && !(withId.notifyEnter || withId.notifyExit)
            ? withId.copyWith(notifyEnter: true)
            : withId;

    final int reminderMinutes =
        _draftTime?.reminderMinutes ??
        _draftLocation?.reminderMinutes ??
        _reminderDuration.inMinutes;

    setState(() {
      _draftLocation = withDefault;
      _draftTime = LocTimeSetting(
        id: _draftTime?.id,
        diaryId: _abcId,
        time: withDefault.time,
        cause: widget.label,
        repeatOption: _repeatOption,
        weekdays: _selectedWeekdays.toList(),
        reminderMinutes: reminderMinutes,
        notifyEnter: false,
        notifyExit: false,
      );
      _noLocTime = false;
    });

    if (saveAfterPick) {
      await _onSavePressed();
    }
  }

  // ====== 도움말 ======


  // ====== 내부 상태 동기화 ======

  void _syncReminderMinutes() {
    final m = _reminderDuration.inMinutes;
    if (_draftTime != null) {
      _draftTime = _draftTime!.copyWith(reminderMinutes: m);
    }
    if (_draftLocation != null) {
      _draftLocation = _draftLocation!.copyWith(reminderMinutes: m);
    }
  }

  void _syncRepeatIntoDrafts() {
    if (_draftTime != null) {
      _draftTime = _draftTime!.copyWith(
        repeatOption: _repeatOption,
        weekdays: _selectedWeekdays.toList(),
      );
    }
    if (_draftLocation != null) {
      _draftLocation = _draftLocation!.copyWith(
        repeatOption: _repeatOption,
        weekdays: _selectedWeekdays.toList(),
      );
    }
  }

  // ====== 저장 버튼 ======
  /// 📍 위치/시간 설정 화면 진입 시, 뒤에서 일기 위치 한 번 업데이트 시도
  // ignore: unused_element
  Future<void> _maybeUpdateDiaryLocation() async {
    // diary_id 없으면 아무것도 안 함
    final diaryId = _abcId;
    if (diaryId == null || diaryId.isEmpty) {
      debugPrint('📍 diaryId 없음 → 위치 업데이트 스킵');
      return;
    }

    // lint 회피용: context를 지역 변수로 캡쳐
    final ctx = context;

    // 위치 + 동의 한 번 요청 (팝업은 뜨지만 UI는 안 막고, 저장은 뒤에서)
    final pos = await _getPositionWithConsent(ctx);
    if (pos == null) {
      debugPrint('📍 위치 동의/획득 실패 → 위치 업데이트 스킵');
      return;
    }

    final addressKo = await _reverseGeocodeKo(pos);

    try {
      await _diariesApi.updateDiary(diaryId, {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        if (addressKo != null) 'address_name': addressKo,
      });
      debugPrint(
        '🟢 일기 위치 백그라운드 업데이트 완료: $diaryId '
            '(lat=${pos.latitude}, lng=${pos.longitude}, addr=$addressKo)',
      );
    } catch (e, st) {
      debugPrint('⚠️ 일기 위치 백그라운드 업데이트 실패: $e\n$st');
      // 여기서는 굳이 SnackBar 안 띄우고 조용히 실패해도 됨
    }
  }

  Future<void> _onSavePressed() async {
    if (_isSaving) return;
    _syncRepeatIntoDrafts();

    debugPrint('🔵 위치/시간 저장 시작: _noLocTime=$_noLocTime');
    setState(() => _isSaving = true);

    try {
      final resolvedDiaryId = await _ensureDiarySaved();
      if (!mounted) return;

      // 1) 위치/시간 비활성화 분기(현재 UI에서는 토글 숨김)
      if (_noLocTime) {
        debugPrint('🟡 위치/시간 안 받을래요 선택됨');
        if (widget.loctimeId != null &&
            widget.loctimeId!.isNotEmpty) {
          await _diariesApi.deleteAlarm(
            resolvedDiaryId,
            widget.loctimeId!,
          );
        } else {
          await _diariesApi.deleteAllAlarms(resolvedDiaryId);
        }

        if (!mounted) return;
        debugPrint('🟢 위치/시간 없음 처리 완료');
        _handlePostSaveNavigation(resolvedDiaryId);
        return;
      }

      // 2) reminderMinutes 최신화
      _syncReminderMinutes();

      // 2-1) 미선택 항목 기본값 자동 채우기
      _draftTime ??= _buildDefaultTimeSetting();
      if (_draftLocation == null) {
        final defaultLocation = await _buildDefaultLocationSetting();
        if (defaultLocation != null) {
          _draftLocation = defaultLocation;
        }
      }

      // 위치 + 시간 → 하나의 문서로 합치기
      String? alarmIdToDelete;
      if (_draftTime != null && _draftLocation != null) {
        final hasLocationTrigger =
            _draftLocation!.notifyEnter || _draftLocation!.notifyExit;
        _draftLocation = _draftLocation!.copyWith(
          time: _draftTime!.time,
          repeatOption: _draftTime!.repeatOption,
          weekdays: _draftTime!.weekdays,
          reminderMinutes:
          _draftLocation!.reminderMinutes ?? _draftTime!.reminderMinutes,
          // 위치를 함께 저장할 때는 트리거를 모두 false로 만들지 않는다.
          // (일부 서버에서 위치 정보 + false/false 조합을 거절)
          notifyEnter: hasLocationTrigger ? _draftLocation!.notifyEnter : true,
          notifyExit: hasLocationTrigger ? _draftLocation!.notifyExit : false,
        );

        if (_draftTime!.id != null && _draftTime!.id != _draftLocation!.id) {
          alarmIdToDelete = _draftTime!.id;
        }

        _draftTime = null;
      }

      Future<void> saveSetting(LocTimeSetting setting) async {
        final payload = _alarmPayload(setting);

        Map<String, dynamic> result;
        if (setting.id != null && setting.id!.isNotEmpty) {
          result = await _diariesApi.updateAlarm(
            resolvedDiaryId,
            setting.id!,
            payload,
          );
        } else {
          result = await _diariesApi.createAlarm(resolvedDiaryId, payload);
        }

        final updated = _settingFromAlarm({
          ...result,
          'diaryId': resolvedDiaryId, // 클라 내부용으로 diaryId 붙여줌
        });
        if (identical(setting, _draftTime)) {
          _draftTime = updated;
        }
        if (identical(setting, _draftLocation)) {
          _draftLocation = updated;
        }
      }

      final draftTimeLocal = _draftTime;
      if (draftTimeLocal != null) {
        await saveSetting(draftTimeLocal);
      }
      final draftLocationLocal = _draftLocation;
      if (draftLocationLocal != null) {
        await saveSetting(draftLocationLocal);
      }

      if (alarmIdToDelete != null && alarmIdToDelete.isNotEmpty) {
        await _diariesApi.deleteAlarm(resolvedDiaryId, alarmIdToDelete);
      }

      debugPrint('🟢 위치/시간 설정 완료');
      _handlePostSaveNavigation(resolvedDiaryId);
    } on DioException catch (e, st) {
      debugPrint('위치/시간 저장 중 오류: $e\n$st');
      String? message;
      final data = e.response?.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          message = detail;
        } else if (detail is List && detail.isNotEmpty) {
          message = detail.first.toString();
        } else {
          message = data['message']?.toString();
        }
      } else {
        message = e.message;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message ?? '위치/시간을 저장하는 중 오류가 발생했습니다. 다시 시도해주세요.'),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('위치/시간 저장 중 오류: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치/시간을 저장하는 중 오류가 발생했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      } else {
        _isSaving = false;
      }
    }
  }

  // ====== 저장 후 네비게이션 ======

  void _handlePostSaveNavigation(String diaryId) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AbcGroupAddScreen(
          origin: widget.origin ?? 'etc',
          diaryId: diaryId,
          label: widget.label,
          sessionId: widget.sessionId,
          sudId: _resolvedSudId ?? widget.sudId,
        ),
      ),
    );
  }

  // ====== 빌드 ======

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.shrink(),
    );
  }



  // 📍 위치 + 동의 + 타임아웃까지 한 번에 처리하는 헬퍼
  Future<Position?> _getPositionWithConsent(BuildContext ctx) async {
    if (!mounted) return null;

    if (!widget.locationConsent) {
      debugPrint('일기 위치 저장 미동의 - 위치 요청 스킵');
      return null;
    }

    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        // ⏱ 최대 3초까지만 기다리고, 넘으면 null
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('위치 접근 실패: $e');
    }
    return null;
  }

  Future<String?> _reverseGeocodeKo(Position pos) async {
    try {
      await setLocaleIdentifier('ko_KR');

      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      ).timeout(const Duration(seconds: 3));

      if (placemarks.isEmpty) return null;
      final p = placemarks.first;

      String? clean(String? v) {
        if (v == null) return null;
        final t = v.trim();
        return t.isEmpty ? null : t;
      }

      final chunks = <String?>[
        clean(p.administrativeArea), // 시/도
        clean(p.locality),           // 시/군/구
        clean(p.subLocality),
        clean(p.thoroughfare),
        clean(p.subThoroughfare),
      ].whereType<String>().toList();

      if (chunks.isEmpty) return null;
      return chunks.join(' ');
    } catch (e) {
      debugPrint('역지오코딩 실패: $e');
      return null;
    }
  }
}
