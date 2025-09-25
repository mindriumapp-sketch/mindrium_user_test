import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/data/notification_provider.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';

/// MapPicker: 위치 선택 및 편집 위젯
/// - [initial]이 주어지면 편집 모드로 동작 (해당 위치로 이동)
/// - 현위치, 저장된 위치, 선택된 위치를 모두 표시
class MapPicker extends StatefulWidget {
  /// 편집 모드로 들어올 때 기존 선택 위치
  final LatLng? initial;

  const MapPicker({super.key, this.initial});

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  // ────────────── Constants ──────────────
  static const LatLng _kDefaultCenter = LatLng(37.5665, 126.9780); // 서울 시청 근처
  static const double _kMinZoom = 13.0;
  static const double _kMaxZoom = 19.0;
  static const double _kInitialZoom = 16.0;

  // ────────────── Controllers & State ──────────────
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  List<Marker> _savedMarkers = <Marker>[]; // 저장된 위치들
  LatLng? _picked; // 사용자가 고른 위치 혹은 initial
  LatLng? _current; // 현위치
  String? _addr; // 역지오코딩 주소

  // ────────────── 사용자 정의 카테고리 ──────────────
  List<String> _customCategories = <String>[];
  bool _customCategoryFinalized = false;

  // ────────────── Lifecycle ──────────────
  @override
  void initState() {
    super.initState();

    // 편집 모드이면 initial 값을 세팅
    if (widget.initial != null) {
      _picked = widget.initial;
      _reverseGeocode(widget.initial!, locale: 'ko_KR');
    }

    _determinePosition(); // 현위치만 가져오고, 지도 이동은 조건부
    _loadSavedLocations(); // 저장된 위치 마커 로드
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ────────────── Firestore: 커스텀 카테고리 ──────────────
  Future<void> _loadCustomCategories() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('map_picker_config')
        .doc('custom_categories')
        .get();

    if (!mounted) return;

    if (snap.exists) {
      final data = snap.data();
      final List<String> list =
          (data?['categories'] as List?)?.cast<String>() ?? <String>[];
      setState(() => _customCategories = list);
    }
  }

  Future<void> _saveCustomCategory(String newCat) async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _customCategories.insert(0, newCat);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('map_picker_config')
        .doc('custom_categories')
        .set({'categories': _customCategories});
  }

  /// 커스텀 카테고리를 삭제하고 Firestore에도 즉시 반영
  Future<void> _removeCustomCategory(String cat) async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _customCategories.remove(cat);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('map_picker_config')
        .doc('custom_categories')
        .set({'categories': _customCategories});
  }

  // ────────────── Firestore: 저장된 위치(알림) 불러오기 ──────────────
  Future<void> _loadSavedLocations() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notification_settings')
        .where('method', isEqualTo: 'location')
        .get();

    final List<Marker> markers = <Marker>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final double? lat = (data['latitude'] as num?)?.toDouble();
      final double? lng = (data['longitude'] as num?)?.toDouble();
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

    if (!mounted) return;
    setState(() => _savedMarkers = markers);
  }

  // ────────────── 위치: 현위치 가져오기 ──────────────
  Future<void> _determinePosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final Position pos = await Geolocator.getCurrentPosition();
    if (!mounted) return;

    setState(() => _current = LatLng(pos.latitude, pos.longitude));

    // initial이 없을 때만 지도 이동
    if (widget.initial == null && _current != null) {
      _mapController.move(_current!, _kInitialZoom);
    }
  }

  // ────────────── 위치: 텍스트 검색 ──────────────
  Future<void> _onSearch() async {
    final String query = _searchController.text.trim();
    if (query.isEmpty) return;

    try {
      final List<Location> res = await locationFromAddress(query);
      if (res.isNotEmpty && mounted) {
        final LatLng latlng = LatLng(res.first.latitude, res.first.longitude);
        setState(() {
          _picked = latlng;
        });
        await _reverseGeocode(latlng, locale: 'ko_KR');
        _mapController.move(latlng, _kInitialZoom);
      }
    } catch (_) {
      // 검색 실패 시 무시
    }
  }

  /// VWorld 역지오코딩(한국어 고정). 성공 시 한국어 도로명/지번 주소 문자열을 반환.
