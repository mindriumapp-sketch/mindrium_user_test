import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:gad_app_team/utils/text_line_material.dart';

import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/kakao_local_api.dart';
import 'package:gad_app_team/data/api/schedule_events_api.dart';
import 'package:gad_app_team/data/loctime_provider.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/widgets/location_picker_map.dart';
import 'package:gad_app_team/widgets/map_picker_design.dart';

class MapPicker extends StatefulWidget {
  final LatLng? initial;
  final TimeOfDay? initialTime;
  final bool enableLocationLabel;
  final String? initialLocationLabel;
  final bool showSavedMarkers;
  final bool enableTimeSelection;
  final double sheetInitialSize;

  const MapPicker({
    super.key,
    this.initial,
    this.initialTime,
    this.enableLocationLabel = false,
    this.initialLocationLabel,
    this.showSavedMarkers = true,
    this.enableTimeSelection = true,
    this.sheetInitialSize = MindriumPopupDesign.defaultSheetInitialSize,
  });

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  static const LatLng _kDefaultCenter = LatLng(37.5665, 126.9780);
  static const double _kInitialZoom = 16.0;
  static const Duration _kRecentLocationThreshold = Duration(minutes: 10);
  static LatLng? _sessionCurrentCache;
  static DateTime? _sessionCurrentCacheAt;

  static bool _isValidLatLng(LatLng point) {
    return point.latitude.isFinite &&
        point.longitude.isFinite &&
        point.latitude >= -90 &&
        point.latitude <= 90 &&
        point.longitude >= -180 &&
        point.longitude <= 180;
  }

  static bool _isRecentTimestamp(DateTime? timestamp) {
    if (timestamp == null) return true;
    return DateTime.now().difference(timestamp).abs() <=
        _kRecentLocationThreshold;
  }

  final LocationPickerMapController _mapController =
      LocationPickerMapController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _locationLabelController =
      TextEditingController();
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final ScheduleEventsApi _scheduleEventsApi = ScheduleEventsApi(
    _apiClient,
  );
  late final KakaoLocalApi _kakaoLocalApi = KakaoLocalApi();

