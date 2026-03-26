import 'package:latlong2/latlong.dart';

typedef LocationPickerMapMoveHandler =
    Future<void> Function(LatLng center, {double zoom});
typedef LocationPickerMapActionHandler = Future<void> Function();

class LocationPickerMapController {
  Object? _owner;
  LocationPickerMapMoveHandler? _moveHandler;
  LocationPickerMapActionHandler? _zoomInHandler;
  LocationPickerMapActionHandler? _zoomOutHandler;

  Future<void> move(LatLng center, {double zoom = 16}) async {
    await _moveHandler?.call(center, zoom: zoom);
  }

  Future<void> zoomIn() async {
    await _zoomInHandler?.call();
  }

  Future<void> zoomOut() async {
    await _zoomOutHandler?.call();
  }

  void attach({
    required Object owner,
    required LocationPickerMapMoveHandler onMove,
    required LocationPickerMapActionHandler onZoomIn,
    required LocationPickerMapActionHandler onZoomOut,
  }) {
    _owner = owner;
    _moveHandler = onMove;
    _zoomInHandler = onZoomIn;
    _zoomOutHandler = onZoomOut;
  }

  void detach(Object owner) {
    if (!identical(_owner, owner)) return;

    _owner = null;
    _moveHandler = null;
    _zoomInHandler = null;
    _zoomOutHandler = null;
  }
}
