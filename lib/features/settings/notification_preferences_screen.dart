import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/today_task_provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/features/alarm/alarm_notification_service.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  static const Color _accentColor = Color(0xFF5B9FD3);

  bool _educationEnabled = true;
  bool _todayTaskReminderEnabled = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final service = AlarmNotificationService.instance;
    final educationEnabled = await service.isEducationReminderEnabled();
    final todayTaskReminderEnabled = await service.isTodayTaskReminderEnabled();
    if (!mounted) return;
    setState(() {
      _educationEnabled = educationEnabled;
      _todayTaskReminderEnabled = todayTaskReminderEnabled;
    });
  }

  Future<void> _handleEducationToggle(bool value) async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    final user = context.read<UserProvider>();
    final service = AlarmNotificationService.instance;

    if (value) {
      await service.requestPermissions();
      final status = await Permission.notification.request();
      if (!status.isGranted && !status.isProvisional) {
        await service.setEducationReminderEnabled(
          false,
          currentWeek: user.currentWeek,
          lastCompletedWeek: user.lastCompletedWeek,
          lastCompletedAt: user.lastCompletedAt,
        );
        if (!mounted) return;
        setState(() {
          _educationEnabled = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('교육 알림을 받으려면 알림 권한이 필요해요.')),
        );
        return;
      }
    }

    await service.setEducationReminderEnabled(
      value,
      currentWeek: user.currentWeek,
      lastCompletedWeek: user.lastCompletedWeek,
      lastCompletedAt: user.lastCompletedAt,
    );

    if (!mounted) return;
    setState(() {
      _educationEnabled = value;
      _isSaving = false;
    });

    if (value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이번 주 교육 미완료 시 화·목·일 저녁에 알려드릴게요.')),
      );
    }
  }

  Future<void> _handleTodayTaskReminderToggle(bool value) async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    final todayTask = context.read<TodayTaskProvider>();
    final service = AlarmNotificationService.instance;

    if (value) {
      await service.requestPermissions();
      final status = await Permission.notification.request();
      if (!status.isGranted && !status.isProvisional) {
        await service.setTodayTaskReminderEnabled(
          false,
          todayDate: todayTask.date,
          diaryDone: todayTask.diaryDone,
          relaxationDone: todayTask.relaxationDone,
        );
        if (!mounted) return;
        setState(() {
          _todayTaskReminderEnabled = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('미수행 알림을 받으려면 알림 권한이 필요해요.')),
        );
        return;
      }
    }

    await service.setTodayTaskReminderEnabled(
      value,
      todayDate: todayTask.date,
      diaryDone: todayTask.diaryDone,
      relaxationDone: todayTask.relaxationDone,
    );

    if (!mounted) return;
    setState(() {
      _todayTaskReminderEnabled = value;
      _isSaving = false;
    });

    if (value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오늘의 할 일을 2일 넘게 쉬면 3일째 저녁에 알려드릴게요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(
        title: '리마인더',
        showHome: true,
        confirmOnBack: false,
        confirmOnHome: false,
        centerTitle: true,
        leadingIconColor: Color(0xFF1E2F3F),
        titleTextStyle: TextStyle(
          fontFamily: 'Noto Sans KR',
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: Color(0xFF1E2F3F),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: Stack(
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
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFCFFFFFF),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE5EDF4)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '리마인더 설정',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E2F3F),
                              fontFamily: 'Noto Sans KR',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '교육 미완료 알림과 오늘의 할 일 미수행 알림을 설정할 수 있어요.',
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              color: Color(0xFF8A97A3),
                              fontFamily: 'Noto Sans KR',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _NotificationPreferenceRow(
                          icon: Icons.notifications_none_rounded,
                          title: '교육 알림',
                          value: _educationEnabled,
                          accentColor: _accentColor,
                          onChanged: _isSaving ? null : _handleEducationToggle,
                        ),
                        const SizedBox(height: 10),
                        _NotificationPreferenceRow(
                          icon: Icons.event_note_rounded,
                          title: '오늘의 할 일 알림',
                          value: _todayTaskReminderEnabled,
                          accentColor: _accentColor,
                          onChanged:
                              _isSaving ? null : _handleTodayTaskReminderToggle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationPreferenceRow extends StatelessWidget {
  const _NotificationPreferenceRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.accentColor,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final Color accentColor;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAF0F5)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F7FB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: const Color(0xFF2C4154)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C4154),
                fontFamily: 'Noto Sans KR',
              ),
            ),
          ),
          Transform.scale(
            scale: 0.9,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: accentColor,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFD7E0E8),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}