  LatLng? _picked;
  LatLng? _current;
  List<LatLng> _savedMarkers = [];
  String? _addr;
  bool _isMapReady = false;
  LatLng? _pendingMapCenter;
  double _pendingMapZoom = _kInitialZoom;
  late TimeOfDay _selectedTime;
  int _reverseGeocodeRequestId = 0;
  bool _isResolvingAddress = false;
  bool _hasAddressLookupFailure = false;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime ?? TimeOfDay.now();
    _locationLabelController.addListener(_handleLocationLabelChanged);
    _setLocationLabelText(widget.initialLocationLabel?.trim() ?? '');
    _initializeSelectionState();
    unawaited(_determinePosition());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDeferredData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _locationLabelController.removeListener(_handleLocationLabelChanged);
    _locationLabelController.dispose();
    _kakaoLocalApi.close();
    super.dispose();
  }

  void _onMapReady() {
    _isMapReady = true;
    final center = _pendingMapCenter;
    final zoom = _pendingMapZoom;
    _pendingMapCenter = null;
    if (center == null) return;
    unawaited(_mapController.move(center, zoom: zoom));
  }

  void _moveMapSafely(LatLng center, {double zoom = _kInitialZoom}) {
    if (!_isMapReady) {
      _pendingMapCenter = center;
      _pendingMapZoom = zoom;
      return;
    }
    unawaited(_mapController.move(center, zoom: zoom));
  }

  bool get _shouldAutoCenterOnCurrent => _picked == null;

  bool get _hasVisibleLocationSelection => _picked != null || _current != null;

  LatLng get _resolvedSelectionPoint => _picked ?? _current ?? _kDefaultCenter;

  String? get _displayLocationText {
    final address = _addr?.trim();
    if (address != null && address.isNotEmpty) {
      return address;
    }
    if (_isResolvingAddress && _hasVisibleLocationSelection) {
      return '주소를 확인하는 중...';
    }
    if (_hasAddressLookupFailure && _hasVisibleLocationSelection) {
      return '주소를 불러오지 못했어요. 다시 선택해 주세요.';
    }
    return null;
  }

  bool get _hasRequiredLocationLabel {
    if (!widget.enableLocationLabel) return true;
    return _locationLabelController.text.trim().isNotEmpty;
  }

  void _applyState(VoidCallback update) {
    if (mounted) {
      setState(update);
      return;
    }
    update();
  }

  void _setLocationLabelText(String value) {
    _locationLabelController.text = value;
    _locationLabelController.selection = TextSelection.fromPosition(
      TextPosition(offset: value.length),
    );
  }

  void _handleLocationLabelChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _initializeSelectionState() {
    final initial = widget.initial;
    if (initial != null && _isValidLatLng(initial)) {
      _picked = initial;
      _pendingMapCenter = initial;
      _pendingMapZoom = _kInitialZoom;
      unawaited(_reverseGeocode(initial));
      return;
    }

    if (initial != null) {
      debugPrint('Ignored invalid initial coordinates: $initial');
    }

    final cachedCurrent = _sessionCurrentCache;
    if (_picked == null &&
        cachedCurrent != null &&
        _isRecentTimestamp(_sessionCurrentCacheAt)) {
      _current = cachedCurrent;
      _pendingMapCenter = cachedCurrent;
      _pendingMapZoom = _kInitialZoom;
    }
  }

  void _loadDeferredData() {
    if (!mounted) return;
    if (widget.showSavedMarkers) {
      unawaited(_loadSavedMarkers());
    }
  }

  void _cacheCurrentLocation(LatLng current) {
    _sessionCurrentCache = current;
    _sessionCurrentCacheAt = DateTime.now();
  }

  void _applyCurrentLocation(LatLng current) {
    _cacheCurrentLocation(current);

    final previous = _current;
    final hasChanged =
        previous == null ||
        previous.latitude != current.latitude ||
        previous.longitude != current.longitude;

    if (hasChanged) {
      _applyState(() => _current = current);
    }

    if (_shouldAutoCenterOnCurrent) {
      _moveMapSafely(current, zoom: _kInitialZoom);
      if ((_addr?.trim().isEmpty ?? true)) {
        unawaited(_reverseGeocode(current));
      }
    }
  }

  Future<void> _loadSavedMarkers() async {
    try {
      final now = DateTime.now();
      final docs = await _scheduleEventsApi
          .listScheduleEvents(
            startDate: now.subtract(const Duration(days: 30)),
            endDate: now.add(const Duration(days: 30)),
          )
          .timeout(const Duration(seconds: 6));
      final markers = <LatLng>[];
      for (final doc in docs) {
        final lat = (doc['latitude'] as num?)?.toDouble();
        final lng = (doc['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        markers.add(LatLng(lat, lng));
        if (markers.length >= 60) break;
      }
      if (mounted) setState(() => _savedMarkers = markers);
    } catch (e) {
      debugPrint('Failed to load saved markers: $e');
    }
  }

  Future<void> _determinePosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return;
      }

      final lastKnownFuture = Geolocator.getLastKnownPosition();
      final currentFuture = Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 6),
        ),
      );
      final lastKnown = await lastKnownFuture;
      if (!mounted) return;

      if (lastKnown != null && _isRecentTimestamp(lastKnown.timestamp)) {
        _applyCurrentLocation(LatLng(lastKnown.latitude, lastKnown.longitude));
      }

      final pos = await currentFuture;
      if (!mounted) return;

      _applyCurrentLocation(LatLng(pos.latitude, pos.longitude));
    } catch (e) {
      debugPrint('Failed to determine position: $e');
    }
  }

  Future<void> _onSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _showSearchMessage('검색어를 입력해주세요.');
      return;
    }

    FocusScope.of(context).unfocus();

    try {
      final kakaoResult = await _kakaoLocalApi.searchLocation(
        query,
        around: _picked ?? _current,
      );
      if (kakaoResult != null) {
        await _pickLocation(
          kakaoResult.point,
          moveMap: true,
          resolvedLabel: kakaoResult.displayLabel,
        );
        return;
      }

      final res = await locationFromAddress(query);
      if (res.isEmpty) {
        _showSearchFailure(query);
        return;
      }
      final latlng = LatLng(res.first.latitude, res.first.longitude);
      await _pickLocation(latlng, moveMap: true);
    } catch (e) {
      debugPrint('Location search failed for "$query": $e');
      _showSearchFailure(query);
    }
  }

  void _showSearchFailure(String query) {
    final kakaoConfigured = _kakaoLocalApi.isConfigured;
    debugPrint(
      'Search returned no result for "$query". Kakao Local configured: $kakaoConfigured',
    );

    final message =
        kakaoConfigured
            ? '검색 결과를 찾지 못했어요. 주소를 조금 더 자세히 입력해 주세요.'
            : '검색 설정을 불러오지 못했어요. 앱을 다시 실행해 주세요.';
    _showSearchMessage(message);
  }

  void _showSearchMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickLocation(
    LatLng latlng, {
    bool moveMap = false,
    String? resolvedLabel,
  }) async {
    final normalizedLabel = resolvedLabel?.trim();
    _applyState(() {
      _picked = latlng;
      if (normalizedLabel != null && normalizedLabel.isNotEmpty) {
        _addr = normalizedLabel;
        _isResolvingAddress = false;
        _hasAddressLookupFailure = false;
      }
    });
    if (normalizedLabel == null || normalizedLabel.isEmpty) {
      await _reverseGeocode(latlng);
    }
    if (moveMap) {
      _moveMapSafely(latlng, zoom: _kInitialZoom);
    }
  }

  String? _cleanAddressPart(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<String?> _reverseGeocodeWithPlacemark(LatLng point) async {
    try {
      await setLocaleIdentifier('ko_KR');
      final placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      ).timeout(const Duration(seconds: 4));

      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final parts =
          <String?>[
            _cleanAddressPart(p.administrativeArea),
            _cleanAddressPart(p.locality),
            _cleanAddressPart(p.subLocality),
            _cleanAddressPart(p.thoroughfare),
            _cleanAddressPart(p.subThoroughfare),
          ].whereType<String>().toList();

      if (parts.isEmpty) return null;
      return parts.join(' ');
    } catch (e) {
      debugPrint('Placemark reverse geocoding failed: $e');
      return null;
    }
  }

  Future<String?> _reverseGeocodeWithKakao(LatLng point) async {
    final address = await _kakaoLocalApi.reverseGeocode(
      latitude: point.latitude,
      longitude: point.longitude,
    );
    return _cleanAddressPart(address);
  }

  Future<void> _reverseGeocode(LatLng point) async {
    final requestId = ++_reverseGeocodeRequestId;

    _applyState(() {
      _addr = null;
      _isResolvingAddress = true;
      _hasAddressLookupFailure = false;
    });

    final kakaoAddress = await _reverseGeocodeWithKakao(point);
    if (!mounted || requestId != _reverseGeocodeRequestId) return;
    if (kakaoAddress != null) {
      _applyState(() {
        _addr = kakaoAddress;
        _hasAddressLookupFailure = false;
        _isResolvingAddress = false;
      });
      return;
    }

    final placemarkAddress = await _reverseGeocodeWithPlacemark(point);
    if (!mounted || requestId != _reverseGeocodeRequestId) return;

    final resolvedAddress = placemarkAddress;
    _applyState(() {
      _addr = resolvedAddress;
      _isResolvingAddress = false;
      _hasAddressLookupFailure = resolvedAddress == null;
    });
  }

  Future<void> _confirmSelection() async {
    final latlng = _resolvedSelectionPoint;
    if ((_addr?.trim().isEmpty ?? true)) {
      await _reverseGeocode(latlng);
    }
    if (!mounted) return;
    final customLabel = _locationLabelController.text.trim();
    if (widget.enableLocationLabel && customLabel.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('위치 라벨을 입력해주세요.')));
      return;
    }
    final address = _addr?.trim() ?? '';
    final fallbackLocation =
        widget.enableLocationLabel && customLabel.isNotEmpty
            ? customLabel
            : '선택한 위치';
    final resolvedLocation =
        widget.enableLocationLabel && customLabel.isNotEmpty
            ? customLabel
            : (address.isNotEmpty ? address : fallbackLocation);

    if (!mounted) return;
    Navigator.of(context).pop(
      LocTimeSetting(
        location: resolvedLocation,
        latitude: latlng.latitude,
        longitude: latlng.longitude,
        description: address.isNotEmpty ? address : fallbackLocation,
        time: _selectedTime,
        notifyEnter: true,
        notifyExit: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MindriumPopupDesign(
      searchController: _searchController,
      mapController: _mapController,
      onMapReady: _onMapReady,
      picked: _picked,
      current: _current,
      savedMarkers: _savedMarkers,
      onSearch: _onSearch,
      onTap: _pickLocation,
      onBack: () => Navigator.pop(context),
      onNext: _hasRequiredLocationLabel ? _confirmSelection : null,
      initialTimeDateTime: DateTime(
        2000,
        1,
        1,
        _selectedTime.hour,
        _selectedTime.minute,
      ),
      onTimeChanged: (dt) {
        _selectedTime = TimeOfDay.fromDateTime(dt);
      },
      sheetInitialSize: widget.sheetInitialSize,
      showTimePicker: widget.enableTimeSelection,
      locationText: _displayLocationText,
      showLocationLabelInput: widget.enableLocationLabel,
      locationLabelController:
          widget.enableLocationLabel ? _locationLabelController : null,
    );
  }
}
