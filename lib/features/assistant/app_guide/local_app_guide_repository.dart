import 'dart:convert';

import 'package:flutter/services.dart';

import 'app_feature.dart';
import 'app_guide_repository.dart';
import 'app_navigation.dart';
import 'app_screen.dart';

/// 앱에 동봉된 `assets/app_guide/app_guide_catalog.json`을 메모리에 올린다.
///
/// `LocalCbtKnowledgeRepository`(상담 지식)와 같은 패턴이다 — 임베딩 없이
/// 한 파일을 통째로 읽어 선형 스캔한다. 규모가 작아(현재 기능 9개, 화면
/// 10개) Phase 6에서는 이 이상이 필요 없다.
class LocalAppGuideRepository implements AppGuideRepository {
  static const String _assetPath =
      'assets/app_guide/app_guide_catalog.json';

  /// 자산 로더. 테스트에서 파일 시스템 로더를 주입할 수 있게 열어 둔다.
  final Future<String> Function(String path) _loadAsset;

  List<AppFeature> _features = const [];
  List<AppScreen> _screens = const [];
  List<AppNavigationPath> _navigationPaths = const [];
  List<AppManualEntry> _manualEntries = const [];
  bool _initialized = false;

  LocalAppGuideRepository({Future<String> Function(String path)? loadAsset})
    : _loadAsset = loadAsset ?? rootBundle.loadString;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    final raw = jsonDecode(await _loadAsset(_assetPath)) as Map<String, dynamic>;

    _features = (raw['features'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(AppFeature.fromJson)
        .toList();
    _screens = (raw['screens'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(AppScreen.fromJson)
        .toList();
    _navigationPaths = (raw['navigation'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(AppNavigationPath.fromJson)
        .toList();
    _manualEntries = (raw['manual'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(AppManualEntry.fromJson)
        .toList();

    _initialized = true;
  }

  @override
  List<AppFeature> get features => _features;

  @override
  List<AppScreen> get screens => _screens;

  @override
  List<AppNavigationPath> get navigationPaths => _navigationPaths;

  @override
  List<AppManualEntry> get manualEntries => _manualEntries;
}
