import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/primary_action_button.dart';

class TermsDetailScreen extends StatelessWidget {
  const TermsDetailScreen({
    super.key,
    required this.title,
    required this.content,
    this.isSignupFlow = false,
  });

  final String title;
  final String content;
  final bool isSignupFlow;

  @override
  Widget build(BuildContext context) {
    final bool isLongTitle = title.length >= 16;

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
                      title,
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
              Expanded(child: ListView(children: _buildDocumentSections())),
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

  List<Widget> _buildDocumentSections() {
    if (title.contains('제3자')) {
      return _thirdPartySections();
    }
    if (title.contains('민감정보')) {
      return _sensitiveSections();
    }
    if (title.contains('처리방침')) {
      return _policySections();
    }
    if (title.contains('수집 및 이용')) {
      return _collectionSections();
    }
    return _serviceSections();
  }

  List<Widget> _serviceSections() {
    return [
      _metaText('시행일자: 2026.03.19'),
      _sectionTitle('제1조 (목적)'),
      _paragraph(
        '본 약관은 마인드리움 앱(이하 "서비스")의 이용조건, 이용자와 회사의 권리·의무 및 책임사항을 정하는 것을 목적으로 합니다.',
      ),
      _sectionTitle('제2조 (제공 서비스)'),
      _numberedList([
        '불안 관리 프로그램 및 주차별 교육 콘텐츠 제공',
        '감정 기록(다이어리), 이완 훈련, 일정 알림 기능 제공',
        '이용 통계 기반 맞춤형 콘텐츠 안내',
      ]),
      _sectionTitle('제3조 (이용자의 의무)'),
      _bulletList([
        '타인의 계정 또는 개인정보를 무단으로 이용하지 않습니다.',
        '서비스 안정성을 저해하는 행위를 하지 않습니다.',
        '관련 법령 및 본 약관을 준수합니다.',
      ]),
      _sectionTitle('제4조 (책임 제한)'),
      _paragraph(
        '회사는 천재지변, 시스템 점검 등 불가피한 사유로 발생한 서비스 중단에 대해 고의 또는 중대한 과실이 없는 한 책임을 제한할 수 있습니다.',
      ),
      _sectionTitle('표 예시'),
      _table(
        headers: const ['항목', '내용'],
        rows: const [
          ['서비스명', '마인드리움'],
          ['운영 주체', '마인드리움 팀'],
          ['문의 채널', '앱 내 문의하기'],
        ],
      ),
      _tailPlaceholder(),
    ];
  }

  List<Widget> _policySections() {
    return [
      _metaText('개인정보처리방침 버전: 1.0 / 시행일자: 2026.03.19'),
      _sectionTitle('1. 개인정보 처리 목적'),
      _bulletList([
        '회원 식별 및 가입 의사 확인',
        '불안관리 서비스 제공 및 이용 이력 관리',
        '고객 문의 대응 및 서비스 품질 개선',
      ]),
      _sectionTitle('2. 처리하는 개인정보 항목'),
      _table(
        headers: const ['구분', '항목', '처리 목적'],
        rows: const [
          ['필수', '이메일, 비밀번호', '회원가입 및 로그인'],
          ['서비스', '다이어리 기록, 프로그램 진행 정보', '개인화 콘텐츠 제공'],
          ['기기', '앱 버전, 기기 식별값(가명처리)', '오류 분석 및 안정성 개선'],
        ],
      ),
      _sectionTitle('3. 보유 및 이용 기간'),
      _paragraph('회원 탈퇴 시까지 보관하며, 관련 법령에 따라 필요한 경우 법정 보관기간 동안 보관합니다.'),
      _sectionTitle('4. 이용자의 권리'),
      _numberedList([
        '개인정보 열람, 정정, 삭제를 요청할 수 있습니다.',
        '처리정지 및 동의 철회를 요청할 수 있습니다.',
        '권리행사는 앱 내 문의 또는 고객센터를 통해 가능합니다.',
      ]),
      _sectionTitle('표 예시'),
      _table(
        headers: const ['요청 유형', '처리 기한'],
        rows: const [
          ['열람/정정/삭제 요청', '접수 후 지체 없이 처리'],
          ['동의 철회 요청', '접수 후 지체 없이 반영'],
        ],
      ),
      _tailPlaceholder(),
    ];
  }

  List<Widget> _collectionSections() {
    return [
      _metaText('개인정보 수집·이용 동의서 (샘플)'),
      _sectionTitle('1. 수집·이용 목적'),
      _numberedList(['회원가입 및 본인확인', '콘텐츠 제공 및 학습/치유 흐름 저장', '문의 대응 및 공지 전달']),
      _sectionTitle('2. 수집 항목'),
      _table(
        headers: const ['구분', '수집 항목', '보유 기간'],
        rows: const [
          ['필수', '이메일, 비밀번호', '회원 탈퇴 시까지'],
          ['서비스 이용정보', '다이어리/훈련 기록, 접속 로그', '회원 탈퇴 시까지'],
        ],
      ),
      _sectionTitle('3. 동의 거부 권리 및 불이익'),
      _paragraph(
        '이용자는 개인정보 수집·이용 동의를 거부할 권리가 있습니다. 다만 필수항목 동의가 없을 경우 회원가입 및 핵심 서비스 이용이 제한될 수 있습니다.',
      ),
      _sectionTitle('표 예시'),
      _table(
        headers: const ['동의 항목', '미동의 시 제한'],
        rows: const [
          ['필수 개인정보', '회원가입 불가'],
          ['서비스 이용정보', '개인화 기능 제한'],
        ],
      ),
      _tailPlaceholder(),
    ];
  }

  List<Widget> _sensitiveSections() {
    return [
      _metaText('민감정보 수집·이용 동의서 (샘플)'),
      _sectionTitle('1. 민감정보 처리 목적'),
      _paragraph(
        '마인드리움은 불안관리 프로그램 제공을 위해 이용자의 정신건강 관련 자기기록 정보를 민감정보로 처리할 수 있습니다.',
      ),
      _sectionTitle('2. 처리 항목'),
      _table(
        headers: const ['항목', '목적', '보유 기간'],
        rows: const [
          ['불안 정도 점수, 감정 상태 기록', '개인화된 훈련 콘텐츠 제공', '회원 탈퇴 시까지'],
          ['자기보고 건강 관련 메모', '경과 확인 및 회복 지원', '회원 탈퇴 시까지'],
        ],
      ),
      _sectionTitle('3. 동의 거부 권리 및 불이익'),
      _bulletList([
        '민감정보 처리 동의를 거부할 수 있습니다.',
        '거부 시 개인화 기능, 일부 분석 기능 제공이 제한될 수 있습니다.',
      ]),
      _sectionTitle('표 예시'),
      _table(
        headers: const ['민감정보 항목', '처리 목적'],
        rows: const [
          ['불안 척도 점수', '회복 단계 분석'],
          ['감정/신체 반응 메모', '맞춤형 콘텐츠 제공'],
        ],
      ),
      _tailPlaceholder(),
    ];
  }

  List<Widget> _thirdPartySections() {
    return [
      _metaText('개인정보 및 민감정보 제3자 제공 동의서 (샘플)'),
      _sectionTitle('1. 제3자 제공 내역'),
      _table(
        headers: const ['제공받는 자', '제공 목적', '제공 항목', '보유 기간'],
        rows: const [
          ['클라우드 인프라 운영사', '데이터 저장 및 백업', '회원 식별정보, 서비스 기록', '위탁 계약 종료 시까지'],
          ['분석/모니터링 도구 제공사', '오류 분석 및 성능 개선', '가명처리된 이용 로그', '수집일로부터 12개월'],
        ],
      ),
      _sectionTitle('2. 동의 거부 권리 및 불이익'),
      _paragraph(
        '이용자는 제3자 제공 동의를 거부할 권리가 있습니다. 다만 동의하지 않을 경우 일부 기능 제공 또는 서비스 안정성 개선이 제한될 수 있습니다.',
      ),
      _sectionTitle('3. 추가 안내'),
      _numberedList([
        '제공 항목 및 제공받는 자가 변경되는 경우 사전 고지합니다.',
        '법령상 보관 의무가 없는 경우 지체 없이 파기합니다.',
      ]),
      _sectionTitle('표 예시'),
      _table(
        headers: const ['구분', '예시'],
        rows: const [
          ['제공 방식', '암호화 전송'],
          ['보호 조치', '접근권한 최소화'],
          ['파기 방식', '복구 불가능한 방식으로 파기'],
        ],
      ),
      _tailPlaceholder(),
    ];
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
                    '• $item',
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

  Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD6DDEC)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Table(
        columnWidths: {
          for (int i = 0; i < headers.length; i++) i: const FlexColumnWidth(),
        },
        border: const TableBorder(
          horizontalInside: BorderSide(color: Color(0xFFE3E8F3)),
          verticalInside: BorderSide(color: Color(0xFFE3E8F3)),
        ),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF5F8FD)),
            children:
                headers
                    .map((header) => _tableCell(header, isHeader: true))
                    .toList(),
          ),
          ...rows.map(
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

  Widget _tailPlaceholder() {
    if (content.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFE3E8F3)),
        const SizedBox(height: 10),
        const Text(
          '추가 메모',
          style: TextStyle(
            fontFamily: 'Noto Sans KR',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF44506B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: const TextStyle(
            fontFamily: 'Noto Sans KR',
            fontSize: 15,
            height: 1.6,
            color: Color(0xFF55607A),
          ),
        ),
      ],
    );
  }
}
