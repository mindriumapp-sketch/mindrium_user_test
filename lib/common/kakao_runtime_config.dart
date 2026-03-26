import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gad_app_team/common/app_env.dart';

class KakaoRuntimeConfig {
  const KakaoRuntimeConfig({
    required this.javascriptKey,
    required this.localRestApiKey,
    required this.mapHtmlBaseUrl,
  });

  static const String configAssetPath = 'dart_defines/kakao.api.json';
  static const String defaultHtmlBaseUrl = 'https://localhost/';

  static Future<KakaoRuntimeConfig>? _loadFuture;
  static KakaoRuntimeConfig? _cached;

  final String javascriptKey;
  final String localRestApiKey;
  final String mapHtmlBaseUrl;

  bool get hasJavascriptKey => javascriptKey.isNotEmpty;
  bool get hasLocalRestApiKey => localRestApiKey.isNotEmpty;

  static KakaoRuntimeConfig get fromEnvironment {
    final htmlBaseUrl = AppEnv.kakaoMapHtmlBaseUrl.trim();

    return KakaoRuntimeConfig(
      javascriptKey: AppEnv.kakaoMapJavascriptKey.trim(),
      localRestApiKey: AppEnv.kakaoLocalRestApiKey.trim(),
      mapHtmlBaseUrl: htmlBaseUrl.isEmpty ? defaultHtmlBaseUrl : htmlBaseUrl,
    );
  }

  static KakaoRuntimeConfig? get cached => _cached;

  static Future<KakaoRuntimeConfig> load() {
    final environmentConfig = fromEnvironment;
    final cachedConfig = _cached;
    if (cachedConfig != null) {
      return Future.value(cachedConfig);
    }

    final hasAllEnvironmentValues =
        environmentConfig.hasJavascriptKey &&
        environmentConfig.hasLocalRestApiKey;
    if (hasAllEnvironmentValues) {
      _cached = environmentConfig;
      return Future.value(environmentConfig);
    }

    return _loadFuture ??= _loadMerged(environmentConfig);
  }

  static Future<KakaoRuntimeConfig> _loadMerged(
    KakaoRuntimeConfig environmentConfig,
  ) async {
    try {
      final rawJson = await rootBundle.loadString(configAssetPath);
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map) {
        _cached = environmentConfig;
        return environmentConfig;
      }

      final assetJavascriptKey =
          decoded['KAKAO_MAP_JS_KEY']?.toString().trim() ?? '';
      final assetLocalRestApiKey =
          decoded['KAKAO_LOCAL_REST_API_KEY']?.toString().trim() ?? '';
      final assetHtmlBaseUrl =
          decoded['KAKAO_MAP_HTML_BASE_URL']?.toString().trim() ?? '';

      final shouldUseAssetHtmlBaseUrl =
          environmentConfig.mapHtmlBaseUrl == defaultHtmlBaseUrl &&
          assetHtmlBaseUrl.isNotEmpty;

      final merged = KakaoRuntimeConfig(
        javascriptKey:
            environmentConfig.javascriptKey.isNotEmpty
                ? environmentConfig.javascriptKey
                : assetJavascriptKey,
        localRestApiKey:
            environmentConfig.localRestApiKey.isNotEmpty
                ? environmentConfig.localRestApiKey
                : assetLocalRestApiKey,
        mapHtmlBaseUrl:
            shouldUseAssetHtmlBaseUrl
                ? assetHtmlBaseUrl
                : environmentConfig.mapHtmlBaseUrl,
      );

      _cached = merged;
      return merged;
    } catch (e) {
      debugPrint('Failed to load Kakao runtime config asset: $e');
      _cached = environmentConfig;
      return environmentConfig;
    }
  }
}
