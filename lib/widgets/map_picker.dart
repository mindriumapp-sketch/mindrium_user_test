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
import 'package:gad_app_team/data/api/schedule_events_api.dart';
import 'package:gad_app_team/data/loctime_provider.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/widgets/map_picker_design.dart';

class MapPicker extends StatefulWidget {
  final LatLng? initial;
  final TimeOfDay? initialTime;

  const MapPicker({super.key, this.initial, this.initialTime});

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  static const LatLng _kDefaultCenter = LatLng(37.5665, 126.9780);
  static const double _kInitialZoom = 16.0;

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final ScheduleEventsApi _scheduleEventsApi = ScheduleEventsApi(_apiClient);

  LatLng? _picked;
  LatLng? _current;
  List<Marker> _savedMarkers = [];
  String? _addr;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime ?? TimeOfDay.now();
    if (widget.initial != null) {
      _picked = widget.initial;
      _reverseGeocode(widget.initial!);
    }
    _determinePosition();
    _loadSavedMarkers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedMarkers() async {
    try {
      final docs = await _scheduleEventsApi.listScheduleEvents();
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
      }
      if (mounted) setState(() => _savedMarkers = markers);
    } catch (e) {
      debugPrint('Failed to load saved markers: $e');
    }
  }

  Future<void> _determinePosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final pos = await Geolocator.getCurrentPosition();
    if (!mounted) return;

    setState(() => _current = LatLng(pos.latitude, pos.longitude));
    _mapController.move(_current!, _kInitialZoom);
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
        _mapController.move(latlng, _kInitialZoom);
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
      final res = await http.get(uri);
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body);
      final result = body['response']?['result']?[0];
      final text = result?['text'];
      if (text != null && mounted) setState(() => _addr = text);
    } catch (_) {}
  }

  Future<void> _confirmSelection() async {
    final LatLng latlng = _picked ?? _current ?? _kDefaultCenter;
    await _reverseGeocode(latlng);
    if (!mounted) return;
    Navigator.of(context).pop(
      LocTimeSetting(
        location: _addr ?? '선택한 위치',
        latitude: latlng.latitude,
        longitude: latlng.longitude,
        description: _addr ?? '',
        time: _selectedTime,
        notifyEnter: true,
        notifyExit: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MindriumPopupDesign(
      title: '위치 선택',
      searchController: _searchController,
      mapController: _mapController,
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
      locationText: _addr,
    );
  }
}
