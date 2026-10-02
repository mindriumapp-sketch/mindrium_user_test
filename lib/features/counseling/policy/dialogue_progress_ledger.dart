import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/user_thought_extractor.dart';

/// Phase 14.3: dialogue progress derived from turn metadata on every call.
///
/// Never stored: the same facts kept in two places drift apart (the
/// 2026-10-02 memory bug). See docs/counseling/phase14_dialogue_moves.md 5.2.
class DialogueProgressLedger {
  const DialogueProgressLedger._();

  /// A clarify-type assistant turn: a clarify question, or the listening turn
  /// that replaces a repeated clarify (also a goal-exhaustion listen).
  static bool _clarifyType(CounselingMessage m) =>
      m.isClarify ||
      m.goalExhaustionRecovery == GoalExhaustionRecovery.listenWithoutQuestion;

  /// Whether [reply] (a user turn) moved the conversation: contentful, and
  /// not answered as a repair. [answer] is the assistant turn that replied to
  /// it, null for the current turn.
  static bool _moved(String reply, CounselingMessage? answer) =>
      UserThoughtExtractor.isContentfulContribution(reply) &&
      answer?.interactionRepairReason == null;

  /// Clarify-type turns at the end of [messages], each answered without new
  /// content. [currentUserText] answers the last assistant turn.
  ///
  /// A contentful reply anywhere resets the run, so a user who keeps saying
  /// things is never wrapped up for "no progress". Repair turns and
  /// unreadable-input turns are skipped (they asked nothing new).
  static int stagnantClarifyRun(List<CounselingMessage> messages, String currentUserText) {
    var count = 0;
    // Walking backwards: `reply` is the user turn right after the assistant
    // turn being looked at, `answer` the assistant turn that replied to it.
    String reply = currentUserText;
    CounselingMessage? answer;
    CounselingMessage? later; // the assistant turn after the current position
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.isUser) {
        reply = m.text;
        answer = later;
        continue;
      }
      later = m;
      if (m.interactionRepairReason != null || m.dialogueAct == DialogueAct.unknown) continue;
      if (!_clarifyType(m)) break;
      if (_moved(reply, answer)) break;
      count++;
    }
    return count;
  }

  /// The last assistant turn was clarify-type and the current reply brought
  /// nothing new: asking the same kind of question again would repeat itself.
  static bool clarifyWouldRepeat(List<CounselingMessage> messages, String currentUserText) {
    final last = messages.reversed.where((m) => !m.isUser).firstOrNull;
    if (last == null || !_clarifyType(last)) return false;
    return !_moved(currentUserText, null);
  }
}
