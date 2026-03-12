import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:uuid/uuid.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/custom_popup_design.dart';
import 'package:gad_app_team/widgets/map_picker.dart';
import 'package:gad_app_team/data/loctime_provider.dart';
import 'package:gad_app_team/data/api/alarm_settings_api.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:latlong2/latlong.dart';

import 'alarm_notification_service.dart';
import 'alarm_settings_sync_helper.dart';

Future<void> _showAlarmGuideDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder:
        (dialogContext) => CustomPopupDesign(
          title: '알림 설정 도움말',
          message:
              '1) 오른쪽 아래 [알림 추가] 버튼으로 새 알림을 만들 수 있어요.\n'
              '2) 목록 카드를 누르면 알림 이름/시간/반복 요일을 수정할 수 있고, 요일은 최소 1개 이상 선택해야 저장됩니다.\n'
              '3) 목록의 스위치로 알림을 바로 켜고 끌 수 있어요.\n'
              '4) 위치 기반 알림을 켜면 지도에서 위치를 선택하고, 진입/이탈 조건을 1개 이상 선택해야 합니다.\n'
              '5) 목록 카드에서 왼쪽으로 밀거나 수정 화면의 [알림 삭제]로 삭제할 수 있어요.',
          positiveText: '확인',
          negativeText: null,
          backgroundAsset: null,
          iconAsset: null,
          onPositivePressed: () => Navigator.pop(dialogContext),
        ),
  );
}

class AlarmSettingsScreen extends StatefulWidget {
  const AlarmSettingsScreen({super.key});

  @override
  State<AlarmSettingsScreen> createState() => _AlarmSettingsScreenState();
}

class _AlarmSettingsScreenState extends State<AlarmSettingsScreen> {
  final AlarmNotificationService _service = AlarmNotificationService.instance;
  final Uuid _uuid = const Uuid();
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final AlarmSettingsApi _alarmSettingsApi = AlarmSettingsApi(_apiClient);

  bool _isLoading = true;
  List<AlarmSetting> _alarms = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _service.initialize();
    List<AlarmSetting> alarms = const [];

    try {
      final remote = await AlarmSettingsSyncHelper.fetchAndSync(
        api: _alarmSettingsApi,
        service: _service,
      );
      alarms = List<AlarmSetting>.from(remote)..sort(_compareAlarm);
    } catch (e) {
      debugPrint('알림 설정 서버 조회 실패(로컬 사용): $e');
      alarms = await _service.loadAlarms();
      await _service.syncAlarms(alarms);
    }

    if (!mounted) return;

