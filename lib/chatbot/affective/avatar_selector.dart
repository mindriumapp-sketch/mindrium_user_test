import 'affect_signal.dart';
import 'avatar_asset_resolver.dart';

/// 표정이 실제로 바뀔 때만 이미지를 교체한다.
///
/// resolver 는 순수 함수라 같은 표정이면 항상 같은 이미지를 주지만, variant 를
/// 쓰기 시작하면 매 턴 이미지가 바뀌어 표정이 들썩이는 느낌이 난다.
/// 그래서 "언제 바꿀지"는 여기서 상태로 들고 있는다.
///
///   attentive → attentive → attentive   같은 이미지 유지
///   attentive → concerned               이미지 교체
class AvatarSelector {
  final AvatarAssetResolver resolver;

  AvatarExpression? _expression;
  int _variantIndex = 0;
  late String _asset = resolver.defaultAsset;

  AvatarSelector({this.resolver = const AvatarAssetResolver()});

  AvatarExpression? get expression => _expression;

  String get asset => _asset;

  /// 표정을 반영하고 화면에 쓸 이미지를 돌려준다.
  String update(AvatarExpression expression) {
    if (_expression == expression) return _asset;

    // 표정이 바뀔 때만 다음 변형으로 넘어간다.
    if (_expression != null) _variantIndex++;
    _expression = expression;
    _asset = resolver.resolve(expression, variantIndex: _variantIndex);
    return _asset;
  }

  /// 세션을 다시 시작할 때 초기 상태로 되돌린다.
  void reset() {
    _expression = null;
    _variantIndex = 0;
    _asset = resolver.defaultAsset;
  }
}
