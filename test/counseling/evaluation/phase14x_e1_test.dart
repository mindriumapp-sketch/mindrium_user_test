// Phase 14.X E1: the same simulated users (holdout drivers) through path A
// (deterministic-led) and path B (bounded LLM-led, deterministic fallback),
// scored by the same session-flow metrics. Calls the real backend, so it
// runs only when LLM_LED_BASE_URL and LLM_LED_TOKEN are set:
//
//   LLM_LED_BASE_URL=http://127.0.0.1:8090 LLM_LED_TOKEN=... \
//   E1_FIXTURE=test/counseling/evaluation/fixtures/phase13_9_holdout_v5.json \
//   E1_OUT=build/llm_led/e1_v5.json \
//   flutter test test/counseling/evaluation/phase14x_e1_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/api/counseling_respond_api.dart';
import 'package:gad_app_team/features/assistant/app_guide/local_app_guide_repository.dart';

import 'support/holdout_runner.dart';
import 'support/session_flow_metrics.dart';

/// Plain HTTP client for the evaluation run (no app token storage).
class HttpRespondApi implements CounselingRespondApi {
  final String baseUrl;
  final String token;
  HttpRespondApi(this.baseUrl, this.token);

  @override
  Future<Map<String, dynamic>> respond(Map<String, dynamic> body, {Duration timeout = const Duration(seconds: 8)}) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.postUrl(Uri.parse('$baseUrl/counseling/respond'));
      req.headers
        ..contentType = ContentType.json
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close().timeout(timeout);
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode >= 400) throw HttpException('status ${res.statusCode} $text');
      return jsonDecode(text) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }
}

void main() {
  final env = Platform.environment;
  final base = env['LLM_LED_BASE_URL'];
  final token = env['LLM_LED_TOKEN'];
  final concurrency = int.tryParse(env['E1_CONCURRENCY'] ?? '') ?? 8;
  final fixture = env['E1_FIXTURE'] ?? 'test/counseling/evaluation/fixtures/phase13_9_holdout_v5.json';
  final out = env['E1_OUT'] ?? 'build/llm_led/e1.json';

  test('E1: A vs B on the holdout drivers', () async {
    final guide = LocalAppGuideRepository(loadAsset: (p) => File(p).readAsString());
    await guide.initialize();
    final api = HttpRespondApi(base!, token!);
    final statuses = <String, int>{};
    final violations = <String, int>{};
    final latencies = <int>[];

    final a = await runHoldout(fixture);
    final b = await runHoldout(
      fixture,
      concurrency: concurrency,
      turn: (harness, session, text) async {
        final t = await harness.handleLlmLedTurn(
          session: session, userMessage: text, api: api, appGuide: guide);
        statuses[t.status] = (statuses[t.status] ?? 0) + 1;
        if (t.detail != null) {
          final k = 'http:${t.detail!.replaceAll(RegExp(r'\s+'), ' ')}';
          violations[k] = (violations[k] ?? 0) + 1;
        }
        for (final v in t.violations) {
          violations[v] = (violations[v] ?? 0) + 1;
        }
        if (t.latencyMs != null && t.status != 'safety') latencies.add(t.latencyMs!);
        return t.result ?? await harness.handleTurn(session: session, userMessage: text);
      },
    );

    Map<String, Object> summary(HoldoutResult r) => {
      'sessions': r.runs.length,
      'user_turns': r.runs.fold<int>(0, (n, run) => n + run.steps.length),
      'tier_a': {for (final k in flowStructuralMetrics) k: r.metrics.counts[k] ?? 0},
      'tier_b': {for (final k in flowDetectionDependentMetrics) k: r.metrics.counts[k] ?? 0},
      'meta_ignored': r.metrics.counts['metaIgnored'] ?? 0,
    };
    latencies.sort();
    int pct(double p) => latencies.isEmpty ? 0 : latencies[((latencies.length - 1) * p).round()];
    final calls = statuses.entries.where((e) => e.key != 'safety').fold<int>(0, (n, e) => n + e.value);
    final report = {
      'fixture': fixture,
      'A': summary(a),
      'B': {
        ...summary(b),
        'b_status': statuses,
        'b_fallback_rate_pct': calls == 0 ? 0 : (100 * (calls - (statuses['success'] ?? 0)) / calls),
        'b_violations': violations,
        'b_latency_ms': {'p50': pct(.5), 'p95': pct(.95), 'max': latencies.isEmpty ? 0 : latencies.last},
      },
      'B_failures': {for (final k in [...flowStructuralMetrics, ...flowDetectionDependentMetrics])
        if ((b.metrics.counts[k] ?? 0) > 0) k: b.metrics.failures[k]},
      'B_transcripts': [
        for (final run in b.runs.take(30))
          {'id': run.id, 'turns': [for (final s in run.steps) {'u': s.user, 'a': s.reply.text, 'intent': s.intent.name}]},
      ],
    };
    File(out)
      ..createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(report));
    // ignore: avoid_print
    print('E1 ${jsonEncode({'A': report['A'], 'B': (report['B'] as Map)..remove('B_transcripts')})}');
  }, timeout: const Timeout(Duration(minutes: 40)),
      skip: base == null || token == null ? 'set LLM_LED_BASE_URL and LLM_LED_TOKEN' : false);
}
