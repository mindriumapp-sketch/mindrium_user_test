import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<String?> appCurrentRouteName = ValueNotifier<String?>(null);

void updateAppCurrentRoute(Route<dynamic>? route) {
  appCurrentRouteName.value = route?.settings.name;
}

String? currentAppRouteName() => appCurrentRouteName.value?.trim();

bool isReadyForExternalNavigation(NavigatorState navigator) {
  if (navigator.canPop()) {
    return true;
  }

  final routeName = currentAppRouteName();
  if (routeName == null || routeName.isEmpty) {
    return false;
  }

  return routeName != '/' &&
      routeName != '/login' &&
      routeName != '/before_survey';
}
