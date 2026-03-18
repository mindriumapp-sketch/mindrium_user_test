import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:gad_app_team/common/app_env.dart';
import 'package:gad_app_team/utils/text_line_material.dart';

class KakaoLocationSearchResult {
  const KakaoLocationSearchResult({required this.point, this.addressName});

  final LatLng point;
  final String? addressName;
}

class KakaoLocalApi {
  KakaoLocalApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  bool get isConfigured => AppEnv.hasKakaoLocalRestApiKey;

  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    if (!isConfigured) return null;

    final uri = Uri.https(
      'dapi.kakao.com',
      '/v2/local/geo/coord2address.json',
      {'x': longitude.toString(), 'y': latitude.toString()},
    );

    final payload = await _getJson(uri);
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
    if (trimmed.isEmpty || !isConfigured) return null;

    final addressResult = await _searchAddress(trimmed);
    if (addressResult != null) return addressResult;

    return _searchKeyword(trimmed, around: around);
  }

  Future<KakaoLocationSearchResult?> _searchAddress(String query) async {
    final uri = Uri.https('dapi.kakao.com', '/v2/local/search/address.json', {
      'query': query,
      'analyze_type': 'similar',
      'size': '1',
    });

    final payload = await _getJson(uri);
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

  Future<KakaoLocationSearchResult?> _searchKeyword(
    String query, {
    LatLng? around,
  }) async {
    final params = <String, String>{'query': query, 'size': '1'};

    if (around != null) {
      params.addAll({
        'x': around.longitude.toString(),
        'y': around.latitude.toString(),
        'radius': '20000',
        'sort': 'distance',
      });
    }

    final uri = Uri.https(
      'dapi.kakao.com',
      '/v2/local/search/keyword.json',
      params,
    );

    final payload = await _getJson(uri);
    if (payload == null) return null;

    final documents = payload['documents'];
    if (documents is! List || documents.isEmpty) return null;

    final first = documents.first;
    if (first is! Map) return null;

    return _parsePointResult(
      first,
      preferredAddress: first['road_address_name']?.toString(),
    );
  }

  KakaoLocationSearchResult? _parsePointResult(
    Map raw, {
    String? preferredAddress,
  }) {
    final x = double.tryParse(raw['x']?.toString() ?? '');
    final y = double.tryParse(raw['y']?.toString() ?? '');
    if (x == null || y == null) return null;

    final primaryAddress = preferredAddress?.trim();
    final fallbackAddress = raw['address_name']?.toString().trim();

    return KakaoLocationSearchResult(
      point: LatLng(y, x),
      addressName:
          primaryAddress != null && primaryAddress.isNotEmpty
              ? primaryAddress
              : (fallbackAddress != null && fallbackAddress.isNotEmpty
                  ? fallbackAddress
                  : null),
    );
  }

  Future<Map<String, dynamic>?> _getJson(Uri uri) async {
    try {
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'KakaoAK ${AppEnv.kakaoLocalRestApiKey}'},
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
