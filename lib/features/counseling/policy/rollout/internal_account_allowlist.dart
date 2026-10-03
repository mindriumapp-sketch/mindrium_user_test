/// Phase 10.6C: internal/dev-account identification for Stage 1 rollout.
///
/// This project has no `role`/`is_staff`/`is_admin` field anywhere (Flutter
/// `UserProvider` and the backend's `UserMe`/auth schemas only carry
/// `email`, `name`, `user_id`, `patient_id` — verified before writing this
/// file, not assumed). So Stage 1 eligibility is a plain email allowlist,
/// checked against the already-available `UserProvider.userEmail`.
///
/// **The allowlist below is empty by default — nobody is internal until an
/// operator adds a real address here.** An empty allowlist plus
/// `RolloutStage.internalOnly` means every session falls through to
/// `not_internal_account` and stays fully deterministic, so leaving this
/// file untouched is exactly as safe as Phase 10.6B's baseline.
library;

/// Add real internal/dev email addresses here before Stage 1 dogfooding
/// begins. Comparison is case-insensitive (emails are normalized to lower
/// case on both sides) and does not touch how the address is validated,
/// authenticated, or stored anywhere else in the app.
const Set<String> internalAccountEmailAllowlist = {
  'sehyun712@skku.edu',
  // synthetic demo account (backend/scripts/seed_demo_account.py)
  'mindrium.demo@example.com',
};

/// `null`/empty `email` is never internal — fails closed.
bool isInternalAccountEmail(
  String? email, {
  Set<String> allowlist = internalAccountEmailAllowlist,
}) {
  if (email == null || email.trim().isEmpty) return false;
  final normalized = email.trim().toLowerCase();
  return allowlist.any((entry) => entry.toLowerCase() == normalized);
}
