import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/chatbot/affective/avatar_asset_resolver.dart';

void main() {
  test('every avatar image is a file in assets/npc_images/', () {
    for (final path in [
      for (final v in AvatarAssetResolver.variants.values) ...v,
      ...AvatarAssetResolver.unusedAssets,
    ]) {
      expect(path, startsWith('assets/npc_images/'));
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });
}
