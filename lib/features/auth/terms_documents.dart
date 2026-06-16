class TermsDocument {
  const TermsDocument({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.updatedAt,
    required this.sections,
  });

  final String key;
  final String title;
  final String subtitle;
  final String updatedAt;
  final List<TermsSection> sections;
}

class TermsSection {
  const TermsSection({
    required this.title,
    this.paragraphs = const [],
    this.bullets = const [],
    this.numbered = const [],
    this.table,
  });

  final String title;
  final List<String> paragraphs;
  final List<String> bullets;
  final List<String> numbered;
  final TermsTable? table;
}

class TermsTable {
  const TermsTable({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;
}

class TermsDocuments {
  static const List<TermsDocument> all = [
    service,
    privacyPolicy,
    personalInfoConsent,
    sensitiveInfoConsent,
    thirdPartyConsent,
  ];

  static TermsDocument byKey(String key) {
    return all.firstWhere(
      (document) => document.key == key,
      orElse: () => service,
    );
  }

  static TermsDocument byTitle(String title) {
    return all.firstWhere(
      (document) => document.title == title,
      orElse: () => service,
    );
  }

  static const TermsDocument service = TermsDocument(
    key: 'service',
    title: '서비스 이용약관',
    subtitle: '서비스 이용 조건 및 운영 정책',
    updatedAt: '시행일자: 2026.06.15',
    sections: [
      TermsSection(
        title: '제1조 (목적)',
        paragraphs: [
          '이 약관은 마인드리움 팀이 제공하는 마인드리움 앱 베타테스트 서비스의 이용 조건, 이용자와 운영자의 권리와 의무, 책임 사항을 정합니다.',
        ],
      ),
      TermsSection(
        title: '제2조 (서비스의 성격)',
        paragraphs: [
          '마인드리움은 불안 관리 연습을 돕기 위한 8주 기반 CBT 교육, ABC 기록, SUD 점수 기록, 이완 훈련, 알림, 보관함, 리포트 기능을 제공합니다.',
          '본 서비스는 의료기관의 진단, 치료, 상담, 처방 또는 응급 지원을 대체하지 않습니다. 심각한 불안, 자해 위험, 응급 상황이 있으면 즉시 보호자, 의료기관 또는 지역 응급 서비스에 연락해야 합니다.',
        ],
      ),
      TermsSection(
        title: '제3조 (베타테스트 이용)',
        bullets: [
          '베타테스트 기간에는 기능, 화면, 알림, 데이터 구조가 변경될 수 있습니다.',
          '이용자는 마인드리움 코드 등 운영자가 정한 절차에 따라 가입하고, 본인의 정보를 정확하게 입력해야 합니다.',
          '베타테스트 참여자는 오류, 불편 사항, 개인정보 관련 요청을 베타테스트 안내 채널 또는 연구 담당자에게 알릴 수 있습니다.',
        ],
      ),
      TermsSection(
        title: '제4조 (이용자의 의무)',
        bullets: [
          '타인의 계정, 마인드리움 코드, 개인정보를 무단으로 사용하지 않습니다.',
          '타인의 권리 또는 서비스 운영을 침해하는 기록, 입력, 역공학, 비정상 접근을 하지 않습니다.',
          '앱에 기록하는 내용이 본인 또는 타인의 민감한 정보를 포함할 수 있음을 인지하고 신중하게 입력합니다.',
        ],
      ),
      TermsSection(
        title: '제5조 (계정과 탈퇴)',
        paragraphs: [
          '이용자는 앱의 계정 관리 화면에서 회원 탈퇴를 요청할 수 있습니다. 탈퇴 시 계정은 비활성화되고 로그인 정보는 더 이상 사용할 수 없으며, 운영 및 법령상 필요한 범위의 기록은 일정 기간 보관되거나 비식별 처리될 수 있습니다.',
        ],
      ),
      TermsSection(
        title: '제6조 (서비스 중단 및 책임 제한)',
        paragraphs: [
          '네트워크, 서버, 앱스토어, 기기 권한, 운영 점검, 천재지변 등으로 서비스가 일시 중단될 수 있습니다. 운영자는 고의 또는 중대한 과실이 없는 한 베타테스트 과정의 일시적 중단, 데이터 지연, 알림 누락에 대해 책임을 제한할 수 있습니다.',
        ],
      ),
      TermsSection(
        title: '제7조 (문의)',
        paragraphs: [
          '서비스 이용, 개인정보, 베타테스트 중단 요청은 베타테스트 안내문에 기재된 문의 채널 또는 연구 담당자를 통해 접수합니다.',
        ],
      ),
    ],
  );

  static const TermsDocument privacyPolicy = TermsDocument(
    key: 'privacy_policy',
    title: '개인정보 처리방침',
    subtitle: '개인정보 처리 기준과 이용자 권리',
    updatedAt: '시행일자: 2026.06.15',
    sections: [
      TermsSection(
        title: '1. 개인정보 처리자',
        paragraphs: [
          '마인드리움 팀은 베타테스트 운영, 계정 관리, 서비스 제공, 오류 대응을 위해 필요한 개인정보를 처리합니다. 개인정보 관련 문의는 베타테스트 안내 채널 또는 연구 담당자를 통해 접수합니다.',
        ],
      ),
      TermsSection(
        title: '2. 처리 목적',
        bullets: [
          '회원가입, 로그인, 본인 계정 식별, 마인드리움 코드 확인',
          '8주 CBT 프로그램, ABC 다이어리, SUD 점수, 이완 훈련, 보관함, 리포트 제공',
          '교육 알림, 오늘의 할 일 알림, 위치/시간 기반 알림 제공',
          '베타테스트 오류 확인, 보안 관리, 고객 문의 및 권리 요청 대응',
          '서비스 품질 개선을 위한 통계 확인 및 비식별 분석',
        ],
      ),
      TermsSection(
        title: '3. 처리 항목',
        table: TermsTable(
          headers: ['구분', '항목'],
          rows: [
            ['계정 정보', '이메일, 비밀번호 해시, 이름, 전화번호, 마인드리움 코드, 환자/참여자 식별값, 가입/수정 시각'],
            [
              '서비스 기록',
              '설문 응답, 주차 진행도, ABC 다이어리, 생각/감정/행동 칩, SUD 전후 점수, 대체 생각, 보관함 기록, 리포트 표시 정보',
            ],
            ['훈련 및 알림 기록', '이완 훈련 진행 기록, 과제 완료 여부, 알림 설정, 요일/시간, 위치 기반 알림 설정값'],
            [
              '위치/기기 권한 관련 정보',
              '이용자가 허용하거나 직접 선택한 위치, 주소, 좌표, 앱 권한 상태, 알림 수신 상태',
            ],
            ['운영 정보', '접속/요청 기록, 토큰 상태, 오류 확인에 필요한 기기 및 앱 환경 정보'],
          ],
        ),
      ),
      TermsSection(
        title: '4. 보유 및 이용 기간',
        bullets: [
          '회원 탈퇴 또는 베타테스트 종료 시까지 보관하는 것을 원칙으로 합니다.',
          '탈퇴 시 계정 식별정보는 비활성화 또는 대체 처리되며, 서비스 기록은 운영 검증, 분쟁 대응, 법령상 의무 이행에 필요한 범위에서 보관 후 파기 또는 비식별 처리될 수 있습니다.',
          '법령에 별도 보관 의무가 있는 경우 해당 기간 동안 보관합니다.',
        ],
      ),
      TermsSection(
        title: '5. 이용자의 권리',
        numbered: [
          '개인정보 열람, 정정, 삭제, 처리정지, 동의 철회를 요청할 수 있습니다.',
          '앱의 계정 관리 화면에서 회원 탈퇴를 요청할 수 있습니다.',
          '권리 요청은 베타테스트 안내 채널 또는 연구 담당자에게 접수할 수 있습니다.',
        ],
      ),
      TermsSection(
        title: '6. 보호 조치',
        bullets: [
          '비밀번호는 원문이 아닌 해시 형태로 저장합니다.',
          '인증 토큰을 이용해 사용자별 데이터 접근을 제한합니다.',
          '운영 데이터 접근 권한을 필요한 담당자로 제한합니다.',
          '민감한 기록은 베타테스트 목적에 필요한 범위에서만 처리합니다.',
        ],
      ),
      TermsSection(
        title: '7. 권한 안내',
        table: TermsTable(
          headers: ['권한', '사용 목적'],
          rows: [
            ['알림', '교육 알림, 오늘의 할 일 리마인더, 불안 완화 알림 제공'],
            ['위치', '위치/시간 기록, 지도 기반 위치 선택, 위치 기반 알림 제공'],
            ['마이크/음성 인식', '보관함 캐릭터 상호작용 등 음성 기반 기능 사용 시 입력 처리'],
            ['활동/모션', '위치 기반 알림의 안정성 및 이동 상태 확인 보조'],
          ],
        ),
      ),
    ],
  );

  static const TermsDocument personalInfoConsent = TermsDocument(
    key: 'personal_info',
    title: '개인정보 수집 및 이용 동의',
    subtitle: '수집 항목, 목적, 보유 기간 안내',
    updatedAt: '시행일자: 2026.06.15',
    sections: [
      TermsSection(
        title: '1. 수집 및 이용 목적',
        bullets: [
          '회원가입, 로그인, 마인드리움 코드 확인, 참여자 관리',
          '앱 기능 제공, 진행도 저장, 알림 및 리포트 제공',
          '문의 대응, 오류 확인, 서비스 안정성 개선',
        ],
      ),
      TermsSection(
        title: '2. 수집 항목',
        table: TermsTable(
          headers: ['구분', '수집 항목', '보유 기간'],
          rows: [
            [
              '필수 계정 정보',
              '이메일, 비밀번호, 이름, 전화번호, 마인드리움 코드',
              '회원 탈퇴 또는 베타테스트 종료 시까지',
            ],
            [
              '서비스 이용 정보',
              '주차 진행도, 과제 완료 여부, 알림 설정, 앱 이용 기록',
              '회원 탈퇴 또는 베타테스트 종료 시까지',
            ],
            [
              '위치/알림 설정 정보',
              '이용자가 직접 입력하거나 권한 허용 후 선택한 위치, 주소, 좌표, 요일/시간 설정',
              '기능 해제, 삭제, 탈퇴 또는 베타테스트 종료 시까지',
            ],
          ],
        ),
      ),
      TermsSection(
        title: '3. 동의 거부 권리 및 불이익',
        paragraphs: [
          '이용자는 개인정보 수집 및 이용에 동의하지 않을 수 있습니다. 다만 필수 개인정보 처리에 동의하지 않으면 회원가입, 로그인, 프로그램 진행 저장 등 핵심 기능을 이용할 수 없습니다.',
        ],
      ),
    ],
  );

  static const TermsDocument sensitiveInfoConsent = TermsDocument(
    key: 'sensitive_info',
    title: '민감정보 수집 및 이용 동의',
    subtitle: '민감정보 처리 목적 및 보호 조치',
    updatedAt: '시행일자: 2026.06.15',
    sections: [
      TermsSection(
        title: '1. 민감정보 처리 목적',
        paragraphs: [
          '마인드리움은 불안 관리 프로그램 제공을 위해 이용자가 직접 입력하거나 프로그램 진행 중 생성되는 정신건강 관련 자기기록을 처리할 수 있습니다.',
        ],
      ),
      TermsSection(
        title: '2. 처리 항목',
        table: TermsTable(
          headers: ['항목', '이용 목적', '보유 기간'],
          rows: [
            [
              '불안 정도 점수, 사전/사후 설문 응답',
              '불안 수준 확인, 리포트 제공, 프로그램 흐름 조정',
              '회원 탈퇴 또는 베타테스트 종료 시까지',
            ],
            [
              'ABC 다이어리, 생각/감정/신체반응/행동 기록, 대체 생각',
              'CBT 연습, 보관함, 회고 및 리포트 제공',
              '회원 탈퇴 또는 베타테스트 종료 시까지',
            ],
            [
              '이완 훈련 로그, 위치/시간 맥락 정보',
              '훈련 이력 저장, 위치/시간 기반 리마인더, 진행도 확인',
              '기능 해제, 삭제, 탈퇴 또는 베타테스트 종료 시까지',
            ],
          ],
        ),
      ),
      TermsSection(
        title: '3. 동의 거부 권리 및 불이익',
        paragraphs: [
          '이용자는 민감정보 수집 및 이용에 동의하지 않을 수 있습니다. 다만 마인드리움의 핵심 기능은 불안 점수, 다이어리, 훈련 기록을 기반으로 하므로 동의하지 않으면 회원가입 또는 주요 기능 이용이 제한될 수 있습니다.',
        ],
      ),
      TermsSection(
        title: '4. 보호 원칙',
        bullets: [
          '민감정보는 베타테스트 및 서비스 제공에 필요한 범위에서만 처리합니다.',
          '운영 담당자의 접근 권한을 제한하고, 외부 공개 시 개인을 식별할 수 없도록 비식별 또는 통계 형태로 처리합니다.',
        ],
      ),
    ],
  );

  static const TermsDocument thirdPartyConsent = TermsDocument(
    key: 'third_party',
    title: '개인정보 및 민감정보 제3자 제공 동의',
    subtitle: '제공받는 자, 목적, 제공 항목 안내',
    updatedAt: '시행일자: 2026.06.15',
    sections: [
      TermsSection(
        title: '1. 제3자 제공',
        table: TermsTable(
          headers: ['제공받는 자', '제공 목적', '제공 항목', '보유 및 이용 기간'],
          rows: [
            [
              '카카오',
              '지도 표시, 주소 검색, 좌표 기반 주소 변환',
              '검색어, 선택 위치의 좌표, 주소 조회 요청 정보',
              '제공받는 자의 정책에 따름',
            ],
            [
              'Google Play, Apple App Store/TestFlight',
              '베타 앱 배포, 설치, 피드백 접수, 테스트 참여 관리',
              '스토어 계정, 기기/설치 정보, 테스터 피드백',
              '각 플랫폼 정책에 따름',
            ],
          ],
        ),
      ),
      TermsSection(
        title: '2. 처리위탁 및 인프라 이용',
        paragraphs: [
          '서비스 운영을 위해 클라우드 서버, 데이터베이스, 앱 배포 플랫폼 등 외부 인프라를 사용할 수 있습니다. 이 경우 운영자는 필요한 범위에서만 데이터를 처리하도록 관리합니다.',
        ],
        table: TermsTable(
          headers: ['수탁자/인프라', '위탁 업무', '처리 항목'],
          rows: [
            [
              '클라우드 서버 및 데이터베이스 제공사',
              'API 서버 운영, 데이터 저장, 백업, 장애 대응',
              '계정 정보, 서비스 기록, 민감정보 기록',
            ],
            ['앱 배포 플랫폼', '베타 앱 배포 및 설치 관리', '테스터 계정, 설치/기기 정보, 피드백'],
          ],
        ),
      ),
      TermsSection(
        title: '3. 동의 거부 권리 및 불이익',
        paragraphs: [
          '이용자는 제3자 제공에 동의하지 않을 수 있습니다. 다만 지도/주소 기능, 베타 앱 배포, 피드백 접수 등 외부 플랫폼이 필요한 기능의 이용이 제한될 수 있습니다.',
        ],
      ),
      TermsSection(
        title: '4. 변경 고지',
        paragraphs: [
          '제공받는 자, 제공 항목, 제공 목적이 변경되는 경우 앱 또는 베타테스트 안내 채널을 통해 사전에 고지하고 필요한 경우 다시 동의를 받습니다.',
        ],
      ),
    ],
  );
}
