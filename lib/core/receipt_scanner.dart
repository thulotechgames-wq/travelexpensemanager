import 'dart:math';

import 'package:flutter/services.dart';

import 'format.dart';

/// One line of text found on a receipt, with its box (top-left origin, any unit).
class OcrLine {
  final String text;
  final double x, y, w, h;
  const OcrLine(this.text, this.x, this.y, this.w, this.h);
  double get cy => y + h / 2;
}

/// What we could read off a receipt. Any field may be missing.
class ReceiptGuess {
  final double? total;
  final DateTime? date;
  final String? merchant;
  const ReceiptGuess({this.total, this.date, this.merchant});
  bool get isEmpty => total == null && date == null && merchant == null;
}

/// Reads receipts on the device (Apple Vision on iOS, ML Kit on Android). Nothing is uploaded.
class ReceiptScanner {
  static const _channel = MethodChannel('expensetracker/receipt_text');

  static Future<ReceiptGuess> scan(String imagePath) async {
    try {
      final raw = await _channel.invokeListMethod<Map>('recognize', {'path': imagePath});
      final lines = [
        for (final m in raw ?? const <Map>[])
          OcrLine(
            m['text'] as String,
            (m['x'] as num).toDouble(),
            (m['y'] as num).toDouble(),
            (m['w'] as num).toDouble(),
            (m['h'] as num).toDouble(),
          ),
      ];
      return parse(lines);
    } on PlatformException {
      return const ReceiptGuess();
    } on MissingPluginException {
      return const ReceiptGuess();
    }
  }

  // ─── Parsing ───────────────────────────────────────────────────────────────

  /// Merges boxes that sit on the same printed row ("TOTAL" … "1,250.00") into one string.
  static List<String> rows(List<OcrLine> lines) {
    final sorted = [...lines]..sort((a, b) => a.cy.compareTo(b.cy));
    final out = <List<OcrLine>>[];
    for (final l in sorted) {
      final row = out.isEmpty ? null : out.last;
      if (row != null) {
        final ref = row.first;
        if ((l.cy - ref.cy).abs() < min(l.h, ref.h) * 0.6) {
          row.add(l);
          continue;
        }
      }
      out.add([l]);
    }
    return [
      for (final r in out) (r..sort((a, b) => a.x.compareTo(b.x))).map((l) => l.text).join('  '),
    ];
  }

  static ReceiptGuess parse(List<OcrLine> lines, {DateTime? now}) {
    final r = rows(lines);
    return ReceiptGuess(total: findTotal(r), date: findDate(r, now: now), merchant: findMerchant(r));
  }

  // Strongest wording first. Rows mentioning any of [_notTotal] are ignored.
  static final _totalWords = [
    RegExp(r'grand\s*total', caseSensitive: false),
    RegExp(r'(amount|balance|total)\s*(due|payable)|net\s*(amount|total|payable)|bill\s*amount|total\s*amount|amount\s*to\s*pay',
        caseSensitive: false),
    RegExp(r'\btotal\b|\btotal:|\bpayable\b', caseSensitive: false),
  ];
  static final _notTotal = RegExp(
      r'sub\s*-?\s*total|total\s*(qty|quantity|items?|savings?|discount|tax|vat)|\btax\b|\bvat\b|discount|change|tender|cash\s*paid|tip|points',
      caseSensitive: false);

  /// Money-looking numbers: 1,250.00 · 1.250,00 · 1250 · 12.5
  static final _amount = RegExp(r'(?<![\d.,])(\d{1,3}(?:[,.]\d{3})+|\d+)(?:[.,](\d{1,2}))?(?![\d.,]*\d)');

  static List<double> amountsIn(String row) {
    final out = <double>[];
    for (final m in _amount.allMatches(row)) {
      final whole = m.group(1)!.replaceAll(RegExp(r'[,.]'), '');
      if (whole.length > 7) continue; // phone numbers, invoice ids
      final v = double.tryParse('$whole.${m.group(2) ?? '0'}');
      if (v != null && v > 0) out.add(v);
    }
    return out;
  }

