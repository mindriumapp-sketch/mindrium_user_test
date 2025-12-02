import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';

/// 🪸 Mindrium “메모지 화면” (리뉴얼)
/// - 배경: eduhome.png
/// - 중앙: memo.png (화면 대부분 차지)
/// - child 안에서 이미지+텍스트 조합 가능
/// - 강조 텍스트는 HighlightText 위젯 사용
class MemoFullDesign extends StatelessWidget {
  final String appBarTitle;
  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final String rightLabel;
  final EdgeInsetsGeometry contentPadding;
  final double? memoHeight;
  final int appBarTitleMaxLines;
  final TextAlign appBarTitleAlign;

  const MemoFullDesign({
    super.key,
    required this.appBarTitle,
    required this.child,
    required this.onBack,
    required this.onNext,
    this.rightLabel = '다음',
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 32,
    ),
    this.memoHeight,
    this.appBarTitleMaxLines = 2,
    this.appBarTitleAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final memoHeights = MediaQuery.of(context).size.height * 0.67;
    final check = (memoHeight != null) ? true : false;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: appBarTitle,
        maxTitleLines: appBarTitleMaxLines,
        titleAlign: appBarTitleAlign,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          /// 🌊 배경
          Positioned.fill(
            child: Opacity(
              opacity: 0.35,
              child: Image.asset(
                'assets/image/eduhome.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // 👆 위쪽: 중앙에 메모장
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 34,
                        vertical: 24,
                      ),
                      child: Container(
                        height: check ? memoHeight : memoHeights,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          image: const DecorationImage(
                            image: AssetImage('assets/image/memo.png'),
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: contentPadding,
                          child: SingleChildScrollView(child: child),
                        ),
                      ),
                    ),
                  ),
                ),

                // 👇 아래: 항상 바닥에 붙어 있는 네비게이션
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: NavigationButtons(
                    onBack: onBack,
                    onNext: onNext,
                    rightLabel: rightLabel,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 🖼️ 이미지 + 텍스트 조합용 위젯
class MemoImageWithText extends StatelessWidget {
  final String imagePath;
  final Widget text;

  const MemoImageWithText({
    super.key,
    required this.imagePath,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// 🖼️ 이미지
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(imagePath, fit: BoxFit.cover),
        ),
        const SizedBox(height: 16),

        /// 구분선
        Container(
          height: 1,
          width: double.infinity,
          color: Colors.black.withValues(alpha: 0.1),
          margin: const EdgeInsets.symmetric(vertical: 12),
        ),

        /// 텍스트
        text,
      ],
    );
  }
}

/// 번호가 붙은 문장들을 촘촘히 보여주는 위젯
class NumberedTextList extends StatelessWidget {
  final List<String> items;

  const NumberedTextList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(items.length, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3), // ✅ 항목 간격 살짝 조정
          child: Text(
            '${index + 1}. ${items[index]}',
            style: const TextStyle(
              fontSize: 14, // ✅ 글자 크기 +1
              height: 1.4, // ✅ 줄 간격 약간 늘림
              color: Colors.black87,
              fontFamily: 'Noto Sans KR',
            ),
          ),
        );
      }),
    );
  }
}

