import 'package:flutter/material.dart';

class LocationPickerMapCurrentMarker extends StatefulWidget {
  const LocationPickerMapCurrentMarker({super.key});

  @override
  State<LocationPickerMapCurrentMarker> createState() =>
      _LocationPickerMapCurrentMarkerState();
}

class _LocationPickerMapCurrentMarkerState
    extends State<LocationPickerMapCurrentMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          final pulseScale = 0.72 + (progress * 0.88);
          final pulseOpacity = (1 - progress) * 0.28;

          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: pulseScale,
                child: Opacity(
                  opacity: pulseOpacity.clamp(0.0, 1.0),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x334A90E2),
                    ),
                  ),
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x264A90E2),
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF2F80ED),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
