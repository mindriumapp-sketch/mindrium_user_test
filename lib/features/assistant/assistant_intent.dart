import 'retrieval/app_guide_knowledge_retriever.dart';
import 'retrieval/counseling_knowledge_retriever.dart';
import 'retrieval/user_context_retriever.dart';

/// 사용자 발화가 어떤 도메인에 속하는지. Phase 7(Intent Router)에서 실제로
/// 채워진다. 지금은 계약만 존재하고, [MindRiumAssistantHarness]는 항상
/// [counseling] 하나만 다룬다.
enum AssistantDomain {
  /// CBT 상담 (현재 유일하게 동작하는 경로).
  counseling,

  /// MindRium 앱 사용법 안내(화면 위치, 기능 설명 등).
  appGuide,

  /// 상담과 앱 안내가 함께 필요한 발화.
  mixed,
}

/// 이번 발화에 어떤 도메인 처리가 필요한지 나타낸다.
///
/// Phase 7(Intent Router) 이전까지는 이 값을 만드는 라우터가 없다 —
/// [MindRiumAssistantHarness]가 상담 하나만 처리하는 동안은 실질적으로
/// 쓰이지 않는 껍데기 계약이다.
class AssistantIntent {
  final bool needsCounseling;
  final bool needsAppGuidance;

  const AssistantIntent({
    required this.needsCounseling,
    required this.needsAppGuidance,
  });

  /// 현재 유일한 production 경로: 항상 상담만 필요하다고 본다.
  static const AssistantIntent counselingOnly = AssistantIntent(
    needsCounseling: true,
    needsAppGuidance: false,
  );

  AssistantDomain get domain {
    if (needsCounseling && needsAppGuidance) return AssistantDomain.mixed;
    if (needsAppGuidance) return AssistantDomain.appGuide;
    return AssistantDomain.counseling;
  }

  bool get isAppGuideOnly => needsAppGuidance && !needsCounseling;
  bool get isCounselingOnly => needsCounseling && !needsAppGuidance;
  bool get isMixed => needsCounseling && needsAppGuidance;
}

/// [MindRiumAssistantHarness]가 세 retrieval 경계(Phase 4)의 결과를 모아
/// 담는 상위 container. 지금은 상담 경로만 실제로 소비하고
/// (`CounselingHarness`는 이 타입을 모른다 — 내부에서 동일한 정보를 직접
/// 다시 조회한다), `userContext`/`counselingKnowledge`/`appGuideKnowledge`는
/// 향후 Agent가 쓸 수 있도록 미리 모아 두는 것이 이번 phase의 목적이다.
class AssistantContext {
  final String userMessage;
  final AssistantIntent intent;
  final UserContextResult? userContext;
  final CounselingKnowledgeResult? counselingKnowledge;
  final AppGuideKnowledgeResult? appGuideKnowledge;

  const AssistantContext({
    required this.userMessage,
    this.intent = AssistantIntent.counselingOnly,
    this.userContext,
    this.counselingKnowledge,
    this.appGuideKnowledge,
  });
}
