import 'dart:convert';
import 'dart:io';

import 'package:expensetracker/core/format.dart';
import 'package:expensetracker/core/receipt_scanner.dart';
import 'package:expensetracker/data/models.dart';
import 'package:expensetracker/data/storage.dart';
import 'package:expensetracker/state/stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds OCR lines top to bottom; a row can hold a left and right box.
List<OcrLine> receipt(List<List<String>> rows) => [
      for (var i = 0; i < rows.length; i++)
        for (var j = 0; j < rows[i].length; j++) OcrLine(rows[i][j], j * 200.0, i * 30.0, 150, 20),
    ];

void main() {
  final now = DateTime(2026, 10, 6);
  final cats = {for (final c in presetCategories) c.id: c};

  group('receipt parsing', () {
    test('label and amount in separate boxes on the same row', () {
      final g = ReceiptScanner.parse(
          receipt([
            ['BHAT-BHATENI SUPERMARKET'],
            ['PAN: 301234567'],
            ['Date: 05/10/2026', '14:32'],
            ['Milk 2 x 110.00', '220.00'],
            ['Sub Total', '1,180.00'],
            ['VAT 13%', '153.40'],
            ['Grand Total', '1,333.40'],
            ['Cash', '1,500.00'],
            ['Change', '166.60'],
          ]),
          now: now);
      expect(g.total, 1333.40);
      expect(g.date, DateTime(2026, 10, 5));
      expect(g.merchant, 'Bhat-Bhateni Supermarket');
    });

    test('amount printed on the line below the label', () {
      final g = ReceiptScanner.parse(receipt([
        ['Cafe Mitra'],
        ['TOTAL'],
        ['Rs. 850'],
      ]), now: now);
      expect(g.total, 850);
      expect(g.merchant, 'Cafe Mitra');
    });

    test('European decimals and ISO date', () {
      final g = ReceiptScanner.parse(
          receipt([
            ['Boulangerie Paul'],
            ['2026-09-30 08:12'],
            ['TOTAL EUR', '12,50'],
          ]),
          now: now);
      expect(g.total, 12.5);
      expect(g.date, DateTime(2026, 9, 30));
    });

    test('no label falls back to the largest decimal amount', () {
      expect(ReceiptScanner.findTotal(['Tea 40.00', 'Momo 180.00', 'Tel 9841234567']), 180);
    });

    test('ignores Bikram Sambat and far-off dates', () {
      expect(ReceiptScanner.findDate(['Miti: 2083/06/19'], now: now), isNull);
      expect(ReceiptScanner.findDate(['12 Mar 2019'], now: now), isNull);
      expect(ReceiptScanner.findDate(['Sep 28, 2026'], now: now), DateTime(2026, 9, 28));
    });

    test('dates are not mistaken for amounts', () {
      expect(ReceiptScanner.amountsIn('05.10.2026'), isEmpty);
    });
  });

  group('safe to spend today', () {
    final today = dateOnly(DateTime.now());
    Trip trip({double budget = 1000}) => Trip(
          id: 't',
          title: 'Pokhara',
          budget: budget,
          startDate: today.subtract(const Duration(days: 5)),
          endDate: today.add(const Duration(days: 4)), // 5 days left including today
          createdAt: today,
        );
    Expense spend(double amount, DateTime date) => Expense(
          id: '$amount$date',
          tripId: 't',
          title: 'x',
          amount: amount,
          categoryId: 'food',
          date: date,
          createdAt: date,
        );

    test('splits what was left this morning over the remaining days', () {
      final s = TripStats.compute(trip(), [
        spend(500, today.subtract(const Duration(days: 2))),
        spend(40, today.add(const Duration(hours: 9))),
      ], cats);
      expect(s.todayAllowance, 100); // (1000 − 500) / 5
      expect(s.safeToday, 60);
    });

    test('overspending today lowers tomorrow', () {
      final s = TripStats.compute(trip(), [spend(300, today.add(const Duration(hours: 9)))], cats);
      expect(s.safeToday, -100); // allowance 200
      expect(s.tomorrowAllowance, 175); // 700 / 4
    });

    test('closed trips and trips without budget have no safe amount', () {
      expect(TripStats.compute(trip(budget: 0), [], cats).safeToday, isNull);
      expect(TripStats.compute(trip().copyWith(closed: true), [], cats).safeToday, isNull);
    });
  });

  test('foreign expenses keep the original amount and survive storage', () {
    final e = Expense(
      id: 'e',
      tripId: 't',
      title: 'Taxi',
      amount: 1452,
      origCurrency: 'EUR',
      origAmount: 10,
      categoryId: 'transport',
      date: now,
      createdAt: now,
    );
    final back = Expense.fromJson(e.toJson());
    expect(back.isForeign, isTrue);
    expect(back.rate, 145.2);
    expect(back.copyWith(clearForeign: true).isForeign, isFalse);
    // Old saved data without the new fields still loads.
    expect(Expense.fromJson(e.toJson()..remove('origCurrency')..remove('origAmount')).isForeign,
        isFalse);
  });

  test('backup restores trips, expenses, settings and receipts', () async {
    final tmp = await Directory.systemTemp.createTemp('backup_test');
    final db = await Storage.openAt(tmp);
    final trip = Trip(id: 't', title: 'Pokhara', budget: 500, startDate: now, createdAt: now);
    await db.putTrip(trip);
    await db.putExpense(Expense(
        id: 'e',
        tripId: 't',
        title: 'Boat',
        amount: 7.5,
        origCurrency: 'NPR',
        origAmount: 1000,
        categoryId: 'activity',
        date: now,
        createdAt: now,
        photo: 'r.jpg'));
    await db.saveSettings(const AppSettings(onboarded: true, currency: 'USD', rates: {'NPR': 0.0075}));
    await db.receiptFile('r.jpg').writeAsBytes([1, 2, 3]);

    // Through JSON text, like the real file.
    final backup = Map<String, dynamic>.from(jsonDecode(jsonEncode(await db.exportAll())) as Map);
    expect(Storage.inspectBackup(backup).expenses, 1);

    await db.wipe();
    expect(db.loadTrips(), isEmpty);
    await db.importAll(backup);

    expect(db.loadTrips().single.title, 'Pokhara');
    expect(db.loadExpenses().single.origAmount, 1000);
    expect(db.loadSettings().rates['NPR'], 0.0075);
    expect(await db.receiptFile('r.jpg').readAsBytes(), [1, 2, 3]);
    expect(() => Storage.inspectBackup({'format': 'other'}), throwsFormatException);
    await tmp.delete(recursive: true);
  });
}
