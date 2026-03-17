import 'package:flutter/material.dart';

PageRouteBuilder<T> buildWeek6NoAnimationRoute<T>(Widget child) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}
