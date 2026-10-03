// Demo smoke regression: the frozen demo scripts (fixtures/demo_smoke_v1.json)
// through path A and path B against a live backend. Records every reply
// (text, closing metadata, B status, violations, timing). Env-gated:
//
//   LLM_LED_BASE_URL=http://127.0.0.1:8090 LLM_LED_TOKEN=<token> \
//   SMOKE_OUT=build/demo_smoke.json \
//   flutter test test/counseling/regression/demo_smoke_test.dart
//
// Pass: every B turn accepted or safely fallen back, crisis → safety reply,
// end requests finalize, no fabricated record, no non-Korean question mark.
// Reference run: baseline/demo_smoke_respond_v11.json.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/assistant/app_guide/local_app_guide_repository.dart';
import 'package:gad_app_team/features/counseling/llm_led/term_glossary.dart';
import 'package:gad_app_team/features/assistant/mindrium_assistant_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

import 'support/http_respond_api.dart';

void main() {
  final env = Platform.environment;
  final base = env['LLM_LED_BASE_URL'];
  final token = env['LLM_LED_TOKEN'];
  final fixture = env['SMOKE_FIXTURE'] ?? 'test/counseling/regression/fixtures/demo_smoke_v1.json';
  final out = env['SMOKE_OUT'] ?? 'build/demo_smoke.json';

  test('demo smoke: A vs B on the frozen demo scripts', () async {
    final repo = LocalCbtKnowledgeRepository(loadAsset: (p) => File(p).readAsString());
    await repo.initialize();
    final guide = LocalAppGuideRepository(loadAsset: (p) => File(p).readAsString());
    await guide.initialize();
    final glossary = await TermGlossary.load((p) => File(p).readAsString());
    final api = HttpRespondApi(base!, token!);
    final only = env['SMOKE_ONLY']?.split(',').toSet();
    final scripts = ((jsonDecode(File(fixture).readAsStringSync()) as Map)['scripts'] as List)
        .cast<Map<String, dynamic>>()
        .where((sc) => only == null || only.contains(sc['id']))
        .toList();

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
        List<String> violations = const [];
        String? primary;
        String? definitionId;
        String? bText;
        Map<String, Object?>? bMeta;
        String? detail;
        String? requestStatus;
        String? group;
        int? httpStatus;
        int? fallbackMs;
        int? endToEndMs;
        Map<String, int?> timing = const {};
        CounselingTurnResult r;
        if (llmLed) {
          final e2e = Stopwatch()..start();
          final t = await harness.handleLlmLedTurn(session: s, userMessage: text, api: api, appGuide: guide, glossary: glossary,
              // evaluation: allow rate-limit retries (the app keeps 8 s)
              timeout: const Duration(minutes: 2));
          status = t.status;
          violations = t.violations;
          definitionId = t.output?.definitionId;
          bText = t.output?.text;
          final o = t.output;
          bMeta = o == null
              ? null
              : {
                  'domain': o.domain,
                  'moves': o.moves,
                  'intervention_step': o.interventionStep,
                  'used_app_fact_ids': o.usedAppFactIds,
                  'session_action': o.sessionAction,
                };
          timing = t.timing;
          detail = t.detail;
          primary = t.primaryRejection ?? (t.status == 'success' ? null : t.status);
          requestStatus = t.requestStatus;
          group = t.group;
          httpStatus = t.failure?.httpStatus;
          detail = t.failure == null ? detail : '${t.failure!.cause ?? ''} ${t.failure!.finishReason ?? ''}'.trim();
          if (t.result != null) {
            r = t.result!;
          } else {
            final fb = Stopwatch()..start();
            r = await assistant.handleTurn(session: s, userMessage: text);
            fallbackMs = fb.elapsedMilliseconds;
          }
          endToEndMs = e2e.elapsedMilliseconds;
        } else {
          r = await assistant.handleTurn(session: s, userMessage: text);
        }
        s.messages
          ..add(CounselingMessage(id: 'u$i', role: 'user', text: text, createdAt: DateTime(2026)))
          ..add(r.assistantMessage);
        rows.add({
          'user': text,
          'check': turn['check'],
          'expect': turn['expect'],
          'only_if_proposed': turn['only_if_proposed'] ?? false,
          'prev_proposed': prev?.closingStep == ClosingStep.proposed,
          'reply': r.assistantMessage.text,
          'closing': r.assistantMessage.closingStep?.name,
          'repair': r.assistantMessage.interactionRepairReason?.name,
          'step': r.assistantMessage.interventionStep?.name,
          'act': r.assistantMessage.dialogueAct?.name,
          'status': status,
          'primary_rejection': primary,
          'definition_id': definitionId,
          'b_text': bText,
          'b_meta': bMeta,
          'timing': timing,
          'detail': detail,
          'request_status': requestStatus,
          'group': group,
          'http_status': httpStatus,
          'fallback_ms': fallbackMs,
          'end_to_end_ms': endToEndMs,
          'violations': violations,
        });
        if (r.assistantMessage.closingStep == ClosingStep.finalized) break;
      }
      return rows;
    }

    final results = <Map<String, Object?>>[];
    final n = int.tryParse(env['SMOKE_CONCURRENCY'] ?? '') ?? 2;
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
