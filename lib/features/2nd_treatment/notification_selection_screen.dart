import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/primary_action_button.dart';
import 'package:gad_app_team/widgets/map_picker.dart';
import 'package:gad_app_team/data/notification_provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';


class NotificationSelectionScreen extends StatefulWidget {
  final bool fromDirectory;
  final String? label;
  final String? abcId;
  final String? notificationId; 
  final String? origin;

  const NotificationSelectionScreen({
    super.key,
    this.fromDirectory = false,
    this.label,
    this.abcId,   
    this.notificationId,
    this.origin
  });

  @override
  State<NotificationSelectionScreen> createState() =>
      _NotificationSelectionScreenState();
}

class _NotificationSelectionScreenState
    extends State<NotificationSelectionScreen> {
  NotificationSetting? _draftTime;
  NotificationSetting? _draftLocation;
  String? _abcId;              // 연결된 ABC 문서 ID

  // DateTime _startDate = DateTime.now();
  RepeatOption _repeatOption = RepeatOption.daily;
  final Set<int> _selectedWeekdays = {};
  // “다시 알림” 전용 지연시간 (최소 1분)
  Duration _reminderDuration = const Duration(hours: 0, minutes: 0);
  // "알림을 설정하지 않을래요." 선택 여부
  bool _noNotification = false;

  // 현재 화면으로 전달된 흐름 정보 ('training', 'apply', etc.)
  String get _origin => widget.origin ?? 'etc';

  @override
  void initState() {
    super.initState();
    // 공통 초기화
    _abcId = widget.abcId;
    _loadExisting();
    debugPrint('[NOTI] _origin=$_origin');
  }

  /// 기존 알림 설정을 불러와 초깃값으로 반영
  Future<void> _loadExisting() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // ── 1) ABC 문서 찾기 ──────────────────────────────────
    DocumentSnapshot<Map<String, dynamic>>? abcDoc;

    if (widget.abcId?.isNotEmpty ?? false) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('abc_models')
          .doc(widget.abcId!)
          .get();
      if (doc.exists) abcDoc = doc;
    } else if (widget.label?.isNotEmpty ?? false) {
      final qs = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('abc_models')
          .where('activatingEvent', isEqualTo: widget.label)
          .limit(1)
          .get();
      if (qs.docs.isNotEmpty) abcDoc = qs.docs.first;
    }
    if (abcDoc == null) return;

    _abcId ??= abcDoc.id; // abcId 확보

    // ── 2) 알림 서브컬렉션(또는 단일 문서) 가져오기 ───────────────
    List<DocumentSnapshot<Map<String, dynamic>>> notifDocs = [];

    if (widget.notificationId != null && widget.notificationId!.isNotEmpty) {
      // 편집 모드: 특정 알림 한 건만
      final single = await abcDoc.reference
          .collection('notification_settings')
          .doc(widget.notificationId!)
          .get();
      if (single.exists) notifDocs = [single];
    } else {
      // 목록 모드: 모든 알림
      final qs = await abcDoc.reference
          .collection('notification_settings')
          .get();
      notifDocs = qs.docs;
    }

    // ── 3) 초깃값 세팅 ────────────────────────────────────────────
    _draftTime = null;
    _draftLocation = null;
    _selectedWeekdays.clear();

    for (final d in notifDocs) {
      final setting = NotificationSetting.fromDoc(d);

      final bool hasLocation = setting.latitude != null && setting.longitude != null;
      final bool hasTime     = setting.time != null;

      if (hasLocation) {
        _draftLocation = setting;

        // 위치 알림에 시간도 포함돼 있다면 startDate/반복 정보도 여기서 끌어옴
        if (hasTime) {
          // _startDate      = setting.startDate;
          _repeatOption   = setting.repeatOption;
          _selectedWeekdays.addAll(setting.weekdays);
        }
      } else if (hasTime) {
        _draftTime       = setting;
        // _startDate       = setting.startDate;
        _repeatOption    = setting.repeatOption;
        _selectedWeekdays.addAll(setting.weekdays);
      }

      if (setting.reminderMinutes != null) {
        _reminderDuration = Duration(minutes: setting.reminderMinutes!);
      }
    }

    // ── 4) 위치 문서에 time 정보만 있는 경우 보완 ─────────────
    if (_draftTime == null &&
        _draftLocation != null &&
        _draftLocation!.time != null) {
      _draftTime = _draftLocation!.copyWith(
        latitude: null,
        longitude: null,
        location: null,
        notifyEnter: false,
        notifyExit: false,
      );
    }

    if (mounted) setState(() {});
  }

  Future<void> _showReminderSheet() async {
    int selHour  = _reminderDuration.inHours;
    int selMin   = _reminderDuration.inMinutes % 60;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.grey100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: MediaQuery.of(ctx).viewInsets,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 248,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // ── Hours picker ──
                    Expanded(
                      child: CupertinoPicker(
                        scrollController:
                            FixedExtentScrollController(initialItem: selHour),
                        itemExtent: 40,
                        onSelectedItemChanged: (v) => selHour = v,
                        children: List.generate(
                          24,
                          (i) => Center(child: Text('$i시')),
                        ),
                      ),
                    ),
                    // ── Minutes picker ──
                    Expanded(
                      child: CupertinoPicker(
                        scrollController:
                            FixedExtentScrollController(initialItem: selMin == 0 ? 0 : selMin),
                        itemExtent: 40,
                        onSelectedItemChanged: (v) => selMin = v,
                        children: List.generate(
                          60,
                          (i) => Center(child: Text('$i분')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: NavigationButtons(
                leftLabel: '닫기',
                rightLabel: '완료',
                onBack: () => Navigator.pop(ctx),
                onNext: () {
                  setState(() {
                    _reminderDuration = Duration(hours: selHour, minutes: selMin);

                    // ⬇️ inject reminderMinutes into the drafts (if they exist)
                    if (_draftTime != null) {
                      _draftTime = _draftTime!.copyWith(
                        reminderMinutes: _reminderDuration.inMinutes,
                      );
                    }
                    if (_draftLocation != null) {
                      _draftLocation = _draftLocation!.copyWith(
                        reminderMinutes: _reminderDuration.inMinutes,
                      );
                    }
                  });
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _showRepeatSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.grey100,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setLocal) => Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 124,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 반복 주기 선택
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          title: const Text('반복'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,     // trailing 영역에 꼭 맞게
                            children: [
                              Text(
                                _repeatOption == RepeatOption.daily ? '매일' : '매주',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 4),          // 텍스트와 아이콘 간격
                              const Icon(Icons.chevron_right, size: 20, color: Colors.black54),
                            ],
                          ),
                          onTap: () async {
                            final opt = await showDialog<RepeatOption>(
                              context: ctx,
                              builder: (dctx) => SimpleDialog(
                                title: const Text('반복 설정'),
                                children: [
                                  SimpleDialogOption(
                                    onPressed: () => Navigator.pop(dctx, RepeatOption.daily),
                                    child: const Text('매일'),
                                  ),
                                  SimpleDialogOption(
                                    onPressed: () => Navigator.pop(dctx, RepeatOption.weekly),
                                    child: const Text('매주'),
                                  ),
                                ],
                              ),
                            );
                            if (opt != null) setLocal(() => _repeatOption = opt);
                          },
                        ),
                      ),
                      // 요일 선택 (weekly)
                      if (_repeatOption == RepeatOption.weekly) ...[
                        const SizedBox(height: 4),
                        Center(
                          child: Wrap(
                            spacing: 4,
                            children: List.generate(7, (i) {
                              final day = i + 1;
                              final selected = _selectedWeekdays.contains(day);
                              return FilterChip(
                                showCheckmark: false,
                                backgroundColor: Colors.white,
                                selectedColor: AppColors.indigo,
                                label: Text(
                                  ['일','월','화','수','목','금','토'][i],
                                  style: TextStyle(
                                      color: selected ? Colors.white : Colors.black),
                                ),
                                selected: selected,
                                onSelected: (_) => setLocal(() {
                                  selected
                                      ? _selectedWeekdays.remove(day)
                                      : _selectedWeekdays.add(day);
                                }),
                              );
                            }),
                          ),
                        )
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: NavigationButtons(
                    leftLabel: '닫기',
                    rightLabel: '완료',
                    onBack: () => Navigator.pop(ctx),
                    onNext: () => Navigator.pop(ctx), // state already mutated
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (mounted) setState(() {});
  }

  

  Future<void> _showTimeSheet() async {
    // ── initialise from existing time draft (if any) ──
    TimeOfDay pickedTime   = (_draftTime?.time ?? _draftLocation?.time) ?? const TimeOfDay(hour: 9, minute: 0);
    // _startDate             = (_draftTime ?? _draftLocation)?.startDate ?? DateTime.now();
    _repeatOption = (_draftTime ?? _draftLocation)?.repeatOption == RepeatOption.weekly
        ? RepeatOption.weekly
        : RepeatOption.daily;
    _selectedWeekdays
      ..clear()
      ..addAll((_draftTime ?? _draftLocation)?.weekdays ?? const []);

    final setting = await showModalBottomSheet<NotificationSetting>(
      context: context,
      backgroundColor: AppColors.grey100,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        TimeOfDay pickedTimeLocal = pickedTime;
        return StatefulBuilder(
          builder: (ctx2, setLocal) => Padding(
            padding: MediaQuery.of(ctx).viewInsets,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                SizedBox(
                  height: 248,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: false,
                    initialDateTime: DateTime(
                        0, 0, 0, pickedTimeLocal.hour, pickedTimeLocal.minute),
                    onDateTimeChanged: (dt) =>
                        pickedTimeLocal = TimeOfDay.fromDateTime(dt),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: NavigationButtons(
                    leftLabel: '닫기',
                    rightLabel: '완료',
                    onBack: () => Navigator.pop(ctx),
                    onNext: () {
                      Navigator.pop(
                        ctx,
                        NotificationSetting(
                          id: _origin == 'edit'
                              ? (_draftTime?.id ?? widget.notificationId)
                              : null,
                          time: pickedTimeLocal,
                          cause: widget.label,
                          // startDate: _startDate,
                          repeatOption: _repeatOption,
                          weekdays: _selectedWeekdays.toList(),
                          reminderMinutes: _draftTime?.reminderMinutes,
                          notifyEnter: false,
                          notifyExit: false,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (setting != null && mounted) {
      // 보존된 id가 있으면 새 설정에 주입해 중복 생성 방지
      final withId = (_draftTime?.id != null && _origin == 'edit')
          ? setting.copyWith(id: _draftTime!.id)
          : setting;
      setState(() => _draftTime = withId);
    }
  }

  Future<void> _showLocationSheet() async {
    // 기존 _draftLocation 의 좌표를 initial 으로 넘겨줄 수도 있습니다.
    LatLng? initialLatLng;
    if (_draftLocation?.latitude != null && _draftLocation?.longitude != null) {
      initialLatLng = LatLng(_draftLocation!.latitude!, _draftLocation!.longitude!);
    }

    // MapPicker 자체에서 Navigator.pop(NotificationSetting) 호출
    final setting = await showModalBottomSheet<NotificationSetting>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height,
        child: MapPicker(initial: initialLatLng),
      ),
    );

    if (setting != null && mounted) {
      // 반복 정보(기본: 매일)를 항상 포함
      final withRepeat = setting.copyWith(
        repeatOption:  _repeatOption,               // default RepeatOption.daily
        weekdays:      _selectedWeekdays.toList(),
      );

      final withId = withRepeat.copyWith(
        id: _origin == 'edit'
            ? (_draftLocation?.id ?? widget.notificationId)
            : null,
        cause: widget.label,
        reminderMinutes: _draftLocation?.reminderMinutes,
      );

      // ── 기본값: 새로 추가되는 위치 알림은 ‘들어갈 때’ 체크 상태로 ──
      final bool isNewLocation = _draftLocation == null;
      final NotificationSetting withDefault =
          isNewLocation && !(withId.notifyEnter || withId.notifyExit)
              ? withId.copyWith(notifyEnter: true)
              : withId;

      setState(() => _draftLocation = withDefault);
    }
  }

  // ────────────────────────── 공통 ListTile 위젯 ──────────────────────────
  Widget _listTile({
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool showChevron = true,
    TextStyle? subtitleStyle,
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: disabled ? Colors.grey : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: subtitleStyle ??
                        TextStyle(
                          fontSize: 16,
                          color: disabled ? Colors.grey : Colors.black54,
                        ),
                  ),
                ],
              ),
            ),
            if (showChevron && !disabled)
              const Icon(Icons.chevron_right,
                  size: 28, color: Colors.black87),
          ],
        ),
      ),
    );
  }
  // ────────────────────────── UI Helpers ──────────────────────────
  Widget _buildSaveButton() {
    return PrimaryActionButton(
      text: '저장하기',
      onPressed: ((_draftTime != null || _draftLocation != null) || _noNotification)
          ? _onSavePressed
          : null,
    );
  }

  void _showHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('도움말',style: TextStyle(fontWeight: FontWeight.bold),),
        backgroundColor: Colors.grey.shade100,
        insetPadding: const EdgeInsets.all(20),
        contentPadding: const EdgeInsets.all(AppSizes.padding),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              // ── 서론 ──
              Text(
                '알림은 걱정 일기에서 작성한 불안의 원인에 집중해 볼 '
                '위치와 시간을 원하는 방식으로 설정할 수 있어요.',
                style: TextStyle(fontSize: 20),
              ),
              SizedBox(height: 16),
              // ── 필수/선택 사항 ──
              Text('• 위치 또는 시간 중 최소 하나를 선택해야 해요.',
                  style: TextStyle(fontSize: 16)),
              Text('• 다시 알림은 선택 사항이에요.',
                  style: TextStyle(fontSize: 16)),
              Text('• 하단의 “알림을 설정하지 않을래요.”를 체크하면 ',
                  style: TextStyle(fontSize: 16)),
              Text('  알림을 끌 수 있어요.',
                  style: TextStyle(fontSize: 16)),    
              SizedBox(height: 24),
              // ── 위치 ──
              Text('위치',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('설정한 장소에 들어가거나 나올 때 알림이 울려요.',
                  style: TextStyle(fontSize: 16)),
              SizedBox(height: 16),
              // ── 시간 ──
              Text('시간',
                  style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('지정한 시간과 반복 주기로 알림이 울려요.',
                  style: TextStyle(fontSize: 16)),
                  SizedBox(height: 16),
              // ── 시간 ──
              Text('위치 + 시간',
                  style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('지정한 시간에 설정한 장소에 도착하거나 머물러 있을 때 알림이 울려요.',
                  style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
        ],
      ),
    );
  }

  void _syncReminderMinutes() {
    final m = _reminderDuration.inMinutes;
    if (_draftTime != null)     _draftTime     = _draftTime!    .copyWith(reminderMinutes: m);
    if (_draftLocation != null) _draftLocation = _draftLocation!.copyWith(reminderMinutes: m);
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

  Future<void> _onSavePressed() async {
    final navigator = Navigator.of(context);
    final provider  = NotificationProvider(); 
    
    _syncRepeatIntoDrafts();

    // 1) “알림을 설정하지 않을래요”
    if (_noNotification) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      if (_abcId == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ABC 모델을 찾을 수 없습니다.')));
        return;
      }

      final abcRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('abc_models')
          .doc(_abcId!);

      if (widget.notificationId != null && widget.notificationId!.isNotEmpty) {
        // ───────── 편집 중인 단일 알림만 제거 ─────────
        final notifRef = abcRef
            .collection('notification_settings')
            .doc(widget.notificationId);
        await notifRef.delete();

        // 스케줄 취소 (단일)
        provider.cancelSchedule(id: widget.notificationId!, abcId: _abcId!);
      } else {
        // ───────── 전체 알림 비활성화 (이전 동작) ─────────
        final batch = FirebaseFirestore.instance.batch();
        final snapshot =
            await abcRef.collection('notification_settings').get();
        for (final d in snapshot.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
        provider.cancelAllSchedules(abcId: _abcId!);
      }

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      return;
    }

    // 2) reminderMinutes 최신화
    _syncReminderMinutes();
    // ── 현재 위치 가져오기 (가능한 경우) ───────────────────────────
    Position? currentPos;
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        currentPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
        );
      }
    } catch (_) {
      // 위치를 못 얻어도 알림 자체는 저장
    }

    // 3) 선택된 알림 저장 & 스케줄
    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (_abcId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ABC 모델을 찾을 수 없습니다.')));
      return;
    }

    /* ───── 위치 + 시간 → 하나의 문서로 합치기 ───── */
    DocumentReference<Map<String, dynamic>>? timeDocToDelete;
    if (_draftTime != null && _draftLocation != null) {
      // 위치 설정에 시간 정보를 덧붙임, 입장/퇴장 조건을 무효화
      _draftLocation = _draftLocation!.copyWith(
        time:          _draftTime!.time,
        // startDate:     _draftTime!.startDate,
        repeatOption:  _draftTime!.repeatOption,
        weekdays:      _draftTime!.weekdays,
        reminderMinutes:
            _draftLocation!.reminderMinutes ?? _draftTime!.reminderMinutes,
        // 위치+시간이 동시에 있을 땐 입장/퇴장 조건을 무효화
        notifyEnter: false,
        notifyExit : false,
      );

      // time-전용 문서가 따로 있었다면 나중에 삭제
      if (_draftTime!.id != null &&
          _draftTime!.id != _draftLocation!.id) {
        timeDocToDelete = FirebaseFirestore.instance
            .collection('users').doc(uid)
            .collection('abc_models').doc(_abcId!)
            .collection('notification_settings')
            .doc(_draftTime!.id);
      }

      // 별도 time draft 제거
      _draftTime = null;
    }

    final batch = FirebaseFirestore.instance.batch();
    final List<Future<void> Function()> afterCommit = [];

    Future<void> upsert(NotificationSetting s) async {
      final col = FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('abc_models').doc(_abcId!)
          .collection('notification_settings');

      // 🔄 편집 모드일 때 ID 결정
      String? docId = s.id;
      // 편집 모드이면서 전달된 id가 없거나 빈 문자열이면, widget.notificationId로 대체
      if (_origin == 'edit' && (docId == null || docId.isEmpty)) {
        docId = widget.notificationId; // fallback
      }

      final ref = (_origin == 'edit' && docId != null && docId.isNotEmpty)
          ? col.doc(docId)
          : col.doc(); // 새 알림
      // 1️.Map으로 변환
      final Map<String, dynamic> data = s.toMap();

      // 2️.위치 정보 추가
      if (currentPos != null) {
        data['latitude']  = currentPos.latitude;
        data['longitude'] = currentPos.longitude;
      }

      if (data['time'] != null) {
        data['notifyEnter'] = null;
        data['notifyExit']  = null;
      }

      // 3️.저장 / 업데이트 및 커밋 후 스케줄링
      if (_origin == 'edit' && docId != null && docId.isNotEmpty) {
        // 편집 모드 → 기존 문서 덮어쓰기
        batch.update(ref, data);
        afterCommit.add(() async =>
            provider.updateSchedule(s.copyWith(id: ref.id), abcId: _abcId!));
      } else {
        // 추가 모드 → 새 문서 생성
        batch.set(ref, data);
        afterCommit.add(() async =>
            provider.createSchedule(s.copyWith(id: ref.id), abcId: _abcId!));
      }

      // 로컬 id 동기화
      if (s.id == null) {
        if (identical(s, _draftTime))       _draftTime    = s.copyWith(id: ref.id);
        if (identical(s, _draftLocation))   _draftLocation = s.copyWith(id: ref.id);
      }
    }

    if (_draftTime != null)     await upsert(_draftTime!);
    if (_draftLocation != null) await upsert(_draftLocation!);
    if (timeDocToDelete != null) {
      batch.delete(timeDocToDelete);
    }
    await batch.commit();
    for (final f in afterCommit) {
      await f();
    }

    if (!mounted) return;
    navigator.pushNamedAndRemoveUntil('/home', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final hasTime = (_draftTime?.time ?? _draftLocation?.time) != null;
    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: CustomAppBar(
        title: '알림 방식 선택',
        showHome: false,
        confirmOnBack: true,
        extraIcon: Icons.help_outline,
        onExtraPressed: _showHelpDialog,
      ),
      body: Stack(
      children: [
        SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      '원하는 알림 방식을 설정해 주세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 32),
                    // ── 선택된 불안 상황(라벨) 표시 ──
                    if (widget.label != null && widget.label!.trim().isNotEmpty)
                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _listTile(
                            title: '불안의 원인/상황',
                            subtitle: widget.label!,
                            showChevron: false,
                            subtitleStyle: const TextStyle(
                              fontSize: 18,
                              color: Colors.black,
                            )),
                      ),
                    const SizedBox(height: 16),
                    // ── 선택 옵션 리스트 ──
                    // ── 위치 · 시간 ──
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          _listTile(
                            title: '위치',
                            subtitle: () {
                              final s = _draftLocation;
                              if (s?.latitude == null) return '위치를 선택하지 않았습니다.';
                              final desc = s?.description?.trim();
                              final loc  = s?.location?.trim();

                              final hasDesc = (desc != null && desc.isNotEmpty);
                              final hasLoc  = (loc  != null && loc.isNotEmpty);

                              if (hasDesc && hasLoc) return "$desc ($loc)";
                              if (hasDesc) return desc;
                              if (hasLoc)  return loc;
                              return '위치를 선택하지 않았습니다.';
                            }(),
                            onTap: _noNotification ? null : _showLocationSheet,
                            disabled: _noNotification,
                          ),

                        if (_draftLocation != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: CheckboxListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    title: const Text('들어갈 때'),
                                    value: _draftLocation!.notifyEnter,
                                    onChanged: (_noNotification || hasTime)
                                      ? null
                                      : (v) => setState(() => _draftLocation =
                                            _draftLocation!.copyWith(notifyEnter: v ?? false)
                                    ),
                                  ),
                                ),
                                Container(width: 1, height: 28, color: Colors.grey.shade300),
                                Expanded(
                                  child: CheckboxListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    title: const Text('나올 때'),
                                    value: _draftLocation!.notifyExit,
                                    onChanged: (_noNotification || hasTime)
                                      ? null
                                      : (v) => setState(() => _draftLocation =
                                            _draftLocation!.copyWith(notifyExit: v ?? false)
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                            child: Divider(height: 1),
                          ),
                          _listTile(
                            title: '시간',
                            subtitle: (_draftTime?.time ?? _draftLocation?.time) != null
                                ? (() {
                                    final settingTime =
                                        _draftTime?.time ?? _draftLocation?.time;
                                    return settingTime != null
                                        ? settingTime.format(context)
                                        : '';
                                  })()
                                : '시간을 선택하지 않았습니다.',
                            onTap: _noNotification ? null : _showTimeSheet,
                            disabled: _noNotification,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ── 시작 날짜 · 다시 알림 ──
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          _listTile(
                            title: '반복',
                            subtitle: () {
                              if (_repeatOption == RepeatOption.daily) return '매일';

                              // weekly: 요일 집합 표시
                              const names = ['일','월','화','수','목','금','토'];
                              final lbl = _selectedWeekdays.isNotEmpty
                                  ? ([..._selectedWeekdays]..sort())
                                      .map((d) => names[(d - 1) % 7])
                                      .join(', ')
                                  : '';
                              return '매주 ${lbl.isNotEmpty ? lbl : ''}';
                            }(),
                            onTap: _noNotification ? null : _showRepeatSheet,
                            disabled: _noNotification,
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                            child: Divider(height: 1),
                          ),
                          // _listTile(
                          //   title: '시작 날짜',
                          //   subtitle: DateFormat('yyyy.MM.dd').format(_startDate),
                          //   onTap: _noNotification ? null : _showStartDateSheet,
                          //   disabled: _noNotification,
                          // ),
                          // Padding(
                          //   padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                          //   child: Divider(height: 1),
                          // ),
                          _listTile(
                            title: '다시 알림',
                            subtitle: (() {
                              final h = _reminderDuration.inHours;
                              final m = _reminderDuration.inMinutes % 60;
                              if (h == 0 && m == 0) return '안 함';
                              if (h > 0 && m > 0) return '$h시간 $m분 후';
                              if (h > 0) return '$h시간 후';
                              return '$m분 후';
                            })(),
                            onTap: _noNotification ? null : _showReminderSheet,
                            disabled: _noNotification,
                          ),
                        ],
                      ),
                    ),
                    // ── 알림 미설정 옵션 ──
                    Row(
                      children: [
                        Checkbox(
                          value: _noNotification,
                          onChanged: (val) {
                            setState(() {
                              _noNotification = val ?? false;
                              if (_noNotification) {
                                _draftTime = null;
                                _draftLocation = null;
                              }
                            });
                          },
                        ),
                        const Expanded(
                          child: Text(
                            '알림을 설정하지 않을래요.',
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSizes.padding, 0, AppSizes.padding, AppSizes.padding),
              child: _buildSaveButton(),
            ),
          ],
        ),
      ),
      ]
    )
    );
  }
}
