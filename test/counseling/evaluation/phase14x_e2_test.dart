// Phase 14.X E2: the frozen cross-domain scripts through path A and path B.
// Records every reply (text + closing metadata + B status); scoring is
// tools/llm_led_eval/score_e2.py. Env-gated like E1:
//
//   LLM_LED_BASE_URL=... LLM_LED_TOKEN=... E2_OUT=build/llm_led/e2.json \
//   flutter test test/counseling/evaluation/phase14x_e2_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/assistant/app_guide/local_app_guide_repository.dart';
import 'package:gad_app_team/features/assistant/mindrium_assistant_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

import 'phase14x_e1_test.dart' show HttpRespondApi;

void main() {
  final env = Platform.environment;
  final base = env['LLM_LED_BASE_URL'];
  final token = env['LLM_LED_TOKEN'];
  final fixture = env['E2_FIXTURE'] ?? 'test/counseling/evaluation/fixtures/phase14x_e2_cross_domain_v1.json';
  final out = env['E2_OUT'] ?? 'build/llm_led/e2.json';

  test('E2: A vs B on the cross-domain scripts', () async {
    final repo = LocalCbtKnowledgeRepository(loadAsset: (p) => File(p).readAsString());
    await repo.initialize();
    final guide = LocalAppGuideRepository(loadAsset: (p) => File(p).readAsString());
    await guide.initialize();
    final api = HttpRespondApi(base!, token!);
    final scripts = ((jsonDecode(File(fixture).readAsStringSync()) as Map)['scripts'] as List)
        .cast<Map<String, dynamic>>();

    Future<List<Map<String, Object?>>> run(Map<String, dynamic> script, bool llmLed) async {
      final harness = CounselingHarness.deterministic(
        llm: MockLlmService(), safetyGate: const KeywordSafetyGate(), knowledgeRepository: repo);
      // A goes through the assistant router (app-guide / mixed), as in the app.
      final assistant = MindRiumAssistantHarness(counselingHarness: harness, appGuideKnowledgeRetriever: LocalAppGuideKnowledgeRetriever(repository: guide));
      final s = CounselingSessionState(sessionId: script['id'] as String, currentWeek: script['week'] as int);
      final rows = <Map<String, Object?>>[];
      for (final (i, turn) in (script['turns'] as List).cast<Map<String, dynamic>>().indexed) {
        final text = turn['user'] as String;
        final prev = s.messages.reversed.where((m) => !m.isUser).firstOrNull;
        String status = 'A';
        CounselingTurnResult r;
        if (llmLed) {
          final t = await harness.handleLlmLedTurn(session: s, userMessage: text, api: api, appGuide: guide);
          status = t.status;
          r = t.result ?? await assistant.handleTurn(session: s, userMessage: text);
        } else {
          r = await assistant.handleTurn(session: s, userMessage: text);
        }
        s.messages
          ..add(CounselingMessage(id: 'u$i', role: 'user', text: text, createdAt: DateTime(2026)))
          ..add(r.assistantMessage);
        rows.add({
          'user': text,
          'check': turn['check'],
          'only_if_proposed': turn['only_if_proposed'] ?? false,
          'prev_proposed': prev?.closingStep == ClosingStep.proposed,
          'reply': r.assistantMessage.text,
          'closing': r.assistantMessage.closingStep?.name,
          'repair': r.assistantMessage.interactionRepairReason?.name,
          'status': status,
        });
        if (r.assistantMessage.closingStep == ClosingStep.finalized) break;
      }
      return rows;
    }

    final results = <Map<String, Object?>>[];
    final n = int.tryParse(env['E2_CONCURRENCY'] ?? '') ?? 2;
    for (var i = 0; i < scripts.length; i += n) {
      final batch = scripts.skip(i).take(n);
      results.addAll(await Future.wait(batch.map((sc) async => {
        'id': sc['id'],
        'week': sc['week'],
        'A': await run(sc, false),
        'B': await run(sc, true),
      })));
    }
    File(out)
      ..createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert({'fixture': fixture, 'scripts': results}));
  }, timeout: const Timeout(Duration(minutes: 40)),
      skip: base == null || token == null ? 'set LLM_LED_BASE_URL and LLM_LED_TOKEN' : false);
}
