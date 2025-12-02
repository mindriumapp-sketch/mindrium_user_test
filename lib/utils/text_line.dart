import 'package:flutter/widgets.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';

/// Text wrapper that applies [protectKoreanWords] to avoid mid-word splits.
/// Mirrors the common [Text] API (including `.rich`) so it can act as a
/// drop-in replacement.
class TextLine extends StatelessWidget {
  const TextLine(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const TextLine.rich(
    this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  InlineSpan _protectSpan(InlineSpan span) {
    if (span is TextSpan) {
      return TextSpan(
        text: span.text != null ? protectKoreanWords(span.text!) : null,
        children:
            span.children?.map(_protectSpan).toList(growable: false),
        style: span.style,
        recognizer: span.recognizer,
        semanticsLabel: span.semanticsLabel != null
            ? protectKoreanWords(span.semanticsLabel!)
            : null,
        locale: span.locale,
        spellOut: span.spellOut,
        mouseCursor: span.mouseCursor,
      );
    }
    return span;
  }

  @override
  Widget build(BuildContext context) {
    if (textSpan != null) {
      return Text.rich(
        _protectSpan(textSpan!),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel != null
            ? protectKoreanWords(semanticsLabel!)
            : null,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }

    return Text(
      protectKoreanWords(data ?? ''),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel != null
          ? protectKoreanWords(semanticsLabel!)
          : null,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
