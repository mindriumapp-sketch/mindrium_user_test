import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/features/auth/terms_detail_screen.dart';
import 'package:gad_app_team/features/auth/terms_documents.dart';
import 'package:gad_app_team/utils/text_line.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';

void main() {
  String documentText(TermsDocument document) {
    return [
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
  }

  test('terms documents do not expose beta placeholders', () {
    const bannedPhrases = ['여기에 입력', '샘플', '표 예시', 'placeholder'];

    for (final document in TermsDocuments.all) {
      expect(document.title.trim(), isNotEmpty);
      expect(document.subtitle.trim(), isNotEmpty);
      expect(document.sections, isNotEmpty);

      final text = documentText(document);

      for (final phrase in bannedPhrases) {
        expect(text, isNot(contains(phrase)));
      }
    }
  });

  test('third party consent names map and beta distribution providers', () {
    final text = documentText(TermsDocuments.thirdPartyConsent);

    expect(text, contains('카카오'));
    expect(text, contains('Google Play'));
    expect(text, contains('Apple App Store'));
    expect(text, contains('TestFlight'));
    expect(text, contains('앱 배포 플랫폼'));
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

  testWidgets('third party terms detail renders provider names', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TermsDetailScreen(
          title: '개인정보 및 민감정보 제3자 제공 동의',
          documentKey: 'third_party',
        ),
      ),
    );

    final renderedText = tester
        .widgetList<TextLine>(find.byType(TextLine))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .map((text) => text.replaceAll('\u2060', ''))
        .join('\n');

    expect(renderedText, contains('카카오'));
    expect(renderedText, contains('Google Play'));
    expect(renderedText, contains('TestFlight'));
    expect(renderedText, contains('앱 배포 플랫폼'));
  });

  testWidgets('custom app bar title stays centered with asymmetric controls', (
    tester,
  ) async {
    Future<void> pumpAppBar(CustomAppBar appBar) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(appBar: appBar, body: const SizedBox.shrink()),
        ),
      );
    }

    Future<void> expectTitleCentered(String title, CustomAppBar appBar) async {
      await pumpAppBar(appBar);

      final titleFinder = find.byWidgetPredicate((widget) {
        if (widget is! RichText) return false;
        final plainText = widget.text.toPlainText().replaceAll('\u2060', '');
        return plainText == title;
      }, description: 'app bar title $title');

      expect(titleFinder, findsOneWidget);

      final screenCenter = tester.getSize(find.byType(Scaffold)).width / 2;
      final titleCenter = tester.getCenter(titleFinder).dx;

      expect(titleCenter, closeTo(screenCenter, 2));
    }

    await expectTitleCentered(
      '마이페이지',
      CustomAppBar(
        title: '마이페이지',
        showBack: false,
        showHome: false,
        confirmOnBack: false,
        confirmOnHome: false,
        extraIcon: Icons.settings_rounded,
        onExtraPressed: () {},
      ),
    );

    await expectTitleCentered(
      '리포트',
      const CustomAppBar(
        title: '리포트',
        showBack: false,
        showHome: true,
        confirmOnBack: false,
        confirmOnHome: false,
      ),
    );

    await expectTitleCentered(
      '약관 및 정책',
      const CustomAppBar(
        title: '약관 및 정책',
        showHome: false,
        confirmOnBack: false,
      ),
    );
  });
}
