import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:gad_app_team/common/kakao_runtime_config.dart';
import 'package:gad_app_team/widgets/location_picker_map_controller.dart';
import 'package:gad_app_team/widgets/location_picker_map_fallback.dart';
import 'package:gad_app_team/widgets/location_picker_map_kakao.dart';

export 'package:gad_app_team/widgets/location_picker_map_controller.dart';

class LocationPickerMap extends StatefulWidget {
  const LocationPickerMap({
    super.key,
    required this.controller,
    required this.initialCenter,
    required this.initialZoom,
    required this.savedMarkers,
    this.current,
    this.picked,
    this.onTap,
    this.onMapReady,
  });

  final LocationPickerMapController controller;
  final LatLng initialCenter;
  final double initialZoom;
  final LatLng? current;
  final LatLng? picked;
  final List<LatLng> savedMarkers;
  final ValueChanged<LatLng>? onTap;
  final VoidCallback? onMapReady;

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  bool _isResolvingRenderer = true;
  bool _preferKakaoRenderer = false;
  String _kakaoJavascriptKey = '';
  String _kakaoHtmlBaseUrl = KakaoRuntimeConfig.defaultHtmlBaseUrl;

  static bool get _supportsKakaoMapRenderer {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _resolveRenderer();
  }

  Future<void> _resolveRenderer() async {
    final config = await KakaoRuntimeConfig.load();
    if (!mounted) return;

    final useKakao = _supportsKakaoMapRenderer && config.hasJavascriptKey;
    debugPrint(
      'LocationPickerMap renderer resolved: ${useKakao ? 'kakao' : 'fallback'} '
      '(platform: $defaultTargetPlatform, jsKey: ${config.hasJavascriptKey ? 'present' : 'missing'})',
    );

    setState(() {
      _kakaoJavascriptKey = config.javascriptKey;
      _kakaoHtmlBaseUrl = config.mapHtmlBaseUrl;
      _preferKakaoRenderer = useKakao;
      _isResolvingRenderer = false;
    });
  }

  void _switchToFallback({required String reason}) {
    if (!mounted || !_preferKakaoRenderer) return;

    debugPrint('LocationPickerMap switching to fallback renderer: $reason');
    setState(() {
      _preferKakaoRenderer = false;
    });
  }

  Widget _buildLoadingPlaceholder() {
    return const ColoredBox(
      color: Color(0xFFEAF2FF),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildRenderer() {
    if (_preferKakaoRenderer) {
      return LocationPickerMapKakaoView(
        controller: widget.controller,
        initialCenter: widget.initialCenter,
        initialZoom: widget.initialZoom,
        current: widget.current,
        picked: widget.picked,
        savedMarkers: widget.savedMarkers,
        onTap: widget.onTap,
        onMapReady: widget.onMapReady,
        javascriptKey: _kakaoJavascriptKey,
        htmlBaseUrl: _kakaoHtmlBaseUrl,
        onRendererFailure: (reason) => _switchToFallback(reason: reason),
      );
    }

    return LocationPickerMapFallbackView(
      controller: widget.controller,
      initialCenter: widget.initialCenter,
      initialZoom: widget.initialZoom,
      current: widget.current,
      picked: widget.picked,
      savedMarkers: widget.savedMarkers,
      onTap: widget.onTap,
      onMapReady: widget.onMapReady,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isResolvingRenderer) {
      return _buildLoadingPlaceholder();
    }

    return _buildRenderer();
  }
}
