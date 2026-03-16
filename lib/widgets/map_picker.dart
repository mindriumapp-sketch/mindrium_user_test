import 'dart:async';
import 'dart:convert';

import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:gad_app_team/utils/text_line_material.dart';

import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/notification_locations_api.dart';
import 'package:gad_app_team/data/api/schedule_events_api.dart';
import 'package:gad_app_team/data/loctime_provider.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/widgets/custom_popup_design.dart';
import 'package:gad_app_team/widgets/map_picker_design.dart';

class MapPicker extends StatefulWidget {
  final LatLng? initial;
  final TimeOfDay? initialTime;
  final bool enableLocationLabel;
  final String? initialLocationLabel;
  final bool showSavedMarkers;
  final bool enableTimeSelection;

  const MapPicker({
    super.key,
    this.initial,
    this.initialTime,
    this.enableLocationLabel = false,
    this.initialLocationLabel,
    this.showSavedMarkers = true,
    this.enableTimeSelection = true,
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

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _locationLabelController =
      TextEditingController();
  final TextEditingController _addLocationLabelController =
      TextEditingController();
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final ScheduleEventsApi _scheduleEventsApi = ScheduleEventsApi(
    _apiClient,
  );
  late final NotificationLocationsApi _notificationLocationsApi =
      NotificationLocationsApi(_apiClient);

  LatLng? _picked;
  LatLng? _current;
  List<Marker> _savedMarkers = [];
  String? _addr;
  List<String> _locationLabelChips = const [];
  bool _isLoadingLocationLabels = false;
  bool _isAddLabelDialogOpen = false;
  bool _isMapReady = false;
  LatLng? _pendingMapCenter;
  double _pendingMapZoom = _kInitialZoom;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime ?? TimeOfDay.now();
    _locationLabelController.text = widget.initialLocationLabel?.trim() ?? '';
    if (widget.initial != null && _isValidLatLng(widget.initial!)) {
      _picked = widget.initial;
      _reverseGeocode(widget.initial!);
      _pendingMapCenter = widget.initial;
      _pendingMapZoom = _kInitialZoom;
    } else if (widget.initial != null) {
      debugPrint('Ignored invalid initial coordinates: ${widget.initial}');
    }
    final cachedCurrent = _sessionCurrentCache;
    if (_picked == null &&
        cachedCurrent != null &&
        _isRecentTimestamp(_sessionCurrentCacheAt)) {
      _current = cachedCurrent;
      _pendingMapCenter = cachedCurrent;
      _pendingMapZoom = _kInitialZoom;
    }
    unawaited(_determinePosition());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.showSavedMarkers) {
        unawaited(_loadSavedMarkers());
      }
      if (widget.enableLocationLabel) {
        unawaited(_loadLocationLabelChips());
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _locationLabelController.dispose();
    _addLocationLabelController.dispose();
    super.dispose();
  }

  void _onMapReady() {
    _isMapReady = true;
    final center = _pendingMapCenter;
    final zoom = _pendingMapZoom;
    _pendingMapCenter = null;
    if (center == null) return;
    try {
      _mapController.move(center, zoom);
    } catch (e) {
      debugPrint('Map move failed on ready: $e');
    }
  }

  void _moveMapSafely(LatLng center, {double zoom = _kInitialZoom}) {
    if (!_isMapReady) {
      _pendingMapCenter = center;
      _pendingMapZoom = zoom;
      return;
    }
    try {
      _mapController.move(center, zoom);
    } catch (e) {
      debugPrint('Map move failed: $e');
      _pendingMapCenter = center;
      _pendingMapZoom = zoom;
      _isMapReady = false;
    }
  }

  bool get _shouldAutoCenterOnCurrent => _picked == null;

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
      if (mounted) {
        setState(() => _current = current);
      } else {
        _current = current;
      }
    }

