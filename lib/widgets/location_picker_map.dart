import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:gad_app_team/common/app_env.dart';
import 'package:gad_app_team/utils/text_line_material.dart';

class LocationPickerMapController {
  _LocationPickerMapDelegate? _delegate;

  Future<void> move(LatLng center, {double zoom = 16}) async {
    await _delegate?.move(center, zoom: zoom);
  }

  Future<void> zoomIn() async {
    await _delegate?.zoomIn();
  }

  Future<void> zoomOut() async {
    await _delegate?.zoomOut();
  }

  void _attach(_LocationPickerMapDelegate delegate) {
    _delegate = delegate;
  }

  void _detach(_LocationPickerMapDelegate delegate) {
    if (_delegate == delegate) {
      _delegate = null;
    }
  }
}

abstract class _LocationPickerMapDelegate {
  Future<void> move(LatLng center, {required double zoom});
  Future<void> zoomIn();
  Future<void> zoomOut();
}

class LocationPickerMap extends StatelessWidget {
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

  static bool get _canUseKakaoMap {
    if (!AppEnv.hasKakaoMapJavascriptKey) return false;
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
  Widget build(BuildContext context) {
    if (_canUseKakaoMap) {
      return _KakaoLocationPickerMap(
        controller: controller,
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        current: current,
        picked: picked,
        savedMarkers: savedMarkers,
        onTap: onTap,
        onMapReady: onMapReady,
      );
    }

    return _FallbackLocationPickerMap(
      controller: controller,
      initialCenter: initialCenter,
      initialZoom: initialZoom,
      current: current,
      picked: picked,
      savedMarkers: savedMarkers,
      onTap: onTap,
      onMapReady: onMapReady,
    );
  }
}

class _FallbackLocationPickerMap extends StatefulWidget {
  const _FallbackLocationPickerMap({
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
  State<_FallbackLocationPickerMap> createState() =>
      _FallbackLocationPickerMapState();
}

class _FallbackLocationPickerMapState extends State<_FallbackLocationPickerMap>
    implements _LocationPickerMapDelegate {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onMapReady?.call();
    });
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    super.dispose();
  }

  @override
  Future<void> move(LatLng center, {required double zoom}) async {
    try {
      _mapController.move(center, zoom);
    } catch (e) {
      debugPrint('Fallback map move failed: $e');
    }
  }

  @override
  Future<void> zoomIn() async {
    try {
      _mapController.move(
        _mapController.camera.center,
        (_mapController.camera.zoom + 1).clamp(2.0, 18.0),
      );
    } catch (e) {
      debugPrint('Fallback map zoom in failed: $e');
    }
  }

  @override
  Future<void> zoomOut() async {
    try {
      _mapController.move(
        _mapController.camera.center,
        (_mapController.camera.zoom - 1).clamp(2.0, 18.0),
      );
    } catch (e) {
      debugPrint('Fallback map zoom out failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.initialCenter,
        initialZoom: widget.initialZoom,
        onTap: (tapPosition, latlng) => widget.onTap?.call(latlng),
        onMapReady: widget.onMapReady,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.mindrium.gad_app_team',
        ),
        if (widget.current != null)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.current!,
                width: 36,
                height: 36,
                child: const Icon(
                  Icons.my_location,
                  color: Color(0xFF4A90E2),
                  size: 32,
                ),
              ),
            ],
          ),
        if (widget.picked != null)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.picked!,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_pin,
                  color: Color(0xFF5B3EFF),
                  size: 44,
                ),
              ),
            ],
          ),
        if (widget.savedMarkers.isNotEmpty)
          MarkerLayer(
            markers:
                widget.savedMarkers
                    .map(
                      (point) => Marker(
                        point: point,
                        width: 28,
                        height: 28,
                        child: const Icon(Icons.star, color: Colors.amber),
                      ),
                    )
                    .toList(),
          ),
      ],
    );
  }
}

