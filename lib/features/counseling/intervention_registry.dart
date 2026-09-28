import 'package:gad_app_team/data/counseling/counseling_models.dart';

enum InterventionType {
  balancedThought,
  behaviorPatternReview,
  consequenceReview,
  gainLossReview,
  valueBasedChoice,
  maintenanceReview,
}

/// 임상 검수된 CBT 항목과 허용 개입을 연결하는 단일 승인 정책.
class ApprovedInterventionPolicy {
  final int week;
  final InterventionType interventionType;
  final String requiredId;
  final String requiredType;
  final Set<String> requiredTags;
  final bool requiresGuidance;

  const ApprovedInterventionPolicy({
    required this.week,
    required this.interventionType,
    required this.requiredId,
    required this.requiredType,
    required this.requiredTags,
    this.requiresGuidance = true,
  });

  bool accepts(CbtKnowledgeItem item) {
    return item.id == requiredId &&
        item.week == week &&
        item.type == requiredType &&
        item.tags.toSet().containsAll(requiredTags) &&
        (!requiresGuidance || item.conversationalGuidanceAvailable);
  }
}

/// Planner 코드 밖에서 관리하는 승인된 intervention allow-list.
class ApprovedInterventionRegistry {
  static const List<ApprovedInterventionPolicy> defaults = [
    ApprovedInterventionPolicy(
      week: 4,
      interventionType: InterventionType.balancedThought,
      requiredId: 'week4_alternative_thought_01',
      requiredType: 'technique',
      requiredTags: {'alternative_thought', 'cognitive_restructuring'},
    ),
    ApprovedInterventionPolicy(
      week: 5,
      interventionType: InterventionType.behaviorPatternReview,
      requiredId: 'week5_confront_avoid_01',
      requiredType: 'education',
      requiredTags: {'behavior', 'avoidance', 'confrontation'},
    ),
    ApprovedInterventionPolicy(
      week: 6,
      interventionType: InterventionType.consequenceReview,
      requiredId: 'week6_short_long_term_01',
      requiredType: 'technique',
      requiredTags: {
        'behavior',
        'avoidance',
        'confrontation',
        'self_monitoring',
      },
    ),
    ApprovedInterventionPolicy(
      week: 7,
      interventionType: InterventionType.gainLossReview,
      requiredId: 'week7_gain_lose_01',
      requiredType: 'technique',
      requiredTags: {'habit', 'behavior', 'avoidance', 'planning'},
    ),
    ApprovedInterventionPolicy(
      week: 8,
      interventionType: InterventionType.maintenanceReview,
      requiredId: 'week8_maintenance_01',
      requiredType: 'technique',
      requiredTags: {'maintenance', 'relapse_prevention', 'habit', 'values'},
    ),
  ];

  final List<ApprovedInterventionPolicy> policies;

  const ApprovedInterventionRegistry({this.policies = defaults});

  ApprovedInterventionPolicy? policyForWeek(int week) {
    for (final policy in policies) {
      if (policy.week == week) return policy;
    }
    return null;
  }
}
