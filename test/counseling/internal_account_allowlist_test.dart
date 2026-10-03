// Phase 10.6C: the email-allowlist check used to gate Stage 1 rollout.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/features/counseling/policy/rollout/internal_account_allowlist.dart';

void main() {
  // Any new address here sends that user's text to OpenAI; add deliberately.
  test('default allowlist: the dogfood account and the synthetic demo account only', () {
    expect(internalAccountEmailAllowlist, {'sehyun712@skku.edu', 'mindrium.demo@example.com'});
  });

  test('null/empty email is never internal', () {
    expect(isInternalAccountEmail(null), isFalse);
    expect(isInternalAccountEmail(''), isFalse);
    expect(isInternalAccountEmail('   '), isFalse);
  });

  test('an address on the allowlist matches, case-insensitively', () {
    const allowlist = {'dev@example.com'};
    expect(
      isInternalAccountEmail('dev@example.com', allowlist: allowlist),
      isTrue,
    );
    expect(
      isInternalAccountEmail('DEV@Example.com', allowlist: allowlist),
      isTrue,
    );
    expect(
      isInternalAccountEmail('  dev@example.com  ', allowlist: allowlist),
      isTrue,
    );
  });

  test('an address not on the allowlist is rejected', () {
    const allowlist = {'dev@example.com'};
    expect(
      isInternalAccountEmail('someone-else@example.com', allowlist: allowlist),
      isFalse,
    );
  });

  test('with the real default allowlist, unregistered real-looking emails are rejected', () {
    for (final email in ['a@b.com', 'user@mindrium.com', 'test@test.com']) {
      expect(isInternalAccountEmail(email), isFalse, reason: email);
    }
  });

  test('with the real default allowlist, the registered dogfood account is accepted', () {
    expect(isInternalAccountEmail('sehyun712@skku.edu'), isTrue);
    expect(isInternalAccountEmail('SEHYUN712@SKKU.EDU'), isTrue);
  });
}
