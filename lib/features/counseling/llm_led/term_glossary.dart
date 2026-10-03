// Phase 14.X: term grounding. Code, not the model, decides which approved
// term the user asked about; the model gets that one definition (read from
// the approved corpus) or, for a term not in the glossary, none at all.
// assets/counseling/glossary.json holds names and aliases only.
import 'dart:convert';

import 'package:gad_app_team/data/counseling/cbt_knowledge_repository.dart';

class GlossaryTerm {
  final String termId;
  final String canonicalName;
  final List<String> aliases;
  final String sourceId;

  const GlossaryTerm(this.termId, this.canonicalName, this.aliases, this.sourceId);
}

/// What the user asked about this turn.
class TermRequest {
  /// null for a term that is not in the glossary.
  final String? termId;
  final String name;

  /// From the approved corpus (approved terms only).
  final String? definition;

  const TermRequest({required this.termId, required this.name, this.definition});

  bool get approved => termId != null;

  Map<String, Object?> toJson() => {
    'status': approved ? 'approved' : 'unknown',
    'term_id': termId,
    'name': name,
    'definition': definition,
  };
}

class TermGlossary {
  final List<GlossaryTerm> terms;

  const TermGlossary(this.terms);

  static const TermGlossary empty = TermGlossary([]);

  static Future<TermGlossary> load(Future<String> Function(String path) loadAsset) async {
    final raw = jsonDecode(await loadAsset('assets/counseling/glossary.json')) as Map<String, dynamic>;
    return TermGlossary([
      for (final t in (raw['terms'] as List).cast<Map<String, dynamic>>())
        GlossaryTerm(
          t['term_id'] as String,
          t['canonical_name'] as String,
          (t['aliases'] as List).cast<String>(),
          t['source_id'] as String,
        ),
    ]);
  }

  // A question about a word: "X가 뭐예요", "X 무슨 뜻", "X란", "X라는 게 뭔데".
  static const String _cue =
      r'(뭐|뭔|무슨\s*(뜻|말|의미)|뜻이|의미|이란|란\s*게|라는\s*게|라는\s*건|어떤\s*거|설명)';

  static final RegExp _quoted = RegExp('[\'‘"“]([^\'’"”]{2,20})[\'’"”]');
  static final RegExp _jargon = RegExp(
    r'([가-힣A-Za-z]{2,12}(화|법|론|요법|기법|사고|이론|모델|훈련|반응))\s*(이|가|은|는|란|이란)?\s*[?？]?',
  );

  /// The term this message asks about, if any.
  TermRequest? resolve(String userText, CbtKnowledgeRepository knowledge) {
    final text = userText.trim();
    final cue = RegExp(_cue);
    if (!cue.hasMatch(text) && !text.contains('?')) return null;

    // approved: the longest alias followed closely by a question cue
    final candidates = [
      for (final t in terms)
        for (final a in {...t.aliases, t.canonicalName}) (t, a),
    ]..sort((x, y) => y.$2.length.compareTo(x.$2.length));
    for (final (t, alias) in candidates) {
      final asked = RegExp('${RegExp.escape(alias)}[^.?!]{0,12}($_cue|[?？])');
      if (asked.hasMatch(text)) {
        final item = knowledge.getById(t.sourceId);
        return TermRequest(
          termId: t.termId,
          name: t.canonicalName,
          definition: item?.paragraphs.take(2).join(' '),
        );
      }
    }

    // not in the glossary: a quoted word or a technical-looking word asked
    // about. A quoted phrase with spaces is someone's sentence ('이번 학기
    // 망했다', '가능성을 따져본다'), explained as meaning, not a term.
    for (final m in [..._quoted.allMatches(text), ..._jargon.allMatches(text)]) {
      final name = m.group(1)!.trim();
      if (name.contains(RegExp(r'\s'))) continue;
      final after = text.substring(m.end).trimLeft();
      final asked = text.substring(m.start, m.end).contains(RegExp(r'[?？]')) ||
          RegExp('^.{0,12}($_cue|[?？])').hasMatch(after);
      if (!asked) continue;
      final known = terms.any((t) => t.aliases.contains(name) || t.canonicalName == name);
      if (!known) return TermRequest(termId: null, name: name);
    }
    return null;
  }
}