    if (_shouldAutoCenterOnCurrent) {
      _moveMapSafely(current, zoom: _kInitialZoom);
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
      final markers = <Marker>[];
      for (final doc in docs) {
        final lat = (doc['latitude'] as num?)?.toDouble();
        final lng = (doc['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 36,
            height: 36,
            child: const Icon(Icons.star, color: Colors.amber),
          ),
        );
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
    if (query.isEmpty) return;

    try {
      final res = await locationFromAddress(query);
      if (res.isNotEmpty && mounted) {
        final latlng = LatLng(res.first.latitude, res.first.longitude);
        setState(() => _picked = latlng);
        await _reverseGeocode(latlng);
        _moveMapSafely(latlng, zoom: _kInitialZoom);
      }
    } catch (_) {}
  }

  Future<void> _reverseGeocode(LatLng point) async {
    try {
      final uri = Uri.parse(
        'https://api.vworld.kr/req/address'
        '?service=address'
        '&request=getAddress'
        '&version=2.0'
        '&format=json'
        '&type=both'
        '&crs=EPSG:4326'
        '&point=${point.longitude},${point.latitude}'
        '&key=$vworldApiKey',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body);
      final result = body['response']?['result']?[0];
      final text = result?['text'];
      if (text != null && mounted) setState(() => _addr = text);
    } catch (_) {}
  }

  Future<void> _loadLocationLabelChips() async {
    if (!widget.enableLocationLabel) return;
    if (mounted) {
      setState(() => _isLoadingLocationLabels = true);
    }
    try {
      final rows = await _notificationLocationsApi
          .listLocationLabels(limit: 24)
          .timeout(const Duration(seconds: 6));
      final labels =
          rows
              .map((raw) => raw['label']?.toString().trim())
              .whereType<String>()
              .where((label) => label.isNotEmpty)
              .toSet()
              .toList();
      if (!mounted) return;
      setState(() {
        _locationLabelChips = labels;
      });
    } catch (e) {
      debugPrint('Failed to load location labels: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocationLabels = false);
      }
    }
  }

  void _selectLocationLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _locationLabelController.text = trimmed;
      _locationLabelController.selection = TextSelection.fromPosition(
        TextPosition(offset: trimmed.length),
      );
    });
  }

  Future<void> _openAddLocationLabelDialog() async {
    if (!widget.enableLocationLabel || !mounted || _isAddLabelDialogOpen) {
      return;
    }
    _isAddLabelDialogOpen = true;

    FocusScope.of(context).unfocus();
    _addLocationLabelController
      ..text = ''
      ..selection = const TextSelection.collapsed(offset: 0);
    try {
      String normalizeLabel(String value) =>
          value.toLowerCase().replaceAll(RegExp(r'\s+'), '');

      final existingNormalized =
          _locationLabelChips
              .map((label) => normalizeLabel(label.trim()))
              .where((v) => v.isNotEmpty)
              .toSet();

      final addedLabel = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return CustomPopupDesign(
            title: '새 위치 라벨 추가',
            highlightText: '',
            message: '',
            positiveText: '추가',
            negativeText: '취소',
            onPositivePressed: () {
              final text = _addLocationLabelController.text.trim();
              if (text.isEmpty) return;
              Navigator.of(dialogContext).pop(text);
            },
            onNegativePressed: () {
              Navigator.of(dialogContext).pop();
            },
            enableInput: true,
            controller: _addLocationLabelController,
            inputHint: '예: 집, 회사, 카페',
            inputMaxLength: 15,
            inputMaxLengthErrorText: '15자 이내로 입력해주세요.',
            inputValidator: (text) {
              final trimmed = text.trim();
              if (trimmed.isEmpty) return '라벨을 입력해주세요.';
              final normalized = normalizeLabel(trimmed);
              if (existingNormalized.contains(normalized)) {
                return '이미 있는 라벨입니다.';
              }
              return null;
            },
          );
        },
      );

      final trimmed = addedLabel?.trim();
      if (trimmed == null || trimmed.isEmpty) return;

      final normalizedNew = normalizeLabel(trimmed);
      String resolvedLabel = trimmed;
      for (final existing in _locationLabelChips) {
        if (normalizeLabel(existing) == normalizedNew) {
          resolvedLabel = existing;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        final next = <String>[..._locationLabelChips];
        final hasSame = next.any(
          (item) => normalizeLabel(item) == normalizeLabel(resolvedLabel),
        );
        if (!hasSame) {
          next.insert(0, resolvedLabel);
        }
        _locationLabelChips = next;
        _locationLabelController.text = resolvedLabel;
        _locationLabelController.selection = TextSelection.fromPosition(
          TextPosition(offset: resolvedLabel.length),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('라벨 추가에 실패했습니다: $e')));
    } finally {
      _isAddLabelDialogOpen = false;
    }
  }

  Future<void> _confirmSelection() async {
    final LatLng latlng = _picked ?? _current ?? _kDefaultCenter;
    if ((_addr?.trim().isEmpty ?? true)) {
      await _reverseGeocode(latlng);
    }
    if (!mounted) return;
    final customLabel = _locationLabelController.text.trim();
    final address = _addr ?? '';
    final resolvedLocation =
        widget.enableLocationLabel && customLabel.isNotEmpty
            ? customLabel
            : (_addr ?? '선택한 위치');

    if (!mounted) return;
    Navigator.of(context).pop(
      LocTimeSetting(
        location: resolvedLocation,
        latitude: latlng.latitude,
        longitude: latlng.longitude,
        description: address.isNotEmpty ? address : resolvedLocation,
        time: _selectedTime,
        notifyEnter: true,
        notifyExit: false,
      ),
    );

    if (widget.enableLocationLabel && customLabel.isNotEmpty) {
      unawaited(_persistLocationLabel(customLabel));
    }
  }

  Future<void> _persistLocationLabel(String label) async {
    try {
      await _notificationLocationsApi
          .upsertLocationLabel(label: label)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Failed to persist location label: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MindriumPopupDesign(
      title: '위치 선택',
      searchController: _searchController,
      mapController: _mapController,
      onMapReady: _onMapReady,
      picked: _picked,
      current: _current,
      savedMarkers: _savedMarkers,
      onSearch: _onSearch,
      onTap: (tapPos, latlng) async {
        setState(() => _picked = latlng);
        await _reverseGeocode(latlng);
      },
      onBack: () => Navigator.pop(context),
      onNext: _confirmSelection,
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
      showTimePicker: widget.enableTimeSelection,
      locationText: _addr,
      showLocationLabelInput: widget.enableLocationLabel,
      locationLabelController:
          widget.enableLocationLabel ? _locationLabelController : null,
      locationLabelChips: _locationLabelChips,
      isLoadingLocationLabels: _isLoadingLocationLabels,
      onLocationLabelSelected: _selectLocationLabel,
      onAddLocationLabel: _openAddLocationLabelDialog,
    );
  }
}
