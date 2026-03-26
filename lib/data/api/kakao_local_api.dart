import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:gad_app_team/common/kakao_runtime_config.dart';
import 'package:gad_app_team/utils/text_line_material.dart';

class KakaoLocationSearchResult {
  const KakaoLocationSearchResult({
    required this.point,
    this.placeName,
    this.addressName,
    this.distanceMeters,
  });

  final LatLng point;
  final String? placeName;
  final String? addressName;
  final int? distanceMeters;

  String? get displayLabel {
    final primary = placeName?.trim();
    if (primary != null && primary.isNotEmpty) {
      return primary;
    }

    final fallback = addressName?.trim();
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }

    return null;
  }
}

class KakaoLocalApi {
  KakaoLocalApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  bool get isConfigured =>
      KakaoRuntimeConfig.fromEnvironment.hasLocalRestApiKey ||
      (KakaoRuntimeConfig.cached?.hasLocalRestApiKey ?? false);

  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final apiKey = await _resolveRestApiKey();
    if (apiKey.isEmpty) return null;

    final uri = Uri.https(
      'dapi.kakao.com',
      '/v2/local/geo/coord2address.json',
      {'x': longitude.toString(), 'y': latitude.toString()},
    );

    final payload = await _getJson(uri, apiKey: apiKey);
    if (payload == null) return null;

    final documents = payload['documents'];
    if (documents is! List || documents.isEmpty) return null;

    final first = documents.first;
    if (first is! Map) return null;

    final roadAddress = first['road_address'];
    if (roadAddress is Map) {
      final roadName = roadAddress['address_name']?.toString().trim();
      if (roadName != null && roadName.isNotEmpty) {
        return roadName;
      }
    }

    final address = first['address'];
    if (address is Map) {
      final addressName = address['address_name']?.toString().trim();
      if (addressName != null && addressName.isNotEmpty) {
        return addressName;
      }
    }

