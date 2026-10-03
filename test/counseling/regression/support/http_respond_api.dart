// Test-only HTTP client for POST /counseling/respond (live backend).
// An upstream rate limit or 5xx is retried, so a shared-key quota does not
// turn into fallbacks during a regression run. The app keeps its own client.
import 'dart:convert';
import 'dart:io';

import 'package:gad_app_team/data/api/counseling_respond_api.dart';

class HttpRespondApi implements CounselingRespondApi {
  final String baseUrl;
  final String token;
  HttpRespondApi(this.baseUrl, this.token);

  /// Evaluation only: an upstream rate-limit error (502 upstream) is retried
  /// after a pause, so a shared-key quota does not turn into fallbacks.
  @override
  Future<Map<String, dynamic>> respond(Map<String, dynamic> body, {Duration timeout = const Duration(seconds: 8)}) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await _once(body, timeout);
      } on CounselingRespondFailure catch (e) {
        if (attempt >= 4 || !(e.requestStatus == 'http_429' || e.requestStatus == 'http_5xx')) rethrow;
        await Future<void>.delayed(Duration(seconds: 15 * (attempt + 1)));
      }
    }
  }

  Future<Map<String, dynamic>> _once(Map<String, dynamic> body, Duration timeout) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.postUrl(Uri.parse('$baseUrl/counseling/respond'));
      req.headers
        ..contentType = ContentType.json
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close().timeout(timeout);
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode >= 400) {
        Object? body;
        try {
          body = jsonDecode(text);
        } on FormatException {
          body = null;
        }
        throw CounselingRespondFailure.fromResponse(res.statusCode, body);
      }
      return jsonDecode(text) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }
}
