import 'counseling_models.dart';
import 'counseling_session_summary.dart';
import 'episode_history.dart';

/// 서버에 저장할 상담 내용. 메모리와 턴 메타데이터를 한 번만 합친다.
class CounselingSessionRecord {
  final CounselingSessionSummary summary;
  final EpisodeFacts facts;
  final String? coreThoughtSource;
  final String? affect;
  final String? interventionOutcome;

  const CounselingSessionRecord._({
    required this.summary,
    required this.facts,
    required this.coreThoughtSource,
    required this.affect,
    required this.interventionOutcome,
  });

  factory CounselingSessionRecord.build({
    required CounselingSessionSummary summary,
    required List<CounselingMessage> messages,
    String? coreThoughtSource,
    String? affect,
  }) {
    final facts = EpisodeFacts.fromMessages(messages);
    final used = summary.interventionUsed;
    final integration =
        used == null
            ? null
            : messages.reversed
                .where(
                  (m) =>
                      !m.isUser &&
                      m.interventionCredited != null &&
                      m.referencedCbtIds.contains(used),
                )
                .firstOrNull;
    return CounselingSessionRecord._(
      summary: summary,
      facts: facts,
      coreThoughtSource: facts.coreThought == null ? null : coreThoughtSource,
      affect: affect,
      interventionOutcome:
          integration == null
              ? null
              : (integration.interventionCredited!
                  ? 'credited'
                  : 'acknowledged'),
    );
  }

  String? get mainConcern => summary.concern ?? facts.mainConcern;
}
