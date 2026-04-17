import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';

class PermissionSettingsScreen extends StatefulWidget {
  final bool onboardingMode;
  final String nextRoute;

  const PermissionSettingsScreen({
    super.key,
    this.onboardingMode = false,
    this.nextRoute = '/home',
  });

  @override
  State<PermissionSettingsScreen> createState() =>
      _PermissionSettingsScreenState();
}

class _PermissionSettingsScreenState extends State<PermissionSettingsScreen>
    with WidgetsBindingObserver {
  PermissionStatus _notificationStatus = PermissionStatus.denied;
  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionStatus _microphoneStatus = PermissionStatus.denied;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatuses();
    }
  }

  Future<void> _refreshStatuses() async {
    setState(() => _isLoading = true);
    final notification = await Permission.notification.status;
    final location = await Permission.locationWhenInUse.status;
    final microphone = await Permission.microphone.status;
    if (!mounted) return;
    setState(() {
      _notificationStatus = notification;
      _locationStatus = location;
      _microphoneStatus = microphone;
      _isLoading = false;
    });
  }

  bool _isGranted(PermissionStatus status) => status.isGranted;

  bool get _hasRequiredPermissions =>
      _isGranted(_notificationStatus) && _isGranted(_locationStatus);

  Future<void> _requestRequiredPermission({
    required String label,
    required Permission permission,
    required bool desiredValue,
  }) async {
    if (!desiredValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label 권한은 치료 진행을 위해 필수예요. 해제할 수 없어요.')),
      );
      await _refreshStatuses();
      return;
    }

    var status = await permission.status;
    if (!status.isGranted) {
      status = await permission.request();
    }
    if (!mounted) return;

    if (status.isGranted) {
      await _refreshStatuses();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label 권한이 거부되었어요. 허용해야 치료 기능을 사용할 수 있어요.'),
        action:
            status.isPermanentlyDenied || status.isRestricted
                ? SnackBarAction(label: '설정 열기', onPressed: openAppSettings)
                : null,
      ),
    );
    await _refreshStatuses();
  }

  Future<void> _continueFromOnboarding() async {
    if (_isLoading) return;

    if (!_isGranted(_notificationStatus)) {
      await _requestRequiredPermission(
        label: '알림',
        permission: Permission.notification,
        desiredValue: true,
      );
    }
    if (!_isGranted(_locationStatus)) {
      await _requestRequiredPermission(
        label: '위치',
        permission: Permission.locationWhenInUse,
        desiredValue: true,
      );
    }

    if (!mounted) return;
    if (!_hasRequiredPermissions) return;

    Navigator.pushNamedAndRemoveUntil(context, widget.nextRoute, (_) => false);
  }

  Future<void> _requestOptionalPermission({
    required String label,
    required Permission permission,
    required bool desiredValue,
  }) async {
    if (!desiredValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label 권한 해제는 시스템 권한 설정에서 변경할 수 있어요.')),
      );
      await _refreshStatuses();
      return;
    }

    var status = await permission.status;
    if (!status.isGranted) {
      status = await permission.request();
    }
    if (!mounted) return;

    if (status.isGranted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$label 권한이 허용되었어요.')));
    } else if (status.isPermanentlyDenied || status.isRestricted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label 권한이 시스템에서 차단되어 있어요. 설정에서 변경해 주세요.'),
          action: SnackBarAction(label: '설정 열기', onPressed: openAppSettings),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$label 권한이 거부되었어요.')));
    }
    await _refreshStatuses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: '권한 설정',
        showBack: !widget.onboardingMode,
        showHome: !widget.onboardingMode,
        confirmOnBack: false,
        confirmOnHome: false,
        centerTitle: true,
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
                  _PermissionSection(
                    title: '필수 권한',
                    description: '치료 진행을 위해 꼭 필요한 권한이에요.',
                    children: [
                      _PermissionToggleTile(
                        icon: Icons.notifications_active_outlined,
                        title: '알림',
                        subtitle: '과제 리마인더와 교육 진행 안내를 위해 필요해요.',
                        value: _isGranted(_notificationStatus),
                        enabled: !_isLoading,
                        requiredPermission: true,
                        onChanged:
                            (value) => _requestRequiredPermission(
                              label: '알림',
                              permission: Permission.notification,
                              desiredValue: value,
                            ),
                      ),
                      const SizedBox(height: 10),
                      _PermissionToggleTile(
                        icon: Icons.location_on_outlined,
                        title: '위치',
                        subtitle: '위치 기반 과제/리마인더 제공을 위해 필요해요.',
                        value: _isGranted(_locationStatus),
                        enabled: !_isLoading,
                        requiredPermission: true,
                        onChanged:
                            (value) => _requestRequiredPermission(
                              label: '위치',
                              permission: Permission.locationWhenInUse,
                              desiredValue: value,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _PermissionSection(
                    title: '선택 권한',
                    description: '부가 기능 제공을 위한 권한이에요. 필요할 때만 허용해도 돼요.',
                    children: [
                      _PermissionToggleTile(
                        icon: Icons.mic_none_rounded,
                        title: '마이크',
                        subtitle: '음성 기반 기능에서 사용해요. 선택 권한이에요.',
                        value: _isGranted(_microphoneStatus),
                        enabled: !_isLoading,
                        requiredPermission: false,
                        onChanged:
                            (value) => _requestOptionalPermission(
                              label: '마이크',
                              permission: Permission.microphone,
                              desiredValue: value,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: openAppSettings,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('시스템 권한 설정 열기'),
                  ),
                  if (widget.onboardingMode) ...[
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _continueFromOnboarding,
                      child: const Text('권한 설정 완료'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionSection extends StatelessWidget {
  const _PermissionSection({
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2F3F),
              fontFamily: 'Noto Sans KR',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: Color(0xFF8A97A3),
              fontFamily: 'Noto Sans KR',
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _PermissionToggleTile extends StatelessWidget {
  const _PermissionToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.requiredPermission,
    this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final bool requiredPermission;
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C4154),
                          fontFamily: 'Noto Sans KR',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color:
                              requiredPermission
                                  ? const Color(0xFFEAF4FF)
                                  : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          requiredPermission ? '필수' : '선택',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color:
                                requiredPermission
                                    ? const Color(0xFF2E6EA3)
                                    : const Color(0xFF6B7280),
                            fontFamily: 'Noto Sans KR',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: Color(0xFF8A97A3),
                      fontFamily: 'Noto Sans KR',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF5B9FD3),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFD7E0E8),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
