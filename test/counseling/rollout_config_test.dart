// Phase 10.6B: pure unit tests for the rollout decision function and
// stable cohort bucketing — no CounselingHarness involved here, see
// canary_rollout_integration_test.dart for the orchestration-level tests.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/features/counseling/policy/rollout/rollout_config.dart';

void main() {
  group('RolloutConfig defaults', () {
    test('default constructor is fully off', () {
      const config = RolloutConfig();
      expect(config.enabled, isFalse);
      expect(config.stage, RolloutStage.off);
      expect(config.rolloutPercentage, 0);
      expect(config.killSwitch, isFalse);
    });
  });

  group('evaluateRollout — precedence and gating', () {
    test('router disallowing wins over everything else', () {
      final decision = evaluateRollout(
        config: const RolloutConfig(
          enabled: true,
          stage: RolloutStage.pilot,
          rolloutPercentage: 100,
        ),
        routerAllowsLlm: false,
        cohortKey: 'session-1',
        isInternalAccount: true,
      );
      expect(decision.attemptRemote, isFalse);
      expect(decision.reason, 'router_disallowed');
    });

    test('kill switch overrides an otherwise-100%-pilot config', () {
      final decision = evaluateRollout(
        config: const RolloutConfig(
          enabled: true,
          stage: RolloutStage.pilot,
          rolloutPercentage: 100,
          killSwitch: true,
        ),
        routerAllowsLlm: true,
        cohortKey: 'session-1',
        isInternalAccount: true,
      );
      expect(decision.attemptRemote, isFalse);
      expect(decision.reason, 'kill_switch');
    });

    test('enabled:false blocks even with stage set', () {
      final decision = evaluateRollout(
        config: const RolloutConfig(
          enabled: false,
          stage: RolloutStage.pilot,
          rolloutPercentage: 100,
        ),
        routerAllowsLlm: true,
        cohortKey: 'session-1',
        isInternalAccount: true,
      );
      expect(decision.attemptRemote, isFalse);
      expect(decision.reason, 'rollout_disabled');
    });

    test('stage:off blocks even when enabled', () {
      final decision = evaluateRollout(
        config: const RolloutConfig(enabled: true, stage: RolloutStage.off),
        routerAllowsLlm: true,
        cohortKey: 'session-1',
        isInternalAccount: true,
      );
      expect(decision.attemptRemote, isFalse);
      expect(decision.reason, 'stage_off');
    });

    test('internalOnly: non-internal account is blocked', () {
      final decision = evaluateRollout(
        config: const RolloutConfig(
          enabled: true,
          stage: RolloutStage.internalOnly,
        ),
        routerAllowsLlm: true,
        cohortKey: 'session-1',
        isInternalAccount: false,
      );
      expect(decision.attemptRemote, isFalse);
      expect(decision.reason, 'not_internal_account');
    });

    test('internalOnly: internal account is allowed', () {
      final decision = evaluateRollout(
        config: const RolloutConfig(
          enabled: true,
          stage: RolloutStage.internalOnly,
        ),
        routerAllowsLlm: true,
        cohortKey: 'session-1',
        isInternalAccount: true,
      );
      expect(decision.attemptRemote, isTrue);
      expect(decision.reason, 'internal_account');
    });

    test('pilot: a key outside the percentage bucket is blocked', () {
      // Find a key whose bucket is >= 5 to prove the boundary is real,
      // not just always-true.
      String key = 'probe';
      var i = 0;
      while (stableBucket(key) < 5 && i < 1000) {
        key = 'probe-$i';
        i++;
      }
      final decision = evaluateRollout(
        config: const RolloutConfig(
          enabled: true,
          stage: RolloutStage.pilot,
          rolloutPercentage: 5,
        ),
        routerAllowsLlm: true,
        cohortKey: key,
        isInternalAccount: false,
      );
      expect(decision.attemptRemote, isFalse);
      expect(decision.reason, 'outside_pilot_cohort');
    });

    test('pilot: rolloutPercentage:100 always includes every key', () {
      for (final key in ['a', 'b', 'session-xyz', 'zzzz']) {
        final decision = evaluateRollout(
          config: const RolloutConfig(
            enabled: true,
            stage: RolloutStage.pilot,
            rolloutPercentage: 100,
          ),
          routerAllowsLlm: true,
          cohortKey: key,
          isInternalAccount: false,
        );
        expect(decision.attemptRemote, isTrue, reason: 'key=$key');
        expect(decision.reason, 'pilot_cohort');
      }
    });

    test('pilot: rolloutPercentage:0 always excludes every key', () {
      for (final key in ['a', 'b', 'session-xyz', 'zzzz']) {
        final decision = evaluateRollout(
          config: const RolloutConfig(
            enabled: true,
            stage: RolloutStage.pilot,
            rolloutPercentage: 0,
          ),
          routerAllowsLlm: true,
          cohortKey: key,
          isInternalAccount: false,
        );
        expect(decision.attemptRemote, isFalse, reason: 'key=$key');
      }
    });
  });

  group('stableBucket', () {
    test('same key always yields the same bucket', () {
      const key = 'session-abc-123';
      final first = stableBucket(key);
      for (var i = 0; i < 20; i++) {
        expect(stableBucket(key), first);
      }
    });

    test('bucket is always in [0, 99]', () {
      for (final key in ['', 'a', 'session-1', '한글세션아이디', 'x' * 200]) {
        final bucket = stableBucket(key);
        expect(bucket, greaterThanOrEqualTo(0));
        expect(bucket, lessThanOrEqualTo(99));
      }
    });

    test('rollout percentage monotonicity: a key included at 5% stays included at 10% and 25%', () {
      // Generate a spread of keys and confirm the "5% subset ⊆ 10% subset
      // ⊆ 25% subset" property holds for all of them, per the frozen
      // spec's requirement that raising the percentage never evicts an
      // already-included session.
      final keys = List.generate(500, (i) => 'session-$i');
      final in5 = keys.where((k) => stableBucket(k) < 5).toSet();
      final in10 = keys.where((k) => stableBucket(k) < 10).toSet();
      final in25 = keys.where((k) => stableBucket(k) < 25).toSet();

      expect(in5.difference(in10), isEmpty, reason: '5% subset must be ⊆ 10% subset');
      expect(in10.difference(in25), isEmpty, reason: '10% subset must be ⊆ 25% subset');
      // Sanity: with 500 samples the buckets should roughly spread out,
      // not degenerately collapse to one value.
      expect(in5, isNotEmpty);
      expect(in10.length, greaterThan(in5.length));
      expect(in25.length, greaterThan(in10.length));
    });
  });
}
