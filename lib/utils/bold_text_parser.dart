import 'package:flutter/material.dart';

List<TextSpan> parseBoldText(String text) {
  final regex = RegExp(r'\*\*(.*?)\*\*');
  final spans = <TextSpan>[];
  int currentIndex = 0;

  for (final match in regex.allMatches(text)) {
    if (match.start > currentIndex) {
      spans.add(TextSpan(text: text.substring(currentIndex, match.start)));
    }
    spans.add(TextSpan(
      text: match.group(1),
      style: const TextStyle(fontWeight: FontWeight.bold),
    ));
    currentIndex = match.end;
  }

  if (currentIndex < text.length) {
    spans.add(TextSpan(text: text.substring(currentIndex)));
  }

  return spans;
}