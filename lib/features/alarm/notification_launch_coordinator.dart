import 'package:flutter/widgets.dart';
import 'package:gad_app_team/features/alarm/alarm_notification_service.dart';
import 'package:gad_app_team/navigation/app_navigator_key.dart';

class NotificationLaunchCoordinator extends StatefulWidget {
  const NotificationLaunchCoordinator({required this.child, super.key});

  final Widget child;

  @override
  State<NotificationLaunchCoordinator> createState() =>
      _NotificationLaunchCoordinatorState();
}

class _NotificationLaunchCoordinatorState
    extends State<NotificationLaunchCoordinator>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeLaunchHandling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _schedulePendingNotificationFlush();
    }
  }

  Future<void> _initializeLaunchHandling() async {
    await AlarmNotificationService.instance.initialize();
    if (!mounted) return;
    _schedulePendingNotificationFlush();
  }

  void _schedulePendingNotificationFlush() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AlarmNotificationService.instance.handlePendingNotificationTap();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

final NavigatorObserver notificationLaunchRouteObserver =
    _NotificationLaunchRouteObserver();

class _NotificationLaunchRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _publish(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _publish(previousRoute);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _publish(newRoute ?? oldRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  void _publish(Route<dynamic>? route) {
    updateAppCurrentRoute(route);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AlarmNotificationService.instance.handlePendingNotificationTap();
    });
  }
}