  static double? findTotal(List<String> rows) {
    for (final word in _totalWords) {
      final found = <double>[];
      for (var i = 0; i < rows.length; i++) {
        if (!word.hasMatch(rows[i]) || _notTotal.hasMatch(rows[i])) continue;
        var nums = amountsIn(rows[i]);
        // Amount printed on the line below the label.
        if (nums.isEmpty && i + 1 < rows.length) nums = amountsIn(rows[i + 1]);
        if (nums.isNotEmpty) found.add(nums.last);
      }
      if (found.isNotEmpty) return found.reduce(max);
    }
    // No label: the largest amount with decimals is usually the total.
    final decimals = RegExp(r'\d[.,]\d{2}(?!\d)');
    final candidates = [
      for (final row in rows)
        if (decimals.hasMatch(row) && !_notTotal.hasMatch(row)) ...amountsIn(row),
    ];
    return candidates.isEmpty ? null : candidates.reduce(max);
  }

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static DateTime? findDate(List<String> rows, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    DateTime? ok(int y, int m, int d) {
      if (y < 100) y += 2000;
      if (m < 1 || m > 12 || d < 1 || d > 31) return null;
      final dt = DateTime(y, m, d);
      if (dt.month != m) return null; // 31 Feb etc.
      // Receipts are recent. This also skips Bikram Sambat dates (year 2080+).
      final age = today.difference(dt).inDays;
      return age >= -1 && age <= 400 ? dt : null;
    }

    final iso = RegExp(r'\b(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\b');
    final dmy = RegExp(r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})\b');
    final named = RegExp(r'\b(\d{1,2})[ -]?([A-Za-z]{3})[a-z]*[ ,.-]*(\d{2,4})\b');
    final namedUs = RegExp(r'\b([A-Za-z]{3})[a-z]*[ .]+(\d{1,2}),?[ ]+(\d{2,4})\b');

    for (final row in rows) {
      for (final m in iso.allMatches(row)) {
        final d = ok(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
        if (d != null) return d;
      }
      for (final m in dmy.allMatches(row)) {
        final a = int.parse(m[1]!), b = int.parse(m[2]!), y = int.parse(m[3]!);
        // Day first unless that is impossible (most of the world prints day/month).
        final d = (b > 12 ? ok(y, a, b) : null) ?? ok(y, b, a) ?? ok(y, a, b);
        if (d != null) return d;
      }
      for (final m in named.allMatches(row)) {
        final mon = _months[m[2]!.toLowerCase()];
        if (mon == null) continue;
        final d = ok(int.parse(m[3]!), mon, int.parse(m[1]!));
        if (d != null) return d;
      }
      for (final m in namedUs.allMatches(row)) {
        final mon = _months[m[1]!.toLowerCase()];
        if (mon == null) continue;
        final d = ok(int.parse(m[3]!), mon, int.parse(m[2]!));
        if (d != null) return d;
      }
    }
    return null;
  }

  static final _notMerchant = RegExp(
      r'invoice|receipt|bill\b|tax|vat|pan\b|gst|tel|phone|mob|date|time|cashier|table|welcome|order|www\.|http|@|address|no\.',
      caseSensitive: false);

  /// The shop name is normally the first real words at the top of the receipt.
  static String? findMerchant(List<String> rows) {
    for (final row in rows.take(max(4, (rows.length * 0.25).ceil()))) {
      final t = row.trim();
      final letters = RegExp(r'[A-Za-z]').allMatches(t).length;
      if (letters < 3 || letters < t.length * 0.5 || _notMerchant.hasMatch(t)) continue;
      final name = t.length > 40 ? t.substring(0, 40).trim() : t;
      // "BHAT-BHATENI SUPERMARKET" → "Bhat-Bhateni Supermarket"
      if (name == name.toUpperCase()) {
        return name
            .toLowerCase()
            .replaceAllMapped(RegExp(r"(^|[\s\-&/'])([a-z])"), (m) => '${m[1]}${m[2]!.toUpperCase()}');
      }
      return name;
    }
    return null;
  }
}
