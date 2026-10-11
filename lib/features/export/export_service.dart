import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/currencies.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/storage.dart';
import '../../state/stats.dart';

class ExportService {
  static final _ink = PdfColor.fromInt(0xFF0E0E0E);
  static final _lime = PdfColor.fromInt(0xFFC6F432);
  static final _muted = PdfColor.fromInt(0xFF8A8A86);
  static final _card = PdfColor.fromInt(0xFFF0F0EC);
  static final _red = PdfColor.fromInt(0xFFE5484D);

  /// Built-in PDF fonts only cover Latin-1; replace anything else so export never fails.
  static String _a(String s) => String.fromCharCodes(s.runes.map((r) {
        if (r == 0x2013 || r == 0x2014 || r == 0x2212) return 0x2D; // dashes, minus
        if (r == 0x00B7 || r == 0x2022) return 0x7C; // middle dot / bullet
        return r < 256 ? r : 0x3F;
      }));

  static String _safeName(String s) {
    final n = s.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim().replaceAll(' ', '_');
    return n.isEmpty ? 'trip' : n;
  }

  static Rect? _origin(BuildContext context) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) return box.localToGlobal(Offset.zero) & box.size;
    return null;
  }

  static Future<void> _share(BuildContext context, File file, String mime, String subject) async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: mime)],
      subject: subject,
      sharePositionOrigin: _origin(context),
    ));
  }

  // ─── CSV ───────────────────────────────────────────────────────────────────
  static String _csvCell(String v) {
    if (v.contains(RegExp(r'[",\n\r]'))) return '"${v.replaceAll('"', '""')}"';
    return v;
  }

  static String _csv(List<List<String>> rows) =>
      '﻿${rows.map((r) => r.map(_csvCell).join(',')).join('\r\n')}\r\n';

  static List<String> _row(Trip t, Expense e, Map<String, SpendCategory> cats, Currency c) => [
        DateFormat('yyyy-MM-dd').format(e.date),
        DateFormat('HH:mm').format(e.date),
        t.title,
        e.title,
        cats[e.categoryId]?.name ?? 'Other',
        e.amount.toStringAsFixed(c.decimals),
        c.code,
        t.memberName(e.paidBy),
        e.splitWith.isEmpty
            ? t.members.map((m) => m.name).join('; ')
            : e.splitWith.map(t.memberName).join('; '),
        e.note,
        e.photo == null ? '' : 'yes',
        e.isForeign ? e.origAmount!.toStringAsFixed(currencyFor(e.origCurrency!).decimals) : '',
        e.origCurrency ?? '',
      ];

  static const _header = [
    'Date', 'Time', 'Trip', 'Title', 'Category', 'Amount', 'Currency', 'Paid by', 'Split with',
    'Note', 'Receipt', 'Paid amount', 'Paid currency'
  ];

  static Future<void> shareCsv(
      BuildContext context, TripStats s, Money money, Map<String, SpendCategory> cats) async {
    final rows = [
      _header,
      for (final e in s.expenses.reversed) _row(s.trip, e, cats, money.c),
    ];
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/${_safeName(s.trip.title)}_expenses.csv');
    await f.writeAsString(_csv(rows));
    if (!context.mounted) return;
    await _share(context, f, 'text/csv', '${s.trip.title} expenses');
  }

  static Future<void> shareAllCsv(BuildContext context, List<Trip> trips, List<Expense> expenses,
      Map<String, SpendCategory> cats, Currency c) async {
    final byId = {for (final t in trips) t.id: t};
    final sorted = [...expenses]..sort((a, b) => a.date.compareTo(b.date));
    final rows = [
      _header,
      for (final e in sorted)
        if (byId[e.tripId] != null) _row(byId[e.tripId]!, e, cats, c),
    ];
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/travel_expenses_all.csv');
    await f.writeAsString(_csv(rows));
    if (!context.mounted) return;
    await _share(context, f, 'text/csv', 'All travel expenses');
  }

  // ─── Backup ────────────────────────────────────────────────────────────────
  /// Shares a full backup file; the user saves it to Files, iCloud Drive, Drive or email.
  static Future<void> shareBackup(BuildContext context, Storage db) async {
    final data = await db.exportAll();
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/expenses-backup-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json');
    await f.writeAsString(jsonEncode(data));
    if (!context.mounted) return;
    await _share(context, f, 'application/json', 'Expenses backup');
  }

  // ─── PDF ───────────────────────────────────────────────────────────────────
  static Future<void> sharePdf(
      BuildContext context, TripStats s, Money money, Map<String, SpendCategory> cats) async {
    final t = s.trip;
    final m = money.plain;
    final doc = pw.Document(title: '${t.title} report', author: 'Travel Expenses Manager');
    final dates = t.endDate == null
        ? 'From ${fmtShortYear(t.startDate)}'
        : '${fmtShortYear(t.startDate)} - ${fmtShortYear(t.endDate!)}';

    pw.Widget stat(String label, String value, {bool dark = false}) => pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            margin: const pw.EdgeInsets.only(right: 6),
            decoration: pw.BoxDecoration(
              color: dark ? _ink : _card,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(_a(value),
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold, color: dark ? _lime : _ink)),
              pw.SizedBox(height: 2),
              pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _muted)),
            ]),
          ),
        );

    pw.Widget section(String title) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
          child: pw.Text(title.toUpperCase(),
              style: pw.TextStyle(
                  fontSize: 9, color: _muted, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
        );

    pw.Widget bar(double frac, PdfColor color) => pw.Container(
          width: 160,
          height: 7,
          decoration: pw.BoxDecoration(color: _card, borderRadius: pw.BorderRadius.circular(4)),
          alignment: pw.Alignment.centerLeft,
          child: pw.Container(
            width: 160 * frac.clamp(0.02, 1).toDouble(),
            height: 7,
            decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(4)),
          ),
        );

    final maxDay = s.byDay.fold<double>(0, (a, e) => e.value > a ? e.value : a);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 36),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Travel Expenses Manager', style: pw.TextStyle(fontSize: 8, color: _muted)),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: _muted)),
      ]),
      build: (ctx) => [
        // Header
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('TRAVEL EXPENSE REPORT',
                  style: pw.TextStyle(
                      fontSize: 9, color: _muted, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
              pw.SizedBox(height: 4),
              pw.Text(_a(t.title),
                  style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: _ink)),
              pw.SizedBox(height: 2),
              pw.Text(_a('$dates  |  ${s.elapsedDays} days  |  ${s.expenses.length} expenses'),
                  style: pw.TextStyle(fontSize: 10, color: _muted)),
            ]),
          ),
          pw.Container(
            width: 36,
            height: 36,
            decoration: pw.BoxDecoration(color: _lime, borderRadius: pw.BorderRadius.circular(10)),
          ),
        ]),
        pw.SizedBox(height: 16),
        pw.Row(children: [
          stat('Total spent', m(s.spent), dark: true),
          if (s.budget != null) stat('Budget', m(s.budget!)),
          if (s.budget != null)
            stat(s.remaining! >= 0 ? 'Remaining' : 'Over budget', m(s.remaining!.abs())),
          stat('Average / day', m(s.avgPerDay)),
        ]),

        // Categories
        section('Spending by category'),
        for (final c in s.byCategory)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Row(children: [
              pw.SizedBox(
                  width: 110,
                  child: pw.Text(_a(c.category.name),
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
              bar(s.spent == 0 ? 0 : c.total / s.spent, c == s.byCategory.first ? _lime : _ink),
              pw.SizedBox(width: 10),
              pw.SizedBox(
                  width: 40,
                  child: pw.Text('${(s.spent == 0 ? 0 : c.total / s.spent * 100).toStringAsFixed(0)}%',
                      style: pw.TextStyle(fontSize: 9, color: _muted))),
              pw.Expanded(
                child: pw.Text(m(c.total),
                    textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10)),
              ),
            ]),
          ),

        // Daily
        section('Daily spending'),
        for (final d in s.byDay.where((e) => e.value > 0))
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(children: [
              pw.SizedBox(
                  width: 110,
                  child: pw.Text(DateFormat('EEE, d MMM').format(d.key),
                      style: const pw.TextStyle(fontSize: 9))),
              bar(maxDay == 0 ? 0 : d.value / maxDay,
                  (s.dailyBudget != null && d.value > s.dailyBudget!) ? _red : _ink),
              pw.Expanded(
                child: pw.Text(m(d.value),
                    textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9)),
              ),
            ]),
          ),
        if (s.dailyBudget != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text('Daily target: ${m(s.dailyBudget!)}. Red bars went over it.',
                style: pw.TextStyle(fontSize: 8, color: _muted)),
          ),

        // Split
        if (t.isGroup) ...[
          section('Group split'),
          pw.TableHelper.fromTextArray(
            headers: ['Person', 'Paid', 'Share', 'Balance'],
            data: [
              for (final b in s.balances)
                [_a(b.member.name), m(b.paid), m(b.share), '${b.balance >= 0 ? '+' : '-'}${m(b.balance.abs())}'],
            ],
            border: null,
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: _ink),
            cellStyle: const pw.TextStyle(fontSize: 9),
            rowDecoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _card, width: 0.8))),
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 8),
          if (s.settlements.isEmpty)
            pw.Text('Everyone is settled.', style: const pw.TextStyle(fontSize: 10)),
          for (final x in s.settlements)
            pw.Bullet(
              text: _a('${x.from.name} pays ${x.to.name}: ${m(x.amount)}'),
              style: const pw.TextStyle(fontSize: 10),
            ),
        ],

        // All expenses
        section('All expenses'),
        pw.TableHelper.fromTextArray(
          headers: [
            'Date',
            'Title',
            'Category',
            if (t.isGroup) 'Paid by',
            'Amount',
          ],
          data: [
            for (final e in s.expenses.reversed)
              [
                DateFormat('d MMM, HH:mm').format(e.date),
                _a([
                  e.title,
                  if (e.isForeign) 'Paid ${e.origAmount!.toStringAsFixed(currencyFor(e.origCurrency!).decimals)} ${e.origCurrency}',
                  if (e.note.isNotEmpty) e.note,
                ].where((x) => x.isNotEmpty).join('\n')),
                _a(cats[e.categoryId]?.name ?? 'Other'),
                if (t.isGroup) _a(t.memberName(e.paidBy)),
                m(e.amount),
              ],
          ],
          border: null,
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: pw.BoxDecoration(color: _ink),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          rowDecoration:
              pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _card, width: 0.8))),
          cellAlignments: {(t.isGroup ? 4 : 3): pw.Alignment.centerRight},
        ),
        pw.SizedBox(height: 10),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Text('Total  ', style: pw.TextStyle(fontSize: 11, color: _muted)),
          pw.Text(m(s.spent), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.SizedBox(height: 6),
        pw.Text('Generated ${DateFormat('d MMM y, HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 8, color: _muted)),
      ],
    ));

    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/${_safeName(t.title)}_report.pdf');
    await f.writeAsBytes(await doc.save());
    if (!context.mounted) return;
    await _share(context, f, 'application/pdf', '${t.title} expense report');
  }
}
