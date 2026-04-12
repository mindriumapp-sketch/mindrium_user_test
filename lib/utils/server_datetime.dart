DateTime? parseServerDateTime(
  dynamic value, {
  DateTime? fallback,
}) {
  if (value == null) return fallback?.toLocal();

  if (value is DateTime) {
    return value.toLocal();
  }

  if (value is String) {
    if (value.isEmpty) return fallback?.toLocal();
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed.toLocal();
    }
  }

  return fallback?.toLocal();
}

DateTime? parseServerDateOnly(
  dynamic value, {
  DateTime? fallback,
}) {
  if (value == null) {
    return fallback == null
        ? null
        : DateTime(fallback.year, fallback.month, fallback.day);
  }

  if (value is DateTime) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) {
      return fallback == null
          ? null
          : DateTime(fallback.year, fallback.month, fallback.day);
    }

    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
    if (match != null) {
      final year = int.tryParse(match.group(1)!);
      final month = int.tryParse(match.group(2)!);
      final day = int.tryParse(match.group(3)!);
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }
  }

  return fallback == null
      ? null
      : DateTime(fallback.year, fallback.month, fallback.day);
}

String formatServerDateOnly(DateTime value) {
  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
