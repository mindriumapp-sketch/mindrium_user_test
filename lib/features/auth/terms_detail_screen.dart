import 'package:gad_app_team/features/auth/terms_documents.dart';
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/primary_action_button.dart';

class TermsDetailScreen extends StatelessWidget {
  const TermsDetailScreen({
    super.key,
    required this.title,
    this.documentKey,
    this.isSignupFlow = false,
  });

  final String title;
  final String? documentKey;
  final bool isSignupFlow;

  TermsDocument get _document {
    final key = documentKey;
    if (key != null && key.isNotEmpty) {
      return TermsDocuments.byKey(key);
    }
    return TermsDocuments.byTitle(title);
  }

  @override
  Widget build(BuildContext context) {
    final document = _document;
    final bool isLongTitle = document.title.length >= 16;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Color(0xFF233B6E),
                    ),
                    visualDensity: VisualDensity.compact,
                    splashRadius: 20,
                  ),
                  Expanded(
                    child: Text(
                      document.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Noto Sans KR',
                        fontWeight: FontWeight.w700,
                        fontSize: isLongTitle ? 17 : 20,
                        height: 1.25,
                        color: Color(0xFF233B6E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 34),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFE3E8F3)),
              const SizedBox(height: 6),
              Expanded(
                child: ListView(
                  children: [
                    _metaText(document.updatedAt),
                    ..._buildDocumentSections(document),
                  ],
                ),
              ),
              if (isSignupFlow) ...[
                const SizedBox(height: 14),
                PrimaryActionButton(
                  text: '동의하기',
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDocumentSections(TermsDocument document) {
    return document.sections
        .map(
          (section) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(section.title),
              ...section.paragraphs.map(_paragraph),
              if (section.bullets.isNotEmpty) _bulletList(section.bullets),
              if (section.numbered.isNotEmpty) _numberedList(section.numbered),
              if (section.table != null) _table(section.table!),
            ],
          ),
        )
        .toList();
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Noto Sans KR',
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F2E4D),
        ),
      ),
    );
  }

  Widget _paragraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Noto Sans KR',
          fontSize: 16,
          height: 1.65,
          color: Color(0xFF2C3550),
        ),
      ),
    );
  }

  Widget _metaText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Noto Sans KR',
          fontSize: 14,
          color: Color(0xFF6A758D),
        ),
      ),
    );
  }

  Widget _numberedList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(items.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '${index + 1}. ${items[index]}',
            style: const TextStyle(
              fontFamily: 'Noto Sans KR',
              fontSize: 16,
              height: 1.6,
              color: Color(0xFF2C3550),
            ),
          ),
        );
      }),
    );
  }

  Widget _bulletList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '- $item',
                    style: const TextStyle(
                      fontFamily: 'Noto Sans KR',
                      fontSize: 16,
                      height: 1.6,
                      color: Color(0xFF2C3550),
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _table(TermsTable table) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD6DDEC)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Table(
        columnWidths: {
          for (int i = 0; i < table.headers.length; i++)
            i: const FlexColumnWidth(),
        },
        border: const TableBorder(
          horizontalInside: BorderSide(color: Color(0xFFE3E8F3)),
          verticalInside: BorderSide(color: Color(0xFFE3E8F3)),
        ),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF5F8FD)),
            children:
                table.headers
                    .map((header) => _tableCell(header, isHeader: true))
                    .toList(),
          ),
          ...table.rows.map(
            (row) => TableRow(
              children: row.map((cell) => _tableCell(cell)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Noto Sans KR',
          fontSize: isHeader ? 15 : 14,
          fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
          color: isHeader ? const Color(0xFF233B6E) : const Color(0xFF2C3550),
          height: 1.5,
        ),
      ),
    );
  }
}
