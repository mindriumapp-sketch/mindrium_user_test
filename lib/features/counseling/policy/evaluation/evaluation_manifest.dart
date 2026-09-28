/// Phase 9.2C: provenance for one real evaluation run against
/// `frozenScenarios`. This is metadata ABOUT a run (which dataset version,
/// which model/prompt, which sampling config produced the raw
/// `List<ScenarioResult>`) — it is never computed from the results
/// themselves, and it carries no scenario content or user data.
///
/// Recording this alongside every run is what makes "activation criteria
/// met" a falsifiable, reproducible claim instead of an anecdote: without
/// it, a later re-run against a changed prompt/model/dataset could silently
/// be compared against an old baseline as if nothing changed.
class EvaluationManifest {
  /// Must match `frozenScenariosVersion` (or a later frozen set's version)
  /// at the time this run was executed.
  final String datasetVersion;

  final int scenarioCount;

  /// From `ScenarioResult.modelIdentifier` / the backend's `/counseling/decide`
  /// response — recorded here once for the whole run rather than trusting
  /// every individual result to agree (a mismatch there is itself a signal
  /// worth surfacing, not something this manifest resolves for you).
  final String modelIdentifier;

  final String promptVersion;

  /// E.g. `{"temperature": 0.0}` — whatever sampling parameters the backend
  /// used for this run. Free-form because the set of relevant parameters is
  /// backend/model-specific.
  final Map<String, Object?> sampling;

  /// Free-form identifier for the evaluation code itself (a git commit hash
  /// is ideal; a package/build version is acceptable if that's unavailable).
  final String runnerVersion;

  final String runId;
  final DateTime timestamp;

  const EvaluationManifest({
    required this.datasetVersion,
    required this.scenarioCount,
    required this.modelIdentifier,
    required this.promptVersion,
    required this.sampling,
    required this.runnerVersion,
    required this.runId,
    required this.timestamp,
  });

  Map<String, Object?> toJson() => {
    'dataset_version': datasetVersion,
    'scenario_count': scenarioCount,
    'model_identifier': modelIdentifier,
    'prompt_version': promptVersion,
    'sampling': sampling,
    'runner_version': runnerVersion,
    'run_id': runId,
    'timestamp': timestamp.toIso8601String(),
  };

  factory EvaluationManifest.fromJson(Map<String, Object?> json) {
    return EvaluationManifest(
      datasetVersion: json['dataset_version'] as String,
      scenarioCount: json['scenario_count'] as int,
      modelIdentifier: json['model_identifier'] as String,
      promptVersion: json['prompt_version'] as String,
      sampling: Map<String, Object?>.from(json['sampling'] as Map),
      runnerVersion: json['runner_version'] as String,
      runId: json['run_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