/// 🌼 인라인 형광펜 강조 텍스트
/// - 문자열 안에서 **이렇게** 감싼 부분만 형광펜 + 굵게
/// - backgroundColor 안 쓰고 CustomPainter로 박스 그림
class HighlightText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color highlightColor;
  final double verticalPadding;
  final double horizontalPadding;
  final double borderRadius;
  final TextAlign textAlign;

  const HighlightText({
    super.key,
    required this.text,
    this.style,
    this.highlightColor = const Color(0xFFFFF59D),
    this.verticalPadding = 4,
    this.horizontalPadding = 2,
    this.borderRadius = 6,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ??
        const TextStyle(
          fontFamily: 'NotoSansKR',
          fontSize: 14,
          height: 1.4,
          color: Colors.black87,
        );

    // 1) **볼드 구간** 파싱 (토큰 제거 + 범위 리스트)
    final parsed = _ParsedBold.fromSource(text);
    final plainText = parsed.plainText;
    final ranges = parsed.ranges;

    // ** 토큰이 하나도 없으면 그냥 Text로
    if (ranges.isEmpty) {
      return Text(
        plainText,
        style: baseStyle,
        softWrap: true,
        overflow: TextOverflow.visible,
        textAlign: textAlign,
        textWidthBasis: TextWidthBasis.parent,
      );
    }

    // 2) 굵기만 적용된 TextSpan 구성 (배경 없음)
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final range in ranges) {
      if (range.start > cursor) {
        spans.add(
          TextSpan(
            text: plainText.substring(cursor, range.start),
            style: baseStyle,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: plainText.substring(range.start, range.end),
          style: baseStyle.copyWith(fontWeight: FontWeight.w600),
        ),
      );
      cursor = range.end;
    }
    if (cursor < plainText.length) {
      spans.add(
        TextSpan(
          text: plainText.substring(cursor),
          style: baseStyle,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        var maxWidth = constraints.maxWidth;
        if (!constraints.hasBoundedWidth || maxWidth.isInfinite) {
          maxWidth = MediaQuery.of(context).size.width * 0.9;
        }

        return CustomPaint(
          painter: _InlineHighlightPainter(
            plainText: plainText,
            textStyle: baseStyle,
            highlightColor: highlightColor,
            verticalPadding: verticalPadding,
            horizontalPadding: horizontalPadding,
            borderRadius: borderRadius,
            maxWidth: maxWidth,
            ranges: ranges,
            textAlign: textAlign,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: RichText(
              text: TextSpan(children: spans),
              softWrap: true,
              overflow: TextOverflow.visible,
              textAlign: textAlign,
              textWidthBasis: TextWidthBasis.parent,
            ),
          ),
        );
      },
    );
  }
}

/// 🔹 plainText 기준으로 [start, end) 구간
class _HighlightRange {
  final int start;
  final int end;
  const _HighlightRange(this.start, this.end);
}

/// 🔹 원본 문자열에서 **토큰 제거 + 범위 생성
class _ParsedBold {
  final String plainText;
  final List<_HighlightRange> ranges;

  const _ParsedBold(this.plainText, this.ranges);

  factory _ParsedBold.fromSource(String src) {
    final buffer = StringBuffer();
    final ranges = <_HighlightRange>[];

    var readIndex = 0;
    var writeIndex = 0;

    while (readIndex < src.length) {
      // '**' 시작
      if (readIndex + 1 < src.length &&
          src[readIndex] == '*' &&
          src[readIndex + 1] == '*') {
        final endMarker = src.indexOf('**', readIndex + 2);
        if (endMarker == -1) {
          // 닫는 '**' 없으면 남은 거 통으로 붙이고 끝
          buffer.write(src.substring(readIndex));
          writeIndex += src.length - readIndex;
          break;
        }

        final inner = src.substring(readIndex + 2, endMarker);
        final start = writeIndex;
        buffer.write(inner);
        writeIndex += inner.length;
        final end = writeIndex;
        ranges.add(_HighlightRange(start, end));

        readIndex = endMarker + 2; // 닫는 '**' 뒤로 이동
      } else {
        buffer.write(src[readIndex]);
        readIndex++;
        writeIndex++;
      }
    }

    return _ParsedBold(buffer.toString(), ranges);
  }
}

/// 🔹 실제 줄바꿈 결과를 기반으로 형광펜 박스를 그리는 Painter
class _InlineHighlightPainter extends CustomPainter {
  final String plainText;
  final TextStyle textStyle;
  final Color highlightColor;
  final double verticalPadding;
  final double horizontalPadding;
  final double borderRadius;
  final double maxWidth;
  final List<_HighlightRange> ranges;
  final TextAlign textAlign;

  _InlineHighlightPainter({
    required this.plainText,
    required this.textStyle,
    required this.highlightColor,
    required this.verticalPadding,
    required this.horizontalPadding,
    required this.borderRadius,
    required this.maxWidth,
    required this.ranges,
    required this.textAlign,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (plainText.isEmpty || ranges.isEmpty) return;

    final textPainter = TextPainter(
      text: TextSpan(text: plainText, style: textStyle),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
      maxLines: null,
      textWidthBasis: TextWidthBasis.parent,
    )..layout(maxWidth: maxWidth);

    final paint = Paint()..color = highlightColor.withValues(alpha: 0.8);

    // 🔹 줄(line)별로 left/right를 합치기 위한 맵
    final Map<double, Rect> lineRects = {};

    for (final range in ranges) {
      final selection = TextSelection(
        baseOffset: range.start,
        extentOffset: range.end,
      );
      final boxes = textPainter.getBoxesForSelection(selection);

      for (final box in boxes) {
        // 같은 줄을 묶기 위한 key (top 좌표를 반올림해서 사용)
        final double lineKey = (box.top).roundToDouble();

        final rect = Rect.fromLTRB(
          box.left,
          box.top,
          box.right,
          box.bottom,
        );

        if (lineRects.containsKey(lineKey)) {
          final prev = lineRects[lineKey]!;
          // 🔹 같은 줄에 있던 박스들이면 좌우로 union
          lineRects[lineKey] = Rect.fromLTRB(
            prev.left < rect.left ? prev.left : rect.left,
            prev.top < rect.top ? prev.top : rect.top,
            prev.right > rect.right ? prev.right : rect.right,
            prev.bottom > rect.bottom ? prev.bottom : rect.bottom,
          );
        } else {
          lineRects[lineKey] = rect;
        }
      }
    }

    // 🔹 이제 줄마다 박스 하나씩만 그리기
    for (final rect in lineRects.values) {
      final padded = Rect.fromLTRB(
        rect.left - horizontalPadding,
        rect.top - verticalPadding,
        rect.right + horizontalPadding,
        rect.bottom + verticalPadding,
      );

      final rrect = RRect.fromRectAndRadius(
        padded,
        Radius.circular(borderRadius),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _InlineHighlightPainter oldDelegate) {
    return plainText != oldDelegate.plainText ||
        textStyle != oldDelegate.textStyle ||
        highlightColor != oldDelegate.highlightColor ||
        verticalPadding != oldDelegate.verticalPadding ||
        horizontalPadding != oldDelegate.horizontalPadding ||
        borderRadius != oldDelegate.borderRadius ||
        maxWidth != oldDelegate.maxWidth ||
        ranges.length != oldDelegate.ranges.length;
  }
}
