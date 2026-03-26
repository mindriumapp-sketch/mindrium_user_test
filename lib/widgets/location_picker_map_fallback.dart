import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:gad_app_team/widgets/location_picker_map_controller.dart';
import 'package:gad_app_team/widgets/location_picker_map_current_marker.dart';

class LocationPickerMapFallbackView extends StatefulWidget {
  const LocationPickerMapFallbackView({
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
  State<LocationPickerMapFallbackView> createState() =>
      _LocationPickerMapFallbackViewState();
}

class _LocationPickerMapFallbackViewState
    extends State<LocationPickerMapFallbackView> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    widget.controller.attach(
      owner: this,
      onMove: _move,
      onZoomIn: _zoomIn,
      onZoomOut: _zoomOut,
    );
    debugPrint('LocationPickerMap using fallback renderer');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onMapReady?.call();
    });
  }

  @override
  void dispose() {
    widget.controller.detach(this);
    super.dispose();
  }

  Future<void> _move(LatLng center, {double zoom = 16}) async {
    try {
      _mapController.move(center, zoom);
    } catch (e) {
      debugPrint('Fallback map move failed: $e');
    }
  }

  Future<void> _zoomIn() async {
    try {
      _mapController.move(
        _mapController.camera.center,
        (_mapController.camera.zoom + 1).clamp(2.0, 18.0),
      );
    } catch (e) {
      debugPrint('Fallback map zoom in failed: $e');
    }
  }

  Future<void> _zoomOut() async {
    try {
      _mapController.move(
        _mapController.camera.center,
        (_mapController.camera.zoom - 1).clamp(2.0, 18.0),
      );
    } catch (e) {
      debugPrint('Fallback map zoom out failed: $e');
    }
  }

  MarkerLayer? _buildCurrentMarkerLayer() {
    final current = widget.current;
    if (current == null) return null;

    return MarkerLayer(
      markers: [
        Marker(
          point: current,
          width: 56,
          height: 56,
          child: const LocationPickerMapCurrentMarker(),
        ),
      ],
    );
  }

  MarkerLayer? _buildPickedMarkerLayer() {
    final picked = widget.picked;
    if (picked == null) return null;

    return MarkerLayer(
      markers: [
        Marker(
          point: picked,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.location_pin,
            color: Color(0xFF5B3EFF),
            size: 44,
          ),
        ),
      ],
    );
  }

  MarkerLayer? _buildSavedMarkerLayer() {
    if (widget.savedMarkers.isEmpty) return null;

    return MarkerLayer(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentMarkerLayer = _buildCurrentMarkerLayer();
    final pickedMarkerLayer = _buildPickedMarkerLayer();
    final savedMarkerLayer = _buildSavedMarkerLayer();

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
        if (currentMarkerLayer != null) currentMarkerLayer,
        if (pickedMarkerLayer != null) pickedMarkerLayer,
        if (savedMarkerLayer != null) savedMarkerLayer,
      ],
    );
  }
}
