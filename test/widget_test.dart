import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/features/auth/terms_detail_screen.dart';
import 'package:gad_app_team/features/auth/terms_documents.dart';
import 'package:gad_app_team/utils/text_line.dart';

void main() {
  test('terms documents do not expose beta placeholders', () {
    const bannedPhrases = ['여기에 입력', '샘플', '표 예시', 'placeholder'];

    for (final document in TermsDocuments.all) {
      expect(document.title.trim(), isNotEmpty);
      expect(document.subtitle.trim(), isNotEmpty);
      expect(document.sections, isNotEmpty);

      final documentText = [
        document.title,
        document.subtitle,
        document.updatedAt,
        for (final section in document.sections) ...[
          section.title,
          ...section.paragraphs,
          ...section.bullets,
          ...section.numbered,
          if (section.table != null) ...[
            ...section.table!.headers,
            for (final row in section.table!.rows) ...row,
          ],
        ],
      ].join('\n');

      for (final phrase in bannedPhrases) {
        expect(documentText, isNot(contains(phrase)));
      }
    }
  });

  testWidgets('terms detail renders the selected document', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TermsDetailScreen(
          title: '민감정보 수집 및 이용 동의',
          documentKey: 'sensitive_info',
        ),
      ),
    );

    final renderedText = tester
        .widgetList<TextLine>(find.byType(TextLine))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .map((text) => text.replaceAll('\u2060', ''))
        .join('\n');

    expect(renderedText, contains('민감정보 수집 및 이용 동의'));
    expect(renderedText, contains('정신건강 관련 자기기록'));
    expect(renderedText, isNot(contains('여기에 입력')));
  });
}
