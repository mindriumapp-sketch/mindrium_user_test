import 'affect_signal.dart';

/// 의미 상태(AvatarExpression) 를 실제 이미지 경로로 옮긴다.
///
/// 9개 이미지를 9개 감정 라벨로 만들지 않는다. 그렇게 하면 "profile7 이 무슨 감정인지"
/// 같은 asset 별 지식이 도메인 코드에 퍼진다. 의미는 5개, 이미지는 표현 변형일 뿐이다.
class AvatarAssetResolver {
  static const String _dir = 'assets/npc_images';

  /// 표정별 변형. 첫 번째가 기본이다.
  // Only files that exist in assets/npc_images/ (checked by test).
  // warm doubles as the empathic face, so it uses the soft smile (reassure);
  // the broad closed-eye smile reads as cheerful and is kept for encouraging.
  static const Map<AvatarExpression, List<String>> variants = {
    AvatarExpression.neutral: ['$_dir/counselor_profile_neutral.png'],
    AvatarExpression.warm: ['$_dir/counselor_profile_reassure.png'],
    AvatarExpression.attentive: ['$_dir/counselor_profile_thinking.png'],
    AvatarExpression.concerned: ['$_dir/counselor_profile_sad.png'],
    AvatarExpression.encouraging: ['$_dir/counselor_profile_warm_smile.png'],
  };

  /// In the folder but not used as a counselor attitude: an open-mouth grin,
  /// a sweat-drop (reads as the counselor being anxious), surprise.
  static const List<String> unusedAssets = [
    '$_dir/counselor_profile.png',
    '$_dir/counselor_profile_careful.png',
    '$_dir/counselor_profile_surprised.png',
  ];

  const AvatarAssetResolver();

  /// 표정에 해당하는 이미지 경로.
  ///
  /// [variantIndex] 를 주면 같은 표정 안에서 변형을 고를 수 있다. 무작위로 고르지
  /// 않는다. 같은 입력에 같은 화면이 나와야 테스트와 재현이 가능하다.
  String resolve(AvatarExpression expression, {int variantIndex = 0}) {
    final options = variants[expression]!;
    return options[variantIndex % options.length];
  }

  /// 앱 시작 시 쓰는 기본 이미지.
  String get defaultAsset => resolve(AvatarExpression.neutral);
}
