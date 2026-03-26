import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:gad_app_team/widgets/location_picker_map_controller.dart';

class LocationPickerMapKakaoView extends StatefulWidget {
  const LocationPickerMapKakaoView({
    super.key,
    required this.controller,
    required this.initialCenter,
    required this.initialZoom,
    required this.savedMarkers,
    required this.javascriptKey,
    required this.htmlBaseUrl,
    this.current,
    this.picked,
    this.onTap,
    this.onMapReady,
    this.onRendererFailure,
  });

  final LocationPickerMapController controller;
  final LatLng initialCenter;
  final double initialZoom;
  final LatLng? current;
  final LatLng? picked;
  final List<LatLng> savedMarkers;
  final ValueChanged<LatLng>? onTap;
  final VoidCallback? onMapReady;
  final String javascriptKey;
  final String htmlBaseUrl;
  final ValueChanged<String>? onRendererFailure;

  @override
  State<LocationPickerMapKakaoView> createState() =>
      _LocationPickerMapKakaoViewState();
}

class _LocationPickerMapKakaoViewState
    extends State<LocationPickerMapKakaoView> {
  static const Duration _kReadyTimeout = Duration(seconds: 8);

  late final WebViewController _webViewController;
  Timer? _readyTimer;

  bool _isMapReady = false;
  bool _isWebViewLoading = true;
  ({LatLng center, double zoom})? _pendingMove;

  @override
  void initState() {
    super.initState();
    widget.controller.attach(
      owner: this,
      onMove: _move,
      onZoomIn: _zoomIn,
      onZoomOut: _zoomOut,
    );
    debugPrint('LocationPickerMap using Kakao WebView renderer');
    _webViewController =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setNavigationDelegate(_buildNavigationDelegate())
          ..addJavaScriptChannel(
            'MindriumMapBridge',
            onMessageReceived: _onJavascriptMessage,
          )
          ..loadHtmlString(_buildHtml(), baseUrl: widget.htmlBaseUrl);
    _readyTimer = Timer(_kReadyTimeout, _handleReadyTimeout);
  }

  @override
  void dispose() {
    _readyTimer?.cancel();
    widget.controller.detach(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LocationPickerMapKakaoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isMapReady) {
      unawaited(_syncMapState());
    }
  }

  NavigationDelegate _buildNavigationDelegate() {
    return NavigationDelegate(
      onPageStarted: (url) {
        debugPrint('Kakao map page started: $url');
        if (!mounted) return;
        setState(() {
          _isWebViewLoading = true;
        });
      },
      onPageFinished: (url) {
        debugPrint('Kakao map page finished: $url');
        if (!mounted) return;
        setState(() {
          _isWebViewLoading = false;
        });
      },
      onWebResourceError: (error) {
        debugPrint(
          'Kakao map web resource error: ${error.errorCode} ${error.description}',
        );
        if (!mounted) return;
        setState(() {
          _isWebViewLoading = false;
        });
      },
    );
  }

  Future<void> _move(LatLng center, {double zoom = 16}) async {
    if (!_isMapReady) {
      _pendingMove = (center: center, zoom: zoom);
      return;
    }

    await _runJavaScript(
      'window.mindriumMap?.moveTo(${center.latitude}, ${center.longitude}, ${_toKakaoLevel(zoom)});',
    );
  }

  Future<void> _zoomIn() async {
    if (!_isMapReady) return;
    await _runJavaScript('window.mindriumMap?.zoomIn();');
  }

  Future<void> _zoomOut() async {
    if (!_isMapReady) return;
    await _runJavaScript('window.mindriumMap?.zoomOut();');
  }

  void _handleReadyTimeout() {
    if (_isMapReady) return;
    widget.onRendererFailure?.call('kakao map ready timeout');
  }

  void _onJavascriptMessage(JavaScriptMessage message) {
    try {
      final decoded = jsonDecode(message.message);
      if (decoded is! Map) return;

      final type = decoded['type']?.toString();
      switch (type) {
        case 'ready':
          _handleReady();
          return;
        case 'error':
          _handleBridgeError(decoded['message']?.toString() ?? 'unknown error');
          return;
        case 'tap':
          _handleTap(decoded);
          return;
      }
    } catch (e) {
      debugPrint('Kakao map bridge parse failed: $e');
    }
  }

  void _handleReady() {
    _readyTimer?.cancel();
    _isMapReady = true;
    debugPrint('Kakao map renderer is ready');
    widget.onMapReady?.call();
    unawaited(_syncMapState());

    final pendingMove = _pendingMove;
    if (pendingMove == null) return;

    _pendingMove = null;
    unawaited(_move(pendingMove.center, zoom: pendingMove.zoom));
  }

  void _handleBridgeError(String errorMessage) {
    debugPrint('Kakao map bridge error: $errorMessage');
    widget.onRendererFailure?.call(errorMessage);
  }

  void _handleTap(Map decoded) {
    final lat = (decoded['lat'] as num?)?.toDouble();
    final lng = (decoded['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    widget.onTap?.call(LatLng(lat, lng));
  }

  Future<void> _syncMapState() async {
    await _runJavaScript(_buildCurrentMarkerScript());
    await _runJavaScript(_buildPickedMarkerScript());
    await _runJavaScript(_buildSavedMarkersScript());
  }

  String _buildCurrentMarkerScript() {
    final current = widget.current;
    if (current == null) {
      return 'window.mindriumMap?.setCurrentMarker(null, null);';
    }

    return 'window.mindriumMap?.setCurrentMarker(${current.latitude}, ${current.longitude});';
  }

  String _buildPickedMarkerScript() {
    final picked = widget.picked;
    if (picked == null) {
      return 'window.mindriumMap?.setPickedMarker(null, null);';
    }

    return 'window.mindriumMap?.setPickedMarker(${picked.latitude}, ${picked.longitude});';
  }

  String _buildSavedMarkersScript() {
    final savedMarkersJson = jsonEncode(
      widget.savedMarkers
          .map((point) => {'lat': point.latitude, 'lng': point.longitude})
          .toList(),
    );

    return 'window.mindriumMap?.setSavedMarkers($savedMarkersJson);';
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
    final builder = _KakaoLocationPickerHtmlBuilder(
      appKey: widget.javascriptKey,
      initialCenter: widget.initialCenter,
      initialLevel: _toKakaoLevel(widget.initialZoom),
    );
    return builder.build();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _webViewController),
        if (_isWebViewLoading && !_isMapReady)
          const ColoredBox(
            color: Color(0x14FFFFFF),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _KakaoLocationPickerHtmlBuilder {
  const _KakaoLocationPickerHtmlBuilder({
    required this.appKey,
    required this.initialCenter,
    required this.initialLevel,
  });

  final String appKey;
  final LatLng initialCenter;
  final int initialLevel;

  String build() {
    final encodedAppKey = Uri.encodeQueryComponent(appKey);

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

      .current-location {
        position: relative;
        width: 56px;
        height: 56px;
        pointer-events: none;
      }

      .current-location__pulse {
        position: absolute;
        inset: 11px;
        border-radius: 999px;
        background: rgba(74, 144, 226, 0.22);
        animation: currentPulse 1.6s ease-out infinite;
        transform-origin: center;
      }

      .current-location__halo {
        position: absolute;
        inset: 15px;
        border-radius: 999px;
        background: rgba(74, 144, 226, 0.15);
      }

      .current-location__core {
        position: absolute;
        inset: 19px;
        border-radius: 999px;
        background: #ffffff;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.18);
      }

      .current-location__center {
        position: absolute;
        inset: 4px;
        border-radius: 999px;
        background: #2F80ED;
      }

      @keyframes currentPulse {
        0% {
          transform: scale(0.72);
          opacity: 0.28;
        }
        100% {
          transform: scale(1.6);
          opacity: 0;
        }
      }
    </style>
    <script
      type="text/javascript"
      src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=$encodedAppKey&autoload=false"
      onerror="window.MindriumMapBridge && MindriumMapBridge.postMessage(JSON.stringify({ type: 'error', message: 'failed to load kakao sdk' }))"
    ></script>
  </head>
  <body>
    <div id="map"></div>
    <script>
      const INITIAL_LAT = ${initialCenter.latitude};
      const INITIAL_LNG = ${initialCenter.longitude};
      const INITIAL_LEVEL = $initialLevel;

      let map = null;
      let pickedMarker = null;
      let currentOverlay = null;
      let savedMarkers = [];
      let pickedMarkerImage = null;
      let savedMarkerImage = null;

      function postMessage(type, payload) {
        if (!window.MindriumMapBridge) return;
        MindriumMapBridge.postMessage(
          JSON.stringify(Object.assign({ type: type }, payload || {})),
        );
      }

      window.addEventListener('error', (event) => {
        postMessage('error', {
          message: event.message || 'javascript error',
        });
      });

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

      function clearSavedMarkers() {
        savedMarkers.forEach((marker) => marker.setMap(null));
        savedMarkers = [];
      }

      function setSavedMarkers(points) {
        if (!map || !savedMarkerImage) return;
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
        if (!map || !pickedMarkerImage) return;
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
        dot.className = 'current-location';
        dot.innerHTML = `
          <div class="current-location__pulse"></div>
          <div class="current-location__halo"></div>
          <div class="current-location__core">
            <div class="current-location__center"></div>
          </div>
        `;

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

      if (!window.kakao || !window.kakao.maps) {
        postMessage('error', { message: 'kakao maps sdk unavailable' });
      } else {
        kakao.maps.load(() => {
          try {
            pickedMarkerImage = createPinImage('#5B3EFF');
            savedMarkerImage = createPinImage('#F0B429');

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
          } catch (error) {
            postMessage('error', {
              message: error?.message || String(error),
            });
          }
        });
      }
    </script>
  </body>
</html>
''';
  }
}
