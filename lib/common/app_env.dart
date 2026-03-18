class AppEnv {
  AppEnv._();

  static const String kakaoMapJavascriptKey = String.fromEnvironment(
    'KAKAO_MAP_JS_KEY',
    defaultValue: '',
  );

  static const String kakaoLocalRestApiKey = String.fromEnvironment(
    'KAKAO_LOCAL_REST_API_KEY',
    defaultValue: '',
  );

  static const String kakaoMapHtmlBaseUrl = String.fromEnvironment(
    'KAKAO_MAP_HTML_BASE_URL',
    defaultValue: 'https://localhost/',
  );

  static bool get hasKakaoMapJavascriptKey =>
      kakaoMapJavascriptKey.trim().isNotEmpty;

  static bool get hasKakaoLocalRestApiKey =>
      kakaoLocalRestApiKey.trim().isNotEmpty;
}