class _KakaoLocationPickerMap extends StatefulWidget {
  const _KakaoLocationPickerMap({
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
  State<_KakaoLocationPickerMap> createState() =>
      _KakaoLocationPickerMapState();
}

class _KakaoLocationPickerMapState extends State<_KakaoLocationPickerMap>
    implements _LocationPickerMapDelegate {
  late final WebViewController _webViewController;

  bool _isMapReady = false;
  ({LatLng center, double zoom})? _pendingMove;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    _webViewController =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..addJavaScriptChannel(
            'MindriumMapBridge',
            onMessageReceived: _onJavascriptMessage,
          )
          ..loadHtmlString(_buildHtml(), baseUrl: AppEnv.kakaoMapHtmlBaseUrl);
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _KakaoLocationPickerMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isMapReady) {
      unawaited(_syncMapState());
    }
  }

  @override
  Future<void> move(LatLng center, {required double zoom}) async {
    if (!_isMapReady) {
      _pendingMove = (center: center, zoom: zoom);
      return;
    }

    await _runJavaScript(
      'window.mindriumMap?.moveTo(${center.latitude}, ${center.longitude}, ${_toKakaoLevel(zoom)});',
    );
  }

  @override
  Future<void> zoomIn() async {
    if (!_isMapReady) return;
    await _runJavaScript('window.mindriumMap?.zoomIn();');
  }

  @override
  Future<void> zoomOut() async {
    if (!_isMapReady) return;
    await _runJavaScript('window.mindriumMap?.zoomOut();');
  }