Future<String?> _reverseGeocodeKoVWorld(LatLng point) async {
  try {
    final uri = Uri.parse(
      'https://api.vworld.kr/req/address'
      '?service=address'
      '&request=getAddress'
      '&version=2.0'
      '&format=json'
      '&type=both' // road 우선, 없으면 parcel
      '&crs=EPSG:4326'
      '&point=${point.longitude},${point.latitude}' // 순서: x=lon, y=lat
      '&key=$vworldApiKey',
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) return null;

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final resp = body['response'] as Map<String, dynamic>?;
    if (resp == null || resp['status'] != 'OK') return null;

    final results = (resp['result'] as List?) ?? const [];
    if (results.isEmpty) return null;

    String? road;
    String? parcel;
    for (final r in results) {
      final m = (r as Map)['type'];
      final t = r['text'];
      if (m == 'road' && t is String && t.isNotEmpty) {
        road = t;
      } else if (m == 'parcel' && t is String && t.isNotEmpty) {
        parcel = t;
      }
    }
    return road ?? parcel ?? (results.first as Map)['text'] as String?;
  } catch (_) {
    return null;
  }
}

  // ────────────── 위치: 역지오코딩 ──────────────
  Future<void> _reverseGeocode(LatLng point, {String locale = 'ko_KR'}) async {
  try {
    // 1) VWorld로 한국어 주소 우선 시도
    final ko = await _reverseGeocodeKoVWorld(point);
    if (ko != null && ko.isNotEmpty) {
      if (!mounted) return;
      setState(() => _addr = ko);
      return;
    }

    // 2) 실패 시 플러그인으로 보조 포맷 생성(기기 로케일 기반)
    final ps = await placemarkFromCoordinates(point.latitude, point.longitude);
    if (ps.isNotEmpty && mounted) {
      final p = ps.first;
      final parts = <String>[
        if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea!,
        if ((p.subAdministrativeArea ?? '').isNotEmpty) p.subAdministrativeArea!,
        if ((p.locality ?? '').isNotEmpty) p.locality!,
        if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
        if ((p.thoroughfare ?? '').isNotEmpty) p.thoroughfare!,
        if ((p.subThoroughfare ?? '').isNotEmpty) p.subThoroughfare!,
      ];
      final poi = (p.name ?? '').trim();
      final formatted = parts.join(' ');
      setState(() => _addr = poi.isNotEmpty && poi != formatted ? '$formatted ($poi)' : formatted);
    }
  } catch (_) {
    // 네트워크/권한 이슈 등은 조용히 무시
  }
}

  // ────────────── 설명(카테고리) 입력 ──────────────
  Future<String?> _askDescription() async {
    // Firestore에서 커스텀 카테고리 불러오기
    await _loadCustomCategories();
    if (!mounted) return null;

    setState(() => _customCategoryFinalized = false);

    return showModalBottomSheet<String>(
      backgroundColor: Colors.grey.shade100,
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (BuildContext ctx) {
        String? selectedCategory;

        List<String> categories = <String>[
          ..._customCategories,
          '학교',
          '지하철',
          '쇼핑몰',
          '식당',
          '카페',
          '병원',
          '집',
          '직장',
          '+ 추가',
        ];

        return StatefulBuilder(
          builder: (BuildContext ctx2, void Function(void Function()) setLocal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx2).viewInsets.bottom,
                left: AppSizes.padding,
                right: AppSizes.padding,
                top: AppSizes.padding,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      '위치에 대한 설명을 선택하거나 추가해 주세요.',
                      style: TextStyle(fontSize: AppSizes.fontSize),
                    ),
                    const SizedBox(height: AppSizes.space),
                    Wrap(
                      spacing: 16,
                      children: categories.map((String cat) {
                        final bool selected = selectedCategory == cat;
                        final bool isCustom = _customCategories.contains(cat);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Stack(
                            alignment: Alignment.centerRight,
                            children: <Widget>[
                              ChoiceChip(
                                showCheckmark: false,
                                backgroundColor: Colors.white,
                                selectedColor: Colors.indigo,
                                label: Text(
                                  cat,
                                  style: TextStyle(
                                    color: selected ? Colors.white : Colors.black,
                                  ),
                                ),
                                labelPadding: EdgeInsets.only(
                                  left: 8,
                                  // X 아이콘(삭제)이 들어가면 오른쪽 여유 공간 확보
                                  right: (isCustom && !_customCategoryFinalized) ? 16 : 8,
                                ),
                                selected: selected,
                                onSelected: (bool yes) async {
                                  if (!yes) return;

                                  // “+ 추가” → 사용자 입력 받기
                                  if (cat == '+ 추가') {
                                    final String? newCat = await showDialog<String>(
                                      context: ctx2,
                                      builder: (BuildContext dCtx) {
                                        final TextEditingController txtCtrl =
                                            TextEditingController();
                                        return AlertDialog(
                                          title: const Text('카테고리 추가'),
                                          content: TextField(
                                            controller: txtCtrl,
                                            autofocus: true,
                                            decoration: const InputDecoration(
                                              hintText: '예: 학원',
                                            ),
                                          ),
                                          actions: <Widget>[
                                            TextButton(
                                              onPressed: () => Navigator.pop(dCtx),
                                              child: const Text('취소'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                final String val = txtCtrl.text.trim();
                                                Navigator.pop(
                                                  dCtx,
                                                  val.isEmpty ? null : val,
                                                );
                                              },
                                              child: const Text('추가'),
                                            ),
                                          ],
                                        );
                                      },
                                    );

                                    if (newCat != null && newCat.isNotEmpty) {
                                      await _saveCustomCategory(newCat);

                                      if (!_customCategories.contains(newCat)) {
                                        _customCategories.insert(0, newCat);
                                      }

                                      if (mounted) setState(() {}); // 외부 상태 새로고침

                                      setLocal(() {
                                        categories = <String>[
                                          ..._customCategories,
                                          '학교',
                                          '지하철',
                                          '쇼핑몰',
                                          '식당',
                                          '카페',
                                          '병원',
                                          '집',
                                          '직장',
                                          '+ 추가',
                                        ];
                                        selectedCategory = newCat;
                                      });
                                    }
                                  } else {
                                    // 일반 카테고리 선택
                                    setLocal(() => selectedCategory = cat);
                                  }
                                },
                              ),

                              // 삭제 버튼: 커스텀 카테고리 & 확정 전
                              if (!_customCategoryFinalized && isCustom)
                                Align(
                                  alignment: Alignment.centerRight,
                                  widthFactor: 1,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () async {
                                      await _removeCustomCategory(cat);
                                      setLocal(() {
                                        categories.remove(cat);
                                        if (selectedCategory == cat) {
                                          selectedCategory = null;
                                        }
                                      });
                                      if (mounted) setState(() {});
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4),
                                      child: Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSizes.space),
                    NavigationButtons(
                      leftLabel: '이전',
                      rightLabel: '완료',
                      onBack: () => Navigator.of(ctx2).pop(),
                      onNext: () {
                        Navigator.of(ctx2).pop(selectedCategory);
                      },
                    ),
                    const SizedBox(height: AppSizes.space * 2),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ────────────── 선택 확정 ──────────────
  Future<void> _confirmSelection() async {
    final LatLng latlng = _picked ?? _current ?? _kDefaultCenter;

    if (_addr == null) await _reverseGeocode(latlng, locale: 'ko_KR');

    final String? descInput = await _askDescription();
    if (descInput == null) return; // 사용자가 닫기
    if (!mounted) return;

    // descInput format: "category|enter,exit" (현재는 category만 사용)
    final List<String> parts = descInput.split('|');
    final String category = parts.first;
    final String timing = parts.length > 1 ? parts[1] : '';
    final bool notifyEnter = timing.contains('enter');
    final bool notifyExit = timing.contains('exit');

    // 설명(주소) 형식으로 저장: "카테고리 (주소)"
    final String locString = '$_addr';

    final String finalDesc =
        category.isNotEmpty ? category : (_addr ?? '선택한 위치');

    // DEBUG: description 전달됨 → $finalDesc
    debugPrint('DEBUG: description 전달됨 → $finalDesc');

    // 더 이상 카테고리 편집 불가
    setState(() => _customCategoryFinalized = true);

    Navigator.of(context).pop(
      NotificationSetting(
        // method: NotificationMethod.location,
        location: locString, // 예: 학교(서울특별시…)
        latitude: latlng.latitude,
        longitude: latlng.longitude,
        description: finalDesc,
        notifyEnter: notifyEnter,
        notifyExit: notifyExit,
      ),
    );
  }

  // ────────────── Zoom Helpers ──────────────
  void _zoomIn() {
    final double next = (_mapController.camera.zoom + 0.5).clamp(_kMinZoom, _kMaxZoom);
    _mapController.move(_mapController.camera.center, next);
  }

  void _zoomOut() {
    final double next = (_mapController.camera.zoom - 0.5).clamp(_kMinZoom, _kMaxZoom);
    _mapController.move(_mapController.camera.center, next);
  }

  // ────────────── UI ──────────────
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.initial ?? _current ?? _kDefaultCenter,
            initialZoom: _kInitialZoom,
            onTap: (tapPos, latlng) async {
              setState(() => _picked = latlng);
              await _reverseGeocode(latlng, locale: 'ko_KR');
            },
          ),
          children: <Widget>[
            TileLayer(
              minZoom: _kMinZoom,
              maxZoom: _kMaxZoom,
              urlTemplate:
                  'https://api.vworld.kr/req/wmts/1.0.0/{key}/Base/{z}/{y}/{x}.png',
              additionalOptions: {'key': vworldApiKey},
            ),

            // 현위치 마커
            if (_current != null)
              MarkerLayer(
                markers: <Marker>[
                  Marker(
                    point: _current!,
                    width: 36,
                    height: 36,
                    child: const Icon(
                      Icons.my_location,
                      size: 30,
                      color: Colors.deepOrange,
                    ),
                  ),
                ],
              ),

            // 선택된 위치 마커
            if (_picked != null)
              MarkerLayer(
                markers: <Marker>[
                  Marker(
                    point: _picked!,
                    width: 36,
                    height: 36,
                    child: const Icon(
                      Icons.location_pin,
                      size: 40,
                      color: Colors.indigo,
                    ),
                  ),
                ],
              ),

            // 저장된 위치 마커
            if (_savedMarkers.isNotEmpty) MarkerLayer(markers: _savedMarkers),
          ],
        ),

        // 검색창
        Positioned(
          top: AppSizes.padding * 4,
          left: AppSizes.padding,
          right: AppSizes.padding,
          child: Material(
            elevation: 1,
            borderRadius: BorderRadius.circular(8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '주소 검색',
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _onSearch(),
            ),
          ),
        ),

        // 취소/확인 버튼
        Positioned(
          bottom: AppSizes.padding * 2,
          left: 16,
          right: 16,
          child: NavigationButtons(
            onBack: () => Navigator.pop(context),
            onNext: _confirmSelection,
            leftLabel: '닫기',
            rightLabel: '확인',
          ),
        ),

        // 줌 버튼
        Positioned(
          bottom: AppSizes.padding * 8,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FloatingActionButton(
                heroTag: 'zoomIn',
                backgroundColor: Colors.white,
                onPressed: _zoomIn,
                child: const Icon(Icons.add, color: Colors.black),
              ),
              const SizedBox(height: AppSizes.space / 2),
              FloatingActionButton(
                heroTag: 'zoomOut',
                backgroundColor: Colors.white,
                onPressed: _zoomOut,
                child: const Icon(Icons.remove, color: Colors.black),
              ),
            ],
          ),
        ),
      ],
    );
  }
}