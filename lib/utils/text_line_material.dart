import 'package:gad_app_team/utils/text_line.dart';

export 'package:flutter/material.dart' hide Text;
export 'package:gad_app_team/utils/text_line.dart';

/// Alias so existing `Text` usages go through [TextLine].
typedef Text = TextLine;