  void _onJavascriptMessage(JavaScriptMessage message) {
    try {
      final decoded = jsonDecode(message.message);
      if (decoded is! Map) return;

      final type = decoded['type']?.toString();
      if (type == 'ready') {
        _isMapReady = true;
        widget.onMapReady?.call();
        unawaited(_syncMapState());
        final pendingMove = _pendingMove;
        if (pendingMove != null) {
          _pendingMove = null;
          unawaited(move(pendingMove.center, zoom: pendingMove.zoom));
        }
        return;
      }

      if (type == 'tap') {
        final lat = (decoded['lat'] as num?)?.toDouble();
        final lng = (decoded['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) return;
        widget.onTap?.call(LatLng(lat, lng));
      }
    } catch (e) {
      debugPrint('Kakao map bridge parse failed: $e');
    }
  }

  Future<void> _syncMapState() async {
    final current = widget.current;
    final picked = widget.picked;
    final savedMarkers = jsonEncode(
      widget.savedMarkers
          .map((point) => {'lat': point.latitude, 'lng': point.longitude})
          .toList(),
    );

    final currentJs =
        current == null
            ? 'window.mindriumMap?.setCurrentMarker(null, null);'
            : 'window.mindriumMap?.setCurrentMarker(${current.latitude}, ${current.longitude});';
    final pickedJs =
        picked == null
            ? 'window.mindriumMap?.setPickedMarker(null, null);'
            : 'window.mindriumMap?.setPickedMarker(${picked.latitude}, ${picked.longitude});';

    await _runJavaScript(currentJs);
    await _runJavaScript(pickedJs);
    await _runJavaScript('window.mindriumMap?.setSavedMarkers($savedMarkers);');
  }

  Future<void> _runJavaScript(String script) async {
    try {
      await _webViewController.runJavaScript(script);
    } catch (e) {
      debugPrint('Kakao map JS execution failed: $e');
    }
  }

  int _toKakaoLevel(double zoom) {
    final derived = (19 - zoom).round();
    return derived.clamp(1, 14);
  }

  String _buildHtml() {
    final initialLevel = _toKakaoLevel(widget.initialZoom);
    final appKey = Uri.encodeQueryComponent(AppEnv.kakaoMapJavascriptKey);

    return '''
<!DOCTYPE html>
<html lang="ko">
  <head>
    <meta charset="utf-8" />
    <meta
      name="viewport"
      content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"
    />
    <style>
      html, body, #map {
        margin: 0;
        padding: 0;
        width: 100%;
        height: 100%;
        background: #eef5ff;
      }

      .current-dot {
        width: 18px;
        height: 18px;
        border-radius: 999px;
        background: #4A90E2;
        border: 4px solid rgba(74, 144, 226, 0.22);
        box-sizing: border-box;
      }
    </style>
    <script
      type="text/javascript"
      src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=$appKey&autoload=false"
    ></script>
  </head>
  <body>
    <div id="map"></div>
    <script>
      const INITIAL_LAT = ${widget.initialCenter.latitude};
      const INITIAL_LNG = ${widget.initialCenter.longitude};
      const INITIAL_LEVEL = $initialLevel;

      let map = null;
      let pickedMarker = null;
      let currentOverlay = null;
      let savedMarkers = [];

      function postMessage(type, payload) {
        if (!window.MindriumMapBridge) return;
        MindriumMapBridge.postMessage(
          JSON.stringify(Object.assign({ type: type }, payload || {})),
        );
      }

      function createPinImage(fillColor) {
        const svg = `
          <svg xmlns="http://www.w3.org/2000/svg" width="40" height="44" viewBox="0 0 40 44">
            <path d="M20 2C12.269 2 6 8.269 6 16c0 10.398 10.26 19.523 13.315 22.045a1.1 1.1 0 0 0 1.37 0C23.74 35.523 34 26.398 34 16 34 8.269 27.731 2 20 2Z" fill="\${fillColor}" stroke="rgba(0,0,0,0.12)" stroke-width="1.5"/>
            <circle cx="20" cy="16" r="5.25" fill="#fff"/>
          </svg>
        `.trim();

        return new kakao.maps.MarkerImage(
          'data:image/svg+xml;charset=UTF-8,' + encodeURIComponent(svg),
          new kakao.maps.Size(40, 44),
          { offset: new kakao.maps.Point(20, 42) },
        );
      }

      const pickedMarkerImage = createPinImage('#5B3EFF');
      const savedMarkerImage = createPinImage('#F0B429');

      function clearSavedMarkers() {
        savedMarkers.forEach((marker) => marker.setMap(null));
        savedMarkers = [];
      }

      function setSavedMarkers(points) {
        if (!map) return;
        clearSavedMarkers();

        points.forEach((point) => {
          const marker = new kakao.maps.Marker({
            position: new kakao.maps.LatLng(point.lat, point.lng),
            image: savedMarkerImage,
            clickable: false,
          });
          marker.setMap(map);
          savedMarkers.push(marker);
        });
      }

      function setPickedMarker(lat, lng) {
        if (!map) return;
        if (pickedMarker) {
          pickedMarker.setMap(null);
          pickedMarker = null;
        }
        if (lat == null || lng == null) return;

        pickedMarker = new kakao.maps.Marker({
          position: new kakao.maps.LatLng(lat, lng),
          image: pickedMarkerImage,
          clickable: false,
          zIndex: 20,
        });
        pickedMarker.setMap(map);
      }

      function setCurrentMarker(lat, lng) {
        if (!map) return;
        if (currentOverlay) {
          currentOverlay.setMap(null);
          currentOverlay = null;
        }
        if (lat == null || lng == null) return;

        const dot = document.createElement('div');
        dot.className = 'current-dot';

        currentOverlay = new kakao.maps.CustomOverlay({
          position: new kakao.maps.LatLng(lat, lng),
          content: dot,
          yAnchor: 0.5,
          xAnchor: 0.5,
          zIndex: 15,
        });
        currentOverlay.setMap(map);
      }

      function moveTo(lat, lng, level) {
        if (!map) return;
        const nextPosition = new kakao.maps.LatLng(lat, lng);
        map.setLevel(level);
        map.panTo(nextPosition);
      }

      function zoomIn() {
        if (!map) return;
        map.setLevel(Math.max(1, map.getLevel() - 1));
      }

      function zoomOut() {
        if (!map) return;
        map.setLevel(Math.min(14, map.getLevel() + 1));
      }

      window.mindriumMap = {
        setSavedMarkers,
        setPickedMarker,
        setCurrentMarker,
        moveTo,
        zoomIn,
        zoomOut,
      };

      kakao.maps.load(() => {
        map = new kakao.maps.Map(document.getElementById('map'), {
          center: new kakao.maps.LatLng(INITIAL_LAT, INITIAL_LNG),
          level: INITIAL_LEVEL,
        });
        map.setDraggable(true);
        map.setZoomable(true);

        kakao.maps.event.addListener(map, 'click', (mouseEvent) => {
          const latLng = mouseEvent.latLng;
          postMessage('tap', {
            lat: latLng.getLat(),
            lng: latLng.getLng(),
          });
        });

        postMessage('ready');
      });
    </script>
  </body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _webViewController);
  }
}