    setState(() {
      _alarms = alarms;
      _isLoading = false;
    });
  }

  Future<void> _persist(List<AlarmSetting> alarms) async {
    final copied = List<AlarmSetting>.from(alarms)..sort(_compareAlarm);
    setState(() => _alarms = copied);

    try {
      final synced = await AlarmSettingsSyncHelper.replaceAndSync(
        api: _alarmSettingsApi,
        alarms: copied,
        service: _service,
      );
      final sortedSynced = List<AlarmSetting>.from(synced)..sort(_compareAlarm);

      if (mounted) {
        setState(() => _alarms = sortedSynced);
      }
    } catch (e) {
      debugPrint('알림 설정 서버 저장 실패(로컬만 저장): $e');
      await _service.saveAlarms(copied);
    }
  }

  Future<void> _addAlarm() async {
    final now = TimeOfDay.now();
    final newAlarm = AlarmSetting(
      id: _uuid.v4(),
      hour: now.hour,
      minute: now.minute,
      label: 'Mindrium 알림',
      enabled: true,
      weekdays: const [1, 2, 3, 4, 5, 6, 7],
      vibration: true,
    );

    final result = await Navigator.of(context).push<_AlarmEditResult>(
      MaterialPageRoute(
        builder: (_) => _AlarmEditScreen(initialAlarm: newAlarm, isNew: true),
      ),
    );
    if (!mounted || result == null) return;

    if (result.action == _AlarmEditAction.save && result.alarm != null) {
      await _upsert(result.alarm!);
    }
  }

  Future<void> _editAlarm(AlarmSetting alarm) async {
    final result = await Navigator.of(context).push<_AlarmEditResult>(
      MaterialPageRoute(
        builder: (_) => _AlarmEditScreen(initialAlarm: alarm, isNew: false),
      ),
    );
    if (!mounted || result == null) return;

    if (result.action == _AlarmEditAction.save && result.alarm != null) {
      await _upsert(result.alarm!);
      return;
    }

    if (result.action == _AlarmEditAction.delete &&
        result.deleteId != null &&
        result.deleteId!.isNotEmpty) {
      await _delete(result.deleteId!);
    }
  }

  Future<void> _upsert(AlarmSetting updated) async {
    final copied = List<AlarmSetting>.from(_alarms);
    final index = copied.indexWhere((a) => a.id == updated.id);
    if (index >= 0) {
      copied[index] = updated;
    } else {
      copied.add(updated);
    }
    await _persist(copied);
  }

  Future<void> _toggle(AlarmSetting alarm, bool enabled) async {
    await _upsert(alarm.copyWith(enabled: enabled));
  }

  Future<void> _delete(String alarmId) async {
    final copied = List<AlarmSetting>.from(_alarms)
      ..removeWhere((a) => a.id == alarmId);
    await _persist(copied);
  }

  String _repeatText(AlarmSetting alarm) {
    final sorted = alarm.weekdays.toSet().toList()..sort();
    if (sorted.length == 7) return '매일';
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return sorted.map((d) => labels[d - 1]).join(' ');
  }

  String _formatTime(BuildContext context, AlarmSetting alarm) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(
      TimeOfDay(hour: alarm.hour, minute: alarm.minute),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
  }

  String _locationDetailText(AlarmSetting alarm) {
    if (!alarm.locationEnabled) return '';
    final label = alarm.locationLabel?.trim();
    final address = alarm.locationAddress?.trim();
    if ((label?.isNotEmpty ?? false) && (address?.isNotEmpty ?? false)) {
      return '$label, $address';
    }
    if (label?.isNotEmpty ?? false) return label!;
    if (address?.isNotEmpty ?? false) return address!;
    return '위치 알림 사용';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: '알림 설정',
        confirmOnBack: false,
        confirmOnHome: false,
        actionIconGap: 6,
        extraIcon: Icons.help_outline_rounded,
        onExtraPressed: () {
          _showAlarmGuideDialog(context);
        },
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _MindriumBackground(),
          SafeArea(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _alarms.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: _alarms.length,
                      itemBuilder: (context, index) {
                        final alarm = _alarms[index];
                        return Dismissible(
                          key: ValueKey(alarm.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade300,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (_) => _delete(alarm.id),
                          child: InkWell(
                            onTap: () => _editAlarm(alarm),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatTime(context, alarm),
                                          style: const TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          alarm.label,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _repeatText(alarm),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        if (alarm.locationEnabled) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            _locationDetailText(alarm),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF3C78A8),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: alarm.enabled,
                                    onChanged: (value) => _toggle(alarm, value),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
          Positioned(
            right: 18,
            bottom: 18,
            child: SafeArea(
              top: false,
              left: false,
              child: _CornerAddButton(onTap: _addAlarm),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.alarm_rounded,
              size: 56,
              color: Colors.blueGrey.shade300,
            ),
            const SizedBox(height: 12),
            const Text(
              '설정된 알림이 없습니다.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '오른쪽 아래 버튼으로 알림을 추가해보세요.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  int _compareAlarm(AlarmSetting a, AlarmSetting b) {
    final aMinutes = a.hour * 60 + a.minute;
    final bMinutes = b.hour * 60 + b.minute;
    if (aMinutes != bMinutes) return aMinutes.compareTo(bMinutes);
    return a.id.compareTo(b.id);
  }
}

enum _AlarmEditAction { save, delete }

class _AlarmEditResult {
  final _AlarmEditAction action;
  final AlarmSetting? alarm;
  final String? deleteId;

  const _AlarmEditResult.save(this.alarm)
    : action = _AlarmEditAction.save,
      deleteId = null;

  const _AlarmEditResult.delete(this.deleteId)
    : action = _AlarmEditAction.delete,
      alarm = null;
}

class _AlarmEditScreen extends StatefulWidget {
  const _AlarmEditScreen({required this.initialAlarm, required this.isNew});

  final AlarmSetting initialAlarm;
  final bool isNew;

  @override
  State<_AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends State<_AlarmEditScreen> {
  int _hour = 9;
  int _minute = 0;
  bool _enabled = true;
  bool _vibration = true;
  bool _locationEnabled = false;
  bool _notifyOnEnter = true;
  bool _notifyOnExit = false;
  int _locationRadiusMeters = 100;
  List<int> _weekdays = const [1, 2, 3, 4, 5, 6, 7];
  double? _latitude;
  double? _longitude;
  String? _locationLabel;
  String? _locationAddress;
  DateTime _pickerTime = DateTime(2000, 1, 1, 9, 0);
  final TextEditingController _labelController = TextEditingController();

  bool _isValidCoordinatePair(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (!lat.isFinite || !lng.isFinite) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  @override
  void initState() {
    super.initState();
    _hour = widget.initialAlarm.hour;
    _minute = widget.initialAlarm.minute;
    _enabled = widget.initialAlarm.enabled;
    _vibration = widget.initialAlarm.vibration;
    _locationEnabled = widget.initialAlarm.locationEnabled;
    _notifyOnEnter = widget.initialAlarm.notifyOnEnter;
    _notifyOnExit = widget.initialAlarm.notifyOnExit;
    _locationRadiusMeters = widget.initialAlarm.locationRadiusMeters;
    _weekdays = widget.initialAlarm.weekdays.toSet().toList()..sort();
    _latitude = widget.initialAlarm.latitude;
    _longitude = widget.initialAlarm.longitude;
    _locationLabel = widget.initialAlarm.locationLabel;
    _locationAddress = widget.initialAlarm.locationAddress;
    _pickerTime = DateTime(2000, 1, 1, _hour, _minute);
    _labelController.text = widget.initialAlarm.label;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _toggleWeekday(int day) {
    final copied = List<int>.from(_weekdays);
    if (copied.contains(day)) {
      if (copied.length == 1) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('요일은 최소 1개 이상 선택해야 합니다.')));
        return;
      }
      copied.remove(day);
    } else {
      copied.add(day);
      copied.sort();
    }
    setState(() => _weekdays = copied);
  }

  Future<void> _pickLocation() async {
    final navigator = Navigator.of(context);
    final allowed =
        await AlarmNotificationService.instance.requestLocationPermission();
    if (!mounted) return;
    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 권한을 허용해야 위치 알림을 설정할 수 있어요.')),
      );
      return;
    }

    final initial =
        _isValidCoordinatePair(_latitude, _longitude)
            ? LatLng(_latitude!, _longitude!)
            : null;

    final selected = await navigator.push<LocTimeSetting>(
      MaterialPageRoute(
        builder:
            (_) => MapPicker(
              initial: initial,
              initialTime: TimeOfDay(hour: _hour, minute: _minute),
              enableLocationLabel: true,
              initialLocationLabel: _locationLabel,
              showSavedMarkers: false,
              enableTimeSelection: false,
            ),
      ),
    );

    if (!mounted || selected == null) return;

    setState(() {
      _latitude = selected.latitude;
      _longitude = selected.longitude;
      _locationLabel = selected.location ?? selected.description;
      _locationAddress = selected.description;
      _locationEnabled = true;
      if (!_notifyOnEnter && !_notifyOnExit) {
        _notifyOnEnter = true;
      }
    });
  }

  void _save() {
    final label =
        _labelController.text.trim().isEmpty
            ? 'Mindrium 알림'
            : _labelController.text.trim();

    if (_locationEnabled && (_latitude == null || _longitude == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 알림을 켜려면 위치를 먼저 선택해주세요.')),
      );
      return;
    }
    if (_locationEnabled && !_notifyOnEnter && !_notifyOnExit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 알림 조건(진입/이탈)을 1개 이상 선택해주세요.')),
      );
      return;
    }

    Navigator.pop(
      context,
      _AlarmEditResult.save(
        widget.initialAlarm.copyWith(
          hour: _hour,
          minute: _minute,
          enabled: _enabled,
          vibration: _vibration,
          weekdays: _weekdays,
          label: label,
          locationEnabled: _locationEnabled,
          latitude: _latitude,
          longitude: _longitude,
          locationLabel: _locationLabel,
          locationAddress: _locationAddress,
          locationRadiusMeters: _locationRadiusMeters,
          notifyOnEnter: _notifyOnEnter,
          notifyOnExit: _notifyOnExit,
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('알림 삭제'),
          content: const Text('이 알림을 삭제할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      if (!mounted) return;
      Navigator.pop(context, _AlarmEditResult.delete(widget.initialAlarm.id));
    }
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 17, color: const Color(0xFF2B78B7)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B3F5F),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    final hasLocation = _isValidCoordinatePair(_latitude, _longitude);
    final locationLabelText = _locationLabel?.trim() ?? '';
    final locationAddressText = _locationAddress?.trim() ?? '';
    final resolvedLocationLabel =
        locationLabelText.isNotEmpty
            ? locationLabelText
            : (hasLocation ? '선택한 위치' : '위치를 선택해주세요.');

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: '알림 설정',
        confirmOnBack: false,
        confirmOnHome: false,
        actionIconGap: 6,
        extraIcon: Icons.help_outline_rounded,
        onExtraPressed: () {
          _showAlarmGuideDialog(context);
        },
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _MindriumBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _labelController,
                        decoration: InputDecoration(
                          labelText: '알림 이름',
                          filled: true,
                          fillColor: const Color(0xFFF7FAFD),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _sectionTitle('시간', Icons.access_time_rounded),
                      const SizedBox(height: 8),
                      Column(
                        children: [
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 156,
                            child: CupertinoDatePicker(
                              mode: CupertinoDatePickerMode.time,
                              use24hFormat:
                                  MediaQuery.of(context).alwaysUse24HourFormat,
                              initialDateTime: _pickerTime,
                              onDateTimeChanged: (dt) {
                                final next = DateTime(
                                  2000,
                                  1,
                                  1,
                                  dt.hour,
                                  dt.minute,
                                );
                                setState(() {
                                  _pickerTime = next;
                                  _hour = dt.hour;
                                  _minute = dt.minute;
                                });
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      const Divider(height: 22),
                      _sectionTitle('위치', Icons.place_outlined),
                      const SizedBox(height: 4),
                      SwitchListTile.adaptive(
                        value: _locationEnabled,
                        onChanged: (value) {
                          setState(() => _locationEnabled = value);
                        },
                        title: const Text('위치 기반 알림'),
                        subtitle: const Text('지정 위치 진입/이탈 시 알림'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_locationEnabled) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FBFF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  hasLocation
                                      ? const Color(0xFFBBD6EE)
                                      : const Color(0xFFD3E3F3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    resolvedLocationLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1A2E42),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          hasLocation
                                              ? const Color(0xFFE4F2FF)
                                              : const Color(0xFFF1F3F5),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      hasLocation ? '설정됨' : '미설정',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            hasLocation
                                                ? const Color(0xFF1F5E93)
                                                : const Color(0xFF7A8795),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (locationAddressText.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  locationAddressText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF5D6A77),
                                    height: 1.35,
                                  ),
                                ),
                              ] else if (!hasLocation) ...[
                                const SizedBox(height: 4),
                                const Text(
                                  '지도에서 알림을 받을 장소를 선택해주세요.',
                                  style: TextStyle(
                                    fontSize: 12.3,
                                    color: Color(0xFF7C8A98),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _pickLocation,
                                  icon: const Icon(
                                    Icons.map_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    hasLocation ? '위치 다시 선택' : '지도에서 위치 선택',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF2F8FD8),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 11,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                dense: true,
                                value: _notifyOnEnter,
                                onChanged: (value) {
                                  setState(
                                    () => _notifyOnEnter = value == true,
                                  );
                                },
                                contentPadding: EdgeInsets.zero,
                                visualDensity: const VisualDensity(
                                  horizontal: -4,
                                  vertical: -3,
                                ),
                                title: const Text(
                                  '위치 진입 시 알림',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: CheckboxListTile(
                                dense: true,
                                value: _notifyOnExit,
                                onChanged: (value) {
                                  setState(() => _notifyOnExit = value == true);
                                },
                                contentPadding: EdgeInsets.zero,
                                visualDensity: const VisualDensity(
                                  horizontal: -4,
                                  vertical: -3,
                                ),
                                title: const Text(
                                  '위치 이탈 시 알림',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      const Divider(height: 22),
                      _sectionTitle('반복 요일', Icons.repeat_rounded),
                      const SizedBox(height: 10),
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(7, (index) {
                            final day = index + 1;
                            final selected = _weekdays.contains(day);
                            return FilterChip(
                              label: Text(labels[index]),
                              selected: selected,
                              showCheckmark: false,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: const VisualDensity(
                                horizontal: -2,
                                vertical: -2,
                              ),
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              selectedColor: const Color(0xFFD8ECFF),
                              backgroundColor: const Color(0xFFF4F7FB),
                              side: BorderSide(
                                color:
                                    selected
                                        ? const Color(0xFF79AEE0)
                                        : const Color(0xFFD5DEE8),
                              ),
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color:
                                    selected
                                        ? const Color(0xFF1F5E93)
                                        : const Color(0xFF5B6A79),
                              ),
                              onSelected: (_) => _toggleWeekday(day),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 22),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2F8FD8), Color(0xFF2170B8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF2F8FD8,
                              ).withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            '저장',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (!widget.isNew) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _confirmDelete,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('알림 삭제'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MindriumBackground extends StatelessWidget {
  const _MindriumBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/image/eduhome.png', fit: BoxFit.cover),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xAAFFFFFF), Color(0x66FFFFFF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }
}

class _CornerAddButton extends StatelessWidget {
  const _CornerAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1F8AD7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_alarm_rounded, size: 19, color: Colors.white),
              SizedBox(width: 6),
              Text(
                '알림 추가',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
