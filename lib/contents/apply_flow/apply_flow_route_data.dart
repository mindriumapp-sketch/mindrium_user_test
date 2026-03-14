import 'package:flutter/widgets.dart';
import 'package:gad_app_team/data/apply_solve_provider.dart';
import 'package:provider/provider.dart';

Map<String, dynamic> castApplyFlowArgs(Object? rawArgs) {
  if (rawArgs is Map<String, dynamic>) {
    return Map<String, dynamic>.from(rawArgs);
  }
  if (rawArgs is Map) {
    return rawArgs.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

String? applyFlowString(dynamic raw) {
  final value = raw?.toString().trim() ?? '';
  return value.isEmpty ? null : value;
}

int? applyFlowInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  if (raw is String) return int.tryParse(raw.trim());
  return null;
}

class ApplyFlowRouteData {
  ApplyFlowRouteData._({required this.args, required this.flow});

  final Map<String, dynamic> args;
  final ApplyOrSolveFlow flow;

  factory ApplyFlowRouteData.read(
    BuildContext context, {
    Object? rawArgs,
    bool override = false,
    bool notify = false,
  }) {
    final args = castApplyFlowArgs(rawArgs);
    final flow =
        context.read<ApplyOrSolveFlow>()
          ..syncFromArgs(args, override: override, notify: notify);
    return ApplyFlowRouteData._(args: args, flow: flow);
  }

  String get origin => flow.origin;

  String? get abcId =>
      flow.diaryId ??
      applyFlowString(args['abcId']) ??
      applyFlowString(args['diaryId']) ??
      applyFlowString(args['taskId']);

  String? get groupId => flow.groupId ?? applyFlowString(args['groupId']);

  int? get beforeSud => flow.beforeSud ?? applyFlowInt(args['beforeSud']);

  String? get sudId => flow.sudId ?? applyFlowString(args['sudId']);

  String? get diaryRoute =>
      flow.diaryRoute ?? applyFlowString(args['diaryRoute']);

  String? get sessionId => flow.sessionId ?? applyFlowString(args['sessionId']);

  dynamic get diary => args.containsKey('diary') ? args['diary'] : flow.diary;

  String? get taskId => abcId ?? groupId;

  bool get hasAbcId => abcId?.isNotEmpty ?? false;

  Map<String, dynamic> mergedArgs({
    Map<String, dynamic> extra = const {},
    bool includeCurrentArgs = false,
    bool includeDiary = false,
  }) {
    final merged = <String, dynamic>{
      if (includeCurrentArgs) ...args,
      ...flow.toArgs(),
      if (includeDiary && diary != null) 'diary': diary,
    };
    merged.addAll(extra);
    return merged;
  }
}
