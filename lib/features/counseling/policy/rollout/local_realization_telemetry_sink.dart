/// Phase 10.6C: local-only telemetry sink for Stage 1 (internalOnly)
/// dogfooding. Per the frozen spec's "no raw content in general telemetry"
/// rule — already enforced by `RealizationTelemetryEvent.toLogEntry()`
/// itself carrying no text fields — this just needs a destination.
///
/// This project has no analytics/logging backend today (verified: no
/// Firebase Analytics/Sentry/Mixpanel dependency, no `/telemetry` backend
/// route). Building one is explicitly out of scope for Stage 1 — internal
/// dogfooders can read these from the device's own debug console
/// (`flutter logs`, Xcode/Android Studio console, or DevTools' Logging
/// view) while the app is running on their device. A real destination
/// (a backend endpoint, a local analytics SDK) is future work once Stage 1
/// dogfooding itself is judged safe enough to justify building one.
library;

import 'dart:convert';
import 'dart:developer' as developer;

import 'realization_telemetry.dart';

const String realizationTelemetryLogName = 'counseling.realization';

/// Structured local log via `dart:developer.log` (visible in
/// `flutter logs`/IDE consoles/DevTools — unlike `print`, it isn't
/// line-truncated and carries a `name` for filtering). Never call this
/// with anything other than a [RealizationTelemetryEvent] — that type is
/// what guarantees no raw conversation content reaches here in the first
/// place.
void logRealizationTelemetryLocally(RealizationTelemetryEvent event) {
  developer.log(
    jsonEncode(event.toLogEntry()),
    name: realizationTelemetryLogName,
  );
}