    return null;
  }

  Future<KakaoLocationSearchResult?> searchLocation(
    String query, {
    LatLng? around,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    final apiKey = await _resolveRestApiKey();
    if (apiKey.isEmpty) return null;

    final addressLike = _looksLikeAddress(trimmed);
    KakaoLocationSearchResult? addressResult;
    if (addressLike) {
      addressResult = await _searchAddress(trimmed, apiKey: apiKey);
      if (addressResult != null) return addressResult;
    }

    final globalKeywordCandidates = await _searchKeywordCandidates(
      trimmed,
      apiKey: apiKey,
    );
    final nearbyKeywordCandidates =
        around == null
            ? const <KakaoLocationSearchResult>[]
            : await _searchKeywordCandidates(
              trimmed,
              around: around,
              apiKey: apiKey,
              sortByDistance: true,
            );
    final keywordResult = _pickBestKeywordResult(trimmed, [
      ...globalKeywordCandidates,
      ...nearbyKeywordCandidates,
    ]);
    if (keywordResult != null) return keywordResult;

    if (!addressLike) {
      addressResult = await _searchAddress(trimmed, apiKey: apiKey);
    }

    return addressResult;
  }

  Future<KakaoLocationSearchResult?> _searchAddress(
    String query, {
    required String apiKey,
  }) async {
    final uri = Uri.https('dapi.kakao.com', '/v2/local/search/address.json', {
      'query': query,
      'analyze_type': 'similar',
      'size': '1',
    });

    final payload = await _getJson(uri, apiKey: apiKey);
    if (payload == null) return null;

    final documents = payload['documents'];
    if (documents is! List || documents.isEmpty) return null;

    final first = documents.first;
    if (first is! Map) return null;

    return _parsePointResult(
      first,
      preferredAddress:
          (first['road_address'] is Map)
              ? (first['road_address'] as Map)['address_name']?.toString()
              : null,
    );
  }

  Future<List<KakaoLocationSearchResult>> _searchKeywordCandidates(
    String query, {
    LatLng? around,
    required String apiKey,
    bool sortByDistance = false,
  }) async {
    final params = <String, String>{'query': query, 'size': '10'};

    if (around != null) {
      params.addAll({
        'x': around.longitude.toString(),
        'y': around.latitude.toString(),
        'radius': '20000',
      });
    }

    params['sort'] = sortByDistance ? 'distance' : 'accuracy';

    final uri = Uri.https(
      'dapi.kakao.com',
      '/v2/local/search/keyword.json',
      params,
    );

    final payload = await _getJson(uri, apiKey: apiKey);
    if (payload == null) return const [];

    final documents = payload['documents'];
    if (documents is! List || documents.isEmpty) return const [];

    return documents
        .whereType<Map>()
        .map(_parseKeywordResult)
        .nonNulls
        .toList();
  }

  KakaoLocationSearchResult? _parsePointResult(
    Map raw, {
    String? preferredPlaceName,
    String? preferredAddress,
    int? distanceMeters,
  }) {
    final x = double.tryParse(raw['x']?.toString() ?? '');
    final y = double.tryParse(raw['y']?.toString() ?? '');
    if (x == null || y == null) return null;

    final placeName = preferredPlaceName?.trim();
    final primaryAddress = preferredAddress?.trim();
    final fallbackAddress = raw['address_name']?.toString().trim();

    return KakaoLocationSearchResult(
      point: LatLng(y, x),
      placeName: placeName != null && placeName.isNotEmpty ? placeName : null,
      addressName:
          primaryAddress != null && primaryAddress.isNotEmpty
              ? primaryAddress
              : (fallbackAddress != null && fallbackAddress.isNotEmpty
                  ? fallbackAddress
                  : null),
      distanceMeters: distanceMeters,
    );
  }

  KakaoLocationSearchResult? _parseKeywordResult(Map raw) {
    final distanceMeters = int.tryParse(raw['distance']?.toString() ?? '');

    return _parsePointResult(
      raw,
      preferredPlaceName: raw['place_name']?.toString(),
      preferredAddress:
          raw['road_address_name']?.toString().trim().isNotEmpty ?? false
              ? raw['road_address_name']?.toString()
              : raw['address_name']?.toString(),
      distanceMeters: distanceMeters,
    );
  }

  KakaoLocationSearchResult? _pickBestKeywordResult(
    String query,
    List<KakaoLocationSearchResult> candidates,
  ) {
    if (candidates.isEmpty) return null;

    final normalizedQuery = _normalizeSearchText(query);
    KakaoLocationSearchResult? best;
    var bestScore = -1 << 20;

    for (final candidate in candidates) {
      final score = _scoreKeywordCandidate(candidate, normalizedQuery);
      if (best == null || score > bestScore) {
        best = candidate;
        bestScore = score;
      }
    }

    return best;
  }

  int _scoreKeywordCandidate(
    KakaoLocationSearchResult candidate,
    String normalizedQuery,
  ) {
    var score = 0;

    final normalizedPlace = _normalizeSearchText(candidate.placeName ?? '');
    final normalizedAddress = _normalizeSearchText(candidate.addressName ?? '');

    score += _textMatchScore(normalizedPlace, normalizedQuery, weight: 1000);
    score += _textMatchScore(normalizedAddress, normalizedQuery, weight: 220);

    final distance = candidate.distanceMeters;
    if (distance != null) {
      score += (300 - (distance / 100).round()).clamp(0, 300);
    }

    return score;
  }

  int _textMatchScore(String value, String query, {required int weight}) {
    if (value.isEmpty || query.isEmpty) return 0;
    if (value == query) return weight;
    if (value.startsWith(query)) return (weight * 0.7).round();
    if (value.contains(query)) return (weight * 0.45).round();
    return 0;
  }

  String _normalizeSearchText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  bool _looksLikeAddress(String query) {
    return RegExp(r'\d').hasMatch(query) ||
        RegExp(r'(로|길|동|읍|면|리|구|시|군|번지)$').hasMatch(query.trim());
  }

  Future<String> _resolveRestApiKey() async {
    final config = await KakaoRuntimeConfig.load();
    return config.localRestApiKey;
  }

  Future<Map<String, dynamic>?> _getJson(
    Uri uri, {
    required String apiKey,
  }) async {
    try {
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'KakaoAK $apiKey'},
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Kakao Local API request failed: ${response.statusCode} ${response.body}',
        );
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
      return null;
    } catch (e) {
      debugPrint('Kakao Local API request error: $e');
      return null;
    }
  }

  void close() {
    _client.close();
  }
}
