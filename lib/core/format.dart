import 'dart:math';

import 'package:intl/intl.dart';

import 'currencies.dart';

class Money {
  final Currency c;
  Money(this.c);

  late final NumberFormat _full = NumberFormat.currency(
    symbol: c.symbol.length > 1 ? '${c.symbol} ' : c.symbol,
    decimalDigits: c.decimals,
  );
  late final NumberFormat _whole = NumberFormat.currency(
    symbol: c.symbol.length > 1 ? '${c.symbol} ' : c.symbol,
    decimalDigits: 0,
  );
  late final NumberFormat _compact = NumberFormat.compact();
  late final NumberFormat _plain = NumberFormat.decimalPatternDigits(decimalDigits: c.decimals);

  /// Full amount: $1,234.50. Drops decimals for whole numbers.
  String call(double v) => (v == v.roundToDouble() ? _whole : _full).format(v);

  /// Always with decimals.
  String exact(double v) => _full.format(v);

  /// For tight spaces and axis labels: $1.2K
  String compact(double v) {
    if (v.abs() < 1000) return call(v.roundToDouble());
    final s = c.symbol.length > 1 ? '${c.symbol} ' : c.symbol;
    return '$s${_compact.format(v)}';
  }

  /// No symbol, used by PDF/CSV: "1,234.50 NPR"
  String plain(double v) => '${_plain.format(v)} ${c.code}';
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

DateTime parseDayKey(String k) => DateTime.parse(k);

/// Calendar-day difference (b - a), safe across daylight-saving changes.
int dayDiff(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day)
    .difference(DateTime.utc(a.year, a.month, a.day))
    .inDays;

String fmtDay(DateTime d) {
  final today = dateOnly(DateTime.now());
  final diff = dayDiff(d, today);
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (d.year == today.year) return DateFormat('EEE, d MMM').format(d);
  return DateFormat('EEE, d MMM y').format(d);
}

String fmtShort(DateTime d) => DateFormat('d MMM').format(d);
String fmtShortYear(DateTime d) => DateFormat('d MMM y').format(d);
String fmtTime(DateTime d) => DateFormat('h:mm a').format(d);

/// Days in the inclusive range [a, b].
int daysBetween(DateTime a, DateTime b) => dayDiff(a, b).abs() + 1;

/// Evaluates simple keypad expressions like "120+45.5-10".
double evalExpr(String s) {
  if (s.isEmpty) return 0;
  double total = 0;
  String num = '';
  int sign = 1;
  for (final ch in s.split('')) {
    if (ch == '+' || ch == '−' || ch == '-') {
      total += sign * (double.tryParse(num) ?? 0);
      num = '';
      sign = ch == '+' ? 1 : -1;
    } else {
      num += ch;
    }
  }
  total += sign * (double.tryParse(num) ?? 0);
  return max(0, total);
}

String newId() {
  final r = Random();
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${r.nextInt(1 << 32).toRadixString(36)}';
}
