import 'package:opshub/core/utils/app_date_formatter.dart';

String formatEgp(int piastres, {bool withSuffix = false}) {
  final negative = piastres < 0;
  final value = piastres.abs();
  final whole = value ~/ 100;
  final fraction = value % 100;
  final amount =
      '${negative ? '-' : ''}${_groupThousands(whole)}${fraction == 0 ? '' : '.${fraction.toString().padLeft(2, '0')}'}';
  return withSuffix ? '$amount EGP' : amount;
}

/// Groups digits in threes from the RIGHT.
///
/// The previous lookahead (`(?=(\d{3})+(?!\d))`) also matched at index 0 whenever
/// the digit count was an exact multiple of three, so every such amount rendered
/// with a leading comma — `945000` became `,945,000`. Counting from the right
/// cannot produce a separator before the first digit.
String _groupThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// A compact EGP figure for tight chart labels: `14.2K`, `1.3M`, `840`.
///
/// Rounds to one significant fractional digit and drops a trailing `.0`, so a
/// bar's caption stays two–four characters wide however large the day. Negative
/// inputs are treated as zero — a day's takings are never negative.
String formatEgpCompact(int piastres) {
  final pounds = (piastres < 0 ? 0 : piastres) ~/ 100;
  if (pounds >= 1000000) return '${_trimTenth(pounds / 1000000)}M';
  if (pounds >= 1000) return '${_trimTenth(pounds / 1000)}K';
  return '$pounds';
}

String _trimTenth(double value) {
  final text = value.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

int? parseEgpToPiastres(String input) {
  final value = input.trim().replaceAll(',', '');
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(value);
  if (match == null) return null;
  final whole = int.tryParse(match.group(1)!);
  if (whole == null) return null;
  final decimals = (match.group(2) ?? '').padRight(2, '0');
  final fraction = decimals.isEmpty ? 0 : int.parse(decimals);
  return whole * 100 + fraction;
}

/// A `yyyyMMdd` business key as a date a human reads. Never show the raw key:
/// "20260805" appeared verbatim on tiles, history rows and the detail screen.
String formatBusinessDate(String businessDateKey) {
  final date = businessDateFromKey(businessDateKey);
  return date == null
      ? businessDateKey
      : AppDateFormatter.dayMonthYear(date);
}

/// A `yyyyMM` month key as a readable month.
String formatBusinessMonth(String monthKey) {
  final date = businessMonthFromKey(monthKey);
  return date == null ? monthKey : AppDateFormatter.monthYear(date);
}

/// Parses a `yyyyMMdd` business key into a local [DateTime] for display only.
/// Null when the key is malformed — callers fall back to the raw string.
DateTime? businessDateFromKey(String businessDateKey) {
  if (!RegExp(r'^\d{8}$').hasMatch(businessDateKey)) return null;
  return DateTime(
    int.parse(businessDateKey.substring(0, 4)),
    int.parse(businessDateKey.substring(4, 6)),
    int.parse(businessDateKey.substring(6, 8)),
  );
}

/// Parses a `yyyyMM` month key into a local [DateTime] for display only.
DateTime? businessMonthFromKey(String monthKey) {
  if (!RegExp(r'^\d{6}$').hasMatch(monthKey)) return null;
  return DateTime(
    int.parse(monthKey.substring(0, 4)),
    int.parse(monthKey.substring(4, 6)),
  );
}
