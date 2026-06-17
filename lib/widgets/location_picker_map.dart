import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:gad_app_team/common/kakao_runtime_config.dart';
import 'package:gad_app_team/widgets/location_picker_map_controller.dart';
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
  bool _canUseKakaoRenderer = false;
  String? _rendererError;
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
      'LocationPickerMap renderer resolved: ${useKakao ? 'kakao' : 'unavailable'} '
      '(platform: $defaultTargetPlatform, jsKey: ${config.hasJavascriptKey ? 'present' : 'missing'})',
    );

    setState(() {
      _kakaoJavascriptKey = config.javascriptKey;
      _kakaoHtmlBaseUrl = config.mapHtmlBaseUrl;
      _canUseKakaoRenderer = useKakao;
      _rendererError = useKakao ? null : 'kakao map renderer unavailable';
      _isResolvingRenderer = false;
    });
  }

  void _showRendererError({required String reason}) {
    if (!mounted) return;

    debugPrint('LocationPickerMap renderer failed: $reason');
    setState(() {
      _canUseKakaoRenderer = false;
      _rendererError = reason;
    });
  }

  Widget _buildLoadingPlaceholder() {
    return const ColoredBox(
      color: Color(0xFFEAF2FF),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorPlaceholder() {
    return const ColoredBox(
      color: Color(0xFFEAF2FF),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '지도를 불러올 수 없습니다.\n인터넷 연결을 확인해 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF3D4352),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKakaoRenderer() {
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
      onRendererFailure: (reason) => _showRendererError(reason: reason),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isResolvingRenderer) {
      return _buildLoadingPlaceholder();
    }

    if (!_canUseKakaoRenderer || _rendererError != null) {
      return _buildErrorPlaceholder();
    }

    return _buildKakaoRenderer();
  }
}
