import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';

class ApplyFlowPromptContent extends StatelessWidget {
  const ApplyFlowPromptContent({
    super.key,
    this.message,
    this.imageAsset = 'assets/image/pink3.png',
    this.showIllustration = true,
    this.imageHeight = 180,
    this.topSpacing = 4,
    this.messageTopSpacing = 8,
  });

  final String? message;
  final String imageAsset;
  final bool showIllustration;
  final double imageHeight;
  final double topSpacing;
  final double messageTopSpacing;

  static const TextStyle _messageStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w300,
    color: Color(0xFF626262),
    height: 1.8,
    wordSpacing: 1.1,
    fontFamily: 'Noto Sans KR',
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIllustration) ...[
          SizedBox(height: topSpacing),
          Image.asset(
            imageAsset,
            height: math.min(
              imageHeight,
              MediaQuery.of(context).size.width * 0.38,
            ),
            fit: BoxFit.contain,
          ),
        ],
        if (message != null) ...[
          SizedBox(height: showIllustration ? messageTopSpacing : 0),
          Text(
            protectKoreanWords(message!),
            textAlign: TextAlign.center,
            style: _messageStyle,
          ),
        ],
      ],
    );
  }
}
